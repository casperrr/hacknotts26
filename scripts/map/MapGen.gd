extends Node3D
class_name MapGen

enum { FLOOR, WALL, CEILING, OFFICE_FLOOR, DOOR, SPAWN, TABLE, COMPUTER, CHAIR,
	   STAFF_ROOM_FLOOR, STAFF_ROOM_WALL, STAFF_ROOM_CEILING, STAFF_ROOM_TABLE,
	   STUDENT_SERVICES_FLOOR, STUDENT_SERVICES_WALL, STUDENT_SERVICES_CEILING,
	   STUDENT_SERVICES_DESK,  STUDENT_SERVICES_WALL_LOGO
	 }
const EMPTY := -1 # Behind locked doors

@export var map_size                            := Vector2i(50, 50) # if you want to scale the params just change this as it affects
@export var map_seed                            := 0 # 0 = random every time, for testing purposes
@export var corridor_width                      := 2
@export_range(10, 64) var block_min_size        := 10
@export var block_max_size                      := 24
@export_range(5, 20) var office_width           := 6
@export var professors: Array[Professor] = []  # one office each
@export var door_scene: PackedScene  # root node needs door.gd attached, do not move it

@onready var grid_map: GridMap = $GridMap
@onready var furniture_map: GridMap = $Furniture

var rng := RandomNumberGenerator.new()
var tiles       := {}  # Vector2i -> item for grid_map
var tile_facing := {}  # Vector2i -> facing, for tiles that need turning e..g., doors
var furniture   := {}  # Vector2i -> [item, facing] for furniture_map
var ceilings    := {}  # Vector2i -> item, placed one layer up
var doors: Array[Dictionary] = []  # { cell, facing, office, block, professor, present, locked, spawn, node }
var staff_room := {}  # { cell, facing, office, block, spawn }, also listed in doors
var student_services := {}  # { cell, facing, office, block, spawn }, open to the corridor, no door
var _door_nodes: Node3D

func _ready() -> void:
	if grid_map.mesh_library == null:
		grid_map.mesh_library = _make_library()
	furniture_map.mesh_library = grid_map.mesh_library
	furniture_map.cell_size = grid_map.cell_size
	generate()

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("reset"):
		generate()

func generate() -> void:
	rng.seed = map_seed if map_seed != 0 else randi()
	for d: Dictionary in [tiles, tile_facing, furniture, ceilings]:
		d.clear()
	doors.clear()

	var bounds := Rect2i(Vector2i.ZERO, map_size)
	_fill(bounds, FLOOR)  # whatever isn't covered by a block = corridor
	var root := BSPNode.new(bounds)
	root.split(rng, block_min_size, block_max_size, corridor_width)

	var rows := []  # each row's door slots, in order along the row
	for block: BSPNode in root.get_leaves():
		_fill(block.rect, EMPTY)
		_draw_outline(block.rect)
		for row: Rect2i in _rows(block.rect):
			var row_doors := []
			for office: Rect2i in _offices(row):
				var door := _make_door(office, block.rect)
				if bounds.has_point(door.cell + door.facing):  # skip doors on outer wall
					row_doors.append(door)
			rows.append(row_doors)
	_draw_outline(bounds)  # outer wall: corridors that reach the edge are dead ends

	staff_room = _take_double(rows)
	student_services = _take_double(rows)
	for row: Array in rows:
		doors.append_array(row)
	_assign_offices()

	if not staff_room.is_empty():
		_special_room(staff_room, STAFF_ROOM_FLOOR, STAFF_ROOM_WALL, STAFF_ROOM_CEILING,
				STAFF_ROOM_TABLE, STAFF_ROOM_WALL)
		staff_room.merge({"professor": null, "present": false, "locked": false})
		_add_door(staff_room)
		doors.append(staff_room)
	if not student_services.is_empty():
		_special_room(student_services, STUDENT_SERVICES_FLOOR, STUDENT_SERVICES_WALL,
				STUDENT_SERVICES_CEILING, STUDENT_SERVICES_DESK, STUDENT_SERVICES_WALL_LOGO)
		_open_front(student_services, STUDENT_SERVICES_FLOOR)

	_build()


# Takes two neighbouring slots from a random row and merges them into one room - helper to create the staff room!
func _take_double(rows: Array) -> Dictionary:
	var options := rows.filter(func(r: Array) -> bool: return r.size() >= 2)
	if options.is_empty():
		return {}
	var row: Array = options[rng.randi() % options.size()]
	var i := rng.randi_range(0, row.size() - 2)
	var a: Dictionary = row.pop_at(i)  # pop_at removes them from the row,
	var b: Dictionary = row.pop_at(i)  # so they don't also become offices
	return _make_door(a.office.merge(b.office), a.block)

# Shuffle the doors and give the first ones to professors, with the rest of the offices being empty.
func _assign_offices() -> void:
	if doors.size() < professors.size():
		push_warning("Only %d doors for %d professors;  the map bigger." % [doors.size(), professors.size()])
	_shuffle(doors)
	for i in doors.size():
		var door := doors[i]
		var prof: Professor = professors[i] if i < professors.size() else null
		door.professor = prof
		door.present = prof != null and rng.randf() < prof.chance_in_office
		door.locked = not door.present
		if prof:
			_furnish_office(door)
		_add_door(door)

func _furnish_office(door: Dictionary) -> void:
	_fill(door.office, OFFICE_FLOOR)
	_draw_outline(door.office)
	var f: Vector2i = door.facing
	var back := _back_cell(door)
	var side := Vector2i(f.y, f.x)  # invert
	if not door.office.grow(-1).has_point(back + side):
		side = -side
	furniture[back] = [COMPUTER, f]
	furniture[back + side] = [TABLE, f]
	furniture[back + f] = [CHAIR, -f]
	tiles[back + side + f] = SPAWN
	door.spawn = back + side + f

# Currently responsile for the furnishing of the conjoined rooms e.g., student services and staff room
func _special_room(room: Dictionary, floor_id: int, wall_id: int, ceiling_id: int,
		table_id: int, logo_id: int) -> void:
	_fill(room.office, floor_id)
	_draw_outline(room.office, wall_id)
	var f: Vector2i = room.facing
	var back := _back_cell(room)
	tiles[back - f] = logo_id # no logo for the staff room
	tile_facing[back - f] = f # turn to face into the room
	furniture[back] = [table_id, f]
	room.spawn = back + f # im getting lazy man lets hurry this shit up
	var inner: Rect2i = room.office.grow(-1)
	for x in range(inner.position.x, inner.end.x):
		for y in range(inner.position.y, inner.end.y):
			ceilings[Vector2i(x, y)] = ceiling_id

# Removes front wall of student services
func _open_front(room: Dictionary, floor_id: int) -> void:
	var inner: Rect2i = room.office.grow(-1) # floor inside walls
	if room.facing.x == 0: # if door facing up or down
		for x in range(inner.position.x, inner.end.x):
			tiles[Vector2i(x, room.cell.y)] = floor_id # replace with floors
	else:
		for y in range(inner.position.y, inner.end.y):
			tiles[Vector2i(room.cell.x, y)] = floor_id # replace with floors

func _add_door(door: Dictionary) -> void:
	tiles[door.cell] = DOOR
	tile_facing[door.cell] = door.facing

func _back_cell(room: Dictionary) -> Vector2i:
	var f: Vector2i = room.facing
	var depth: int = room.office.size.x if f.x != 0 else room.office.size.y
	return room.cell - f * (depth - 2)

# split block into 2  b2b rows
func _rows(r: Rect2i) -> Array:
	var wide := r.size.x >= r.size.y
	var depth := r.size.y if wide else r.size.x # short side
	var half := int((depth + 1) / 2.0)
	if wide:
		return [Rect2i(r.position.x, r.position.y, r.size.x, half),
				Rect2i(r.position.x, r.position.y + half - 1, r.size.x, depth - half + 1)]
	return [Rect2i(r.position.x, r.position.y, half, r.size.y),
			Rect2i(r.position.x + half - 1, r.position.y, depth - half + 1, r.size.y)]

# Take a row and split into equal slots
func _offices(row: Rect2i) -> Array:
	var wide := row.size.x >= row.size.y
	var length := row.size.x if wide else row.size.y
	var count := maxi(1, roundi((length - 1) / float(office_width - 1))) # Steps from time to time
	var offices := []
	for i in count:
		var a := roundi(i * (length - 1) / float(count))
		var b := roundi((i + 1) * (length - 1) / float(count))
		if wide:
			offices.append(Rect2i(row.position.x + a, row.position.y, b - a + 1, row.size.y))
		else:
			offices.append(Rect2i(row.position.x, row.position.y + a, row.size.x, b - a + 1))
	return offices

func _make_door(office: Rect2i, block: Rect2i) -> Dictionary:
	var cell := Vector2i.ZERO
	var facing := Vector2i.ZERO
	if block.size.x >= block.size.y:  # door in the top or bottom wall
		cell.x = int((office.position.x + office.end.x - 1) / 2.0)
		if office.position.y == block.position.y:
			cell.y = office.position.y
			facing = Vector2i.UP
		else:
			cell.y = office.end.y - 1
			facing = Vector2i.DOWN
	else:  # door in the left or right wall
		cell.y = int((office.position.y + office.end.y - 1) / 2.0)
		if office.position.x == block.position.x:
			cell.x = office.position.x
			facing = Vector2i.LEFT
		else:
			cell.x = office.end.x - 1
			facing = Vector2i.RIGHT
	return {"cell": cell, "facing": facing, "office": office, "block": block}

func _fill(r: Rect2i, item: int) -> void:
	for x in range(r.position.x, r.end.x):
		for y in range(r.position.y, r.end.y):
			tiles[Vector2i(x, y)] = item

func _draw_outline(r: Rect2i, item := WALL) -> void:
	for x in range(r.position.x, r.end.x):
		tiles[Vector2i(x, r.position.y)] = item
		tiles[Vector2i(x, r.end.y - 1)] = item
	for y in range(r.position.y, r.end.y):
		tiles[Vector2i(r.position.x, y)] = item
		tiles[Vector2i(r.end.x - 1, y)] = item


func _build() -> void:
	grid_map.clear()
	furniture_map.clear()
	for cell: Vector2i in tiles:
		var rot := _orient(tile_facing[cell]) if tile_facing.has(cell) else 0
		grid_map.set_cell_item(Vector3i(cell.x, 0, cell.y), tiles[cell], rot)
	for cell: Vector2i in ceilings:
		grid_map.set_cell_item(Vector3i(cell.x, 1, cell.y), ceilings[cell])
	for cell: Vector2i in furniture:
		var item: Array = furniture[cell]
		furniture_map.set_cell_item(Vector3i(cell.x, 0, cell.y), item[0], _orient(item[1]))
	_spawn_doors()

func _orient(facing: Vector2i) -> int:
	return grid_map.get_orthogonal_index_from_basis(Basis(Vector3.UP, atan2(facing.x, facing.y)))

func _spawn_doors() -> void:
	if is_instance_valid(_door_nodes):
		_door_nodes.queue_free()
	_door_nodes = Node3D.new()
	grid_map.add_child(_door_nodes)
	if door_scene == null:
		return

	var size := grid_map.cell_size
	for door: Dictionary in doors:
		var node := door_scene.instantiate() as ProfessorDoor
		if node == null:
			push_warning("door_scene's root node needs the door.gd script.")
			return
		node.position = Vector3((door.cell.x + 0.5) * size.x, 0.0, (door.cell.y + 0.5) * size.z)
		node.rotation.y = atan2(door.facing.x, door.facing.y)  # door's front (+Z) faces the corridor
		_door_nodes.add_child(node)
		node.setup(door.professor, door.locked)
		door.node = node

# Array.shuffle() ignores seed; use rng directly
func _shuffle(arr: Array) -> void:
	for i in range(arr.size() - 1, 0, -1):
		var j := rng.randi_range(0, i)
		var tmp: Variant = arr[i]
		arr[i] = arr[j]
		arr[j] = tmp

func _make_library() -> MeshLibrary:
	var lib := MeshLibrary.new()
	var c := grid_map.cell_size
	var flat := Vector3(c.x, 0.1, c.z)
	var desk := Vector3(c.x, 0.8, c.z * 0.6)
	var low := -c.y * 0.5  # bottom of a cell
	var wood := Color(0.5, 0.33, 0.2)
	var staff := Color(0.55, 0.75, 0.6)
	var services := Color(0.55, 0.6, 0.85)
	_add_box(lib, FLOOR, flat, Color(0.3, 0.3, 0.35), low)
	_add_box(lib, WALL, c, Color(0.85, 0.85, 0.8), 0.0)
	_add_box(lib, CEILING, flat, Color(0.7, 0.7, 0.7), low)
	_add_box(lib, OFFICE_FLOOR, flat, Color(0.35, 0.4, 0.55), low)
	_add_box(lib, DOOR, flat, wood, low)
	_add_box(lib, SPAWN, flat, Color(0.2, 0.7, 0.3), low)
	_add_box(lib, TABLE, desk, wood, low + 0.4)
	_add_box(lib, COMPUTER, desk, Color(0.1, 0.1, 0.12), low + 0.4)
	_add_box(lib, CHAIR, Vector3(0.6, 0.5, 0.6), Color(0.15, 0.15, 0.2), low + 0.25)
	_add_box(lib, STAFF_ROOM_FLOOR, flat, staff.darkened(0.4), low)
	_add_box(lib, STAFF_ROOM_WALL, c, staff, 0.0)
	_add_box(lib, STAFF_ROOM_CEILING, flat, staff.darkened(0.2), low)
	_add_box(lib, STAFF_ROOM_TABLE, desk, wood, low + 0.4)
	_add_box(lib, STUDENT_SERVICES_FLOOR, flat, services.darkened(0.4), low)
	_add_box(lib, STUDENT_SERVICES_WALL, c, services, 0.0)
	_add_box(lib, STUDENT_SERVICES_CEILING, flat, services.darkened(0.2), low)
	_add_box(lib, STUDENT_SERVICES_DESK, desk, wood, low + 0.4)
	_add_box(lib, STUDENT_SERVICES_WALL_LOGO, c, Color(0.9, 0.7, 0.2), 0.0)
	return lib

func _add_box(lib: MeshLibrary, id: int, box_size: Vector3, colour: Color, y: float) -> void:
	var box := BoxMesh.new()
	box.size = box_size
	var mat := StandardMaterial3D.new()
	mat.albedo_color = colour
	box.material = mat
	lib.create_item(id)
	lib.set_item_mesh(id, box)
	lib.set_item_mesh_transform(id, Transform3D(Basis(), Vector3(0, y, 0)))
