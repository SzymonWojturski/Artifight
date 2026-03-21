extends TileMapLayer

func set_tile_data(data: Array) -> void:
	tile_map_data = PackedByteArray(data)
	notify_runtime_tile_data_update()

func reset_tiles() -> void:
	#print(tile_map_data)
	tile_map_data = PackedByteArray([0, 0, 7, 0, 7, 0, 0, 0, 0, 0, 0, 0, 0, 0, 7, 0, 6, 0, 0, 0, 0, 0, 5, 0, 0, 0]
)
	notify_runtime_tile_data_update()
