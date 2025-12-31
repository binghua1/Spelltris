extends Node2D

@onready var tile_map = $tilemap
@onready var ghost_map = $ghost_map # 請務必新增這個節點，或是複製 tilemap 改名
@onready var timer = $Timer

const TYPE_WALL = 2   
const TYPE_BLOCK = 3  

const COLOR_MAP = [
	Vector2i(1, 1), # I
	Vector2i(5, 1), # J
	Vector2i(11, 1),# L
	Vector2i(13, 1),# O
	Vector2i(3, 4), # S
	Vector2i(7, 4), # T
	Vector2i(11, 4) # Z
]
const WALL_COLOR = Vector2i(0, 0)

const BOARD_WIDTH = 10
const BOARD_HEIGHT = 20

const PIECE_TYPES = [
	[ Vector2i(0, -1), Vector2i(0, 0), Vector2i(0, 1), Vector2i(0, 2)   ], # 0: I
	[ Vector2i(-1, -1), Vector2i(0, -1), Vector2i(0, 0), Vector2i(0, 1) ], # 1: J
	[ Vector2i(0, -1), Vector2i(0, 0), Vector2i(0, 1), Vector2i(-1, 1)  ], # 2: L
	[ Vector2i(-1, 0), Vector2i(-1, 1), Vector2i(0, 0), Vector2i(0, 1)  ], # 3: O
	[ Vector2i(0, -1), Vector2i(0, 0), Vector2i(-1, 0), Vector2i(-1, 1) ], # 4: S
	[ Vector2i(0, -1), Vector2i(-1, 0), Vector2i(0, 0), Vector2i(0, 1)  ], # 5: T
	[ Vector2i(-1, -1), Vector2i(-1, 0), Vector2i(0, 0), Vector2i(0, 1) ]  # 6: Z
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
	[ Vector2i(0, 0) ], [ Vector2i(1, 0) ], [ Vector2i(1, -1) ], [ Vector2i(0, -1) ]
]

var cur_type_idx := 0
var cur_cells := [] 
var cur_pos := Vector2i(5, 5) 
var cur_rot_state := 0 
var ghost_pos := Vector2i.ZERO # 新增：幽靈位置

func _ready() -> void:
	$Camera2D.position = Vector2(3000, 1280) # 配合你之前的 128x128 縮放中心
	$Camera2D.zoom = Vector2(0.3, 0.3)
	# 如果你有設定 ghost_map，將其透明度調低，營造幽靈感
	if has_node("ghost_map"):
		$ghost_map.modulate.a = 0.2
	draw_walls()
	spawn_piece()
	timer.wait_time = 0.5
	timer.start()

func draw_walls():
	for row in range(-1, BOARD_HEIGHT + 1):
		_set_tile(row, -1, TYPE_WALL, WALL_COLOR)
		_set_tile(row, BOARD_WIDTH, TYPE_WALL, WALL_COLOR)
	for col in range(-1, BOARD_WIDTH + 1):
		_set_tile(BOARD_HEIGHT, col, TYPE_WALL, WALL_COLOR)
		_set_tile(-1, col, TYPE_WALL, WALL_COLOR)

func _set_tile(r: int, c: int, source_id: int, atlas_coord: Vector2i = Vector2i.ZERO, is_ghost: bool = false):
	if is_ghost:
		ghost_map.set_cell(Vector2i(c, r), source_id, atlas_coord)
	else:
		tile_map.set_cell(Vector2i(c, r), source_id, atlas_coord)

func _get_source_id(r: int, c: int) -> int:
	return tile_map.get_cell_source_id(Vector2i(c, r))

var bag: Array = []
func choose(): # 7 bag
	if bag.is_empty():
		bag = [0, 1, 2, 3, 4, 5, 6]
		bag.shuffle()
	return bag.pop_front()
	

func spawn_piece():
	cur_type_idx = choose()
	cur_cells = PIECE_TYPES[cur_type_idx].duplicate()
	cur_pos = Vector2i(1, 4)
	cur_rot_state = 0
	if Collide(cur_pos, cur_cells):
		get_tree().reload_current_scene()
	update_visuals()

# --- 修改：整合繪製邏輯，包含幽靈方塊 ---
func update_visuals():
	clear_piece() # 先清除舊的方塊與幽靈
	
	# 1. 計算幽靈位置：從目前位置一直往下試探直到碰撞
	ghost_pos = cur_pos
	while not Collide(ghost_pos + Vector2i(1, 0), cur_cells):
		ghost_pos.x += 1
	
	# 2. 畫幽靈
	for c in cur_cells:
		_set_tile(ghost_pos.x + c.x, ghost_pos.y + c.y, TYPE_BLOCK, COLOR_MAP[cur_type_idx], true)
		
	# 3. 畫本體
	for c in cur_cells:
		_set_tile(cur_pos.x + c.x, cur_pos.y + c.y, TYPE_BLOCK, COLOR_MAP[cur_type_idx], false)

func clear_piece():
	# 清除本體
	for c in cur_cells:
		_set_tile(cur_pos.x + c.x, cur_pos.y + c.y, -1, Vector2i.ZERO, false)
	# 清除幽靈 (ghost_map 也要清)
	if has_node("ghost_map"):
		ghost_map.clear()

func Collide(p: Vector2i, cells_to_check: Array) -> bool:
	for c in cells_to_check:
		var r = p.x + c.x
		var col = p.y + c.y
		if _get_source_id(r, col) != -1:
			return true
	return false

func move(dr: int, dc: int) -> bool:
	clear_piece()
	var new_p = cur_pos + Vector2i(dr, dc)
	if not Collide(new_p, cur_cells):
		cur_pos = new_p
		update_visuals()
		return true
	update_visuals()
	return false

# --- 新增：Hard Drop (硬降) ---
func hard_drop():
	clear_piece()
	# 直接移動到幽靈位置
	cur_pos = ghost_pos
	update_visuals()
	# 強制觸發落地邏輯
	check_line_clear()
	spawn_piece()

func _on_timer_timeout() -> void:
	if not move(1, 0): 
		check_line_clear()
		spawn_piece()

func _input(event):
	if event.is_action_pressed("ui_left"): move(0, -1)
	if event.is_action_pressed("ui_right"): move(0, 1)
	if event.is_action_pressed("ui_down"): move(1, 0)
	if event.is_action_pressed("ui_up"): rotate_piece(1)
	if event.is_action_pressed("ui_accept"): hard_drop() # Space 鍵 (ui_accept 預設包含 Space)
	if event.is_action_pressed("ui_z"): rotate_piece(-1) # Z 鍵逆時針 (需在 Input Map 設定 ui_z)

func rotate_piece(d: int):
	var next_rot = (cur_rot_state + 4 + d) % 4
	var next_cells = []
	
	for cell in cur_cells:
		if d == -1: # 逆時針
			next_cells.append(Vector2i(-cell.y, cell.x))
		else:       # 順時針
			next_cells.append(Vector2i(cell.y, -cell.x))
	
	var offset_table
	if cur_type_idx == 0: offset_table = TABLE_I
	elif cur_type_idx == 3: offset_table = TABLE_O
	else: offset_table = TABLE
	
	clear_piece()
	
	for test in range(offset_table[cur_rot_state].size()):
		var kick = offset_table[cur_rot_state][test] - offset_table[next_rot][test]
		
		if not Collide(cur_pos + kick, next_cells):
			cur_pos += kick
			cur_cells = next_cells
			cur_rot_state = next_rot
			if cur_type_idx == 5: check_t_spin()
			update_visuals()
			return
			
	update_visuals()

func check_t_spin():
	var count = 0
	var corners = [Vector2i(-1,-1), Vector2i(-1,1), Vector2i(1,-1), Vector2i(1,1)]
	for c in corners:
		if _get_source_id(cur_pos.x + c.x, cur_pos.y + c.y) != -1:
			count += 1
	if count >= 3:
		print("T-Spin!")

func check_line_clear():
	for r in range(BOARD_HEIGHT - 1, -1, -1):
		var is_full = true
		for x in range(BOARD_WIDTH):
			if _get_source_id(r, x) == -1:
				is_full = false
				break
		if is_full:
			remove_line(r)
			check_line_clear()
			break

func remove_line(row_idx):
	for c in range(BOARD_WIDTH):
		_set_tile(row_idx, c, -1)
	for r in range(row_idx, 0, -1):
		for x in range(BOARD_WIDTH):
			var s_id = _get_source_id(r - 1, x)
			var atlas = tile_map.get_cell_atlas_coords(Vector2i(x, r - 1))
			_set_tile(r, x, s_id, atlas)
