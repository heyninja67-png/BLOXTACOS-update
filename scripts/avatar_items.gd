class_name AvatarItems
extends RefCounted

## Loads original BloxTacos accessory meshes as separate GLB scenes. The models
## are authored for the classic avatar-root coordinate system (Y up, forward -Z).
const ACCESSORY_SCENES := {
	"classic_cap": "res://assets/catalog/models/classic_cap.glb",
	"retro_shades": "res://assets/catalog/models/retro_shades.glb",
	"gold_crown": "res://assets/catalog/models/gold_crown.glb",
	"green_visor": "res://assets/catalog/models/green_visor.glb",
	"red_backpack": "res://assets/catalog/models/red_backpack.glb",
	"star_halo": "res://assets/catalog/models/star_halo.glb",
	"headphones": "res://assets/catalog/models/headphones.glb",
	"classic_scarf": "res://assets/catalog/models/classic_scarf.glb",
	"gold_chain": "res://assets/catalog/models/gold_chain.glb",
	"blue_tee": "res://assets/catalog/models/blue_tee.glb"
}

static func apply(root: Node3D, equipped_ids: Array) -> void:
	if root == null:
		return
	var old_layer := root.get_node_or_null("BloxTacosCosmetics")
	if old_layer != null:
		root.remove_child(old_layer)
		old_layer.queue_free()
	var layer := Node3D.new()
	layer.name = "BloxTacosCosmetics"
	root.add_child(layer)
	for item_id in equipped_ids:
		var asset_path: String = ACCESSORY_SCENES.get(String(item_id), "")
		if asset_path.is_empty():
			continue
		var packed := load(asset_path) as PackedScene
		if packed == null:
			push_warning("Modelo de acessório não pôde ser carregado: " + asset_path)
			continue
		var accessory := packed.instantiate() as Node3D
		if accessory == null:
			continue
		accessory.name = "Accessory_" + String(item_id)
		layer.add_child(accessory)
