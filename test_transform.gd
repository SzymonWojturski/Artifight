extends Node2D

# Empiryczny test: mierzy prawdziwą konwencję flag Godota (renderując kafel)
# i sprawdza, czy transformacje z load_and_save.gd są spójne z pozycjami.

const FH := TileSetAtlasSource.TRANSFORM_FLIP_H
const FV := TileSetAtlasSource.TRANSFORM_FLIP_V
const TR := TileSetAtlasSource.TRANSFORM_TRANSPOSE
const MASK := FH | FV | TR
const N := 15

# macierze 2x2 [a,b,c,d] = [[a,b],[c,d]] działające na (x,y), y w dół
var MATS := {
	"I":    [1, 0, 0, 1],
	"H":    [-1, 0, 0, 1],
	"V":    [1, 0, 0, -1],
	"negI": [-1, 0, 0, -1],
	"T":    [0, 1, 1, 0],
	"Rp":   [0, -1, 1, 0],
	"Rm":   [0, 1, -1, 0],
	"negT": [0, -1, -1, 0],
}

var _subvp: SubViewport
var _tml: TileMapLayer

func _ready() -> void:
	var base_img := _make_asym_image()
	var tileset := _make_tileset(base_img)

	_subvp = SubViewport.new()
	_subvp.size = Vector2i(N, N)
	_subvp.transparent_bg = true
	_subvp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	add_child(_subvp)
	_tml = TileMapLayer.new()
	_tml.tile_set = tileset
	_tml.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_subvp.add_child(_tml)

	# referencje: 8 geometrii zastosowanych do obrazu bazowego
	var refs := {}
	for name in MATS:
		refs[name] = _apply_mat(base_img, MATS[name])

	var combos := [0, FH, FV, FH | FV, TR, TR | FH, TR | FV, TR | FH | FV]
	var geom := {}  # flagbits -> nazwa macierzy (zmierzona konwencja Godota)

	print("=== ZMIERZONA KONWENCJA FLAG GODOTA ===")
	for c in combos:
		var img := await _render_cell(c)
		var best := _closest(img, refs)
		geom[c] = best
		print("  t=%d h=%d v=%d  ->  %s" % [int((c & TR) != 0), int((c & FH) != 0), int((c & FV) != 0), best])

	print("=== SPRAWDZENIE SPÓJNOŚCI load_and_save.gd ===")
	var fails := 0
	for rot in range(4):
		for flip in [false, true]:
			for f in combos:
				var actual_flags: int = _transform_alt(f, rot, flip) & MASK
				var actual_mat: Array = MATS[geom[actual_flags]]
				# oczekiwana macierz = (H jeśli flip) * Rm^rot * geom[f]
				var pos := _pos_matrix(rot, flip)
				var expected: Array = _mul(pos, MATS[geom[f]])
				if not _eq(actual_mat, expected):
					fails += 1
					print("  ZLE rot=%d flip=%s f=(t%d h%d v%d): render=%s oczekiwano=%s" % [
						rot, str(flip),
						int((f & TR) != 0), int((f & FH) != 0), int((f & FV) != 0),
						geom[actual_flags], _name_of(expected)])

	print("=== WYNIK: %d niespojnosci ===" % fails)
	get_tree().quit()


func _pos_matrix(rot: int, flip: bool) -> Array:
	var m := MATS["I"]
	for i in range(rot):
		m = _mul(MATS["Rm"], m)
	if flip:
		m = _mul(MATS["H"], m)
	return m


func _mul(a: Array, b: Array) -> Array:
	return [
		a[0]*b[0] + a[1]*b[2], a[0]*b[1] + a[1]*b[3],
		a[2]*b[0] + a[3]*b[2], a[2]*b[1] + a[3]*b[3],
	]


func _eq(a: Array, b: Array) -> bool:
	return a[0] == b[0] and a[1] == b[1] and a[2] == b[2] and a[3] == b[3]


func _name_of(m: Array) -> String:
	for name in MATS:
		if _eq(MATS[name], m):
			return name
	return "?"


func _make_asym_image() -> Image:
	var img := Image.create(N, N, false, Image.FORMAT_RGBA8)
	for y in range(N):
		for x in range(N):
			img.set_pixel(x, y, Color(float(x) / N, float(y) / N, float((x * 3 + y) % 5) / 5.0, 1.0))
	return img


func _make_tileset(img: Image) -> TileSet:
	var tex := ImageTexture.create_from_image(img)
	var src := TileSetAtlasSource.new()
	src.texture = tex
	src.texture_region_size = Vector2i(N, N)
	src.create_tile(Vector2i(0, 0))
	var ts := TileSet.new()
	ts.tile_size = Vector2i(N, N)
	ts.add_source(src, 0)
	return ts


func _render_cell(flagbits: int) -> Image:
	_tml.set_cell(Vector2i(0, 0), 0, Vector2i(0, 0), flagbits)
	await RenderingServer.frame_post_draw
	await RenderingServer.frame_post_draw
	return _subvp.get_texture().get_image()


func _apply_mat(img: Image, m: Array) -> Image:
	var out := Image.create(N, N, false, Image.FORMAT_RGBA8)
	var c := (N - 1) / 2
	for sy in range(N):
		for sx in range(N):
			var cx := sx - c
			var cy := sy - c
			var dx := m[0] * cx + m[1] * cy + c
			var dy := m[2] * cx + m[3] * cy + c
			out.set_pixel(dx, dy, img.get_pixel(sx, sy))
	return out


func _closest(img: Image, refs: Dictionary) -> String:
	var best := ""
	var best_d := 1e20
	for name in refs:
		var d := _dist(img, refs[name])
		if d < best_d:
			best_d = d
			best = name
	return best


func _dist(a: Image, b: Image) -> float:
	var s := 0.0
	for y in range(N):
		for x in range(N):
			var ca := a.get_pixel(x, y)
			var cb := b.get_pixel(x, y)
			s += abs(ca.r - cb.r) + abs(ca.g - cb.g) + abs(ca.b - cb.b)
	return s


# ---- skopiowane z load_and_save.gd ----
func _transform_alt(alt: int, rot: int, flip: bool) -> int:
	var base_id := alt & ~MASK
	var old := alt & MASK
	var result := old
	for i in range(rot):
		result = _rotate90(result)
	if flip:
		result = _flip_h(result)
	return base_id | result

func _rotate90(flags: int) -> int:
	var t = (flags & TR) != 0
	var h = (flags & FH) != 0
	var v = (flags & FV) != 0
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
