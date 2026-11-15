extends Node3D

## Lightweight customer routine: enters, queues, orders, sits, eats, and exits.
## The route is authored for the BloxTacos Pizza Place floor, so no external navigation bake is required.

var _avatar_scene: PackedScene
var _seat_position := Vector3.ZERO
var _spawn_position := Vector3.ZERO
var _visual_root: Node3D
var _skeleton: Skeleton3D
var _status_label: Label3D
var _route: Array[Vector3] = []
var _route_index := 0
var _state := "entering"
var _state_timer := 0.0
var _move_speed := 2.15
var _cycle_offset := 0.0
var _customer_name := "Cliente"
var _order_name := "Pizza de queijo"
var _gait_clock := 0.0

func configure(avatar_scene: PackedScene, spawn_position: Vector3, seat_position: Vector3, cycle_offset: float = 0.0) -> void:
	_avatar_scene = avatar_scene
	_spawn_position = spawn_position
	seat_position.y = 0.2
	_seat_position = seat_position
	_cycle_offset = cycle_offset
	var names := ["Alex", "Sam", "Taylor", "Jordan", "Casey", "Riley"]
	var orders := ["Pizza de queijo", "Pizza de tomate", "Pizza especial"]
	_customer_name = names[int(fposmod(cycle_offset * 7.0, float(names.size())))]
	_order_name = orders[int(fposmod(cycle_offset * 5.0, float(orders.size())))]
	position = _spawn_position
	_build_visual()
	_start_route()

func _build_visual() -> void:
	if _avatar_scene == null:
		return
	_visual_root = _avatar_scene.instantiate() as Node3D
	_visual_root.name = "CustomerAvatar"
	_visual_root.rotation.x = -PI * 0.5
	add_child(_visual_root)
	_skeleton = _find_skeleton(_visual_root)
	_status_label = Label3D.new()
	_status_label.name = "CustomerStatus"
	_status_label.position = Vector3(0, 3.0, 0)
	_status_label.font_size = 22
	_status_label.pixel_size = 0.006
	_status_label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	_status_label.outline_size = 5
	_status_label.modulate = Color("#fff4c9")
	add_child(_status_label)

func _start_route() -> void:
	var queue_position := Vector3(-8.0 + fposmod(_cycle_offset, 3.0) * 0.65, 0.2, 4.8)
	_route = [_spawn_position, queue_position, _seat_position, _spawn_position]
	_route_index = 1
	_state = "entering"
	_state_timer = 0.0
	if _status_label != null:
		_status_label.text = "%s • PEDIDO" % _customer_name

func _process(delta: float) -> void:
	if _route.is_empty():
		return
	if _state == "ordering" or _state == "eating" or _state == "leaving_wait":
		_state_timer -= delta
		if _state_timer <= 0.0:
			_advance_state()
		return
	var target: Vector3 = _route[_route_index]
	var flat_target := Vector3(target.x, position.y, target.z)
	var distance := position.distance_to(flat_target)
	if distance <= 0.16:
		_arrived_at_waypoint()
		return
	var direction := (flat_target - position).normalized()
	position = position.move_toward(flat_target, _move_speed * delta)
	_gait_clock += delta * 7.0
	_animate_walk(true)
	if _visual_root != null and direction.length() > 0.01:
		_visual_root.rotation.y = lerp_angle(_visual_root.rotation.y, atan2(-direction.x, -direction.z), minf(1.0, delta * 8.0))

func _arrived_at_waypoint() -> void:
	_animate_walk(false)
	match _route_index:
		1:
			_state = "ordering"
			_state_timer = 2.4 + fposmod(_cycle_offset, 1.4)
			if _status_label != null:
				_status_label.text = "%s\n%s" % [_customer_name, _order_name]
		2:
			_state = "eating"
			_state_timer = 5.0 + fposmod(_cycle_offset, 2.5)
			if _status_label != null:
				_status_label.text = "%s\nCOMENDO" % _customer_name
		3:
			_state = "leaving_wait"
			_state_timer = 1.0
			if _status_label != null:
				_status_label.text = "%s\nVOLTE SEMPRE!" % _customer_name

func _advance_state() -> void:
	if _state == "ordering":
		_route_index = 2
		_state = "walking_to_seat"
	elif _state == "eating":
		_route_index = 3
		_state = "leaving"
	elif _state == "leaving_wait":
		position = _spawn_position
		_route_index = 1
		_state = "entering"
		if _status_label != null:
			_status_label.text = "%s • PEDIDO" % _customer_name

func _find_skeleton(root: Node) -> Skeleton3D:
	if root is Skeleton3D:
		return root as Skeleton3D
	for child in root.get_children():
		var found := _find_skeleton(child)
		if found != null:
			return found
	return null

func _animate_walk(moving: bool) -> void:
	if _skeleton == null:
		return
	var swing := sin(_gait_clock) * (0.36 if moving else 0.015)
	var left_leg := _skeleton.find_bone("Left Leg_04")
	var right_leg := _skeleton.find_bone("Right Leg_05")
	var left_arm := _skeleton.find_bone("Left Arm_02")
	var right_arm := _skeleton.find_bone("Right Arm_03")
	if left_leg >= 0:
		_skeleton.set_bone_pose_rotation(left_leg, Quaternion(Vector3.RIGHT, swing))
	if right_leg >= 0:
		_skeleton.set_bone_pose_rotation(right_leg, Quaternion(Vector3.RIGHT, -swing))
	if left_arm >= 0:
		_skeleton.set_bone_pose_rotation(left_arm, Quaternion(Vector3.RIGHT, -swing * 0.7))
	if right_arm >= 0:
		_skeleton.set_bone_pose_rotation(right_arm, Quaternion(Vector3.RIGHT, swing * 0.7))
