extends TileMapLayer

@onready var logic = $"../swordLogic"

var dirty := true

func _ready():
	rebuild()

func mark_dirty():
	dirty = true

func _process(_delta):
	if dirty:
		rebuild()
		dirty = false

func rebuild():
	clear()

	var new_y = 0

	var rows := {}

	for pos in logic.get_used_cells():
		if (pos.y+1) % 2 == 0 and (pos.x+1) % 2 == 0:
			if not rows.has(pos.y):
				rows[pos.y] = []
			rows[pos.y].append(pos)

	var sorted_rows = rows.keys()
	sorted_rows.sort()

	for y in sorted_rows:
		var row = rows[y]
		row.sort_custom(func(a, b): return a.x < b.x)

		var new_x = 0

		for pos in row:
			var source_id = logic.get_cell_source_id(pos)
			var atlas = logic.get_cell_atlas_coords(pos)

			set_cell(Vector2i(new_x, new_y), source_id, atlas)

			new_x += 1

		new_y += 1
