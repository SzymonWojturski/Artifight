extends Node

@onready var tilemap: TileMapLayer = get_node_or_null("swordLogic") as TileMapLayer

var productions_shrink: Array = []
var _expand_productions: Array = []
var expand_charges_left: int = 0

func _ready() -> void:
	productions_shrink = load_all_productions("res://data/productions/generated/shrink")
	_expand_productions = load_all_productions("res://data/productions/generated/expand")

	if GameState.has_state and GameState.sword_tile_data.size() > 0:
		tilemap.tile_map_data = GameState.sword_tile_data
		tilemap.notify_runtime_tile_data_update()
		$"swordRender".mark_dirty()

	if GameState.perk_rebuild:
		tilemap.reset_tiles()
		$"swordRender".mark_dirty()
		GameState.perk_rebuild = false

	$"swordRender".capture_anchor()

	expand_charges_left = GameState.production_count
	_update_buttons()


func _back_to_game() -> void:
	if tilemap:
		GameState.sword_tile_data = tilemap.tile_map_data
	GameState.sword_render_data = $"swordRender".tile_map_data
	GameState.sword_anchor_cell = $"swordRender".anchor_cell
	GameState.sword_grip = $"swordRender".hand_grip
	GameState.has_sword_grip = true
	GameState.has_state = true
	get_tree().change_scene_to_file("res://scenes/game.tscn")


func _on_restart_pressed() -> void:
	if tilemap == null:
		return
	if not GameState.has_free_reset:
		return
	GameState.has_free_reset = false
	expand_charges_left = GameState.production_count
	tilemap.reset_tiles()
	$"swordRender".mark_dirty()
	$"swordRender".capture_anchor()
	_update_buttons()


func _on_production_expand_pressed() -> void:
	if tilemap == null or _expand_productions.is_empty():
		return
	if expand_charges_left <= 0:
		return
	var candidates: Array = []
	for prod in _expand_productions:
		for origin in _find_matches_tilemap(tilemap, prod.left_tiles):
			candidates.append({"prod": prod, "origin": origin})
	if candidates.is_empty():
		return
	var chosen: Dictionary = candidates[randi() % candidates.size()]
	_apply_production_at(tilemap, chosen.prod, chosen.origin)
	expand_charges_left -= 1
	$"swordRender".mark_dirty()
	_update_buttons()


func _apply_production_at(tm_layer: TileMapLayer, prod: ProductionResource, origin: Vector2i) -> void:
	var anchor_offset: Vector2i = _get_anchor_offset(prod.left_tiles)
	for part in prod.left_tiles:
		tm_layer.erase_cell(_pattern_pos(origin, part, anchor_offset))
	for part in prod.right_tiles:
		tm_layer.set_cell(
			_pattern_pos(origin, part, anchor_offset),
			int(part.get("source", -1)),
			Vector2i(part.get("atlas", Vector2i(-1, -1))),
			int(part.get("alt", 0))
		)


func _on_production_shrink_pressed() -> void:
	if productions_shrink.is_empty() or tilemap == null:
		return
	if expand_charges_left <= 0:
		return
	for i in range(100):
		var prod = productions_shrink[randi() % productions_shrink.size()]
		replace_pattern_tilemaplayer(tilemap, prod.left_tiles, prod.right_tiles)
	expand_charges_left -= 1
	$"swordRender".mark_dirty()
	_update_buttons()


func _update_buttons() -> void:
	var has_charges := expand_charges_left > 0
	$"Button".text = "expand (%d kliknięć)" % expand_charges_left
	$"Button".disabled = not has_charges
	$"Button2".disabled = not has_charges
	$"Button3".text = "reset (dostępny)" if GameState.has_free_reset else "reset (zużyty)"
	$"Button3".disabled = not GameState.has_free_reset


# =======================
# HELPERS
# =======================

func _get_anchor_offset(pattern: Array) -> Vector2i:
	if pattern.is_empty():
		return Vector2i.ZERO
	var anchor: Dictionary = pattern[0]
	return Vector2i(anchor.get("pos", Vector2i.ZERO))


func _pattern_pos(origin: Vector2i, part: Dictionary, anchor_offset: Vector2i) -> Vector2i:
	return origin + Vector2i(part.get("pos", Vector2i.ZERO)) - anchor_offset


# =======================
# CELL MATCHING
# =======================

func _cell_matches(layer: TileMapLayer, pos: Vector2i, data: Dictionary) -> bool:
	var atlas_coords: Vector2i = Vector2i(data.get("atlas", Vector2i(-1, -1)))
	var source_id: int = int(data.get("source", -1))
	var alt: int = int(data.get("alt", 0))

	if atlas_coords == Vector2i(0, 4):
		return layer.get_cell_source_id(pos) == -1

	var cell_source: int = layer.get_cell_source_id(pos)
	var cell_atlas: Vector2i = layer.get_cell_atlas_coords(pos)
	var cell_alt: int = layer.get_cell_alternative_tile(pos)

	if cell_source != source_id or cell_atlas != atlas_coords or cell_alt != alt:
		return false

	return true


# =======================
# FIND MATCHES ACROSS TILEMAP
# =======================

func _find_matches_tilemap(tm_layer: TileMapLayer, pattern: Array) -> Array:
	var matches: Array = []

	if pattern.is_empty() or tm_layer == null:
		return matches

	var anchor_offset: Vector2i = _get_anchor_offset(pattern)

	var min_local_x := 0
	var min_local_y := 0
	var max_local_x := 0
	var max_local_y := 0

	for part in pattern:
		var local_pos: Vector2i = Vector2i(part.get("pos", Vector2i.ZERO)) - anchor_offset
		if local_pos.x < min_local_x:
			min_local_x = local_pos.x
		if local_pos.y < min_local_y:
			min_local_y = local_pos.y
		if local_pos.x > max_local_x:
			max_local_x = local_pos.x
		if local_pos.y > max_local_y:
			max_local_y = local_pos.y

	var margin := 3
	var map_bounds: Rect2i = tm_layer.get_used_rect()

	var min_x: int = map_bounds.position.x - margin
	var min_y: int = map_bounds.position.y - margin
	var max_x: int = map_bounds.position.x + map_bounds.size.x - 1 + margin
	var max_y: int = map_bounds.position.y + map_bounds.size.y - 1 + margin

	for origin_x in range(min_x, max_x + 1):
		for origin_y in range(min_y, max_y + 1):
			var origin: Vector2i = Vector2i(origin_x, origin_y)
			var ok := true

			for part in pattern:
				var pos: Vector2i = _pattern_pos(origin, part, anchor_offset)
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

	var anchor_offset: Vector2i = _get_anchor_offset(pattern)

	var matches: Array = _find_matches_tilemap(tm_layer, pattern)
	if matches.is_empty():
		return

	var rng := RandomNumberGenerator.new()
	rng.randomize()
	var chosen_origin: Vector2i = matches[rng.randi_range(0, matches.size() - 1)]

	for part in pattern:
		var pos: Vector2i = _pattern_pos(chosen_origin, part, anchor_offset)
		tm_layer.erase_cell(pos)

	for part in replacement:
		var pos: Vector2i = _pattern_pos(chosen_origin, part, anchor_offset)
		tm_layer.set_cell(
			pos,
			int(part.get("source", -1)),
			Vector2i(part.get("atlas", Vector2i(-1, -1))),
			int(part.get("alt", 0))
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
	var dir := DirAccess.open(folder_path)
	if not dir:
		return []

	var productions: Array = []
	dir.list_dir_begin()
	var file_name := dir.get_next()

	while file_name != "":
		if not dir.current_is_dir():
			if file_name.ends_with(".tres") or file_name.ends_with(".res"):
				var res = load_production_resource(folder_path + "/" + file_name)
				if res:
					productions.append(res)
		file_name = dir.get_next()

	dir.list_dir_end()
	return productions
