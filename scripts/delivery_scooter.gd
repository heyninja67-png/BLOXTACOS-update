extends Node3D

## Original low-poly delivery scooter visual. It is parented to the player while mounted.

func _ready() -> void:
	_build_scooter()

func _build_scooter() -> void:
	_add_box("Deck", Vector3(0, -0.62, 0.18), Vector3(0.48, 0.14, 1.2), Color("#c64b3f"))
	_add_box("FrontFairing", Vector3(0, -0.34, -0.34), Vector3(0.42, 0.45, 0.42), Color("#d7dce0"))
	_add_box("Headlamp", Vector3(0, -0.27, -0.56), Vector3(0.22, 0.16, 0.05), Color("#fff0b2"))
	_add_box("Seat", Vector3(0, -0.13, 0.28), Vector3(0.42, 0.13, 0.52), Color("#303b45"))
	_add_box("HandleStem", Vector3(0, 0.02, -0.48), Vector3(0.09, 0.65, 0.09), Color("#6d747a"))
	_add_box("HandleBar", Vector3(0, 0.34, -0.48), Vector3(0.78, 0.09, 0.12), Color("#343a40"))
	_add_box("DeliveryBox", Vector3(0, 0.12, 0.65), Vector3(0.65, 0.52, 0.58), Color("#f1dfb6"))
	_add_box("BoxStripe", Vector3(0, 0.12, 0.35), Vector3(0.66, 0.12, 0.06), Color("#bd493d"))
	_add_wheel("FrontWheel", Vector3(0, -0.62, -0.58))
	_add_wheel("RearWheel", Vector3(0, -0.62, 0.72))

func _add_box(node_name: String, local_position: Vector3, dimensions: Vector3, color: Color) -> void:
	var instance := MeshInstance3D.new()
	instance.name = node_name
	var mesh := BoxMesh.new()
	mesh.size = dimensions
	instance.mesh = mesh
	instance.position = local_position
	instance.material_override = _material(color)
	add_child(instance)

func _add_wheel(node_name: String, local_position: Vector3) -> void:
	var wheel := MeshInstance3D.new()
	wheel.name = node_name
	var mesh := CylinderMesh.new()
	mesh.top_radius = 0.28
	mesh.bottom_radius = 0.28
	mesh.height = 0.16
	wheel.mesh = mesh
	wheel.position = local_position
	wheel.rotation.z = PI * 0.5
	wheel.material_override = _material(Color("#20262c"))
	add_child(wheel)
	var hub := MeshInstance3D.new()
	var hub_mesh := CylinderMesh.new()
	hub_mesh.top_radius = 0.11
	hub_mesh.bottom_radius = 0.11
	hub_mesh.height = 0.18
	hub.mesh = hub_mesh
	hub.position = local_position
	hub.rotation.z = PI * 0.5
	hub.material_override = _material(Color("#aeb8bf"))
	add_child(hub)

func _material(color: Color) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.roughness = 0.76
	return material
