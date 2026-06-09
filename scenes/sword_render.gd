extends TileMapLayer

@onready var logic: TileMapLayer = $"../swordLogic"
var dirty := true

func _ready() -> void:
	rebuild()

func mark_dirty() -> void:
	dirty = true

func _process(_delta: float) -> void:
	if dirty:
		rebuild()
		dirty = false

func rebuild() -> void:
	clear()

	if logic == null:
		return

	var rect: Rect2i = logic.get_used_rect()
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
