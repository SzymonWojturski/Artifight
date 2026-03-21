extends Node

@onready var tilemap: TileMapLayer = get_node_or_null("swordLogic") as TileMapLayer

var productions_expand: Array = []
var productions_shrink: Array = []

func _ready():
	productions_expand = load_all_productions("res://data/productions/expand")
	productions_shrink = load_all_productions("res://data/productions/shrink")

func _on_restart_pressed():
	$"swordRender".mark_dirty()
	if tilemap == null:
		return
	tilemap.reset_tiles()

func _on_production_expand_pressed():
	$"swordRender".mark_dirty()
	if productions_expand.is_empty() or tilemap == null:
		return
	var prod = productions_expand[randi() % productions_expand.size()]
	replace_pattern_tilemaplayer(tilemap, prod.left_tiles, prod.right_tiles)

func _on_production_shrink_pressed():
	$"swordRender".mark_dirty()
	if productions_shrink.is_empty() or tilemap == null:
		return

	var prod = productions_shrink[randi() % productions_shrink.size()]
	replace_pattern_tilemaplayer(tilemap, prod.left_tiles, prod.right_tiles)


func _cell_source(cell) -> int:
	if cell is Dictionary:
		return int(cell.get("source", 0))
	return int(cell)

func _cell_matches2(layer: TileMapLayer, pos: Vector2i, data: Dictionary) -> bool:
	var atlas_coords: Vector2i = data.get("atlas", Vector2i(-1, -1))
	var require_empty: bool = atlas_coords == Vector2i(0, 4)

	if require_empty:
		return layer.get_cell_source_id(pos) == -1

	var source_id: int = int(data.get("source", -1))
	return layer.get_cell_source_id(pos) == source_id \
		and layer.get_cell_atlas_coords(pos) == atlas_coords

func _cell_matches(layer: TileMapLayer, pos: Vector2i, data: Dictionary) -> bool:
	var atlas_coords: Vector2i = data.get("atlas", Vector2i(-1, -1))
	var require_empty: bool = atlas_coords == Vector2i(0, 4)

	if require_empty:
		return layer.get_cell_source_id(pos) == -1

	var source_id: int = int(data.get("source", -1))
	return layer.get_cell_source_id(pos) == source_id \
		and layer.get_cell_atlas_coords(pos) == atlas_coords

func replace_pattern_tilemaplayer(tm_layer: TileMapLayer, pattern: Array, replacement: Array) -> void:
	if tm_layer == null or pattern.is_empty() or replacement.is_empty():
		return

	var anchor: Dictionary = pattern[0]
	var anchor_offset: Vector2i = anchor.get("pos", Vector2i.ZERO)

	var matches: Array[Vector2i] = []
	var used_cells := tm_layer.get_used_cells()

	for cell in used_cells:
		var origin := cell - anchor_offset
		var ok := true

		for part in pattern:
			var offset: Vector2i = part.get("pos", Vector2i.ZERO)
			var p = origin + offset
			if not _cell_matches(tm_layer, p, part):
				ok = false
				break

		if ok:
			matches.append(origin)

	if matches.is_empty():
		return
	var rng := RandomNumberGenerator.new()
	rng.randomize()
	var chosen_origin := matches[rng.randi_range(0, matches.size() - 1)]

	for part in pattern:
		var pos = chosen_origin + part.get("pos", Vector2i.ZERO)
		tm_layer.erase_cell(pos)

	for part in replacement:
		var pos = chosen_origin + part.get("pos", Vector2i.ZERO)
		tm_layer.set_cell(
			pos,
			int(part.get("source", -1)),
			part.get("atlas", Vector2i(-1, -1)),
			int(part.get("alternative_tile", 0))
		)

func load_production_resource(path: String) -> ProductionResource:
	var res = ResourceLoader.load(path)
	if res and res is ProductionResource:
		return res
	return null

func load_all_productions(folder_path: String) -> Array:
	var dir = DirAccess.open(folder_path)
	if not dir:
		return []

	var productions = []
	dir.list_dir_begin()
	var file_name = dir.get_next()
	while file_name != "":
		if not dir.current_is_dir():
			if file_name.ends_with(".tres") or file_name.ends_with(".res"):
				var res = load_production_resource(folder_path + "/" + file_name)
				if res:
					productions.append(res)
		file_name = dir.get_next()
	dir.list_dir_end()
	return productions
