extends Node3D

## Small deterministic worker routine for Pizza Place stations.
## Uses a hand-authored waypoint loop so the scene does not need a navigation bake.

var _avatar_scene: PackedScene
var _visual_root: Node3D
var _skeleton: Skeleton3D
var _nameplate: Label3D
var _route: Array[Vector3] = []
var _route_index := 0
var _pause_timer := 0.0
var _gait_clock := 0.0
var _walk_speed := 1.55
var _job_label := "FUNCIONÁRIO"
var _name := "Funcionário"

func configure(avatar_scene: PackedScene, worker_name: String, job_label: String, route: Array, walk_speed: float = 1.55) -> void:
	_avatar_scene = avatar_scene
	_name = worker_name
	_job_label = job_label
	_route.clear()
	for waypoint in route:
		if waypoint is Vector3:
			_route.append(waypoint)
	_walk_speed = walk_speed
	if not _route.is_empty():
		position = _route[0]
	_build_visual()

func _build_visual() -> void:
	if _avatar_scene == null:
		return
	_visual_root = _avatar_scene.instantiate() as Node3D
	if _visual_root == null:
		return
	_visual_root.name = "WorkerAvatar"
	_visual_root.rotation.x = -PI * 0.5
	add_child(_visual_root)
	_skeleton = _find_skeleton(_visual_root)
	_nameplate = Label3D.new()
	_nameplate.name = "WorkerNameplate"
	_nameplate.text = "%s\n%s" % [_name, _job_label]
	_nameplate.position = Vector3(0, 3.0, 0)
	_nameplate.font_size = 20
	_nameplate.pixel_size = 0.006
	_nameplate.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	_nameplate.outline_size = 5
	_nameplate.modulate = Color("#fff0cf")
	add_child(_nameplate)

func _process(delta: float) -> void:
	if _route.size() < 2:
		return
	if _pause_timer > 0.0:
		_pause_timer = maxf(0.0, _pause_timer - delta)
		_animate_walk(false)
		return
	var target := _route[_route_index]
	var flat_target := Vector3(target.x, position.y, target.z)
	var direction := flat_target - position
	if direction.length() <= 0.18:
		_route_index = (_route_index + 1) % _route.size()
		_pause_timer = 1.2 + float((_route_index * 3) % 4) * 0.25
		if _nameplate != null:
			_nameplate.text = "%s\n%s" % [_name, _job_label]
		_animate_walk(false)
		return
	position = position.move_toward(flat_target, _walk_speed * delta)
	_gait_clock += delta * 7.0
	_animate_walk(true)
	if _visual_root != null:
		_visual_root.rotation.y = lerp_angle(_visual_root.rotation.y, atan2(-direction.x, -direction.z), minf(1.0, delta * 7.0))

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
	var swing := sin(_gait_clock) * (0.3 if moving else 0.012)
	var left_leg := _skeleton.find_bone("Left Leg_04")
	var right_leg := _skeleton.find_bone("Right Leg_05")
	var left_arm := _skeleton.find_bone("Left Arm_02")
	var right_arm := _skeleton.find_bone("Right Arm_03")
	if left_leg >= 0:
		_skeleton.set_bone_pose_rotation(left_leg, Quaternion(Vector3.RIGHT, swing))
	if right_leg >= 0:
		_skeleton.set_bone_pose_rotation(right_leg, Quaternion(Vector3.RIGHT, -swing))
	if left_arm >= 0:
		_skeleton.set_bone_pose_rotation(left_arm, Quaternion(Vector3.RIGHT, -swing * 0.65))
	if right_arm >= 0:
		_skeleton.set_bone_pose_rotation(right_arm, Quaternion(Vector3.RIGHT, swing * 0.65))
