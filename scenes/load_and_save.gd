@tool
extends Node2D

@export var production_resource : ProductionResource

@export_tool_button("Save Production", "Callable") var save_action = save_production
@export_tool_button("Load Production", "Callable") var load_action = load_production


func save_production():
	if not production_resource:
		production_resource = ProductionResource.new()

	var path = production_resource.resource_path
	if path == "":
		path = "res://data/productions/1.tres"

	production_resource.left_tiles = _collect_tiles($LeftSide)
	production_resource.right_tiles = _collect_tiles($RightSide)
	production_resource.border_tiles = _collect_tiles($Border)

	ResourceSaver.save(production_resource, path)
	print("Zapisano")


func load_production():
	if not production_resource:
		print("Brak resource")
		return

	_apply_tiles($LeftSide, production_resource.left_tiles)
	_apply_tiles($RightSide, production_resource.right_tiles)
	_apply_tiles($Border, production_resource.border_tiles)

	print("Wczytano")

func _collect_tiles(tilemap: TileMapLayer) -> Array:
	var data = []
	for cell in tilemap.get_used_cells():
		var source_id = tilemap.get_cell_source_id(cell)
		var atlas_coords = tilemap.get_cell_atlas_coords(cell)
		var alt = tilemap.get_cell_alternative_tile(cell)
		data.append({
			"pos": cell,
			"source": source_id,
			"atlas": atlas_coords,
			"alt": alt
		})
	return data
func _apply_tiles(tilemap: TileMapLayer, data: Array):
	tilemap.clear()
	for t in data:
		tilemap.set_cell(t["pos"], t["source"], t["atlas"], t["alt"])
	tilemap.update_internals()
