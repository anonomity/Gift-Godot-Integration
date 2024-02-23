extends Node


var terrain_arr = []

func erase_tile(pos):
	pos = Vector2i(pos)
	print("before " ,terrain_arr.size())
	terrain_arr.erase(pos)	
	print("after " ,terrain_arr.size())
	return terrain_arr

func set_terrain_arr(cells):
	terrain_arr = cells
