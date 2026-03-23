extends Node

@onready var tilemap: TileMapLayer = get_node_or_null("swordLogic") as TileMapLayer

var productions_expand: Array = []
var productions_shrink: Array = []

func _ready():
	productions_expand = load_all_productions("res://data/productions/generated/expand")
	productions_shrink = load_all_productions("res://data/productions/generated/shrink")
	print("Expand:", len(productions_expand), "Shrink:", len(productions_shrink))


func _on_restart_pressed():
	$"swordRender".mark_dirty()
	if tilemap == null:
		print("TileMapLayer missing")
		return
	tilemap.reset_tiles()
	print("Tilemap reset")


func _on_production_expand_pressed():
	$"swordRender".mark_dirty()
	if productions_expand.is_empty() or tilemap == null:
		print("No expand productions or tilemap missing")
		return
	var prod = productions_expand[randi() % productions_expand.size()]
	print("Applying expand production:", prod)
	replace_pattern_tilemaplayer(tilemap, prod.left_tiles, prod.right_tiles)


func _on_production_shrink_pressed():
	$"swordRender".mark_dirty()
	if productions_shrink.is_empty() or tilemap == null:
		print("No shrink productions or tilemap missing")
		return
	var prod = productions_shrink[randi() % productions_shrink.size()]
	print("Applying shrink production:", prod)
	replace_pattern_tilemaplayer(tilemap, prod.left_tiles, prod.right_tiles)


# =======================
# CELL MATCHING
# =======================
func _cell_matches(layer: TileMapLayer, pos: Vector2i, data: Dictionary) -> bool:
	var atlas_coords: Vector2i = data.get("atlas", Vector2i(-1, -1))
	var source_id: int = int(data.get("source", -1))

	# puste kafelki (atlas 0,4)
	if atlas_coords == Vector2i(0,4):
		var empty = layer.get_cell_source_id(pos) == -1
		if not empty:
			print("Expected empty cell at", pos, "but found source", layer.get_cell_source_id(pos))
		return empty

	# normalne kafelki: porównujemy tylko source i atlas
	var cell_source = layer.get_cell_source_id(pos)
	var cell_atlas = layer.get_cell_atlas_coords(pos)

	if cell_source != source_id or cell_atlas != atlas_coords:
		print("Cell mismatch at:", pos)
		print("Expected -> source:", source_id, "atlas:", atlas_coords)
		print("Actual   -> source:", cell_source, "atlas:", cell_atlas)
		return false

	return true


# =======================
# FIND MATCHES ACROSS TILEMAP
# =======================
func _find_matches_tilemap(tm_layer: TileMapLayer, pattern: Array) -> Array:
	var matches: Array = []

	if pattern.is_empty() or tm_layer == null:
		return matches

	# maksymalny offset patternu
	var max_pattern_x = -1
	var max_pattern_y = -1
	for part in pattern:
		var pos: Vector2i = part.get("pos", Vector2i.ZERO)
		if pos.x > max_pattern_x:
			max_pattern_x = pos.x
		if pos.y > max_pattern_y:
			max_pattern_y = pos.y

	# rozmiar tilemapy
	var used_cells := tm_layer.get_used_cells()
	if used_cells.is_empty():
		return matches

	var min_x = used_cells[0].x
	var min_y = used_cells[0].y
	var max_x = used_cells[0].x
	var max_y = used_cells[0].y
	for c in used_cells:
		if c.x < min_x:
			min_x = c.x
		if c.y < min_y:
			min_y = c.y
		if c.x > max_x:
			max_x = c.x
		if c.y > max_y:
			max_y = c.y

	# przesuwamy pattern w granicach tilemapy
	for origin_x in range(min_x, max_x - max_pattern_x + 1):
		for origin_y in range(min_y, max_y - max_pattern_y + 1):
			var origin = Vector2i(origin_x, origin_y)
			var ok = true
			for part in pattern:
				var pos = origin + part.get("pos", Vector2i.ZERO)
				if not _cell_matches(tm_layer, pos, part):
					ok = false
					break
			if ok:
				matches.append(origin)

	return matches


# =======================
# REPLACE PATTERN TILEMAPLAYER
# =======================
func replace_pattern_tilemaplayer(tm_layer: TileMapLayer, pattern: Array, replacement: Array) -> void:
	if tm_layer == null or pattern.is_empty() or replacement.is_empty():
		return

	# szukamy dopasowań
	var matches = _find_matches_tilemap(tm_layer, pattern)
	if matches.is_empty():
		print("No matches found for pattern")
		return

	var rng = RandomNumberGenerator.new()
	rng.randomize()
	var chosen_origin = matches[rng.randi_range(0, matches.size() - 1)]
	print("Chosen origin:", chosen_origin)

	# usuń starą wersję
	for part in pattern:
		var pos = chosen_origin + part.get("pos", Vector2i.ZERO)
		print("Erasing cell at:", pos, "source:", part.get("source"))
		tm_layer.erase_cell(pos)

	# wstaw nową wersję
	for part in replacement:
		var pos = chosen_origin + part.get("pos", Vector2i.ZERO)
		tm_layer.set_cell(
			pos,
			int(part.get("source", -1)),
			Vector2i(part.get("atlas", Vector2i(-1,-1))),
			int(part.get("alternative_tile", 0))
		)


# =======================
# LOAD PRODUCTIONS
# =======================
func load_production_resource(path: String) -> ProductionResource:
	var res = ResourceLoader.load(path)
	if res and res is ProductionResource:
		return res
	return null


func load_all_productions(folder_path: String) -> Array:
	var dir = DirAccess.open(folder_path)
	if not dir:
		print("Folder not found:", folder_path)
		return []

	var productions: Array = []
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
	print("Loaded productions from", folder_path, "count:", productions.size())
	return productions
