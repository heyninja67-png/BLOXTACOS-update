extends Node3D

const PLAYER_SCRIPT := preload("res://scripts/player_controller.gd")
const JOYSTICK_SCRIPT := preload("res://scripts/mobile_joystick.gd")
const AVATAR_PREVIEW_SCRIPT := preload("res://scripts/avatar_preview.gd")
const CUSTOMER_SCRIPT := preload("res://scripts/pizza_customer.gd")
const WORKER_SCRIPT := preload("res://scripts/pizza_worker.gd")
const TACO_LOGO := preload("res://assets/bloxtacos_taco.png")
const SAVE_PATH := "user://bloxtacos_profile.cfg"

const CLASSIC_GREEN := Color("#6e9d45")
const CLASSIC_BLUE := Color("#1769aa")
const PANEL_WHITE := Color("#f5f7fa")
const TEXT_DARK := Color("#273746")

var _player: ClassicPlayer
var _joystick: MobileJoystick
var _mouse_look_active := false
var _world_root: Node3D
var _loading_layer: CanvasLayer
var _loading_overlay: Control
var _loading_bar: ProgressBar
var _loading_status_label: Label
var _loading_paths: Array[String] = []
var _loading_finished: Dictionary = {}
var _loaded_avatar_resources: Dictionary = {}
var _startup_ready := false
var _top_bar: PanelContainer
var _nav_bar: PanelContainer
var _player_list_panel: PanelContainer
var _player_list_entries: VBoxContainer
var _network_status_label: Label
var _network_address_input: LineEdit
var _vehicle_button: Button
var _remote_player_nodes: Dictionary = {}
var _network_send_clock := 0.0
var _role_button: Button
var _auto_rotate := false
var _fullscreen_enabled := false
var _pizza_oven_timer := 0.0
var _pizza_oven_ready := false
var _pizza_role_index := 0
const PIZZA_ROLES := ["Funcionário", "Caixa", "Cozinheiro", "Entregador"]
var _canvas: CanvasLayer
var _ui_root: Control
var _page_panel: PanelContainer
var _page_content: VBoxContainer
var _wallet_label: Label
var _purchase_dialog: ConfirmationDialog
var _pending_purchase_id := ""
var _chat_log: RichTextLabel
var _chat_input: LineEdit
var _chat_panel: PanelContainer
var _round_label: Label
var _mode_hint: Label
var _interaction_button: Button
var _game_hud_controls: Array[Control] = []
var _active_page := "home"
var _current_mode := "classic"
var _wallet := 100
var _owned_items: Array[String] = []
var _equipped_items: Array[String] = []
var _selected_avatar := "noob"
var _pizza_stage := 0
var _pizza_orders := 0
var _pizza_tips := 0
var _deliveries_completed := 0
var _pizza_delivery_active := false
var _pizza_delivery_target := Vector3.ZERO
var _delivery_marker: Node3D
var _vehicle_active := false
var _round_active := false
var _round_remaining := 60.0
var _disaster_kind := "flood"
var _disaster_delay := 5.0
var _disaster_debris: Array[RigidBody3D] = []
var _debris_triggered := false
var _water: MeshInstance3D
var _tornado_visual: Node3D
var _water_start_y := -3.0
var _water_level_speed := 0.22
var _weather_clock := 0.0
var _chat_messages: Array[String] = []

const CATALOG := [
	{"id":"classic_cap", "name":"Boné Clássico", "description":"Um boné azul retrô.", "price":15, "color":Color("#2874bd"), "category":"Chapéus"},
	{"id":"retro_shades", "name":"Óculos Retrô", "description":"Lentes escuras de estilo antigo.", "price":20, "color":Color("#2d3540"), "category":"Rostos"},
	{"id":"gold_crown", "name":"Coroa Dourada", "description":"Uma coroa brilhante.", "price":35, "color":Color("#f2c64b"), "category":"Chapéus"},
	{"id":"green_visor", "name":"Viseira Verde", "description":"Visual esportivo clássico.", "price":15, "color":Color("#35ad70"), "category":"Chapéus"},
	{"id":"red_backpack", "name":"Mochila Vermelha", "description":"Para levar suas coisas pelo mapa.", "price":30, "color":Color("#c34a42"), "category":"Acessórios"},
	{"id":"star_halo", "name":"Auréola Estelar", "description":"Um aro dourado sobre a cabeça.", "price":25, "color":Color("#f5d65a"), "category":"Acessórios"},
	{"id":"headphones", "name":"Fones Azuis", "description":"Fones para explorar com estilo.", "price":25, "color":Color("#3e6fbd"), "category":"Acessórios"},
	{"id":"classic_scarf", "name":"Cachecol Vermelho", "description":"Um toque de cor para o avatar.", "price":10, "color":Color("#b33f3f"), "category":"Roupas"},
	{"id":"gold_chain", "name":"Corrente Dourada", "description":"Acessório dourado simples.", "price":20, "color":Color("#f3c64e"), "category":"Acessórios"},
	{"id":"blue_tee", "name":"Emblema Azul", "description":"Um detalhe azul no torso.", "price":12, "color":Color("#2f79d0"), "category":"Roupas"}
]

func _ready() -> void:
	_setup_input_map()
	_load_profile()
	NetworkManager.set_local_profile("BloxPlayer", _selected_avatar, _equipped_items)
	NetworkManager.roster_changed.connect(_on_network_roster_changed)
	NetworkManager.player_state_changed.connect(_on_network_player_state)
	NetworkManager.chat_received.connect(_on_network_chat_received)
	NetworkManager.status_changed.connect(_on_network_status_changed)
	NetworkManager.experience_changed.connect(_on_network_experience_changed)
	if NetworkManager.is_dedicated_server():
		_startup_ready = true
		_build_environment()
		_build_classic_yard()
		print("BloxTacos dedicated server ready • UDP multiplayer active.")
		return
	_apply_screen_orientation(false)
	_build_loading_screen()
	_begin_startup_loading()

func _process(delta: float) -> void:
	if not _startup_ready:
		_update_startup_loading()
		return
	if _player != null and _joystick != null:
		_player.set_joystick_input(_joystick.direction)
	if _player != null and NetworkManager.is_online() and _active_page == "none":
		_network_send_clock += delta
		if _network_send_clock >= 0.10:
			_network_send_clock = 0.0
			NetworkManager.submit_local_state(_player.global_position, _player.get_network_yaw(), _selected_avatar)
	for peer_id in _remote_player_nodes.keys():
		var remote: Dictionary = _remote_player_nodes[peer_id]
		var avatar_node: Node3D = remote.get("node")
		if is_instance_valid(avatar_node):
			var previous_position := avatar_node.position
			var target_position: Vector3 = remote.get("target_position", avatar_node.position)
			avatar_node.position = avatar_node.position.lerp(target_position, clampf(delta * 14.0, 0.0, 1.0))
			avatar_node.rotation.y = lerp_angle(avatar_node.rotation.y, float(remote.get("target_yaw", 0.0)), clampf(delta * 12.0, 0.0, 1.0))
			var remote_speed := previous_position.distance_to(avatar_node.position) / maxf(delta, 0.001)
			var gait_clock := float(remote.get("gait_clock", 0.0)) + delta * clampf(remote_speed, 0.0, 9.0) * 1.6
			remote["gait_clock"] = gait_clock
			var visual := avatar_node.get_node_or_null("AvatarVisual") as Node3D
			if visual != null:
				_animate_network_avatar(visual, String(remote.get("avatar", "noob")), gait_clock, remote_speed)
			_remote_player_nodes[peer_id] = remote
	# Opening the menu pauses local round and oven timers, matching a classic pause menu.
	if _active_page == "none" and _round_active:
		_update_disaster(delta)
	if _active_page == "none" and _current_mode == "pizza" and _mode_hint != null:
		if _pizza_oven_timer > 0.0:
			_pizza_oven_timer = maxf(0.0, _pizza_oven_timer - delta)
			if _pizza_oven_timer == 0.0:
				_pizza_oven_ready = true
				_add_chat_message("Cozinha", "A pizza saiu do forno. Retire e leve para entrega!")
		_update_pizza_hint()

func _unhandled_input(event: InputEvent) -> void:
	if _player == null or _active_page != "none":
		return
	if event is InputEventScreenDrag:
		var screen_size := get_viewport().get_visible_rect().size
		if event.position.x > screen_size.x * 0.38 and event.position.y < screen_size.y - 145.0:
			_player.add_look_input(event.relative)
	elif event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_RIGHT:
		_mouse_look_active = event.pressed
	elif event is InputEventMouseMotion and _mouse_look_active:
		_player.add_look_input(event.relative)
	elif event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_ESCAPE and _active_page == "none":
			_open_page("home")
		elif event.keycode == KEY_ENTER and _active_page == "none" and _current_mode == "pizza":
			_pizza_interact()


func _build_loading_screen() -> void:
	_loading_layer = CanvasLayer.new()
	_loading_layer.name = "BloxTacosBootLayer"
	_loading_layer.layer = 100
	add_child(_loading_layer)
	_loading_overlay = Control.new()
	_loading_overlay.name = "BloxTacosLoadingScreen"
	_loading_overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_loading_overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	_loading_layer.add_child(_loading_overlay)
	var background := ColorRect.new()
	background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	background.color = Color("#123d61")
	_loading_overlay.add_child(background)
	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_loading_overlay.add_child(center)
	var stack := VBoxContainer.new()
	stack.custom_minimum_size = Vector2(320, 0)
	stack.add_theme_constant_override("separation", 18)
	center.add_child(stack)
	var logo := TextureRect.new()
	logo.texture = TACO_LOGO
	logo.custom_minimum_size = Vector2(176, 176)
	logo.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	logo.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	logo.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	stack.add_child(logo)
	var title := Label.new()
	title.text = "BloxTacos"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 34)
	title.add_theme_color_override("font_color", Color.WHITE)
	stack.add_child(title)
	_loading_status_label = Label.new()
	_loading_status_label.text = "Preparando avatares clássicos…"
	_loading_status_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_loading_status_label.add_theme_font_size_override("font_size", 14)
	_loading_status_label.add_theme_color_override("font_color", Color("#d4e8f5"))
	stack.add_child(_loading_status_label)
	_loading_bar = ProgressBar.new()
	_loading_bar.custom_minimum_size = Vector2(300, 18)
	_loading_bar.min_value = 0.0
	_loading_bar.max_value = 100.0
	_loading_bar.value = 0.0
	_loading_bar.show_percentage = true
	stack.add_child(_loading_bar)
	var footer := Label.new()
	footer.text = "EXPERIÊNCIAS CLÁSSICAS • PROJETO INDEPENDENTE"
	footer.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	footer.add_theme_font_size_override("font_size", 10)
	footer.add_theme_color_override("font_color", Color("#a8c9df"))
	stack.add_child(footer)
	var tween := create_tween().set_loops()
	tween.tween_property(logo, "rotation", 0.06, 0.75)
	tween.tween_property(logo, "rotation", -0.06, 0.75)

func _begin_startup_loading() -> void:
	_loading_paths = ["res://assets/avatars/noob_r6.glb", "res://assets/avatars/bacon_hair.glb"]
	for resource_path in _loading_paths:
		var request_error := ResourceLoader.load_threaded_request(resource_path)
		if request_error != OK:
			_loading_finished[resource_path] = true
			push_warning("Não foi possível iniciar a carga em segundo plano de: " + resource_path)

func _update_startup_loading() -> void:
	if _loading_paths.is_empty():
		_finish_startup()
		return
	var progress_sum := 0.0
	var completed := 0
	for resource_path in _loading_paths:
		if _loading_finished.has(resource_path):
			progress_sum += 1.0
			completed += 1
			continue
		var progress: Array = []
		var status := ResourceLoader.load_threaded_get_status(resource_path, progress)
		if status == ResourceLoader.THREAD_LOAD_LOADED:
			_loaded_avatar_resources[resource_path] = ResourceLoader.load_threaded_get(resource_path)
			_loading_finished[resource_path] = true
			progress_sum += 1.0
			completed += 1
		elif status == ResourceLoader.THREAD_LOAD_FAILED or status == ResourceLoader.THREAD_LOAD_INVALID_RESOURCE:
			_loading_finished[resource_path] = true
			progress_sum += 1.0
			completed += 1
			push_warning("Falha ao carregar recurso: " + resource_path)
		else:
			progress_sum += float(progress[0]) if not progress.is_empty() else 0.0
	if _loading_bar != null:
		_loading_bar.value = (progress_sum / float(_loading_paths.size())) * 100.0
	if completed >= _loading_paths.size():
		if _loading_status_label != null:
			_loading_status_label.text = "Finalizando o mundo…"
		_finish_startup()

func _finish_startup() -> void:
	if _startup_ready:
		return
	_startup_ready = true
	_build_environment()
	_build_classic_yard()
	_spawn_player()
	_build_hud()
	_open_page("home")
	_on_network_roster_changed(NetworkManager.get_roster())
	_add_chat_message("BloxTacos", "Bem-vindo! O chat envia mensagens pela rede quando você se conecta a um servidor.")
	if _loading_layer != null:
		_loading_layer.queue_free()
	_loading_layer = null
	_loading_overlay = null
	print("BloxTacos pronto: recursos carregados, avatares GLB e experiências locais.")

func _apply_screen_orientation(in_game: bool) -> void:
	if not (OS.has_feature("android") or OS.has_feature("ios")):
		return
	var orientation: int
	if _auto_rotate:
		orientation = DisplayServer.SCREEN_SENSOR_LANDSCAPE if in_game else DisplayServer.SCREEN_SENSOR_PORTRAIT
	else:
		orientation = DisplayServer.SCREEN_LANDSCAPE if in_game else DisplayServer.SCREEN_PORTRAIT
	DisplayServer.screen_set_orientation(orientation)

func _set_auto_rotate(enabled: bool) -> void:
	_auto_rotate = enabled
	_save_profile()
	_apply_screen_orientation(_active_page == "none")

func _set_fullscreen(enabled: bool) -> void:
	_fullscreen_enabled = enabled
	if not OS.has_feature("android") and not OS.has_feature("ios"):
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN if enabled else DisplayServer.WINDOW_MODE_WINDOWED)
	_save_profile()

func _setup_input_map() -> void:
	_add_key_action("move_forward", KEY_W)
	_add_key_action("move_forward", KEY_UP)
	_add_key_action("move_back", KEY_S)
	_add_key_action("move_back", KEY_DOWN)
	_add_key_action("move_left", KEY_A)
	_add_key_action("move_left", KEY_LEFT)
	_add_key_action("move_right", KEY_D)
	_add_key_action("move_right", KEY_RIGHT)
	_add_key_action("jump", KEY_SPACE)
	_add_key_action("respawn", KEY_R)

func _add_key_action(action_name: StringName, keycode: Key) -> void:
	if not InputMap.has_action(action_name):
		InputMap.add_action(action_name)
	var key_event := InputEventKey.new()
	key_event.physical_keycode = keycode
	if not InputMap.action_has_event(action_name, key_event):
		InputMap.action_add_event(action_name, key_event)

func _load_profile() -> void:
	var config := ConfigFile.new()
	if config.load(SAVE_PATH) == OK:
		_wallet = int(config.get_value("profile", "wallet", 100))
		_owned_items.clear()
		for saved_item in config.get_value("profile", "owned_items", []):
			_owned_items.append(String(saved_item))
		_equipped_items.clear()
		for saved_item in config.get_value("profile", "equipped_items", []):
			_equipped_items.append(String(saved_item))
		_selected_avatar = String(config.get_value("profile", "avatar", "noob"))
		_auto_rotate = bool(config.get_value("profile", "auto_rotate", false))
		_fullscreen_enabled = bool(config.get_value("profile", "fullscreen", false))
		_pizza_orders = int(config.get_value("profile", "pizza_orders", 0))
		_pizza_tips = int(config.get_value("profile", "pizza_tips", 0))
		_deliveries_completed = int(config.get_value("profile", "deliveries_completed", 0))
	else:
		_wallet = 100
		_owned_items = []
		_equipped_items = []
		_selected_avatar = "noob"
		_auto_rotate = false
		_fullscreen_enabled = false
		_pizza_orders = 0
		_pizza_tips = 0
		_deliveries_completed = 0
	if not ["noob", "bacon"].has(_selected_avatar):
		_selected_avatar = "noob"
	_save_profile()

func _save_profile() -> void:
	var config := ConfigFile.new()
	config.set_value("profile", "wallet", _wallet)
	config.set_value("profile", "owned_items", _owned_items)
	config.set_value("profile", "equipped_items", _equipped_items)
	config.set_value("profile", "avatar", _selected_avatar)
	config.set_value("profile", "auto_rotate", _auto_rotate)
	config.set_value("profile", "fullscreen", _fullscreen_enabled)
	config.set_value("profile", "pizza_orders", _pizza_orders)
	config.set_value("profile", "pizza_tips", _pizza_tips)
	config.set_value("profile", "deliveries_completed", _deliveries_completed)
	config.save(SAVE_PATH)

func _build_environment() -> void:
	var world_environment := WorldEnvironment.new()
	var environment := Environment.new()
	environment.background_mode = Environment.BG_SKY
	var sky := Sky.new()
	var sky_material := ProceduralSkyMaterial.new()
	sky_material.sky_top_color = Color("#477eb0")
	sky_material.sky_horizon_color = Color("#c4d6e7")
	sky.sky_material = sky_material
	environment.sky = sky
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.ambient_light_color = Color("#d7e3ed")
	environment.ambient_light_energy = 0.76
	environment.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	world_environment.environment = environment
	add_child(world_environment)
	var sun := DirectionalLight3D.new()
	sun.name = "ClassicSun"
	sun.rotation_degrees = Vector3(-48.0, -32.0, 0.0)
	sun.light_energy = 1.15
	sun.shadow_enabled = true
	add_child(sun)

func _build_classic_yard() -> void:
	_current_mode = "classic"
	_clear_world()
	_world_root = Node3D.new()
	_world_root.name = "ClassicYardWorld"
	add_child(_world_root)
	_add_baseplate(_world_root, 64.0, CLASSIC_GREEN)
	_add_block(_world_root, "WelcomeBlue", Vector3(-9, 1, -10), Vector3(5, 2, 2), Color("#267ac0"))
	_add_block(_world_root, "WelcomeRed", Vector3(-14, 1, -10), Vector3(2, 2, 2), Color("#c94a40"))
	_add_block(_world_root, "WelcomeYellow", Vector3(-4, 1, -10), Vector3(2, 2, 2), Color("#e5b83c"))
	for i in range(5):
		_add_block(_world_root, "ObbyStep_%02d" % i, Vector3(7.0 + i * 4.0, 0.7 + i * 0.62, -12), Vector3(3, 0.5, 3), [Color("#e75a4f"), Color("#e6b641"), Color("#438bd0"), Color("#59a75d"), Color("#8a67ba")][i])
	_add_block(_world_root, "TowerRed", Vector3(-20, 1.0, 8), Vector3(4, 2, 4), Color("#c94a40"))
	_add_block(_world_root, "TowerBlue", Vector3(-20, 3.1, 8), Vector3(3.2, 2.2, 3.2), Color("#267ac0"))
	_add_block(_world_root, "TowerYellow", Vector3(-20, 5.35, 8), Vector3(2.4, 2.3, 2.4), Color("#e5b83c"))
	_create_tree(_world_root, Vector3(20, 0, 20))
	_create_tree(_world_root, Vector3(25, 0, 15))
	_create_tree(_world_root, Vector3(-25, 0, -19))
	_create_sign(_world_root, Vector3(0, 0, -5), "BLOXTACOS  •  CLASSIC YARD")
	_reset_player_spawn(Vector3(0, 0.2, 5))

func _build_natural_disaster_world() -> void:
	_round_active = false
	_current_mode = "disaster"
	_clear_world()
	_world_root = Node3D.new()
	_world_root.name = "NaturalDisastersWorld"
	add_child(_world_root)
	_add_baseplate(_world_root, 72.0, Color("#60934b"))
	_create_sign(_world_root, Vector3(0, 0, -28), "BLOXTACOS  •  NATURAL DISASTERS")
	# Beach hut and safe platforms.
	_add_block(_world_root, "BeachHouseFloor", Vector3(-13, 0.45, -3), Vector3(10, 0.9, 8), Color("#c6a36b"))
	_add_block(_world_root, "BeachHouseBack", Vector3(-13, 3.0, 1), Vector3(10, 5, 0.5), Color("#e8e0d2"))
	_add_block(_world_root, "BeachHouseLeft", Vector3(-18, 3.0, -3), Vector3(0.5, 5, 8), Color("#e8e0d2"))
	_add_block(_world_root, "BeachHouseRight", Vector3(-8, 3.0, -3), Vector3(0.5, 5, 8), Color("#e8e0d2"))
	_add_block(_world_root, "BeachRoof", Vector3(-13, 5.8, -3), Vector3(11, 0.8, 9), Color("#b44a3d"))
	# Main tower with climbable block steps.
	_add_block(_world_root, "SurvivalTower", Vector3(12, 5, -4), Vector3(5, 10, 5), Color("#497eb3"))
	for step in range(6):
		_add_block(_world_root, "TowerStep_%02d" % step, Vector3(8.0 + float(step) * 1.1, 0.7 + float(step) * 1.35, -1.0), Vector3(2.4, 0.45, 3.0), Color("#d5b14a"))
	_add_block(_world_root, "HighPlatform", Vector3(12, 10.5, -4), Vector3(9, 0.5, 9), Color("#e7e4d9"))
	# A few square buildings, trees and rocks form a small island.
	_add_building(_world_root, Vector3(22, 0, 15), Color("#d6dbe0"), Color("#b64b43"))
	_add_building(_world_root, Vector3(-24, 0, 16), Color("#e5d6b9"), Color("#4d7fae"))
	_create_tree(_world_root, Vector3(28, 0, -20))
	_create_tree(_world_root, Vector3(-28, 0, -20))
	_add_block(_world_root, "RockA", Vector3(0, 1.2, 19), Vector3(5, 2.4, 4), Color("#727d84"))
	_add_block(_world_root, "RockB", Vector3(4, 2.8, 20), Vector3(3, 3.0, 3), Color("#8a9499"))
	_water = MeshInstance3D.new()
	_water.name = "RisingFloodWater"
	var water_mesh := PlaneMesh.new()
	water_mesh.size = Vector2(74, 74)
	_water.mesh = water_mesh
	_water.position = Vector3(0, -3.0, 0)
	var water_material := StandardMaterial3D.new()
	water_material.albedo_color = Color(0.12, 0.52, 0.88, 0.70)
	water_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	water_material.roughness = 0.22
	water_material.shading_mode = BaseMaterial3D.SHADING_MODE_PER_PIXEL
	_water.material_override = water_material
	_world_root.add_child(_water)
	_tornado_visual = Node3D.new()
	_tornado_visual.name = "WindstormFunnel"
	_tornado_visual.position = Vector3(-18, 0, -12)
	_world_root.add_child(_tornado_visual)
	for funnel_part in range(4):
		var funnel := MeshInstance3D.new()
		var funnel_mesh := CylinderMesh.new()
		funnel_mesh.top_radius = 0.45 + float(funnel_part) * 0.22
		funnel_mesh.bottom_radius = 1.05 + float(funnel_part) * 0.28
		funnel_mesh.height = 2.4
		funnel.mesh = funnel_mesh
		funnel.position.y = 1.2 + float(funnel_part) * 1.55
		var funnel_material := StandardMaterial3D.new()
		funnel_material.albedo_color = Color(0.72, 0.78, 0.82, 0.72)
		funnel_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		funnel_material.roughness = 1.0
		funnel.material_override = funnel_material
		_tornado_visual.add_child(funnel)
	_tornado_visual.hide()
	_reset_player_spawn(Vector3(0, 0.2, 22))

func _build_pizza_place_world() -> void:
	_round_active = false
	_current_mode = "pizza"
	_clear_world()
	_world_root = Node3D.new()
	_world_root.name = "PizzaPlaceWorld"
	add_child(_world_root)
	_add_baseplate(_world_root, 58.0, Color("#79a653"))
	# Restaurant exterior and interior, built from original block geometry.
	_add_block(_world_root, "RestaurantFloor", Vector3(0, 0.18, 0), Vector3(25, 0.36, 20), Color("#d8d0bd"))
	_add_block(_world_root, "BackWall", Vector3(0, 4.0, -9.7), Vector3(25, 8, 0.6), Color("#f0eee8"))
	_add_block(_world_root, "LeftWall", Vector3(-12.2, 4.0, 0), Vector3(0.6, 8, 20), Color("#f0eee8"))
	_add_block(_world_root, "RightWall", Vector3(12.2, 4.0, 0), Vector3(0.6, 8, 20), Color("#f0eee8"))
	_add_block(_world_root, "FrontAwning", Vector3(0, 6.0, 9.2), Vector3(25, 0.55, 2.0), Color("#b8423b"))
	_add_block(_world_root, "SignPanel", Vector3(0, 7.0, -9.25), Vector3(12, 1.8, 0.35), Color("#2c6498"))
	_add_label_3d(_world_root, "PizzaPlaceSign", "PIZZA PLACE", Vector3(0, 7.0, -9.0), 48, Color.WHITE)
	# Ordering counter.
	_add_block(_world_root, "OrderCounter", Vector3(-8.0, 1.0, 3.0), Vector3(5.0, 2.0, 1.4), Color("#99663e"))
	_add_block(_world_root, "OrderCounterTop", Vector3(-8.0, 2.08, 3.0), Vector3(5.3, 0.18, 1.7), Color("#f4eee2"))
	_add_label_3d(_world_root, "OrderLabel", "PEDIDOS", Vector3(-8.0, 3.0, 2.3), 28, Color("#245b8d"))
	# Prep counter and pizza display.
	_add_block(_world_root, "PrepCounter", Vector3(-1.5, 1.0, -3.0), Vector3(6.0, 2.0, 2.0), Color("#9b6c45"))
	_add_block(_world_root, "PrepTop", Vector3(-1.5, 2.08, -3.0), Vector3(6.3, 0.18, 2.3), Color("#f2e3c7"))
	_create_pizza_prop(_world_root, Vector3(-1.5, 2.22, -3.0))
	_add_label_3d(_world_root, "PrepLabel", "COZINHA", Vector3(-1.5, 3.0, -4.2), 28, Color("#245b8d"))
	# Oven and delivery shelf.
	_add_block(_world_root, "PizzaOven", Vector3(6.0, 1.6, -5.7), Vector3(4.5, 3.2, 3.2), Color("#737b82"))
	_add_block(_world_root, "OvenDoor", Vector3(6.0, 1.4, -4.0), Vector3(2.2, 1.8, 0.18), Color("#343a40"))
	_add_block(_world_root, "OvenWindow", Vector3(6.0, 1.45, -3.88), Vector3(1.35, 0.78, 0.08), Color("#e2a94b"))
	_add_label_3d(_world_root, "OvenLabel", "FORNO", Vector3(6.0, 3.6, -4.2), 28, Color("#245b8d"))
	_add_block(_world_root, "DeliveryShelf", Vector3(8.0, 1.0, 4.0), Vector3(4.2, 2.0, 1.2), Color("#8b5c3c"))
	_add_block(_world_root, "DeliveryTop", Vector3(8.0, 2.1, 4.0), Vector3(4.5, 0.18, 1.5), Color("#f2e3c7"))
	_add_label_3d(_world_root, "DeliveryLabel", "ENTREGAS", Vector3(8.0, 3.0, 3.4), 26, Color("#245b8d"))
	# Customer seating.
	for table_index in range(3):
		var tx := -5.0 + float(table_index) * 8.0
		_add_block(_world_root, "TableTop_%d" % table_index, Vector3(tx, 1.5, 7.0), Vector3(3.2, 0.22, 2.4), Color("#f2e3c7"))
		_add_block(_world_root, "TableLeg_%d" % table_index, Vector3(tx, 0.75, 7.0), Vector3(0.35, 1.4, 0.35), Color("#80553a"))
		for side in [-1.0, 1.0]:
			_add_block(_world_root, "Seat_%d_%d" % [table_index, int(side)], Vector3(tx, 0.7, 7.0 + side * 2.0), Vector3(1.5, 1.0, 1.1), Color("#b84a43"))
	_create_tree(_world_root, Vector3(18, 0, -12))
	_create_tree(_world_root, Vector3(-18, 0, -15))
	_add_block(_world_root, "OceanHorizon", Vector3(0, -1.2, -35), Vector3(90, 0.6, 16), Color("#4099ca"), false)
	_create_sign(_world_root, Vector3(0, 0, 14), "BLOXTACOS  •  PIZZA PLACE")
	_spawn_pizza_customers()
	_spawn_pizza_workers()
	_pizza_stage = 0
	_pizza_oven_timer = 0.0
	_pizza_oven_ready = false
	_pizza_role_index = 0
	_reset_player_spawn(Vector3(0, 0.2, 11.0))

func _spawn_pizza_customers() -> void:
	var noob_resource: Resource = _loaded_avatar_resources.get("res://assets/avatars/noob_r6.glb", load("res://assets/avatars/noob_r6.glb"))
	if not (noob_resource is PackedScene):
		return
	var spawn_positions := [Vector3(-11.0, 0.2, 13.0), Vector3(0.0, 0.2, 13.0), Vector3(10.0, 0.2, 13.0)]
	var seats := [Vector3(-5.0, 0.2, 9.0), Vector3(3.0, 0.2, 5.0), Vector3(11.0, 0.2, 9.0)]
	for index in range(spawn_positions.size()):
		var customer := Node3D.new()
		customer.set_script(CUSTOMER_SCRIPT)
		customer.name = "PizzaCustomer_%02d" % index
		customer.configure(noob_resource as PackedScene, spawn_positions[index], seats[index], float(index) * 0.8)
		_world_root.add_child(customer)

func _spawn_pizza_workers() -> void:
	var noob_resource: Resource = _loaded_avatar_resources.get("res://assets/avatars/noob_r6.glb", load("res://assets/avatars/noob_r6.glb"))
	if not (noob_resource is PackedScene):
		return
	var workers := [
		{"name": "Casey", "job": "CAIXA • PEDIDOS", "speed": 1.25, "route": [Vector3(-10.0, 0.2, 1.0), Vector3(-6.5, 0.2, 1.0), Vector3(-6.5, 0.2, 4.8), Vector3(-10.0, 0.2, 4.8)]},
		{"name": "Jordan", "job": "COZINHEIRO • PREPARO", "speed": 1.05, "route": [Vector3(-4.0, 0.2, -5.8), Vector3(-1.5, 0.2, -5.8), Vector3(2.0, 0.2, -5.8), Vector3(5.5, 0.2, -5.8)]},
		{"name": "Riley", "job": "EQUIPE • ENTREGAS", "speed": 1.45, "route": [Vector3(7.0, 0.2, 2.5), Vector3(9.5, 0.2, 3.0), Vector3(9.5, 0.2, 5.6), Vector3(7.0, 0.2, 5.6)]}
	]
	for worker_data in workers:
		var worker := Node3D.new()
		worker.set_script(WORKER_SCRIPT)
		worker.name = "PizzaWorker_" + String(worker_data["name"])
		worker.configure(noob_resource as PackedScene, String(worker_data["name"]), String(worker_data["job"]), worker_data["route"], float(worker_data["speed"]))
		_world_root.add_child(worker)

func _clear_world() -> void:
	if _world_root != null:
		_world_root.queue_free()
		_world_root = null
	_remote_player_nodes.clear()
	if _delivery_marker != null and is_instance_valid(_delivery_marker):
		_delivery_marker.queue_free()
	_delivery_marker = null
	_disaster_debris.clear()
	_water = null
	_tornado_visual = null

func _reset_player_spawn(spawn: Vector3) -> void:
	if _player != null:
		_player.spawn_position = spawn
		_player.respawn()

func _spawn_player() -> void:
	var player_node := PLAYER_SCRIPT.new() as ClassicPlayer
	player_node.name = "LocalPlayer"
	player_node.spawn_position = Vector3(0.0, 0.2, 5.0)
	player_node.current_avatar = _selected_avatar
	player_node.set_equipped_items(_equipped_items)
	_player = player_node
	add_child(_player)

func _add_baseplate(parent: Node3D, width: float, color: Color) -> void:
	var ground := StaticBody3D.new()
	ground.name = "ClassicStuddedBaseplate"
	parent.add_child(ground)
	var ground_mesh := MeshInstance3D.new()
	var ground_box := BoxMesh.new()
	ground_box.size = Vector3(width, 1.0, width)
	ground_mesh.mesh = ground_box
	ground_mesh.position.y = -0.5
	ground_mesh.material_override = _make_material(color)
	ground.add_child(ground_mesh)
	var collision := CollisionShape3D.new()
	var box_shape := BoxShape3D.new()
	box_shape.size = Vector3(width, 1.0, width)
	collision.shape = box_shape
	collision.position.y = -0.5
	ground.add_child(collision)
	_add_studs(parent, width, color.darkened(0.12))

func _add_studs(parent: Node3D, width: float, color: Color) -> void:
	var stud_mesh := BoxMesh.new()
	stud_mesh.size = Vector3(0.72, 0.16, 0.72)
	var multimesh := MultiMesh.new()
	multimesh.transform_format = MultiMesh.TRANSFORM_3D
	multimesh.mesh = stud_mesh
	var positions: Array[Vector3] = []
	var limit := int(width * 0.5) - 2
	for x in range(-limit, limit + 1, 2):
		for z in range(-limit, limit + 1, 2):
			positions.append(Vector3(float(x), 0.08, float(z)))
	multimesh.instance_count = positions.size()
	for i in range(positions.size()):
		multimesh.set_instance_transform(i, Transform3D(Basis.IDENTITY, positions[i]))
	var studs := MultiMeshInstance3D.new()
	studs.name = "BaseplateStuds"
	studs.multimesh = multimesh
	studs.material_override = _make_material(color)
	parent.add_child(studs)

func _add_block(parent: Node3D, block_name: String, pos: Vector3, dimensions: Vector3, color: Color, collision_enabled: bool = true) -> StaticBody3D:
	var body := StaticBody3D.new()
	body.name = block_name
	body.position = pos
	parent.add_child(body)
	var mesh_instance := MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = dimensions
	mesh_instance.mesh = box
	mesh_instance.material_override = _make_material(color)
	body.add_child(mesh_instance)
	if collision_enabled:
		var collision := CollisionShape3D.new()
		var shape := BoxShape3D.new()
		shape.size = dimensions
		collision.shape = shape
		body.add_child(collision)
	return body

func _add_building(parent: Node3D, center: Vector3, wall_color: Color, roof_color: Color) -> void:
	_add_block(parent, "BuildingBody", center + Vector3(0, 2.2, 0), Vector3(8, 4.4, 7), wall_color)
	_add_block(parent, "BuildingRoof", center + Vector3(0, 4.6, 0), Vector3(8.8, 0.6, 7.8), roof_color)
	_add_block(parent, "BuildingDoor", center + Vector3(0, 1.1, -3.56), Vector3(1.4, 2.2, 0.12), Color("#7f5a3c"), false)
	_add_block(parent, "BuildingWindowA", center + Vector3(-2.3, 2.8, -3.58), Vector3(1.4, 1.2, 0.1), Color("#80c2dc"), false)
	_add_block(parent, "BuildingWindowB", center + Vector3(2.3, 2.8, -3.58), Vector3(1.4, 1.2, 0.1), Color("#80c2dc"), false)

func _create_tree(parent: Node3D, tree_position: Vector3) -> void:
	_add_block(parent, "TreeTrunk", tree_position + Vector3(0, 1.2, 0), Vector3(0.8, 2.4, 0.8), Color("#80502f"))
	_add_block(parent, "TreeLeavesLower", tree_position + Vector3(0, 3.0, 0), Vector3(3.2, 1.6, 3.2), Color("#397e41"))
	_add_block(parent, "TreeLeavesUpper", tree_position + Vector3(0, 4.1, 0), Vector3(2.1, 1.4, 2.1), Color("#4d9950"))

func _create_sign(parent: Node3D, sign_position: Vector3, text_value: String) -> void:
	_add_block(parent, "SignPost", sign_position + Vector3(0, 1.2, 0), Vector3(0.35, 2.4, 0.35), Color("#80502f"))
	_add_block(parent, "SignBoard", sign_position + Vector3(0, 2.65, 0), Vector3(8.8, 1.35, 0.32), Color("#1d5f98"))
	_add_label_3d(parent, "SignText", text_value, sign_position + Vector3(0, 2.68, -0.19), 36, Color.WHITE)

func _add_label_3d(parent: Node3D, node_name: String, value: String, position_3d: Vector3, font_size: int, color: Color) -> void:
	var label := Label3D.new()
	label.name = node_name
	label.text = value
	label.position = position_3d
	label.font_size = font_size
	label.pixel_size = 0.006
	label.modulate = color
	label.outline_size = 7
	parent.add_child(label)

func _create_pizza_prop(parent: Node3D, position_3d: Vector3) -> void:
	var base := MeshInstance3D.new()
	var crust := CylinderMesh.new()
	crust.top_radius = 0.82
	crust.bottom_radius = 0.82
	crust.height = 0.14
	base.mesh = crust
	base.position = position_3d
	base.material_override = _make_material(Color("#d8a44d"))
	parent.add_child(base)
	var cheese := MeshInstance3D.new()
	var topping := CylinderMesh.new()
	topping.top_radius = 0.72
	topping.bottom_radius = 0.72
	topping.height = 0.055
	cheese.mesh = topping
	cheese.position = position_3d + Vector3(0, 0.09, 0)
	cheese.material_override = _make_material(Color("#f3d56b"))
	parent.add_child(cheese)
	for i in range(6):
		var pepperoni := MeshInstance3D.new()
		var disc := CylinderMesh.new()
		disc.top_radius = 0.13
		disc.bottom_radius = 0.13
		disc.height = 0.035
		pepperoni.mesh = disc
		var angle := TAU * float(i) / 6.0
		pepperoni.position = position_3d + Vector3(cos(angle) * 0.38, 0.13, sin(angle) * 0.38)
		pepperoni.material_override = _make_material(Color("#b74335"))
		parent.add_child(pepperoni)

func _make_material(color: Color) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.roughness = 0.86
	return material

# -----------------------------------------------------------------------------
# Classic-style 2016-era interface
# -----------------------------------------------------------------------------
func _build_hud() -> void:
	_canvas = CanvasLayer.new()
	_canvas.name = "BloxTacosInterface"
	add_child(_canvas)
	_ui_root = Control.new()
	_ui_root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_ui_root.mouse_filter = Control.MOUSE_FILTER_PASS
	_canvas.add_child(_ui_root)
	_build_top_bar()
	_build_nav_bar()
	_build_page_panel()
	_build_chat_widget()
	_build_game_controls()
	_build_round_status()
	_build_player_list()
	_purchase_dialog = ConfirmationDialog.new()
	_purchase_dialog.title = "Confirmar compra"
	_purchase_dialog.ok_button_text = "Comprar"
	_purchase_dialog.confirmed.connect(_on_purchase_confirmed)
	_ui_root.add_child(_purchase_dialog)
	_ui_root.resized.connect(_apply_responsive_layout)
	_apply_responsive_layout()

func _build_top_bar() -> void:
	_top_bar = PanelContainer.new()
	_top_bar.name = "ClassicTopBar"
	_top_bar.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
	_top_bar.offset_bottom = 58
	_top_bar.add_theme_stylebox_override("panel", _panel_style(Color("#f7f8fa"), Color("#b9c7d1"), 0, 0))
	_ui_root.add_child(_top_bar)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)
	row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_top_bar.add_child(row)
	var logo := TextureRect.new()
	logo.texture = TACO_LOGO
	logo.custom_minimum_size = Vector2(42, 42)
	logo.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	logo.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	row.add_child(logo)
	var brand := Label.new()
	brand.text = "BloxTacos"
	brand.add_theme_font_size_override("font_size", 24)
	brand.add_theme_color_override("font_color", Color("#1769aa"))
	brand.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	brand.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(brand)
	_wallet_label = Label.new()
	_wallet_label.text = "◈ %d Robux" % _wallet
	_wallet_label.add_theme_font_size_override("font_size", 15)
	_wallet_label.add_theme_color_override("font_color", Color("#26713e"))
	_wallet_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	row.add_child(_wallet_label)
	var settings_button := Button.new()
	settings_button.text = "⚙"
	settings_button.tooltip_text = "Configurações"
	settings_button.custom_minimum_size = Vector2(44, 40)
	settings_button.add_theme_font_size_override("font_size", 22)
	settings_button.pressed.connect(_open_page.bind("settings"))
	row.add_child(settings_button)

func _build_nav_bar() -> void:
	_nav_bar = PanelContainer.new()
	_nav_bar.name = "ClassicNavigation"
	_nav_bar.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
	_nav_bar.offset_top = 58
	_nav_bar.offset_bottom = 108
	_nav_bar.add_theme_stylebox_override("panel", _panel_style(Color("#1769aa"), Color("#0d568f"), 0, 0))
	_ui_root.add_child(_nav_bar)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 3)
	row.add_theme_constant_override("margin_left", 8)
	row.add_theme_constant_override("margin_right", 8)
	_nav_bar.add_child(row)
	row.add_child(_nav_button("HOME", "home"))
	row.add_child(_nav_button("GAMES", "games"))
	row.add_child(_nav_button("AVATAR", "avatar"))
	row.add_child(_nav_button("PROFILE", "profile"))
	row.add_child(_nav_button("CATALOG", "catalog"))
	row.add_child(_nav_button("BAG", "inventory"))
	row.add_child(_nav_button("CHAT", "chat"))

func _nav_button(text_value: String, page_name: String) -> Button:
	var button := Button.new()
	button.text = text_value
	button.custom_minimum_size = Vector2(0, 42)
	button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	button.add_theme_font_size_override("font_size", 12)
	button.add_theme_color_override("font_color", Color.WHITE)
	button.add_theme_color_override("font_hover_color", Color.WHITE)
	button.add_theme_stylebox_override("normal", _button_style(Color("#1769aa"), Color("#1769aa")))
	button.add_theme_stylebox_override("hover", _button_style(Color("#2d82c4"), Color("#7eb9e0")))
	button.add_theme_stylebox_override("pressed", _button_style(Color("#0f5289"), Color("#8fc7eb")))
	button.pressed.connect(_open_page.bind(page_name))
	return button

func _build_page_panel() -> void:
	_page_panel = PanelContainer.new()
	_page_panel.name = "PagePanel"
	_page_panel.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_page_panel.offset_left = 12
	_page_panel.offset_top = 118
	_page_panel.offset_right = -12
	_page_panel.offset_bottom = -12
	_page_panel.add_theme_stylebox_override("panel", _panel_style(Color("#f5f7fa"), Color("#bfcbd5"), 1, 5))
	_ui_root.add_child(_page_panel)
	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 12)
	margin.add_theme_constant_override("margin_right", 12)
	margin.add_theme_constant_override("margin_top", 12)
	margin.add_theme_constant_override("margin_bottom", 12)
	_page_panel.add_child(margin)
	var scroll := ScrollContainer.new()
	scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	margin.add_child(scroll)
	_page_content = VBoxContainer.new()
	_page_content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_page_content.add_theme_constant_override("separation", 12)
	scroll.add_child(_page_content)

func _apply_responsive_layout() -> void:
	if _ui_root == null:
		return
	var viewport_size := _ui_root.size
	if viewport_size.x <= 0.0 or viewport_size.y <= 0.0:
		return
	var is_portrait := viewport_size.y >= viewport_size.x
	var top_height := 58.0 if is_portrait else 48.0
	var nav_height := 50.0 if is_portrait else 44.0
	if _top_bar != null:
		_top_bar.offset_bottom = top_height
	if _nav_bar != null:
		_nav_bar.offset_top = top_height
		_nav_bar.offset_bottom = top_height + nav_height
	if _page_panel != null:
		_page_panel.offset_left = 10.0 if is_portrait else 18.0
		_page_panel.offset_top = top_height + nav_height + 8.0
		_page_panel.offset_right = -10.0 if is_portrait else -18.0
		_page_panel.offset_bottom = -10.0
	if _chat_panel != null:
		_chat_panel.position = Vector2(12, 12)
		_chat_panel.size = Vector2(minf(280.0, viewport_size.x * 0.30), 142.0 if is_portrait else 130.0)
	if _player_list_panel != null:
		_player_list_panel.position = Vector2(-184, 12)
	if _joystick != null:
		var stick_size := 144.0 if is_portrait else 154.0
		_joystick.size = Vector2(stick_size, stick_size)
		_joystick.position = Vector2(18, -stick_size - 18)
	if _round_label != null:
		_round_label.position = Vector2(0, 10)
		_round_label.size = Vector2(viewport_size.x, 30)
	if _mode_hint != null:
		_mode_hint.offset_left = 150.0
		_mode_hint.offset_right = -150.0
		_mode_hint.offset_top = -42.0
		_mode_hint.offset_bottom = -10.0

func _build_player_list() -> void:
	_player_list_panel = PanelContainer.new()
	_player_list_panel.name = "LocalPlayerList"
	_player_list_panel.set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT)
	_player_list_panel.position = Vector2(-184, 12)
	_player_list_panel.size = Vector2(172, 78)
	_player_list_panel.add_theme_stylebox_override("panel", _panel_style(Color(0.06, 0.12, 0.18, 0.78), Color(0.72, 0.84, 0.92, 0.65), 1, 3))
	_ui_root.add_child(_player_list_panel)
	var stack := VBoxContainer.new()
	stack.add_theme_constant_override("separation", 2)
	_player_list_panel.add_child(stack)
	_player_list_entries = VBoxContainer.new()
	_player_list_entries.add_theme_constant_override("separation", 1)
	stack.add_child(_player_list_entries)
	_update_player_list_ui()

func _open_page(page_name: String) -> void:
	_active_page = page_name
	var in_game := page_name == "none"
	if _player != null:
		_player.set_input_enabled(in_game)
	_apply_screen_orientation(in_game)
	if in_game:
		_page_panel.hide()
		_top_bar.hide()
		_nav_bar.hide()
		_chat_panel.show()
		_player_list_panel.show()
		_round_label.show()
		_mode_hint.show()
		if _role_button != null:
			_role_button.visible = _current_mode == "pizza"
		_set_game_controls_visible(true)
		return
	_page_panel.show()
	_top_bar.show()
	_nav_bar.show()
	_chat_panel.hide()
	_player_list_panel.hide()
	_round_label.hide()
	_mode_hint.hide()
	if _role_button != null:
		_role_button.hide()
	_set_game_controls_visible(false)
	for child in _page_content.get_children():
		_page_content.remove_child(child)
		child.queue_free()
	match page_name:
		"home": _show_home_page()
		"games": _show_games_page()
		"avatar": _show_avatar_page()
		"profile": _show_profile_page()
		"catalog": _show_catalog_page()
		"inventory": _show_inventory_page()
		"chat": _show_chat_page()
		"settings": _show_settings_page()
		_: _show_home_page()

func _show_home_page() -> void:
	var hero := PanelContainer.new()
	hero.custom_minimum_size = Vector2(0, 124)
	hero.add_theme_stylebox_override("panel", _panel_style(Color("#e7f1f8"), Color("#bed4e3"), 1, 4))
	_page_content.add_child(hero)
	var hero_row := HBoxContainer.new()
	hero_row.add_theme_constant_override("separation", 12)
	hero.add_child(hero_row)
	var logo := TextureRect.new()
	logo.texture = TACO_LOGO
	logo.custom_minimum_size = Vector2(104, 104)
	logo.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	logo.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	hero_row.add_child(logo)
	var hero_text := VBoxContainer.new()
	hero_text.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hero_text.add_child(_make_label("BLOXTACOS", 23, Color("#155e95")))
	var tagline := _make_label("Uma viagem às experiências clássicas de blocos.", 12, Color("#526a7b"))
	tagline.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	hero_text.add_child(tagline)
	hero_row.add_child(hero_text)
	_page_content.add_child(_make_card("Seu perfil", "Avatar: %s  •  %d Robux de demonstração" % [_avatar_display_name(_selected_avatar), _wallet], Color("#ffffff")))
	_page_content.add_child(_page_title("JOGOS POPULARES", "Experiências clássicas • sessão local ou ENet."))
	_page_content.add_child(_experience_card("Work at a Pizza Place", "Atenda pedidos, prepare a pizza no forno e conclua entregas.", Color("#bd6943"), "pizza"))
	_page_content.add_child(_experience_card("Natural Disasters", "Encontre abrigo e sobreviva a enchentes, terremotos e ventanias.", Color("#4d89b8"), "disaster"))
	_page_content.add_child(_experience_card("Classic Yard", "Explore uma baseplate clássica, construções e obstáculos.", Color("#6e9d45"), "classic"))
	_page_content.add_child(_make_label("%d jogador(es) • %s" % [NetworkManager.get_player_count(), NetworkManager.get_status_message()], 11, Color("#667783")))

func _show_games_page() -> void:
	_page_content.add_child(_page_title("Experiências", "Escolha um mundo e entre na partida."))
	_page_content.add_child(_experience_card("Work at a Pizza Place", "Quatro estações de trabalho, pedidos, forno e entregas.", Color("#bd6943"), "pizza"))
	_page_content.add_child(_experience_card("Natural Disasters", "Rodadas de enchente, terremoto e ventania.", Color("#4d89b8"), "disaster"))
	_page_content.add_child(_experience_card("Classic Yard", "Baseplate verde, studs, obby e torres clássicas.", Color("#6e9d45"), "classic"))

func _show_avatar_page() -> void:
	_page_content.add_child(_page_title("Avatar", "Escolha seu personagem. Arraste a prévia 3D para girá-lo."))
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)
	_page_content.add_child(row)
	row.add_child(_avatar_card("noob", "Noob R6", "Modelo 3D rigado enviado ao projeto. Aparência clássica amarelo e azul."))
	row.add_child(_avatar_card("bacon", "Bacon Hair", "Modelo 3D rigado com cabelo bacon e animação original incluída."))
	_page_content.add_child(_make_label("A seleção e os acessórios equipados são salvos localmente neste dispositivo.", 12, Color("#687985")))

func _show_profile_page() -> void:
	_page_content.add_child(_page_title("Profile", "Seu perfil BloxTacos salvo neste dispositivo."))
	var preview := _create_avatar_preview(_selected_avatar)
	preview.custom_minimum_size = Vector2(0, 190)
	_page_content.add_child(preview)
	_page_content.add_child(_make_card("Jogador local", "Avatar: %s\nSessão: somente neste dispositivo\nConta online: ainda não conectada" % _avatar_display_name(_selected_avatar), Color("#ffffff")))
	_page_content.add_child(_make_card("Estatísticas", "%d Robux de demonstração\n%d itens no inventário\n%d pedidos concluídos na Pizza Place" % [_wallet, _owned_items.size(), _pizza_orders], Color("#eaf2f8")))
	_page_content.add_child(_make_button("PERSONALIZAR AVATAR", Color("#2878b8"), _open_page.bind("avatar")))
	_page_content.add_child(_make_button("ABRIR INVENTÁRIO", Color("#4c795c"), _open_page.bind("inventory")))

func _show_catalog_page() -> void:
	_page_content.add_child(_page_title("Catálogo", "Acessórios independentes para personalizar seu avatar."))
	_page_content.add_child(_make_card("Sua carteira", "%d Robux de demonstração • saldo local, sem conexão com o Roblox." % _wallet, Color("#eaf2f8")))
	var grid := GridContainer.new()
	grid.columns = 2
	grid.add_theme_constant_override("h_separation", 8)
	grid.add_theme_constant_override("v_separation", 8)
	_page_content.add_child(grid)
	for item in CATALOG:
		grid.add_child(_catalog_card(item))

func _show_inventory_page() -> void:
	_page_content.add_child(_page_title("Inventário", "Itens que você possui. Toque para equipar ou remover."))
	if _owned_items.is_empty():
		_page_content.add_child(_make_card("Seu inventário está vazio", "Visite o Catálogo para adquirir seu primeiro acessório.", Color("#ffffff")))
		_page_content.add_child(_make_button("ABRIR CATÁLOGO", Color("#2878b8"), _open_page.bind("catalog")))
		return
	var grid := GridContainer.new()
	grid.columns = 2
	grid.add_theme_constant_override("h_separation", 8)
	grid.add_theme_constant_override("v_separation", 8)
	_page_content.add_child(grid)
	for item in CATALOG:
		if _owned_items.has(String(item.id)):
			grid.add_child(_catalog_card(item))

func _show_settings_page() -> void:
	_page_content.add_child(_page_title("Configurações", "Orientação, apresentação e sessão multiplayer."))
	var rotation_panel := _make_card("Rotação automática", "Menu em retrato e gameplay em paisagem. A rotação por sensor permite inverter a orientação dentro de cada formato.", Color("#ffffff"))
	_page_content.add_child(rotation_panel)
	var rotation_toggle := CheckButton.new()
	rotation_toggle.text = "Ativar rotação automática"
	rotation_toggle.button_pressed = _auto_rotate
	rotation_toggle.toggled.connect(_set_auto_rotate)
	rotation_toggle.custom_minimum_size.y = 46
	_page_content.add_child(rotation_toggle)
	if OS.has_feature("android") or OS.has_feature("ios"):
		_page_content.add_child(_make_card("Tela cheia", "O modo imersivo do Android usa a área disponível sem depender de ADB ou emulador.", Color("#ffffff")))
	else:
		var fullscreen_toggle := CheckButton.new()
		fullscreen_toggle.text = "Tela cheia"
		fullscreen_toggle.button_pressed = _fullscreen_enabled
		fullscreen_toggle.toggled.connect(_set_fullscreen)
		_page_content.add_child(fullscreen_toggle)
	_page_content.add_child(_make_card("Multiplayer ENet", "O servidor aceita até 16 conexões por UDP na porta %d. Hospedar nesta rede funciona para testes LAN; acesso pela internet exige um servidor público ou encaminhamento UDP no roteador." % NetworkManager.DEFAULT_PORT, Color("#eaf2f8")))
	_network_address_input = LineEdit.new()
	_network_address_input.placeholder_text = "IP LAN, 127.0.0.1 ou domínio do servidor"
	_network_address_input.text = ""
	_network_address_input.custom_minimum_size.y = 42
	_page_content.add_child(_network_address_input)
	var network_buttons := GridContainer.new()
	network_buttons.columns = 2
	network_buttons.add_theme_constant_override("h_separation", 8)
	network_buttons.add_theme_constant_override("v_separation", 8)
	_page_content.add_child(network_buttons)
	network_buttons.add_child(_make_button("CRIAR SERVIDOR LAN", Color("#397b50"), _start_lan_server))
	network_buttons.add_child(_make_button("CONECTAR", Color("#2878b8"), _join_network_server))
	network_buttons.add_child(_make_button("DESCONECTAR", Color("#9b4a43"), func(): NetworkManager.disconnect_session()))
	_network_status_label = _make_label(NetworkManager.get_status_message(), 12, Color("#245b8d"))
	_network_status_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_page_content.add_child(_network_status_label)
	_page_content.add_child(_make_card("Servidor dedicado", "Para manter o mundo online sem um jogador hospedando, rode o comando documentado em SERVER_GUIDE.md em um VPS ou computador ligado. Este app não finge que o servidor está na nuvem.", Color("#ffffff")))
	var leader_text := "Você é o líder da sessão." if NetworkManager.is_session_leader() else "O líder da sessão escolhe a experiência."
	_page_content.add_child(_make_card("Jogadores nesta sessão", "%d conectado(s). %s Chat, avatares e acessórios equipados são sincronizados. Carteira e compras continuam locais nesta versão." % [NetworkManager.get_player_count(), leader_text], Color("#edf4f8")))

func _start_lan_server() -> void:
	NetworkManager.set_local_profile("BloxPlayer", _selected_avatar, _equipped_items)
	var error_code := NetworkManager.start_server()
	if error_code == OK:
		_add_chat_message("BloxTacos", "Servidor LAN iniciado na porta UDP %d." % NetworkManager.DEFAULT_PORT)
	_update_player_list_ui()

func _join_network_server() -> void:
	NetworkManager.set_local_profile("BloxPlayer", _selected_avatar, _equipped_items)
	var host := "127.0.0.1" if _network_address_input == null else _network_address_input.text.strip_edges()
	NetworkManager.start_client(host)

func _show_chat_page() -> void:
	_page_content.add_child(_page_title("Chat clássico", "Offline: mensagens locais. Online: chat distribuído pelo host ENet."))
	var chat_panel := PanelContainer.new()
	chat_panel.custom_minimum_size.y = 330
	chat_panel.add_theme_stylebox_override("panel", _panel_style(Color.WHITE, Color("#c8d2dc"), 1, 4))
	_page_content.add_child(chat_panel)
	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 10)
	margin.add_theme_constant_override("margin_right", 10)
	margin.add_theme_constant_override("margin_top", 10)
	margin.add_theme_constant_override("margin_bottom", 10)
	chat_panel.add_child(margin)
	var stack := VBoxContainer.new()
	margin.add_child(stack)
	var history := RichTextLabel.new()
	history.fit_content = false
	history.size_flags_vertical = Control.SIZE_EXPAND_FILL
	history.scroll_following = true
	history.bbcode_enabled = true
	history.add_theme_color_override("default_color", Color("#273746"))
	for entry in _chat_messages:
		history.append_text(entry + "\n")
	stack.add_child(history)
	var input_row := HBoxContainer.new()
	stack.add_child(input_row)
	var input := LineEdit.new()
	input.placeholder_text = "Digite /help para ver os comandos..."
	input.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	input_row.add_child(input)
	var send := _make_button("Enviar", Color("#2878b8"), func(): _send_chat_from(input, history))
	input_row.add_child(send)
	input.text_submitted.connect(func(_value: String): _send_chat_from(input, history))
	_page_content.add_child(_make_label("Comandos: /help, /who, /clear e /respawn. O chat online passa pelo host ENet.", 11, Color("#7b858e")))

func _page_title(title_text: String, subtitle_text: String) -> VBoxContainer:
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 3)
	var title := Label.new()
	title.text = title_text
	title.add_theme_font_size_override("font_size", 22)
	title.add_theme_color_override("font_color", Color("#273746"))
	box.add_child(title)
	var subtitle := Label.new()
	subtitle.text = subtitle_text
	subtitle.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	subtitle.add_theme_font_size_override("font_size", 12)
	subtitle.add_theme_color_override("font_color", Color("#6b7883"))
	box.add_child(subtitle)
	return box

func _make_card(title_text: String, body_text: String, color: Color) -> PanelContainer:
	var panel := PanelContainer.new()
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	panel.custom_minimum_size = Vector2(0, 78)
	panel.add_theme_stylebox_override("panel", _panel_style(color, color.darkened(0.12), 1, 4))
	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 12)
	margin.add_theme_constant_override("margin_right", 12)
	margin.add_theme_constant_override("margin_top", 8)
	margin.add_theme_constant_override("margin_bottom", 8)
	panel.add_child(margin)
	var stack := VBoxContainer.new()
	margin.add_child(stack)
	stack.add_child(_make_label(title_text, 15, TEXT_DARK))
	var body := _make_label(body_text, 11, Color("#53616d"))
	body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	stack.add_child(body)
	return panel

func _experience_card(title_text: String, description: String, color: Color, mode_id: String, _large: bool = false) -> Control:
	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(0, 122)
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	panel.add_theme_stylebox_override("panel", _panel_style(Color.WHITE, Color("#c8d2dc"), 1, 4))
	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 8)
	margin.add_theme_constant_override("margin_right", 8)
	margin.add_theme_constant_override("margin_top", 8)
	margin.add_theme_constant_override("margin_bottom", 8)
	panel.add_child(margin)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)
	margin.add_child(row)
	var cover := TextureRect.new()
	var cover_path := "res://assets/covers/classic_yard.png"
	match mode_id:
		"disaster": cover_path = "res://assets/covers/natural_disasters.png"
		"pizza": cover_path = "res://assets/covers/pizza_place.png"
	cover.texture = load(cover_path)
	cover.custom_minimum_size = Vector2(140, 92)
	cover.size_flags_vertical = Control.SIZE_EXPAND_FILL
	cover.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	cover.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	row.add_child(cover)
	var content := VBoxContainer.new()
	content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	content.add_theme_constant_override("separation", 3)
	row.add_child(content)
	content.add_child(_make_label(title_text, 14, TEXT_DARK))
	var desc := _make_label(description, 10, Color("#657681"))
	desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	desc.size_flags_vertical = Control.SIZE_EXPAND_FILL
	content.add_child(desc)
	var play := _make_button("JOGAR", color, func(): _launch_mode(mode_id))
	play.custom_minimum_size = Vector2(0, 34)
	content.add_child(play)
	return panel

func _avatar_card(avatar_id: String, title_text: String, details: String) -> PanelContainer:
	var panel := PanelContainer.new()
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	panel.custom_minimum_size = Vector2(0, 280)
	panel.add_theme_stylebox_override("panel", _panel_style(Color.WHITE, Color("#c8d2dc"), 1, 5))
	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 8)
	margin.add_theme_constant_override("margin_right", 8)
	margin.add_theme_constant_override("margin_top", 8)
	margin.add_theme_constant_override("margin_bottom", 8)
	panel.add_child(margin)
	var stack := VBoxContainer.new()
	stack.add_theme_constant_override("separation", 6)
	margin.add_child(stack)
	stack.add_child(_create_avatar_preview(avatar_id))
	stack.add_child(_make_label(title_text, 16, Color("#273746")))
	var desc := _make_label(details, 10, Color("#657681"))
	desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	stack.add_child(desc)
	var selected := avatar_id == _selected_avatar
	var choose := _make_button("EQUIPADO" if selected else "ESCOLHER", Color("#4c975d") if selected else Color("#2878b8"), func(): _choose_avatar(avatar_id))
	choose.disabled = selected
	stack.add_child(choose)
	return panel

func _create_avatar_preview(avatar_id: String) -> SubViewportContainer:
	var container := SubViewportContainer.new()
	container.set_script(AVATAR_PREVIEW_SCRIPT)
	container.custom_minimum_size = Vector2(0, 160)
	container.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	container.stretch = true
	var viewport := SubViewport.new()
	viewport.size = Vector2i(360, 240)
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	viewport.transparent_bg = false
	viewport.own_world_3d = true
	container.add_child(viewport)
	var preview_world := Node3D.new()
	viewport.add_child(preview_world)
	var preview_environment := WorldEnvironment.new()
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color("#dceaf3")
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color("#d7e3ed")
	env.ambient_light_energy = 0.9
	preview_environment.environment = env
	preview_world.add_child(preview_environment)
	var floor := MeshInstance3D.new()
	var floor_mesh := PlaneMesh.new()
	floor_mesh.size = Vector2(6, 6)
	floor.mesh = floor_mesh
	floor.rotation.x = 0.0
	floor.position.y = -0.05
	var floor_material := StandardMaterial3D.new()
	floor_material.albedo_color = Color("#9cb58e")
	floor.material_override = floor_material
	preview_world.add_child(floor)
	var camera := Camera3D.new()
	camera.position = Vector3(0, 1.0, 3.5)
	camera.look_at(Vector3(0, 0.9, 0), Vector3.UP)
	camera.current = true
	preview_world.add_child(camera)
	var light := DirectionalLight3D.new()
	light.rotation_degrees = Vector3(-35, -25, 0)
	light.light_energy = 1.25
	preview_world.add_child(light)
	var fill := OmniLight3D.new()
	fill.position = Vector3(-2, 2, 2)
	fill.light_energy = 0.55
	preview_world.add_child(fill)
	var avatar_path := "res://assets/avatars/bacon_hair.glb" if avatar_id == "bacon" else "res://assets/avatars/noob_r6.glb"
	var avatar_resource: Resource = _loaded_avatar_resources.get(avatar_path, load(avatar_path))
	if avatar_resource is PackedScene:
		var preview_root := Node3D.new()
		preview_root.name = "AvatarPreviewRoot"
		var model := (avatar_resource as PackedScene).instantiate() as Node3D
		if avatar_id == "bacon":
			model.scale = Vector3.ONE * 32.0
		else:
			model.rotation.x = -PI * 0.5
		preview_root.add_child(model)
		preview_world.add_child(preview_root)
		AvatarItems.apply(preview_root, _equipped_items)
		container.set("avatar_model", preview_root)
	return container

func _catalog_card(item: Dictionary) -> PanelContainer:
	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(0, 142)
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	panel.add_theme_stylebox_override("panel", _panel_style(Color.WHITE, Color("#d1d8df"), 1, 4))
	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 8)
	margin.add_theme_constant_override("margin_right", 8)
	margin.add_theme_constant_override("margin_top", 8)
	margin.add_theme_constant_override("margin_bottom", 8)
	panel.add_child(margin)
	var stack := VBoxContainer.new()
	stack.add_theme_constant_override("separation", 4)
	margin.add_child(stack)
	var top := HBoxContainer.new()
	stack.add_child(top)
	var thumbnail := TextureRect.new()
	thumbnail.texture = load("res://assets/catalog/icons/%s.png" % String(item.id))
	thumbnail.custom_minimum_size = Vector2(48, 42)
	thumbnail.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	thumbnail.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	top.add_child(thumbnail)
	var title := _make_label(String(item.name), 12, TEXT_DARK)
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	top.add_child(title)
	var desc := _make_label(String(item.description), 10, Color("#6d7b86"))
	desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	desc.size_flags_vertical = Control.SIZE_EXPAND_FILL
	stack.add_child(desc)
	var owned := _owned_items.has(String(item.id))
	var equipped := _equipped_items.has(String(item.id))
	var button_text := "EQUIPADO" if equipped else ("EQUIPAR" if owned else "COMPRAR  ◈ %d" % int(item.price))
	var action := _make_button(button_text, Color("#4e975d") if owned else Color("#2878b8"), func(): _request_catalog_action(String(item.id)))
	stack.add_child(action)
	return panel

func _make_button(text_value: String, color: Color, callback: Callable) -> Button:
	var button := Button.new()
	button.text = text_value
	button.custom_minimum_size = Vector2(110, 36)
	button.add_theme_font_size_override("font_size", 12)
	button.add_theme_color_override("font_color", Color.WHITE)
	button.add_theme_color_override("font_hover_color", Color.WHITE)
	button.add_theme_stylebox_override("normal", _button_style(color, color.darkened(0.12)))
	button.add_theme_stylebox_override("hover", _button_style(color.lightened(0.12), color))
	button.add_theme_stylebox_override("pressed", _button_style(color.darkened(0.16), color.darkened(0.24)))
	button.add_theme_stylebox_override("disabled", _button_style(Color("#9ca8b1"), Color("#8a969f")))
	button.pressed.connect(callback)
	return button

func _button_style(background: Color, border: Color) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = background
	style.border_color = border
	style.set_border_width_all(1)
	style.set_corner_radius_all(3)
	style.content_margin_left = 9
	style.content_margin_right = 9
	style.content_margin_top = 6
	style.content_margin_bottom = 6
	return style

func _panel_style(background: Color, border: Color, border_width: int, radius: int) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = background
	style.border_color = border
	style.set_border_width_all(border_width)
	style.set_corner_radius_all(radius)
	style.content_margin_left = 7
	style.content_margin_right = 7
	style.content_margin_top = 5
	style.content_margin_bottom = 5
	return style

func _make_label(text_value: String, font_size: int, color: Color) -> Label:
	var label := Label.new()
	label.text = text_value
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", color)
	return label

func _build_chat_widget() -> void:
	_chat_panel = PanelContainer.new()
	_chat_panel.name = "ClassicChatWidget"
	_chat_panel.set_anchors_and_offsets_preset(Control.PRESET_TOP_LEFT)
	_chat_panel.position = Vector2(12, 12)
	_chat_panel.size = Vector2(280, 140)
	_chat_panel.add_theme_stylebox_override("panel", _panel_style(Color(0.96, 0.97, 0.98, 0.90), Color("#aebbc5"), 1, 3))
	_ui_root.add_child(_chat_panel)
	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 7)
	margin.add_theme_constant_override("margin_right", 7)
	margin.add_theme_constant_override("margin_top", 5)
	margin.add_theme_constant_override("margin_bottom", 5)
	_chat_panel.add_child(margin)
	var stack := VBoxContainer.new()
	margin.add_child(stack)
	stack.add_child(_make_label("CHAT • LOCAL / ENET", 11, Color("#2d5f8b")))
	_chat_log = RichTextLabel.new()
	_chat_log.bbcode_enabled = true
	_chat_log.fit_content = false
	_chat_log.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_chat_log.scroll_following = true
	_chat_log.add_theme_font_size_override("normal_font_size", 10)
	_chat_log.add_theme_color_override("default_color", Color("#34495a"))
	stack.add_child(_chat_log)
	var row := HBoxContainer.new()
	stack.add_child(row)
	_chat_input = LineEdit.new()
	_chat_input.placeholder_text = "Converse..."
	_chat_input.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(_chat_input)
	var send := Button.new()
	send.text = ">"
	send.custom_minimum_size = Vector2(34, 28)
	send.pressed.connect(_send_chat_from.bind(_chat_input, _chat_log))
	row.add_child(send)
	_chat_input.text_submitted.connect(func(_value: String): _send_chat_from(_chat_input, _chat_log))
	for message in _chat_messages:
		_chat_log.append_text(message + "\n")

func _build_game_controls() -> void:
	_joystick = JOYSTICK_SCRIPT.new() as MobileJoystick
	_joystick.name = "VirtualJoystick"
	_joystick.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_LEFT)
	_joystick.position = Vector2(18, -162)
	_joystick.size = Vector2(144, 144)
	_ui_root.add_child(_joystick)
	var jump := Button.new()
	jump.text = "PULAR"
	jump.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_RIGHT)
	jump.position = Vector2(-116, -112)
	jump.size = Vector2(100, 84)
	jump.add_theme_font_size_override("font_size", 16)
	jump.add_theme_color_override("font_color", Color.WHITE)
	jump.add_theme_stylebox_override("normal", _button_style(Color("#2878b8"), Color("#e5f1fb")))
	jump.pressed.connect(_on_jump_pressed)
	_ui_root.add_child(jump)
	_game_hud_controls.append(jump)
	var respawn := Button.new()
	respawn.text = "RENASCER"
	respawn.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_RIGHT)
	respawn.position = Vector2(-116, -38)
	respawn.size = Vector2(100, 28)
	respawn.add_theme_font_size_override("font_size", 10)
	respawn.add_theme_color_override("font_color", Color.WHITE)
	respawn.add_theme_stylebox_override("normal", _button_style(Color("#4e5c68"), Color("#d3dbe2")))
	respawn.pressed.connect(_on_respawn_pressed)
	_ui_root.add_child(respawn)
	_game_hud_controls.append(respawn)
	_interaction_button = Button.new()
	_interaction_button.text = "INTERAGIR"
	_interaction_button.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_RIGHT)
	_interaction_button.position = Vector2(-226, -98)
	_interaction_button.size = Vector2(102, 52)
	_interaction_button.add_theme_font_size_override("font_size", 11)
	_interaction_button.add_theme_color_override("font_color", Color.WHITE)
	_interaction_button.add_theme_stylebox_override("normal", _button_style(Color("#bd6943"), Color("#f5e4d8")))
	_interaction_button.pressed.connect(_pizza_interact)
	_ui_root.add_child(_interaction_button)
	_interaction_button.hide()
	var menu_button := Button.new()
	menu_button.text = "MENU"
	menu_button.set_anchors_and_offsets_preset(Control.PRESET_TOP_LEFT)
	menu_button.position = Vector2(12, 12)
	menu_button.size = Vector2(62, 38)
	menu_button.add_theme_font_size_override("font_size", 11)
	menu_button.pressed.connect(_open_page.bind("home"))
	_ui_root.add_child(menu_button)
	_game_hud_controls.append(menu_button)
	_role_button = Button.new()
	_role_button.text = "FUNÇÃO: FUNCIONÁRIO"
	_role_button.set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT)
	_role_button.position = Vector2(-248, 94)
	_role_button.size = Vector2(236, 34)
	_role_button.add_theme_font_size_override("font_size", 10)
	_role_button.pressed.connect(_cycle_pizza_role)
	_ui_root.add_child(_role_button)
	_role_button.hide()
	_vehicle_button = Button.new()
	_vehicle_button.text = "MONTAR SCOOTER"
	_vehicle_button.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_RIGHT)
	_vehicle_button.position = Vector2(-238, -42)
	_vehicle_button.size = Vector2(116, 34)
	_vehicle_button.add_theme_font_size_override("font_size", 10)
	_vehicle_button.add_theme_color_override("font_color", Color.WHITE)
	_vehicle_button.add_theme_stylebox_override("normal", _button_style(Color("#377d58"), Color("#d8efdf")))
	_vehicle_button.pressed.connect(_toggle_delivery_vehicle)
	_ui_root.add_child(_vehicle_button)
	_vehicle_button.hide()
	_game_hud_controls.append(_vehicle_button)

func _build_round_status() -> void:
	_round_label = _make_label("", 15, Color.WHITE)
	_round_label.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
	_round_label.position = Vector2(0, 10)
	_round_label.size = Vector2(720, 30)
	_round_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_round_label.add_theme_color_override("font_shadow_color", Color("#1a2732"))
	_round_label.add_theme_constant_override("shadow_offset_x", 2)
	_round_label.add_theme_constant_override("shadow_offset_y", 2)
	_ui_root.add_child(_round_label)
	_mode_hint = _make_label("", 11, Color.WHITE)
	_mode_hint.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
	_mode_hint.offset_left = 150
	_mode_hint.offset_right = -150
	_mode_hint.offset_top = -42
	_mode_hint.offset_bottom = -10
	_mode_hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_mode_hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_mode_hint.add_theme_color_override("font_shadow_color", Color("#1a2732"))
	_mode_hint.add_theme_constant_override("shadow_offset_x", 1)
	_mode_hint.add_theme_constant_override("shadow_offset_y", 1)
	_ui_root.add_child(_mode_hint)

func _cycle_pizza_role() -> void:
	_pizza_role_index = (_pizza_role_index + 1) % PIZZA_ROLES.size()
	if _role_button != null:
		_role_button.text = "FUNÇÃO: %s" % PIZZA_ROLES[_pizza_role_index].to_upper()
	_add_chat_message("Pizza Place", "Sua função agora é %s." % PIZZA_ROLES[_pizza_role_index])

func _set_game_controls_visible(value: bool) -> void:
	if _joystick != null:
		_joystick.visible = value
	for control in _game_hud_controls:
		if is_instance_valid(control):
			control.visible = value
	if _interaction_button != null:
		_interaction_button.visible = value and _current_mode == "pizza"
	if _role_button != null:
		_role_button.visible = value and _current_mode == "pizza"
	if _vehicle_button != null:
		_vehicle_button.visible = value and _current_mode == "pizza" and _pizza_delivery_active

func _choose_avatar(avatar_id: String) -> void:
	_selected_avatar = avatar_id
	if _player != null:
		_player.set_avatar(avatar_id)
	NetworkManager.set_local_profile("BloxPlayer", _selected_avatar, _equipped_items)
	_save_profile()
	_open_page("avatar")

func _request_catalog_action(item_id: String) -> void:
	if _owned_items.has(item_id):
		_pending_purchase_id = ""
		_catalog_action(item_id)
		return
	for item in CATALOG:
		if String(item.id) != item_id:
			continue
		var price := int(item.price)
		if _wallet < price:
			_add_chat_message("BloxTacos", "Saldo insuficiente para %s." % String(item.name))
			return
		_pending_purchase_id = item_id
		_purchase_dialog.dialog_text = "Comprar %s por %d Robux de demonstração?\nO saldo será alterado apenas nesta sessão local salva no dispositivo." % [String(item.name), price]
		_purchase_dialog.popup_centered()
		return

func _on_purchase_confirmed() -> void:
	if _pending_purchase_id.is_empty():
		return
	var item_id := _pending_purchase_id
	_pending_purchase_id = ""
	_catalog_action(item_id)

func _catalog_action(item_id: String) -> void:
	var item: Dictionary = {}
	for candidate in CATALOG:
		if String(candidate.id) == item_id:
			item = candidate
			break
	if item.is_empty():
		return
	if not _owned_items.has(item_id):
		var cost := int(item.price)
		if _wallet < cost:
			_add_chat_message("BloxTacos", "Saldo insuficiente para %s." % String(item.name))
			return
		_wallet -= cost
		_owned_items.append(item_id)
		_equipped_items.append(item_id)
	else:
		if _equipped_items.has(item_id):
			_equipped_items.erase(item_id)
		else:
			_equipped_items.append(item_id)
	if _player != null:
		_player.set_equipped_items(_equipped_items)
	NetworkManager.set_local_profile("BloxPlayer", _selected_avatar, _equipped_items)
	_save_profile()
	_update_wallet()
	_open_page("catalog")

func _update_wallet() -> void:
	if _wallet_label != null:
		_wallet_label.text = "◈ %d Robux" % _wallet

func _avatar_display_name(avatar_id: String) -> String:
	return "Bacon Hair" if avatar_id == "bacon" else "Noob R6"

func _launch_mode(mode_id: String) -> void:
	if NetworkManager.is_online() and not NetworkManager.is_server_session():
		NetworkManager.request_experience(mode_id)
		return
	_apply_mode_locally(mode_id)
	if NetworkManager.is_server_session():
		NetworkManager.set_experience(mode_id)

func _apply_mode_locally(mode_id: String) -> void:
	match mode_id:
		"classic": _start_classic()
		"disaster": _start_disaster()
		"pizza": _start_pizza()
	_open_page("none")
	_on_network_roster_changed(NetworkManager.get_roster())

func _start_classic() -> void:
	_round_active = false
	if _player != null:
		_player.set_camera_shake(0.0)
	_round_label.text = "CLASSIC YARD  •  EXPLORE"
	_mode_hint.text = "WASD / joystick para andar  •  Arraste para girar a câmera  •  Espaço para pular"
	_build_classic_yard()
	_open_page("none")

func _start_disaster() -> void:
	if _player != null:
		_player.set_camera_shake(0.0)
	_build_natural_disaster_world()
	var disasters := ["flood", "quake", "wind"]
	_disaster_kind = disasters[randi_range(0, disasters.size() - 1)]
	_round_remaining = 60.0
	_disaster_delay = 5.0
	_weather_clock = 0.0
	_debris_triggered = false
	_disaster_debris.clear()
	_round_active = true
	_water_start_y = -3.0
	if _water != null:
		_water.position.y = _water_start_y
	if _tornado_visual != null:
		_tornado_visual.visible = _disaster_kind == "wind"
	_round_label.text = "NATURAL DISASTERS  •  PREPARE-SE"
	_mode_hint.text = "Você tem 5 segundos para encontrar um lugar seguro."
	_open_page("none")

func _start_pizza() -> void:
	if _player != null:
		_player.set_camera_shake(0.0)
	_pizza_stage = 0
	_pizza_oven_timer = 0.0
	_pizza_oven_ready = false
	_pizza_delivery_active = false
	_vehicle_active = false
	if _player != null:
		_player.set_delivery_vehicle_enabled(false)
	_build_pizza_place_world()
	_round_label.text = "PIZZA PLACE  •  PEDIDO #1"
	_mode_hint.text = "Vá até cada estação e toque em INTERAGIR. No PC, pressione ENTER."
	_interaction_button.show()
	_open_page("none")

func _update_disaster(delta: float) -> void:
	_weather_clock += delta
	if _disaster_delay > 0.0:
		_disaster_delay -= delta
		_round_label.text = "ALERTA: %s COMEÇA EM %d" % [_disaster_display_name(), ceili(_disaster_delay)]
		return
	_round_remaining -= delta
	if not _debris_triggered:
		_debris_triggered = true
		_spawn_disaster_debris(_disaster_kind)
	match _disaster_kind:
		"flood":
			if _water != null:
				_water.position.y += _water_level_speed * delta
				for debris in _disaster_debris:
					if is_instance_valid(debris) and debris.global_position.y < _water.global_position.y + 0.6:
						debris.apply_central_force(Vector3.UP * debris.mass * 18.0)
				if _player != null and _player.global_position.y < _water.position.y + 1.0:
					_round_active = false
					_player.respawn()
					_round_label.text = "A ENCHENTE CHEGOU! TENTE DE NOVO"
					_mode_hint.text = "Suba para uma plataforma mais alta antes da água chegar."
		"quake":
			if _player != null:
				_player.set_camera_shake(0.12 + absf(sin(_weather_clock * 6.0)) * 0.12)
			if _world_root != null:
				_world_root.position = Vector3(sin(_weather_clock * 13.0) * 0.07, 0, cos(_weather_clock * 11.0) * 0.06)
		"wind":
			for debris in _disaster_debris:
				if is_instance_valid(debris):
					debris.apply_central_force(Vector3(1.0, 0.2, -0.55) * debris.mass * 7.5)
			if _player != null:
				_player.set_camera_shake(0.04)
				if int(_weather_clock * 3.0) % 3 == 0:
					_player.add_weather_push(Vector3(sin(_weather_clock * 2.2), 0, cos(_weather_clock * 1.7)) * delta * 2.8)
			if _tornado_visual != null:
				_tornado_visual.rotation.y += delta * 2.4
				_tornado_visual.position.x = -18.0 + sin(_weather_clock * 0.45) * 7.0
				_tornado_visual.position.z = -12.0 + cos(_weather_clock * 0.36) * 6.0
	_round_label.text = "%s  •  %02d s" % [_disaster_display_name(), ceili(maxf(0.0, _round_remaining))]
	if _round_remaining <= 0.0:
		_round_active = false
		if _player != null:
			_player.set_camera_shake(0.0)
		if _world_root != null:
			_world_root.position = Vector3.ZERO
		_wallet += 10
		_update_wallet()
		_save_profile()
		_round_label.text = "VOCÊ SOBREVIVEU!  •  +10 ROBUX DE DEMONSTRAÇÃO"
		_mode_hint.text = "Recompensa local adicionada à carteira. Toque em MENU para escolher outra experiência."

func _disaster_display_name() -> String:
	match _disaster_kind:
		"flood": return "ENCHENTE"
		"quake": return "TERREMOTO"
		"wind": return "VENTANIA"
	return "DESASTRE NATURAL"

func _pizza_interact() -> void:
	if _current_mode != "pizza" or _player == null or _pizza_oven_timer > 0.0:
		return
	if _pizza_delivery_active:
		if _player.global_position.distance_to(_pizza_delivery_target) > 5.0:
			_mode_hint.text = "Siga o marcador até o cliente para concluir a entrega."
			return
		_complete_pizza_delivery()
		return
	var station_positions := [Vector3(-8, 1, 3), Vector3(-1.5, 2, -3), Vector3(6, 1.6, -5.7), Vector3(8, 1, 4)]
	var station_names := ["balcão de pedidos", "preparo da pizza", "forno", "área de entregas"]
	var target: Vector3 = station_positions[_pizza_stage]
	if _player.global_position.distance_to(target) > 5.0:
		_mode_hint.text = "Chegue mais perto: %s." % station_names[_pizza_stage]
		return
	if _pizza_stage == 2 and not _pizza_oven_ready:
		_pizza_oven_timer = 4.0
		_interaction_button.disabled = true
		_interaction_button.text = "ASSANDO…"
		_round_label.text = "PIZZA PLACE  •  FORNO LIGADO"
		_mode_hint.text = "Aguarde a pizza assar."
		return
	if _pizza_stage == 2 and _pizza_oven_ready:
		_pizza_oven_ready = false
	_pizza_stage += 1
	if _pizza_stage >= 4:
		_begin_pizza_delivery()
		return
	_round_label.text = "PIZZA PLACE  •  ETAPA %d/4" % (_pizza_stage + 1)
	_mode_hint.text = "Agora vá para %s." % station_names[_pizza_stage]

func _begin_pizza_delivery() -> void:
	var delivery_points := [Vector3(18.0, 0.2, 12.0), Vector3(-20.0, 0.2, 7.0), Vector3(20.0, 0.2, -18.0)]
	_pizza_delivery_target = delivery_points[randi_range(0, delivery_points.size() - 1)]
	_pizza_delivery_active = true
	if _delivery_marker != null and is_instance_valid(_delivery_marker):
		_delivery_marker.queue_free()
	_delivery_marker = Node3D.new()
	_delivery_marker.name = "PizzaDeliveryMarker"
	_delivery_marker.position = _pizza_delivery_target
	var beacon := MeshInstance3D.new()
	var beacon_mesh := CylinderMesh.new()
	beacon_mesh.top_radius = 0.48
	beacon_mesh.bottom_radius = 0.48
	beacon_mesh.height = 0.12
	beacon.mesh = beacon_mesh
	beacon.position.y = 0.14
	beacon.material_override = _make_material(Color("#f0bf45"))
	_delivery_marker.add_child(beacon)
	var label := Label3D.new()
	label.text = "ENTREGA"
	label.position.y = 1.0
	label.font_size = 26
	label.pixel_size = 0.006
	label.modulate = Color("#fff5c9")
	label.outline_size = 6
	_delivery_marker.add_child(label)
	if _world_root != null:
		_world_root.add_child(_delivery_marker)
	if _player != null:
		_player.set_delivery_vehicle_enabled(true)
	_vehicle_active = true
	if _vehicle_button != null:
		_vehicle_button.visible = true
		_vehicle_button.text = "DESCER SCOOTER"
	_round_label.text = "PIZZA PLACE  •  ENTREGA EXTERNA"
	_mode_hint.text = "Pedido pronto! Use o scooter para chegar ao marcador e toque em ENTREGAR."
	_interaction_button.text = "ENTREGAR"
	_interaction_button.show()

func _complete_pizza_delivery() -> void:
	_pizza_delivery_active = false
	_deliveries_completed += 1
	_pizza_orders += 1
	var role_bonus := 0
	match PIZZA_ROLES[_pizza_role_index]:
		"Caixa": role_bonus = 5
		"Cozinheiro": role_bonus = 10
		"Entregador": role_bonus = 15
	var reward := 35 + role_bonus
	_pizza_tips += reward
	_wallet += reward
	_pizza_stage = 0
	_vehicle_active = false
	if _player != null:
		_player.set_delivery_vehicle_enabled(false)
	if _vehicle_button != null:
		_vehicle_button.hide()
	if _delivery_marker != null and is_instance_valid(_delivery_marker):
		_delivery_marker.queue_free()
	_delivery_marker = null
	_update_wallet()
	_save_profile()
	_round_label.text = "ENTREGA CONCLUÍDA!  •  %d pedidos" % _pizza_orders
	_mode_hint.text = "Você recebeu %d Robux de demonstração. Próximo pedido: balcão." % reward
	_interaction_button.hide()

func _toggle_delivery_vehicle() -> void:
	if not _pizza_delivery_active or _player == null:
		return
	_vehicle_active = not _vehicle_active
	_player.set_delivery_vehicle_enabled(_vehicle_active)
	_vehicle_button.text = "DESCER SCOOTER" if _vehicle_active else "MONTAR SCOOTER"

func _update_pizza_hint() -> void:
	if _active_page != "none" or _player == null:
		return
	if _pizza_delivery_active:
		var near_delivery := _player.global_position.distance_to(_pizza_delivery_target) <= 5.0
		_interaction_button.visible = true
		_interaction_button.disabled = false
		_interaction_button.text = "ENTREGAR" if near_delivery else "SIGA O MARCADOR"
		_mode_hint.text = "Cliente esperando no marcador. Use o scooter para chegar mais rápido." if not near_delivery else "Você chegou! Toque em ENTREGAR para finalizar o pedido."
		if _vehicle_button != null:
			_vehicle_button.visible = true
		return
	var station_positions := [Vector3(-8, 1, 3), Vector3(-1.5, 2, -3), Vector3(6, 1.6, -5.7), Vector3(8, 1, 4)]
	var station_names := ["PEDIDOS", "PREPARO", "FORNO", "ENTREGAS"]
	var near_station := _player.global_position.distance_to(station_positions[_pizza_stage]) <= 5.0
	_interaction_button.visible = near_station and _pizza_oven_timer <= 0.0
	_interaction_button.disabled = _pizza_oven_timer > 0.0
	if _pizza_oven_timer > 0.0:
		_interaction_button.text = "ASSANDO %ds" % ceili(_pizza_oven_timer)
	elif _pizza_stage == 2 and _pizza_oven_ready:
		_interaction_button.text = "RETIRAR PIZZA"
	else:
		_interaction_button.text = "INTERAGIR"
	if near_station:
		_mode_hint.text = "Toque em %s: %s." % ["RETIRAR PIZZA" if _pizza_stage == 2 and _pizza_oven_ready else "INTERAGIR", station_names[_pizza_stage]]

func _send_chat_from(input: LineEdit, history: RichTextLabel) -> void:
	var message := input.text.strip_edges()
	if message.is_empty():
		return
	message = message.left(140)
	match message.to_lower():
		"/help":
			_add_chat_message("BloxTacos", "Comandos: /help, /who, /clear e /respawn.")
		"/who":
			var player_names: Array[String] = []
			for player_record in NetworkManager.get_roster():
				player_names.append(String(player_record.get("name", "Jogador")))
			if player_names.is_empty():
				player_names.append("Você (local)")
			_add_chat_message("BloxTacos", "Jogadores nesta sessão: " + ", ".join(player_names))
		"/clear":
			_chat_messages.clear()
			if _chat_log != null:
				_chat_log.clear()
			if history != null and history != _chat_log:
				history.clear()
		"/respawn":
			_on_respawn_pressed()
			_add_chat_message("BloxTacos", "Você voltou ao ponto de início.")
		_:
			NetworkManager.send_chat(message)
			if history != null and history != _chat_log:
				history.append_text("[color=#2678b8]Você:[/color] %s\n" % _bbcode_escape(message))
	input.clear()

func _add_chat_message(author: String, message: String) -> void:
	var escaped := _bbcode_escape(message)
	var entry := "[color=#2678b8]%s:[/color] %s" % [author, escaped]
	_chat_messages.append(entry)
	while _chat_messages.size() > 40:
		_chat_messages.pop_front()
	if _chat_log != null:
		_chat_log.append_text(entry + "\n")

func _bbcode_escape(value: String) -> String:
	return value.replace("[", "\\[").replace("]", "\\]")

func _on_jump_pressed() -> void:
	if _player != null:
		_player.jump()

func _on_respawn_pressed() -> void:
	if _player != null:
		_player.respawn()



func _spawn_disaster_debris(disaster_id: String) -> void:
	if _world_root == null:
		return
	_release_structure_pieces(disaster_id)
	for index in range(14):
		var debris := RigidBody3D.new()
		debris.name = "DisasterDebris_%02d" % index
		debris.mass = randf_range(0.7, 1.8)
		debris.position = Vector3(randf_range(-18.0, 18.0), randf_range(2.5, 7.0), randf_range(-16.0, 16.0))
		debris.linear_damp = 0.25
		debris.angular_damp = 0.3
		var size := Vector3(randf_range(0.55, 1.3), randf_range(0.45, 1.1), randf_range(0.55, 1.3))
		var visual := MeshInstance3D.new()
		var mesh := BoxMesh.new()
		mesh.size = size
		visual.mesh = mesh
		visual.material_override = _make_material([Color("#b98b58"), Color("#8a969c"), Color("#c9b88d")][index % 3])
		debris.add_child(visual)
		var collision := CollisionShape3D.new()
		var shape := BoxShape3D.new()
		shape.size = size
		collision.shape = shape
		debris.add_child(collision)
		_world_root.add_child(debris)
		_disaster_debris.append(debris)
		if disaster_id == "quake":
			debris.apply_central_impulse(Vector3(randf_range(-3.2, 3.2), randf_range(2.5, 5.0), randf_range(-3.2, 3.2)) * debris.mass)
			debris.apply_torque_impulse(Vector3(randf_range(-1.8, 1.8), randf_range(-1.2, 1.2), randf_range(-1.8, 1.8)) * debris.mass)
		elif disaster_id == "wind":
			debris.apply_central_impulse(Vector3(randf_range(4.0, 7.0), randf_range(1.2, 2.4), randf_range(-3.0, 3.0)) * debris.mass)
			debris.apply_torque_impulse(Vector3(randf_range(-2.2, 2.2), randf_range(-1.4, 1.4), randf_range(-2.2, 2.2)) * debris.mass)


func _release_structure_pieces(disaster_id: String) -> void:
	if _world_root == null:
		return
	var breakable_names := ["SurvivalTower", "BeachRoof", "BuildingRoof", "TowerStep_04", "TowerStep_03"]
	var candidates: Array[StaticBody3D] = []
	_collect_breakable_bodies(_world_root, breakable_names, candidates)
	var released := 0
	for static_body in candidates:
		if released >= 6 or not is_instance_valid(static_body):
			break
		var visual_source := static_body.get_node_or_null("MeshInstance3D") as MeshInstance3D
		var collision_source := static_body.get_node_or_null("CollisionShape3D") as CollisionShape3D
		if visual_source == null or collision_source == null:
			continue
		var parent := static_body.get_parent()
		var saved_transform := static_body.transform
		var piece_name := String(static_body.name)
		var visual_copy := visual_source.duplicate() as MeshInstance3D
		var collision_copy := collision_source.duplicate() as CollisionShape3D
		parent.remove_child(static_body)
		static_body.queue_free()
		var falling_piece := RigidBody3D.new()
		falling_piece.name = "%s_Falling" % piece_name
		falling_piece.mass = 3.2 if disaster_id == "quake" else 2.0
		falling_piece.linear_damp = 0.22
		falling_piece.angular_damp = 0.28
		falling_piece.transform = saved_transform
		falling_piece.add_child(visual_copy)
		falling_piece.add_child(collision_copy)
		parent.add_child(falling_piece)
		_disaster_debris.append(falling_piece)
		var impulse := Vector3(randf_range(-3.5, 3.5), randf_range(2.0, 4.6), randf_range(-3.5, 3.5))
		if disaster_id == "wind":
			impulse = Vector3(randf_range(4.0, 7.0), randf_range(1.2, 2.8), randf_range(-3.0, 3.0))
		elif disaster_id == "flood":
			impulse = Vector3(randf_range(-1.0, 1.0), randf_range(0.4, 1.4), randf_range(-1.0, 1.0))
		falling_piece.apply_central_impulse(impulse * falling_piece.mass)
		falling_piece.apply_torque_impulse(Vector3(randf_range(-1.5, 1.5), randf_range(-1.0, 1.0), randf_range(-1.5, 1.5)) * falling_piece.mass)
		released += 1

func _collect_breakable_bodies(root: Node, wanted_names: Array, result: Array[StaticBody3D]) -> void:
	for child in root.get_children():
		if child is StaticBody3D and wanted_names.has(String(child.name)):
			result.append(child as StaticBody3D)
		_collect_breakable_bodies(child, wanted_names, result)

func _update_player_list_ui() -> void:
	if _player_list_entries == null or _player_list_panel == null:
		return
	for child in _player_list_entries.get_children():
		child.queue_free()
	var roster := NetworkManager.get_roster()
	var title := _make_label("JOGADORES  •  %d" % NetworkManager.get_player_count(), 10, Color("#d5e9f5"))
	_player_list_entries.add_child(title)
	if roster.is_empty():
		_player_list_entries.add_child(_make_label("● Você (local)", 12, Color.WHITE))
	else:
		var count := 0
		for record in roster:
			if count >= 5:
				_player_list_entries.add_child(_make_label("+ %d jogadores" % (roster.size() - count), 10, Color("#d5e9f5")))
				break
			var player_name := String(record.get("name", "Jogador"))
			var is_local := int(record.get("peer_id", 0)) == NetworkManager.get_local_peer_id()
			_player_list_entries.add_child(_make_label("● %s%s" % [player_name, " (você)" if is_local else ""], 11, Color.WHITE))
			count += 1
	_player_list_panel.size.y = 28.0 + float(mini(roster.size(), 5)) * 17.0

func _safe_equipped_from_record(record: Dictionary) -> Array:
	var result: Array = []
	var supplied: Variant = record.get("equipped", [])
	if supplied is Array:
		for item_id in supplied:
			var clean_id := String(item_id)
			if AvatarItems.ACCESSORY_SCENES.has(clean_id) and not result.has(clean_id):
				result.append(clean_id)
	return result

func _on_network_roster_changed(roster: Array) -> void:
	if NetworkManager.is_dedicated_server():
		return
	var seen: Dictionary = {}
	var local_peer_id := NetworkManager.get_local_peer_id()
	for record in roster:
		if not (record is Dictionary):
			continue
		var peer_id := int(record.get("peer_id", 0))
		if peer_id <= 0 or peer_id == local_peer_id:
			continue
		seen[peer_id] = true
		_ensure_remote_player(peer_id, record)
	for peer_id in _remote_player_nodes.keys():
		if not seen.has(peer_id):
			var remote: Dictionary = _remote_player_nodes[peer_id]
			var node: Node3D = remote.get("node")
			if is_instance_valid(node):
				node.queue_free()
			_remote_player_nodes.erase(peer_id)
	_update_player_list_ui()

func _ensure_remote_player(peer_id: int, record: Dictionary) -> void:
	if _world_root == null:
		return
	var avatar_id := String(record.get("avatar", "noob"))
	if not _remote_player_nodes.has(peer_id):
		var remote_root := Node3D.new()
		remote_root.name = "RemotePlayer_%d" % peer_id
		var visual_root := Node3D.new()
		visual_root.name = "AvatarVisual"
		var avatar_path := "res://assets/avatars/bacon_hair.glb" if avatar_id == "bacon" else "res://assets/avatars/noob_r6.glb"
		var avatar_resource: Resource = _loaded_avatar_resources.get(avatar_path, load(avatar_path))
		if avatar_resource is PackedScene:
			var avatar_model := (avatar_resource as PackedScene).instantiate() as Node3D
			if avatar_id == "bacon":
				avatar_model.scale = Vector3.ONE * 32.0
			else:
				avatar_model.rotation.x = -PI * 0.5
			visual_root.add_child(avatar_model)
		AvatarItems.apply(visual_root, _safe_equipped_from_record(record))
		remote_root.add_child(visual_root)
		var nameplate := Label3D.new()
		nameplate.name = "Nameplate"
		nameplate.text = String(record.get("name", "Jogador"))
		nameplate.position = Vector3(0, 3.1, 0)
		nameplate.font_size = 24
		nameplate.pixel_size = 0.006
		nameplate.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		nameplate.modulate = Color("#ffffff")
		nameplate.outline_size = 6
		remote_root.add_child(nameplate)
		_world_root.add_child(remote_root)
		_remote_player_nodes[peer_id] = {"node": remote_root, "target_position": Vector3.ZERO, "target_yaw": 0.0, "avatar": avatar_id, "equipped": _safe_equipped_from_record(record)}
	var remote_state: Dictionary = _remote_player_nodes[peer_id]
	var remote_node: Node3D = remote_state.get("node")
	if is_instance_valid(remote_node):
		if String(remote_state.get("avatar", "noob")) != avatar_id:
			var previous_visual := remote_node.get_node_or_null("AvatarVisual")
			if previous_visual != null:
				remote_node.remove_child(previous_visual)
				previous_visual.queue_free()
			var replacement_visual := Node3D.new()
			replacement_visual.name = "AvatarVisual"
			var replacement_path := "res://assets/avatars/bacon_hair.glb" if avatar_id == "bacon" else "res://assets/avatars/noob_r6.glb"
			var replacement_resource: Resource = _loaded_avatar_resources.get(replacement_path, load(replacement_path))
			if replacement_resource is PackedScene:
				var replacement_model := (replacement_resource as PackedScene).instantiate() as Node3D
				if avatar_id == "bacon":
					replacement_model.scale = Vector3.ONE * 32.0
				else:
					replacement_model.rotation.x = -PI * 0.5
				replacement_visual.add_child(replacement_model)
			AvatarItems.apply(replacement_visual, _safe_equipped_from_record(record))
			remote_node.add_child(replacement_visual)
		var equipped_now := _safe_equipped_from_record(record)
		if remote_state.get("equipped", []) != equipped_now:
			AvatarItems.apply(remote_node.get_node_or_null("AvatarVisual") as Node3D, equipped_now)
			remote_state["equipped"] = equipped_now
		remote_state["target_position"] = record.get("position", remote_node.position)
		remote_state["target_yaw"] = float(record.get("yaw", 0.0))
		remote_state["avatar"] = avatar_id
		var name_label := remote_node.get_node_or_null("Nameplate") as Label3D
		if name_label != null:
			name_label.text = String(record.get("name", "Jogador"))
		_remote_player_nodes[peer_id] = remote_state

func _animate_network_avatar(visual: Node3D, avatar_id: String, gait_clock: float, speed: float) -> void:
	var moving := speed > 0.45
	if avatar_id == "noob":
		var skeleton := _find_network_skeleton(visual)
		if skeleton == null:
			return
		var swing := sin(gait_clock) * (0.42 if moving else 0.025)
		var left_leg := skeleton.find_bone("Left Leg_04")
		var right_leg := skeleton.find_bone("Right Leg_05")
		var left_arm := skeleton.find_bone("Left Arm_02")
		var right_arm := skeleton.find_bone("Right Arm_03")
		if left_leg >= 0:
			skeleton.set_bone_pose_rotation(left_leg, Quaternion(Vector3.RIGHT, swing))
		if right_leg >= 0:
			skeleton.set_bone_pose_rotation(right_leg, Quaternion(Vector3.RIGHT, -swing))
		if left_arm >= 0:
			skeleton.set_bone_pose_rotation(left_arm, Quaternion(Vector3.RIGHT, -swing * 0.72))
		if right_arm >= 0:
			skeleton.set_bone_pose_rotation(right_arm, Quaternion(Vector3.RIGHT, swing * 0.72))
	else:
		var player := _find_network_animation_player(visual)
		if player != null:
			if String(player.current_animation).is_empty():
				for animation_name in player.get_animation_list():
					if String(animation_name).to_upper() != "RESET":
						var clip := player.get_animation(animation_name)
						if clip != null:
							clip.loop_mode = Animation.LOOP_LINEAR
							player.play(animation_name)
							break
			player.speed_scale = clampf(speed / 5.0, 0.45, 1.35) if moving else 0.62

func _find_network_skeleton(root: Node) -> Skeleton3D:
	if root is Skeleton3D:
		return root as Skeleton3D
	for child in root.get_children():
		var found := _find_network_skeleton(child)
		if found != null:
			return found
	return null

func _find_network_animation_player(root: Node) -> AnimationPlayer:
	if root is AnimationPlayer:
		return root as AnimationPlayer
	for child in root.get_children():
		var found := _find_network_animation_player(child)
		if found != null:
			return found
	return null

func _on_network_player_state(peer_id: int, player_position: Vector3, yaw: float, avatar_id: String) -> void:
	if peer_id == NetworkManager.get_local_peer_id() or NetworkManager.is_dedicated_server():
		return
	var current_record: Dictionary = {"peer_id": peer_id, "name": "Jogador %d" % peer_id, "avatar": avatar_id, "position": player_position, "yaw": yaw}
	for record in NetworkManager.get_roster():
		if int(record.get("peer_id", 0)) == peer_id:
			current_record = record
			break
	_ensure_remote_player(peer_id, current_record)
	if _remote_player_nodes.has(peer_id):
		var remote: Dictionary = _remote_player_nodes[peer_id]
		remote["target_position"] = player_position
		remote["target_yaw"] = yaw
		_remote_player_nodes[peer_id] = remote

func _on_network_chat_received(author: String, message_text: String) -> void:
	_add_chat_message(author, message_text)

func _on_network_status_changed(message: String) -> void:
	if _network_status_label != null and is_instance_valid(_network_status_label):
		_network_status_label.text = message
	_update_player_list_ui()

func _on_network_experience_changed(mode_id: String) -> void:
	if not _startup_ready or NetworkManager.is_dedicated_server():
		return
	if ["classic", "disaster", "pizza"].has(mode_id) and mode_id != _current_mode:
		_apply_mode_locally(mode_id)
		_on_network_roster_changed(NetworkManager.get_roster())
