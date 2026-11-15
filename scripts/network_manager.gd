extends Node

## BloxTacos high-level multiplayer coordinator.
## ENet is UDP-based. The host remains authoritative for roster, chat, match selection,
## and movement acceptance. Client position packets are rate-limited and speed-clamped.
## Cosmetic IDs are allow-listed and synchronized, but ownership remains local in this alpha.

signal status_changed(message: String)
signal roster_changed(roster: Array)
signal player_state_changed(peer_id: int, position: Vector3, yaw: float, avatar_id: String)
signal chat_received(author: String, message: String)
signal experience_changed(mode_id: String)

const DEFAULT_PORT := 24680
const MAX_CLIENTS := 16
const ALLOWED_AVATARS := ["noob", "bacon"]
const ALLOWED_ACCESSORIES := ["classic_cap", "retro_shades", "gold_crown", "green_visor", "red_backpack", "star_halo", "headphones", "classic_scarf", "gold_chain", "blue_tee"]
const ALLOWED_EXPERIENCES := ["classic", "disaster", "pizza"]
const MAX_CHAT_LENGTH := 140
const MAX_MOVE_SPEED := 14.0
const MIN_STATE_INTERVAL_MS := 45

var _peer: ENetMultiplayerPeer
var _network_active := false
var _server_mode := false
var _client_connected := false
var _dedicated_server := false
var _server_port := DEFAULT_PORT
var _session_leader_id := 0
var _local_profile: Dictionary = {"name": "BloxPlayer", "avatar": "noob", "equipped": []}
var _players: Dictionary = {}
var _chat_timestamps: Dictionary = {}
var _last_state_timestamps: Dictionary = {}
var _current_experience := "classic"
var _status_message := "Offline — sessão local"

func _ready() -> void:
	multiplayer.peer_connected.connect(_on_peer_connected)
	multiplayer.peer_disconnected.connect(_on_peer_disconnected)
	multiplayer.connected_to_server.connect(_on_connected_to_server)
	multiplayer.connection_failed.connect(_on_connection_failed)
	multiplayer.server_disconnected.connect(_on_server_disconnected)
	_parse_server_arguments()

func _parse_server_arguments() -> void:
	var wants_server := false
	for argument in OS.get_cmdline_user_args():
		if argument == "--server":
			wants_server = true
		elif argument.begins_with("--port="):
			_server_port = clampi(int(argument.trim_prefix("--port=")), 1, 65535)
	if wants_server:
		_dedicated_server = true
		call_deferred("start_server", _server_port)

func set_local_profile(player_name: String, avatar_id: String, equipped_ids: Array = []) -> void:
	var clean_name := _clean_player_name(player_name)
	_local_profile = {
		"name": clean_name,
		"avatar": avatar_id if ALLOWED_AVATARS.has(avatar_id) else "noob",
		"equipped": _sanitize_equipped(equipped_ids)
	}
	if _network_active and _server_mode:
		_players[1] = _make_player_record(1, _local_profile)
		_broadcast_roster()
	elif _network_active and _client_connected:
		_rpc_register_profile.rpc_id(1, _local_profile)

func start_server(port: int = DEFAULT_PORT) -> Error:
	disconnect_session()
	var new_peer := ENetMultiplayerPeer.new()
	var result := new_peer.create_server(clampi(port, 1, 65535), MAX_CLIENTS)
	if result != OK:
		_set_status("Falha ao abrir servidor UDP na porta %d (código %d)." % [port, result])
		return result
	_peer = new_peer
	multiplayer.multiplayer_peer = _peer
	_network_active = true
	_server_mode = true
	_client_connected = false
	_server_port = port
	_session_leader_id = 0 if _dedicated_server else 1
	_players.clear()
	if not _dedicated_server:
		_players[1] = _make_player_record(1, _local_profile)
		_last_state_timestamps[1] = Time.get_ticks_msec()
	if _dedicated_server:
		_set_status("Servidor dedicado ativo • UDP %d • aguardando jogadores" % port)
	else:
		var lan_address := _get_private_ipv4()
		var address_text := lan_address if not lan_address.is_empty() else "IP local não identificado"
		_set_status("Servidor LAN ativo • %s:%d UDP • aguardando jogadores" % [address_text, port])
	_emit_roster()
	return OK

func start_client(address: String, port: int = DEFAULT_PORT) -> Error:
	var host := address.strip_edges()
	if host.is_empty():
		_set_status("Informe o IP ou domínio do servidor.")
		return ERR_INVALID_PARAMETER
	disconnect_session()
	var new_peer := ENetMultiplayerPeer.new()
	var result := new_peer.create_client(host, clampi(port, 1, 65535))
	if result != OK:
		_set_status("Não foi possível iniciar a conexão (código %d)." % result)
		return result
	_peer = new_peer
	multiplayer.multiplayer_peer = _peer
	_network_active = true
	_server_mode = false
	_client_connected = false
	_players.clear()
	_set_status("Conectando a %s:%d…" % [host, port])
	return OK

func disconnect_session() -> void:
	if _network_active:
		multiplayer.multiplayer_peer = OfflineMultiplayerPeer.new()
	_peer = null
	_network_active = false
	_server_mode = false
	_client_connected = false
	_players.clear()
	_chat_timestamps.clear()
	_last_state_timestamps.clear()
	_session_leader_id = 0
	_set_status("Offline — sessão local")
	_emit_roster()

func is_online() -> bool:
	return _network_active

func is_server_session() -> bool:
	return _network_active and _server_mode

func is_dedicated_server() -> bool:
	return _dedicated_server

func get_status_message() -> String:
	return _status_message

func get_player_count() -> int:
	return _players.size() if _network_active else 1

func get_local_peer_id() -> int:
	return multiplayer.get_unique_id() if _network_active else 1

func get_roster() -> Array:
	return _make_roster()

func get_current_experience() -> String:
	return _current_experience

func set_experience(mode_id: String) -> void:
	if not is_server_session() or not ALLOWED_EXPERIENCES.has(mode_id):
		return
	_apply_experience(mode_id)

func request_experience(mode_id: String) -> void:
	if not ALLOWED_EXPERIENCES.has(mode_id):
		return
	if _server_mode:
		if _session_leader_id == 1:
			_apply_experience(mode_id)
	elif _client_connected:
		_rpc_request_experience.rpc_id(1, mode_id)

func is_session_leader() -> bool:
	return _network_active and _session_leader_id > 0 and get_local_peer_id() == _session_leader_id

func _apply_experience(mode_id: String) -> void:
	if not ALLOWED_EXPERIENCES.has(mode_id):
		return
	_current_experience = mode_id
	if _server_mode:
		_rpc_receive_experience.rpc(mode_id)
	experience_changed.emit(mode_id)

func submit_local_state(player_position: Vector3, yaw: float, avatar_id: String) -> void:
	if not _network_active:
		return
	var safe_avatar := avatar_id if ALLOWED_AVATARS.has(avatar_id) else "noob"
	if _server_mode:
		_accept_player_state(1, player_position, yaw, safe_avatar)
	else:
		_rpc_submit_player_state.rpc_id(1, player_position, yaw, safe_avatar)

func send_chat(message_text: String) -> void:
	var clean_message := message_text.strip_edges().replace("[", "(").replace("]", ")").left(MAX_CHAT_LENGTH)
	if clean_message.is_empty():
		return
	if not _network_active:
		chat_received.emit(String(_local_profile.get("name", "Você")), clean_message)
	elif _server_mode:
		_accept_chat(1, clean_message)
	else:
		_rpc_submit_chat.rpc_id(1, clean_message)

func _make_player_record(peer_id: int, profile: Dictionary) -> Dictionary:
	return {
		"peer_id": peer_id,
		"is_leader": peer_id == _session_leader_id,
		"name": _clean_player_name(String(profile.get("name", "Jogador"))),
		"avatar": String(profile.get("avatar", "noob")) if ALLOWED_AVATARS.has(String(profile.get("avatar", "noob"))) else "noob",
		"equipped": _sanitize_equipped(profile.get("equipped", [])),
		"position": Vector3(0.0, 0.2, 5.0),
		"yaw": 0.0
	}

func _sanitize_equipped(value: Variant) -> Array:
	var result: Array = []
	if not (value is Array):
		return result
	for accessory_id in value:
		var item_id := String(accessory_id)
		if ALLOWED_ACCESSORIES.has(item_id) and not result.has(item_id):
			result.append(item_id)
	return result

func _clean_player_name(raw_name: String) -> String:
	var value := raw_name.strip_edges().left(18)
	var filter := RegEx.new()
	filter.compile("[^A-Za-z0-9 _-]")
	value = filter.sub(value, "", true).strip_edges()
	return value if not value.is_empty() else "BloxPlayer"

func _elect_session_leader() -> int:
	if not _dedicated_server:
		return 1
	var candidates: Array[int] = []
	for peer_id in _players.keys():
		if int(peer_id) > 1:
			candidates.append(int(peer_id))
	candidates.sort()
	return candidates[0] if not candidates.is_empty() else 0

func _update_leader_flags() -> void:
	for peer_id in _players.keys():
		var record: Dictionary = _players[peer_id]
		record["is_leader"] = int(peer_id) == _session_leader_id
		_players[peer_id] = record

func _broadcast_roster() -> void:
	_update_leader_flags()
	_emit_roster()
	if _server_mode:
		_rpc_receive_roster.rpc(_make_roster(), _current_experience)

func _make_roster() -> Array:
	var result: Array = []
	for peer_id in _players.keys():
		var record: Dictionary = _players[peer_id].duplicate(true)
		record["peer_id"] = int(peer_id)
		result.append(record)
	result.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return int(a.peer_id) < int(b.peer_id))
	return result

func _emit_roster() -> void:
	roster_changed.emit(_make_roster())

func _set_status(message: String) -> void:
	_status_message = message
	status_changed.emit(message)

func _on_peer_connected(_peer_id: int) -> void:
	if _server_mode:
		var limit := MAX_CLIENTS if _dedicated_server else MAX_CLIENTS + 1
		_set_status("Jogador conectando • %d/%d" % [_players.size(), limit])

func _on_peer_disconnected(peer_id: int) -> void:
	if _server_mode:
		_players.erase(peer_id)
		_chat_timestamps.erase(peer_id)
		_last_state_timestamps.erase(peer_id)
		if peer_id == _session_leader_id:
			_session_leader_id = _elect_session_leader()
		_update_leader_flags()
		_broadcast_roster()
	else:
		_emit_roster()
	if _network_active:
		_set_status("Conectado • %d jogador(es)" % get_player_count())

func _on_connected_to_server() -> void:
	_client_connected = true
	_set_status("Conectado ao servidor • registrando avatar…")
	_rpc_register_profile.rpc_id(1, _local_profile)

func _on_connection_failed() -> void:
	disconnect_session()
	_set_status("Conexão recusada. Confira o IP, a porta UDP e se o servidor está ativo.")

func _on_server_disconnected() -> void:
	disconnect_session()
	_set_status("O servidor encerrou a conexão.")

@rpc("any_peer", "call_remote", "reliable")
func _rpc_register_profile(profile: Dictionary) -> void:
	if not multiplayer.is_server():
		return
	var sender_id := multiplayer.get_remote_sender_id()
	var record_limit := MAX_CLIENTS if _dedicated_server else MAX_CLIENTS + 1
	if sender_id <= 1 or (not _players.has(sender_id) and _players.size() >= record_limit):
		return
	if _dedicated_server and _session_leader_id == 0:
		_session_leader_id = sender_id
	var accepted := _make_player_record(sender_id, profile)
	_players[sender_id] = accepted
	_last_state_timestamps[sender_id] = Time.get_ticks_msec()
	_broadcast_roster()
	_set_status("Conectado • %d jogador(es)" % get_player_count())

@rpc("authority", "call_remote", "reliable")
func _rpc_receive_roster(roster: Array, experience_id: String) -> void:
	_players.clear()
	for record in roster:
		if record is Dictionary:
			var peer_id := int(record.get("peer_id", 0))
			if peer_id > 0:
				_players[peer_id] = record.duplicate(true)
	_current_experience = experience_id if ALLOWED_EXPERIENCES.has(experience_id) else "classic"
	_session_leader_id = 0
	for record in roster:
		if record is Dictionary and bool(record.get("is_leader", false)):
			_session_leader_id = int(record.get("peer_id", 0))
	_emit_roster()
	_set_status("Conectado ao servidor • %d jogador(es)" % get_player_count())
	experience_changed.emit(_current_experience)

@rpc("authority", "call_remote", "reliable")
func _rpc_receive_player_joined(peer_id: int, record: Dictionary) -> void:
	_players[peer_id] = record.duplicate(true)
	_emit_roster()

@rpc("authority", "call_remote", "reliable")
func _rpc_receive_player_left(peer_id: int) -> void:
	_players.erase(peer_id)
	_emit_roster()

@rpc("any_peer", "call_remote", "reliable")
func _rpc_request_experience(mode_id: String) -> void:
	if not multiplayer.is_server() or not ALLOWED_EXPERIENCES.has(mode_id):
		return
	var sender_id := multiplayer.get_remote_sender_id()
	if sender_id != _session_leader_id:
		return
	_apply_experience(mode_id)

@rpc("any_peer", "call_remote", "unreliable_ordered", 1)
func _rpc_submit_player_state(player_position: Vector3, yaw: float, avatar_id: String) -> void:
	if not multiplayer.is_server():
		return
	var sender_id := multiplayer.get_remote_sender_id()
	if not _players.has(sender_id):
		return
	_accept_player_state(sender_id, player_position, yaw, avatar_id)

func _accept_player_state(peer_id: int, requested_position: Vector3, yaw: float, avatar_id: String) -> void:
	if not _players.has(peer_id):
		return
	var record: Dictionary = _players[peer_id]
	var now := Time.get_ticks_msec()
	var last_time := int(_last_state_timestamps.get(peer_id, now))
	var elapsed_ms := now - last_time
	if elapsed_ms < MIN_STATE_INTERVAL_MS:
		return
	var elapsed := clampf(float(elapsed_ms) / 1000.0, 0.045, 0.5)
	if not (is_finite(requested_position.x) and is_finite(requested_position.y) and is_finite(requested_position.z) and is_finite(yaw)):
		return
	var old_position: Vector3 = record.get("position", Vector3(0, 0.2, 5))
	var allowed_distance := MAX_MOVE_SPEED * elapsed + 0.35
	var displacement := requested_position - old_position
	var accepted_position := requested_position
	if displacement.length() > allowed_distance:
		accepted_position = old_position + displacement.normalized() * allowed_distance
	accepted_position.x = clampf(accepted_position.x, -140.0, 140.0)
	accepted_position.z = clampf(accepted_position.z, -140.0, 140.0)
	if accepted_position.y < -12.0 or accepted_position.y > 65.0:
		accepted_position.y = old_position.y
	var safe_avatar := avatar_id if ALLOWED_AVATARS.has(avatar_id) else String(record.get("avatar", "noob"))
	record["position"] = accepted_position
	record["yaw"] = wrapf(yaw, -PI, PI)
	record["avatar"] = safe_avatar
	_players[peer_id] = record
	_last_state_timestamps[peer_id] = now
	_rpc_receive_player_state.rpc(peer_id, accepted_position, float(record.yaw), safe_avatar)
	player_state_changed.emit(peer_id, accepted_position, float(record.yaw), safe_avatar)

@rpc("authority", "call_remote", "unreliable_ordered", 1)
func _rpc_receive_player_state(peer_id: int, player_position: Vector3, yaw: float, avatar_id: String) -> void:
	if _players.has(peer_id):
		var record: Dictionary = _players[peer_id]
		record["position"] = player_position
		record["yaw"] = yaw
		record["avatar"] = avatar_id
		_players[peer_id] = record
	player_state_changed.emit(peer_id, player_position, yaw, avatar_id)

@rpc("any_peer", "call_remote", "reliable")
func _rpc_submit_chat(message_text: String) -> void:
	if not multiplayer.is_server():
		return
	var sender_id := multiplayer.get_remote_sender_id()
	if not _players.has(sender_id):
		return
	var now := Time.get_ticks_msec()
	var last_time := int(_chat_timestamps.get(sender_id, 0))
	if now - last_time < 550:
		return
	_chat_timestamps[sender_id] = now
	_accept_chat(sender_id, message_text)

func _accept_chat(peer_id: int, message_text: String) -> void:
	var clean_message := message_text.strip_edges().replace("[", "(").replace("]", ")").left(MAX_CHAT_LENGTH)
	if clean_message.is_empty():
		return
	var record: Dictionary = _players.get(peer_id, _make_player_record(peer_id, _local_profile))
	var author := String(record.get("name", "Jogador"))
	_rpc_receive_chat.rpc(author, clean_message)
	chat_received.emit(author, clean_message)

@rpc("authority", "call_remote", "reliable")
func _rpc_receive_chat(author: String, message_text: String) -> void:
	chat_received.emit(_clean_player_name(author), message_text.left(MAX_CHAT_LENGTH))

@rpc("authority", "call_remote", "reliable")
func _rpc_receive_experience(mode_id: String) -> void:
	if not ALLOWED_EXPERIENCES.has(mode_id):
		return
	_current_experience = mode_id
	experience_changed.emit(mode_id)


func _get_private_ipv4() -> String:
	for address in IP.get_local_addresses():
		var value := String(address)
		if value.contains(":") or value.begins_with("127.") or value == "0.0.0.0":
			continue
		if value.begins_with("10.") or value.begins_with("192.168."):
			return value
		var segments := value.split(".")
		if segments.size() == 4 and segments[0] == "172":
			var second := int(segments[1])
			if second >= 16 and second <= 31:
				return value
	return ""
