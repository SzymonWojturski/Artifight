extends TileMapLayer

func set_tile_data(data: Array) -> void:
	tile_map_data = PackedByteArray(data)
	notify_runtime_tile_data_update()

func reset_tiles() -> void:
	tile_map_data = PackedByteArray([0, 0, 7, 0, 6, 0, 0, 0, 0, 0, 5, 0, 0, 96, 7, 0, 7, 0, 0, 0, 0, 0, 0, 0, 0, 0])
	notify_runtime_tile_data_update()

func get_sword_stats() -> Dictionary:
	var total_damage := 0
	var total_attack_speed := 0
	var total_lifetime := 0
	var total_size := 0
	var total_pierce := 0
	var total_speed := 0
	for cell in get_used_cells():
		var tile_data = get_cell_tile_data(cell)
		if tile_data:
			total_damage += int(tile_data.get_custom_data("Damage"))
			total_attack_speed += int(tile_data.get_custom_data("AttackSpeed"))
			total_lifetime += int(tile_data.get_custom_data("Lifetime"))
			total_size += int(tile_data.get_custom_data("Size"))
			total_pierce += int(tile_data.get_custom_data("Pierce"))
			total_speed += int(tile_data.get_custom_data("Speed"))
	return {
		"damage": max(1, total_damage),
		"attack_speed": total_attack_speed,
		"lifetime": total_lifetime,
		"size": total_size,
		"pierce": total_pierce,
		"speed": total_speed,
	}
