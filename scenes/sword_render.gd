extends TileMapLayer

const CELL_PX := 60.0       # render: tile_size (15) * scale (4)
const HAND_CELL_PX := 15.0  # dłoń: tile_size (15) * scale (1)

# punkt chwytu = pozycja węzła HandSword ustawiona w edytorze
# (przeciągnij HandSword w scenie crafting, żeby zmienić miejsce miecza w ręce)
var hand_grip := Vector2(55, 36)

@onready var logic: TileMapLayer = $"../swordLogic"
@onready var hand: TileMapLayer = get_node_or_null("../PlayerPreview/HandSword") as TileMapLayer

var dirty := true

# kotwica — logiczna komórka, która ma zostać zawsze na środku sceny
var screen_center := Vector2(960, 540)
var anchor_logic := Vector2i(7, 7)
var anchor_captured := false
var anchor_cell := Vector2i.ZERO  # komórka-kotwica w przestrzeni renderu (dla gry/dłoni)

# przesuwanie widoku myszką
var pan_offset := Vector2.ZERO
var _pinned_base := Vector2.ZERO
var _panning := false

func _ready() -> void:
	screen_center = Vector2(470.0, get_viewport_rect().size.y / 2.0)
	if hand:
		hand_grip = hand.position  # zapamiętaj chwyt ustawiony w edytorze
	rebuild()

func mark_dirty() -> void:
	dirty = true

# ustawia kotwicę na środek aktualnego miecza (wołane po wczytaniu/resecie)
func capture_anchor() -> void:
	if logic == null:
		return
	var r := logic.get_used_rect()
	if r.size != Vector2i.ZERO:
		anchor_logic = r.position + r.size / 2
		anchor_captured = true
	mark_dirty()

func _process(_delta: float) -> void:
	if dirty:
		rebuild()
		dirty = false

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_MIDDLE:
		_panning = event.pressed
	elif event is InputEventMouseMotion and _panning:
		pan_offset += event.relative
		_apply_position()

func _apply_position() -> void:
	position = _pinned_base + pan_offset

func rebuild() -> void:
	clear()

	if logic == null:
		return

	var rect: Rect2i = logic.get_used_rect()
	if not anchor_captured and rect.size != Vector2i.ZERO:
		anchor_logic = rect.position + rect.size / 2
		anchor_captured = true

	var start := rect.position
	var end := rect.position + rect.size

	for y in range(start.y, end.y):
		for x in range(start.x, end.x):
			# tylko co drugi kafel
			if (x+1) % 2 != 0 or (y+1) % 2 != 0:
				continue

			var src := Vector2i(x, y)
			var dst := Vector2i((x - start.x+1) / 2, (y - start.y+1) / 2)

			var source_id := logic.get_cell_source_id(src)
			if source_id == -1:
				# puste zostaje puste
				continue

			var atlas := logic.get_cell_atlas_coords(src)
			var alt := logic.get_cell_alternative_tile(src)

			set_cell(dst, source_id, atlas, alt)

	# przypnij komórkę-kotwicę do środka sceny, żeby miecz nie "skakał"
	var rcell := Vector2i((anchor_logic.x - start.x + 1) / 2, (anchor_logic.y - start.y + 1) / 2)
	anchor_cell = rcell
	_pinned_base = screen_center - Vector2(rcell) * CELL_PX - Vector2(CELL_PX, CELL_PX) / 2.0
	_apply_position()

	# postać w scenie crafting trzyma w dłoni dokładnie tę samą część,
	# przypiętą tą samą kotwicą — początkowy tile zawsze w punkcie chwytu
	if hand:
		hand.tile_map_data = tile_map_data
		hand.notify_runtime_tile_data_update()
		# offset komórki-kotwicy jest obracany razem z węzłem (dłoń ma rotację),
		# więc kompensację trzeba obrócić o tę samą rotację
		var off: Vector2 = (Vector2(rcell) * HAND_CELL_PX * hand.scale).rotated(hand.rotation)
		hand.position = hand_grip - off
