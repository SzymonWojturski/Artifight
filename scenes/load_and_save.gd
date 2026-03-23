@tool
extends Node2D

const FH := TileSetAtlasSource.TRANSFORM_FLIP_H
const FV := TileSetAtlasSource.TRANSFORM_FLIP_V
const TR := TileSetAtlasSource.TRANSFORM_TRANSPOSE

const TRANSFORM_MASK := FH | FV | TR

@export var production_resource : ProductionResource

@export_tool_button("Save Production", "Callable")
var save_action = save_production

@export_tool_button("Load Production", "Callable")
var load_action = load_production


func save_production():
	if not production_resource:
		production_resource = ProductionResource.new()

	var path = production_resource.resource_path
	if path == "":
		path = "res://data/productions/oryginal/1.tres"

	# --- ORYGINAŁ ---
	production_resource.left_tiles = _collect_tiles($LeftSide)
	production_resource.right_tiles = _collect_tiles($RightSide)
	production_resource.border_tiles = _collect_tiles($Border)
	ResourceSaver.save(production_resource, path)

	var anchor = _find_shared_anchor([
		production_resource.left_tiles,
		production_resource.right_tiles,
		production_resource.border_tiles
	])

	var base_name = path.get_file().get_basename()
	var dir_path = path.get_base_dir()
	var generated_dir = dir_path.replace("oryginal", "generated") + "/"

	# --- ROTACJE ---
	for rot in range(4):
		_save_variant(rot, false, anchor, base_name, generated_dir)

	# --- FLIP + ROTACJE ---
	for rot in range(4):
		_save_variant(rot, true, anchor, base_name, generated_dir)


func _save_variant(rot: int, flip: bool, anchor: Vector2i, base_name: String, dir: String):
	var variant = ProductionResource.new()

	variant.left_tiles = _transform_pattern(production_resource.left_tiles, rot, flip, anchor)
	variant.right_tiles = _transform_pattern(production_resource.right_tiles, rot, flip, anchor)
	variant.border_tiles = _transform_pattern(production_resource.border_tiles, rot, flip, anchor)

	var suffix = ("_f" if flip else "") + "_r" + str(rot * 90)
	ResourceSaver.save(variant, dir + base_name + suffix + ".tres")


func load_production():
	if not production_resource:
		return
	_apply_tiles($LeftSide, production_resource.left_tiles)
	_apply_tiles($RightSide, production_resource.right_tiles)
	_apply_tiles($Border, production_resource.border_tiles)


func _collect_tiles(tilemap: TileMapLayer) -> Array:
	var data = []
	for cell in tilemap.get_used_cells():
		data.append({
			"pos": cell,
			"source": tilemap.get_cell_source_id(cell),
			"atlas": tilemap.get_cell_atlas_coords(cell),
			"alt": tilemap.get_cell_alternative_tile(cell)
		})
	return data


func _apply_tiles(tilemap: TileMapLayer, data: Array):
	tilemap.clear()
	for t in data:
		tilemap.set_cell(t["pos"], t["source"], t["atlas"], t["alt"])
	tilemap.update_internals()


# =========================================================
# 🔥 KLUCZOWA CZĘŚĆ — poprawne składanie transformacji
# =========================================================
func _transform_alt(alt: int, rot: int, flip: bool) -> int:
	var base_id := alt & ~TRANSFORM_MASK
	var old := alt & TRANSFORM_MASK

	var result := old

	# --- ROTACJA (składanie transformacji) ---
	for i in range(rot):
		result = _rotate90(result)

	# --- FLIP ---
	if flip:
		result = _flip_h(result)

	return base_id | result


func _rotate90(flags: int) -> int:
	var t = (flags & TR) != 0
	var h = (flags & FH) != 0
	var v = (flags & FV) != 0

	# poprawna kompozycja rotacji 90°
	return _make_flags(!t, v, !h)


func _flip_h(flags: int) -> int:
	var t = (flags & TR) != 0
	var h = (flags & FH) != 0
	var v = (flags & FV) != 0

	return _make_flags(t, !h, v)


func _make_flags(t: bool, h: bool, v: bool) -> int:
	var f := 0
	if t: f |= TR
	if h: f |= FH
	if v: f |= FV
	return f


# =========================================================


func _find_shared_anchor(arrays: Array) -> Vector2i:
	if arrays.is_empty():
		return Vector2i.ZERO

	var common := {}

	for i in range(arrays.size()):
		var positions := {}
		for t in arrays[i]:
			positions[t["pos"]] = true

		if i == 0:
			common = positions
		else:
			var next := {}
			for p in common.keys():
				if positions.has(p):
					next[p] = true
			common = next

	if common.is_empty():
		return Vector2i.ZERO

	return common.keys()[0]


func _transform_pattern(pattern: Array, rot: int, flip: bool, anchor: Vector2i) -> Array:
	var result: Array = []

	for part in pattern:
		var local: Vector2i = Vector2i(part["pos"]) - anchor
		var pos: Vector2i

		match rot:
			0:
				pos = local
			1:
				pos = Vector2i(local.y, -local.x)
			2:
				pos = -local
			3:
				pos = Vector2i(-local.y, local.x)

		if flip:
			pos.x = -pos.x

		pos += anchor

		result.append({
			"pos": pos,
			"source": part["source"],
			"atlas": part["atlas"],
			"alt": _transform_alt(part["alt"], rot, flip)
		})

	return result
