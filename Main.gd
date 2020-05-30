extends Node2D

var Room = preload("res://Room.tscn")
var Player = preload("res://Player.tscn")
var font = preload("res://assets/RobotoBold120.tres")
onready var nav : Navigation2D = $Navigation2D
onready var Map = $Navigation2D/Floor
onready var Walls = $Wall

var tile_size_x = 128  # size of a tile in the TileMap
var tile_size_y = 64  # size of a tile in the TileMap
var num_rooms = 30 # number of rooms to generate
var min_size = 10  # minimum room size (in tiles)
var max_size = 20  # maximum room size (in tiles)
var hspread = 0  # horizontal spread (in pixels)
var cull = 0.5  # chance to cull room

var debug = false

var path  # AStar pathfinding object
var start_room = null
var end_room = null
var test_room = null
var play_mode = false  
var player = null

var	last_pos = Vector2(0, 0)

var path_navigate : PoolVector2Array
var goal : Vector2
export var speed := 400

var time: float = 0
var time_mult = 1.0
var paused = false

var debug_mode = false

func _ready():
	
	if debug_mode == true:
		player = $Navigation2D/Floor/Player
		pass
	else:
		randomize()
		make_rooms()
	
	
func make_rooms():
	for i in range(num_rooms):
			
		var pos = Vector2(rand_range(-hspread, hspread), 0)
		var r = Room.instance()
		var w = min_size + randi() % (max_size - min_size)
		var h = min_size + randi() % (max_size - min_size)
		#making start room
		var start_and_end = []
		if start_room == null:
			w = 15
			h = 15
			r.make_room(pos, Vector2(w, h) * 64)
			$Rooms.add_child(r)
			for room in $Rooms.get_children():
					start_room = room
			print("Start")
		if end_room == null:
			w = 15
			h = 15
			r.make_room(pos, Vector2(w, h) * 64)
			$Rooms.add_child(r)
			print("End")
			for room in $Rooms.get_children():
					end_room = room
			print(str(start_and_end))
			
		else:
			r.make_room(pos, Vector2(w, h) * 64)
			print(str(w) + " " + str(h))
			$Rooms.add_child(r)
	# wait for movement to stop
	yield(get_tree().create_timer(1.1), 'timeout')
	# cull rooms
	var room_positions = []
	for room in $Rooms.get_children():
		if room == start_room:
			room.mode = RigidBody2D.MODE_STATIC
			room_positions.append(Vector3(room.position.x,room.position.y, 0))
		if room == end_room:
			room.mode = RigidBody2D.MODE_STATIC
			room_positions.append(Vector3(room.position.x,room.position.y, 0))
		else:
			if randf() < cull:
				room.queue_free()
				
			else:
				room.mode = RigidBody2D.MODE_STATIC
				room_positions.append(Vector3(room.position.x,room.position.y, 0))
	yield(get_tree(), 'idle_frame')
	# generate a minimum spanning tree connecting the rooms
	path = find_mst(room_positions)
	make_map()
			
#func _draw():
#	if start_room:
#		draw_string(font, start_room.position-Vector2(125,0), "start", Color(1,1,1))
#	if end_room:
#		draw_string(font, end_room.position-Vector2(125,0), "end", Color(1,1,1))
#	if play_mode:
#		return
#	for room in $Rooms.get_children():
#		draw_rect(Rect2(room.position - room.size, room.size * 2),Color(0, 1, 0), false)
#	if path:
#		for p in path.get_points():
#			for c in path.get_point_connections(p):
#				var pp = path.get_point_position(p)
#				var cp = path.get_point_position(c)
#				draw_line(Vector2(pp.x, pp.y), Vector2(cp.x, cp.y),
#						  Color(1, 1, 0), 15, true)
#

func _process(delta):
	var mouse_pos = get_global_mouse_position()
	var tile_pos = Map.world_to_map(mouse_pos)
	if !tile_pos == last_pos:
		$Highlight.set_cell(last_pos.x, last_pos.y, -1)
		last_pos = tile_pos
		$Highlight.set_cell(tile_pos.x, tile_pos.y, 1)
	
	if not paused:
		time += delta * time_mult
		
		$CanvasLayer/lbltime.text = str(int(time))
	
	if player:
		#Tile position
		#player.set_text(str(Vector2(player.position.x / tile_size_x, player.position.y / tile_size_y).floor()))
		player.set_text(str(player.position))
	if !path_navigate:
		$Line2D.hide()
		return
	if path_navigate.size() > 0:
		var d: float = player.position.distance_to(path_navigate[0])
		if d > 5:
			player.position = player.position.linear_interpolate(path_navigate[0], (speed * delta)/d)
		else:
			path_navigate.remove(0)
	update()
	
func _input(event):
	if event.is_action_pressed('ui_select'):
		if play_mode:
			player.queue_free()
			play_mode = false
		for n in $Rooms.get_children():
			n.queue_free()
		path = null
		start_room = null
		end_room = null
		make_rooms()
	if event.is_action_pressed('ui_focus_next'):
		
		var test = Map.map_to_world(Map.world_to_map(player.position))
		test = Vector2(test.x , test.y + Map.cell_size.y / 2)
		player.position = test
		print(str(test))
	if event.is_action_pressed('ui_cancel'):
		player = Player.instance()
		Map.add_child(player)
		#Takes tile coordinates and makes into global coordinates
		player.global_position = Map.map_to_world(Vector2(start_room.global_position.x / tile_size_x, start_room.global_position.y / tile_size_y).floor())
		play_mode = true
	if event is InputEventMouseButton:
		if event.button_index == BUTTON_LEFT and event.pressed:
			goal = event.position
			var mouse_pos = get_global_mouse_position()
			var tile_pos = Map.map_to_world(Map.world_to_map(mouse_pos))
			tile_pos = Vector2(tile_pos.x , tile_pos.y + Map.cell_size.y / 2)
			path_navigate = nav.get_simple_path(player.position, tile_pos, false)
			$Line2D.points = PoolVector2Array(path_navigate)
			$Line2D.show()
			print(str(tile_pos))

func find_mst(nodes):
	# Prim's algorithm
	# Given an array of positions (nodes), generates a minimum
	# spanning tree
	# Returns an AStar object
	
	# Initialize the AStar and add the first point
	var path = AStar.new()
	path.add_point(path.get_available_point_id(), nodes.pop_front())
	
	# Repeat until no more nodes remain
	while nodes:
		var min_dist = INF  # Minimum distance so far
		var min_p = null  # Position of that node
		var p = null  # Current position
		# Loop through points in path
		for p1 in path.get_points():
			p1 = path.get_point_position(p1)
			# Loop through the remaining nodes
			for p2 in nodes:
				# If the node is closer, make it the closest
				if p1.distance_to(p2) < min_dist:
					min_dist = p1.distance_to(p2)
					min_p = p2
					p = p1
		# Insert the resulting node into the path and add
		# its connection
		var n = path.get_available_point_id()
		path.add_point(n, min_p)
		path.connect_points(path.get_closest_point(p), n)
		# Remove the node from the array so it isn't visited again
		nodes.erase(min_p)
	return path
		
func make_map():
	# Create a TileMap from the generated rooms and path
	Map.clear()
	Walls.clear()
	
	find_start_room()
	find_end_room()
	print_info()
	
	# Fill TileMap with walls, then carve empty rooms
#	var full_rect = Rect2()
#	for room in $Rooms.get_children():
#		var r = Rect2(room.position-room.size,room.get_node("CollisionShape2D").shape.extents*2)
#		full_rect = full_rect.merge(r)
#	var topleft = full_rect.position / tile_size
#	var bottomright = full_rect.end / tile_size
#	for x in range(topleft.x, bottomright.x):
#		for y in range(topleft.y, bottomright.y):
#			Map.set_cell(x, y, 1)	
	
	# Carve rooms
	var corridors = []  # One corridor per connection
	for room in $Rooms.get_children():
		var s = Vector2(room.size.x / tile_size_x, room.size.y / tile_size_y).floor() 
		#var pos = Map.world_to_map(room.position)
		var ul = Vector2(room.position.x / tile_size_x, room.position.y / tile_size_y).floor() - s
		
		for x in range(1, s.x * 2 - 1):
			for y in range(1, s.y * 2 - 1):
				Walls.set_cell(ul.x + x, ul.y + y, 2)
		for x in range(2, s.x * 2 - 2):
			for y in range(2, s.y * 2 - 2):
				Map.set_cell(ul.x + x, ul.y + y, 0)
				Walls.set_cell(ul.x + x, ul.y + y, -1)
	for room in $Rooms.get_children():
		# Carve connecting corridor
		var p = path.get_closest_point(Vector3(room.position.x, room.position.y, 0))
		for conn in path.get_point_connections(p):
			if not conn in corridors:
				find_room(path.get_point_position(p).x,path.get_point_position(p).y)
				var start = Vector2(test_room.position.x / tile_size_x,test_room.position.y / tile_size_y).floor()
				find_room(path.get_point_position(conn).x,path.get_point_position(conn).y)
				var end = Vector2(test_room.position.x / tile_size_x,test_room.position.y / tile_size_y).floor()
				
				carve_path(start, end)
		corridors.append(p)
	for room in $Rooms.get_children():
		var ul = Vector2(room.position.x / tile_size_x, room.position.y / tile_size_y).floor() 
		Map.set_cell(ul.x, ul.y, 1)

		
				
func find_room(_x, _y):
	for room in $Rooms.get_children():
		if (room.position.x - 1) < _x and (room.position.x + 1) > _x:
			#print("Matches" + str(_x) + " " + str(room.position.x))
			if (room.position.y - 1) < _y and (room.position.y + 1) > _y:
				#print("Matches" + str(_x) + " " + str(room.position.x))
				test_room = room
				return
#		if room.position.x == _x and room.position.y == _y:
#			test_room = room
#			#print("Room found!")
#			return
	print("Room not found: " + str(_x) + "" + str(_y))
	
func carve_path(pos1, pos2):
	# Carve a path between two points
	var x_diff = sign(pos2.x - pos1.x)
	var y_diff = sign(pos2.y - pos1.y)
	if x_diff == 0: x_diff = pow(-1.0, randi() % 2)
	if y_diff == 0: y_diff = pow(-1.0, randi() % 2)
	
	# choose either x/y or y/x
	var x_y = pos1
	var y_x = pos2
	if (randi() % 2) > 0:
		x_y = pos2
		y_x = pos1
	var floor_tile = Map.get_used_cells_by_id (0)
	for x in range(pos1.x, pos2.x, x_diff):
		
		Map.set_cell(x, x_y.y, 0)
		Walls.set_cell(x, x_y.y, -1)
		Map.set_cell(x, x_y.y + y_diff, 0) 
		Walls.set_cell(x, x_y.y + y_diff, -1)# widen the corridor
		floor_tile.append(Vector2(x, x_y.y))
		floor_tile.append(Vector2(x, x_y.y + y_diff))
		
		#Walls
		var this_cell = Vector2(x, x_y.y + y_diff + y_diff).floor()
		if !floor_tile.has(this_cell):
			Walls.set_cell(x, x_y.y + y_diff + y_diff, 2)
		this_cell = Vector2(x, x_y.y - y_diff).floor()
		if !floor_tile.has(this_cell):
			Walls.set_cell(x, x_y.y - y_diff, 2)
			
		if x == pos1.x or x == pos2.x + 1 or x == pos2.x - 1:
			#check surronding tiles are filled in at begining and end
			this_cell = Vector2(x + x_diff, x_y.y).floor()
			if !floor_tile.has(this_cell):
				Walls.set_cell(this_cell.x, this_cell.y, 2)
			this_cell = Vector2(x + x_diff, x_y.y + y_diff).floor()
			if !floor_tile.has(this_cell):
				Walls.set_cell(this_cell.x, this_cell.y, 2)
			this_cell = Vector2(x + x_diff, x_y.y + y_diff + y_diff).floor()
			if !floor_tile.has(this_cell):
				Walls.set_cell(this_cell.x, this_cell.y, 2)
			this_cell = Vector2(x + x_diff, x_y.y - y_diff).floor()
			if !floor_tile.has(this_cell):
				Walls.set_cell(this_cell.x, this_cell.y, 2)
			
			this_cell = Vector2(x - x_diff, x_y.y).floor()
			if !floor_tile.has(this_cell):
				Walls.set_cell(this_cell.x, this_cell.y, 2)
			this_cell = Vector2(x - x_diff, x_y.y + y_diff).floor()
			if !floor_tile.has(this_cell):
				Walls.set_cell(this_cell.x, this_cell.y, 2)
			this_cell = Vector2(x - x_diff, x_y.y + y_diff + y_diff).floor()
			if !floor_tile.has(this_cell):
				Walls.set_cell(this_cell.x, this_cell.y, 2)
			this_cell = Vector2(x - x_diff, x_y.y - y_diff).floor()
			if !floor_tile.has(this_cell):
				Walls.set_cell(this_cell.x, this_cell.y, 2)
		 
	for y in range(pos1.y, pos2.y, y_diff):
		Map.set_cell(y_x.x, y, 0)
		Walls.set_cell(y_x.x, y, -1)
		Map.set_cell(y_x.x + x_diff, y, 0)
		Walls.set_cell(y_x.x + x_diff, y, -1)
		floor_tile.append(Vector2(y_x.x, y))
		floor_tile.append(Vector2(y_x.x, y + x_diff))
		
		var this_cell = Vector2(y_x.x + x_diff + x_diff, y).floor()
		if !floor_tile.has(this_cell):
			Walls.set_cell(y_x.x + x_diff + x_diff, y, 2)
		this_cell = Vector2(y_x.x - x_diff, y).floor()
		if !floor_tile.has(this_cell):
			Walls.set_cell(y_x.x - x_diff, y, 2)
		
		if y == pos1.y or y == pos2.y + 1 or y == pos2.y - 1:
			#check surronding tiles are filled in at begining and end
			this_cell = Vector2(y_x.x, y + y_diff).floor()
			if !floor_tile.has(this_cell):
				Walls.set_cell(this_cell.x, this_cell.y, 2)
			this_cell = Vector2(y_x.x + x_diff, y + y_diff).floor()
			if !floor_tile.has(this_cell):
				Walls.set_cell(this_cell.x, this_cell.y, 2)
			this_cell = Vector2(y_x.x + x_diff + x_diff, y + y_diff).floor()
			if !floor_tile.has(this_cell):
				Walls.set_cell(this_cell.x, this_cell.y, 2)
			this_cell = Vector2(y_x.x - x_diff, y + y_diff).floor()
			if !floor_tile.has(this_cell):
				Walls.set_cell(this_cell.x, this_cell.y, 2)
			
			this_cell = Vector2(y_x.x, y - y_diff).floor()
			if !floor_tile.has(this_cell):
				Walls.set_cell(this_cell.x, this_cell.y, 2)
			this_cell = Vector2(y_x.x + x_diff, y - y_diff).floor()
			if !floor_tile.has(this_cell):
				Walls.set_cell(this_cell.x, this_cell.y, 2)
			this_cell = Vector2(y_x.x + x_diff + x_diff, y - y_diff).floor()
			if !floor_tile.has(this_cell):
				Walls.set_cell(this_cell.x, this_cell.y, 2)
			this_cell = Vector2(y_x.x - x_diff, y - y_diff).floor()
			if !floor_tile.has(this_cell):
				Walls.set_cell(this_cell.x, this_cell.y, 2)
	
func find_start_room():
	var min_x = INF
#	for room in $Rooms.get_children():
#		if room.position.x < min_x:
#			start_room = room
#			min_x = room.position.x

func find_end_room():
	var max_x = -INF
#	for room in $Rooms.get_children():
#		if room.position.x > max_x:
#			end_room = room
#			max_x = room.position.x

func get_random_location():
	var used = Map.get_used_cells_by_id(1)
	var randomcell = randi() % used.size()
	var cell = used[randomcell]
	return Vector2(cell.x, cell.y)
	
func get_time():
	return time

func get_end():
	var used = Map.get_used_cells_by_id(6)
	var cell = used[0]
	return Vector2(cell.x, cell.y)


func print_info():
	if debug == true:
		for room in $Rooms.get_children():
			print(room.name + ": " + str(room.position.x) + " " + str(room.position.y))
		if path:
			for p in path.get_points():
				print(path.get_point_connections(p))
	else:
		pass
