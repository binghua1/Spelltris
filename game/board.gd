extends Node2D

const ROWS := 20
const COLS := 10
const CELL_SIZE := 32
const BIAS := Vector2i(5, 5)

const TYPE = [
	[ Vector2i(0, -1), Vector2i(0, 0), Vector2i(0, 1), Vector2i(0, 2)   ], # I
	[ Vector2i(-1, -1), Vector2i(0, -1), Vector2i(0, 0), Vector2i(0, 1) ], # J
	[ Vector2i(0, -1), Vector2i(0, 0), Vector2i(0, 1), Vector2i(-1, 1)  ], # L
	[ Vector2i(-1, 0), Vector2i(-1, 1), Vector2i(0, 0), Vector2i(0, 1)  ], # O
	[ Vector2i(0, -1), Vector2i(0, 0), Vector2i(-1, 0), Vector2i(-1, 1) ], # S
	[ Vector2i(0, -1), Vector2i(-1, 0), Vector2i(0, 0), Vector2i(0, 1)  ], # T
	[ Vector2i(-1, -1), Vector2i(-1, 0), Vector2i(0, 0), Vector2i(0, 1) ]  # Z
]

const TABLE = [
	[ Vector2i(0, 0), Vector2i(0, 0), Vector2i(0, 0), Vector2i(0, 0), Vector2i(0, 0)      ], # 0
	[ Vector2i(0, 0), Vector2i(0, 1), Vector2i(1, 1), Vector2i(-2, 0), Vector2i(-2, 1)    ], # R
	[ Vector2i(0, 0), Vector2i(0, 0), Vector2i(0, 0), Vector2i(0, 0), Vector2i(0, 0)      ], # 2
	[ Vector2i(0, 0), Vector2i(0, -1), Vector2i(1, -1), Vector2i(-2, 0), Vector2i(-2, -1) ]  # L
]

const TABLE_I = [
	[ Vector2i(0, 0), Vector2i(0, -1), Vector2i(0, 2), Vector2i(0, -1), Vector2i(0, 2)     ], # 0
	[ Vector2i(0, -1), Vector2i(0, 0), Vector2i(0, 0), Vector2i(-1, 0), Vector2i(2, 0)     ], # R
	[ Vector2i(-1, -1), Vector2i(-1, 1), Vector2i(-1, -2), Vector2i(0, 1), Vector2i(0, -2) ], # 2
	[ Vector2i(-1, 0), Vector2i(-1, 0), Vector2i(-1, 0), Vector2i(1, 0), Vector2i(-2, 0)   ]  # L
]

const TABLE_O = [
	[ Vector2i(0, 0), Vector2i(0, 0), Vector2i(0, 0), Vector2i(0, 0), Vector2i(0, 0)      ], # 0
	[ Vector2i(1, 0), Vector2i(1, 0), Vector2i(1, 0), Vector2i(1, 0), Vector2i(1, 0)      ], # R
	[ Vector2i(1, -1), Vector2i(1, -1), Vector2i(1, -1), Vector2i(1, -1), Vector2i(1, -1) ], # 2
	[ Vector2i(0, -1), Vector2i(0, -1), Vector2i(0, -1), Vector2i(0, -1), Vector2i(0, -1) ]  # L
]

const COLOR = [Color.CYAN, Color.BLUE, Color.ORANGE, Color.YELLOW, Color.GREEN, Color.PURPLE, Color.RED]

const BUTTON_DELAY := 0.25
const BUTTON_REPEAT := 0.04

var grid := []
var cells := []
var timer := 0.0
var DROP_TIME := 0.7
var pos := Vector2i(0, 0)
var dir := 0
var type := 0
var horiz_dir := 0
var horiz_time := 0.0
var verti_dir := 0
var verti_time := 0.0
var spin_dir := 0
var spin_time := 0.0

func _draw() -> void:
	for y in range(ROWS):
		for x in range(COLS):
			var color = Color(0.07, 0.07, 0.07) if (x + y) % 2 == 0 else Color(0.09, 0.09, 0.09)
			if grid[y][x] != null:
				color = grid[y][x]
			draw_rect(
				Rect2(
					BIAS.x + x * CELL_SIZE,
					BIAS.y + y * CELL_SIZE,
					CELL_SIZE,
					CELL_SIZE
				),
				color
			)

	draw_rect(
		Rect2(BIAS.x + 0, BIAS.y + 0, COLS * CELL_SIZE, ROWS * CELL_SIZE),
		Color.WHITE,
		false,
		2
	)
	
	for c in cells:
		var cp = pos + c
		if cp.x < 0:
			continue
		draw_rect(
			Rect2(
				BIAS.x + cp.y * CELL_SIZE,
				BIAS.y + cp.x * CELL_SIZE,
				CELL_SIZE,
				CELL_SIZE
			),
			COLOR[type]
		)

# Called when the node enters the scene tree for the first time.
func _ready():
	for y in range(ROWS):
		grid.append([])
		for x in range(COLS):
			grid[y].append(null)
	pos = Vector2i(5, 5)
	type = randi_range(0, 6)
	cells = TYPE[type]


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta):
	timer += delta
	if timer > DROP_TIME:
		Fall()
		timer = 0
	if horiz_dir != 0:
		horiz_time -= delta
		if horiz_time <= 0:
			Move(horiz_dir)
			horiz_time = BUTTON_REPEAT
	if verti_dir != 0:
		verti_time -= delta
		if verti_time <= 0:
			Drop()
			verti_time = BUTTON_REPEAT
	if spin_dir != 0:
		spin_time -= delta
		if spin_time <= 0:
			Rotate(spin_dir)
			spin_time = BUTTON_REPEAT
	queue_redraw()
	
func _input(e):
	if e.is_action_pressed("SPACE"):
		Hard_Drop()
	elif e.is_action_pressed("ui_left"):
		horiz_dir = -1
		horiz_time = BUTTON_DELAY
		timer = 0.0
		Move(-1)
	elif e.is_action_released("ui_left"):
		if horiz_dir == -1:
			horiz_dir = 0
	elif e.is_action_pressed("ui_right"):
		horiz_dir = 1
		horiz_time = BUTTON_DELAY
		timer = 0.0
		Move(1)
	elif e.is_action_released("ui_right"):
		if horiz_dir == 1:
			horiz_dir = 0
	elif e.is_action_pressed("ui_down"):
		verti_dir = 1
		verti_time = BUTTON_DELAY
		timer = 0.0
		Drop()
	elif e.is_action_released("ui_down"):
		if verti_dir == 1:
			verti_dir = 0
	elif e.is_action_pressed("x"):
		spin_dir = 1
		spin_time = BUTTON_DELAY
		timer = 0.0
		Rotate(1)
	elif e.is_action_released("x"):
		if spin_dir == 1:
			spin_dir = 0
	elif e.is_action_pressed("z"):
		spin_dir = -1
		spin_time = BUTTON_DELAY
		timer = 0.0
		Rotate(-1)
	elif e.is_action_released("z"):
		if spin_dir == -1:
			spin_dir = 0
		
func Collide(new_p, new_cells) -> bool:
	for c in new_cells:
		var cp = new_p + c
		if cp.x >= ROWS or cp.y < 0 or cp.y >= COLS or (cp.x >= 0 and grid[cp.x][cp.y] != null):
			return true
	return false
	
func Fall() -> void:
	var new_pos = pos + Vector2i(1, 0)
	if (Collide(new_pos, cells)):
		for c in cells:
			var cp = pos + c
			grid[cp.x][cp.y] = COLOR[type]
		pos = Vector2i(0, 5)
		#type = randi_range(0, 6)
		type = (type + 1) % 7
		dir = 0
		cells = TYPE[type]
	else:
		pos = new_pos
		
func Move(d) -> void:
	var new_pos = pos
	new_pos.y += d
	if not Collide(new_pos, cells):
		pos = new_pos
		
func Rotate(d) -> void:
	var next_dir = (dir + 4 + d) % 4
	var next_cells = []
	for cell in cells:
		if d == -1:
			next_cells.append(Vector2i(-cell.y, cell.x))
		else:
			next_cells.append(Vector2i(cell.y, -cell.x))
	for test in range(5):
		var bias
		if type == 0:
			bias = TABLE_I[dir][test] - TABLE_I[next_dir][test]
		elif type == 3:
			bias = TABLE_O[dir][test] - TABLE_O[next_dir][test]
		else:
			bias = TABLE[dir][test] - TABLE[next_dir][test]
		if not Collide(pos + bias, next_cells):
			pos = pos + bias
			cells = next_cells
			dir = next_dir
			break;
			
func Drop() -> void:
	var next_pos = pos
	next_pos.x += 1
	if not Collide(next_pos, cells):
		pos = next_pos
	
func Hard_Drop() -> void:
	while not Collide(pos, cells):
		pos.x += 1
	pos.x -= 1
	timer = DROP_TIME
