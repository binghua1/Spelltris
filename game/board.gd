extends Node2D

const ROWS := 20
const COLS := 10
const CELL_SIZE := 50
const BIAS := Vector2i(500, 300)

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
const LOCK_DELAY := 0.5
const OPERATION_LIMIT := 15

const show_next := 5

const OPPONENT_BIAS = Vector2i(1850, 300) # 對手盤面畫在右邊 (根據螢幕寬度調整)
var opponent_grid = [] # 儲存對手的顏色數據
var opponent_hold = null
var opponent_next = []
var opponent_type = 0
var opponent_cells = []
var opponent_pos = Vector2i(0, 0)
var opponent_ghost_pos = Vector2i(0, 0)

var grid := []
var cells := []
var drop_timer := 0.0
var lock_timer := 0.0
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
var ghost_pos := Vector2i(0, 0)

var seven_bag = []
var rng
var rng_seed = 114514
var hold = null
var is_holded = false
var op_times = 0
var is_on_ground = false

var gaming = true

# 攻擊相關變數
var lines_cleared = 0 # 累計消除的行數
var incoming_attack_lines = 0 # 即將到來的攻擊行數
var last_move_was_tspin = false # 上一次動作是否為T-spin
var last_rotated = false # 上次是否旋轉
var b2b = false
var combo = -1

func Cell(p, b=Vector2i(0, 0)) -> Rect2:
	return Rect2(BIAS.x + b.x + p.y * CELL_SIZE, BIAS.y + b.y + p.x * CELL_SIZE, CELL_SIZE, CELL_SIZE)

func Opp_Cell(p, b=Vector2i(0, 0)) -> Rect2:
	return Rect2(OPPONENT_BIAS.x + b.x + p.y * CELL_SIZE, OPPONENT_BIAS.y + b.y + p.x * CELL_SIZE, CELL_SIZE, CELL_SIZE)

func _draw() -> void:
	# BackGround & Placed Tetromino
	for y in range(ROWS):
		for x in range(COLS):
			var color = Color(0.07, 0.07, 0.07) if (x + y) % 2 == 0 else Color(0.09, 0.09, 0.09)
			if grid[y][x] != null:
				color = grid[y][x]
			draw_rect(Cell(Vector2i(y, x)), color)
	# Borderline
	draw_rect(
		Rect2(BIAS.x + 0, BIAS.y + 0, COLS * CELL_SIZE, ROWS * CELL_SIZE),
		Color.WHITE,
		false,
		2
	)
	# Cell & Ghost
	for c in cells:
		var cp = pos + c
		if cp.x >= 0:
			draw_rect(Cell(cp), COLOR[type])
		var gcp = ghost_pos + c
		if gcp.x >= 0:
			var color = COLOR[type]
			color.a = 0.4
			draw_rect(Cell(gcp), color)
	var area
	var area_rect
	# Hold
	area = Vector2i(CELL_SIZE * 5, CELL_SIZE * 3)
	area_rect = Rect2(BIAS.x - area.x, BIAS.y, area.x, area.y)
	draw_rect(area_rect, Color.BLACK)
	draw_rect(area_rect, Color.WHITE, false, 2)
	if hold != null:
		for c in TYPE[hold]:
			var b = Vector2i(- (CELL_SIZE + area.x) / 2, area.y / 2)
			if hold == 0:
				b.x -= CELL_SIZE / 2.0
				b.y -= CELL_SIZE / 2.0
			elif hold == 3:
				b.x -= CELL_SIZE / 2.0
			var color = COLOR[hold]
			if is_holded:
				color.a = 0.7
			draw_rect(Cell(c, b), color)
	# Next
	area.y = area.y * show_next
	area_rect = Rect2(BIAS.x - area.x + CELL_SIZE * (COLS + 5), BIAS.y, area.x, area.y)
	draw_rect(area_rect, Color.BLACK)
	draw_rect(area_rect, Color.WHITE, false, 2)
	for i in range(show_next):
		for c in TYPE[seven_bag[i]]:
			var b = Vector2i(- (CELL_SIZE + area.x) / 2, area.y / 2)
			if seven_bag[i] == 0:
				b.x -= CELL_SIZE / 2.0
				b.y -= CELL_SIZE / 2.0
			elif seven_bag[i] == 3:
				b.x -= CELL_SIZE / 2.0
			b += Vector2i(CELL_SIZE * (COLS + 5), CELL_SIZE * i * 3 - (area.y - CELL_SIZE * 3) / 2.0)
			draw_rect(Cell(c, b), COLOR[seven_bag[i]])
	### Enemy ############
	for y in range(ROWS):
		for x in range(COLS):
			var color = opponent_grid[y][x]
			if color == null:
				color = Color(0.05, 0.05, 0.05) # 對手底色更深一點
			# 這裡使用自定義位移 OPPONENT_BIAS
			var rect = Rect2(OPPONENT_BIAS.x + x * CELL_SIZE, OPPONENT_BIAS.y + y * CELL_SIZE, CELL_SIZE, CELL_SIZE)
			draw_rect(rect, color)
	# Enemy Borderline
	draw_rect(
		Rect2(OPPONENT_BIAS.x + 0, OPPONENT_BIAS.y + 0, COLS * CELL_SIZE, ROWS * CELL_SIZE),
		Color.WHITE,
		false,
		2
	)
	
	# Emeny Cell & Ghost
	for c in opponent_cells:
		var cp = opponent_pos + c
		if cp.x >= 0:
			draw_rect(Opp_Cell(cp), COLOR[opponent_type])
		var gcp = opponent_ghost_pos + c
		if gcp.x >= 0:
			var color = COLOR[opponent_type]
			color.a = 0.4
			draw_rect(Opp_Cell(gcp), color)
	
	# Enemy Hold
	area = Vector2i(CELL_SIZE * 5, CELL_SIZE * 3)
	area_rect = Rect2(OPPONENT_BIAS.x - area.x, OPPONENT_BIAS.y, area.x, area.y)
	draw_rect(area_rect, Color.BLACK)
	draw_rect(area_rect, Color.WHITE, false, 2)
	if opponent_hold != null:
		for c in TYPE[opponent_hold]:
			var b = Vector2i(- (CELL_SIZE + area.x) / 2, area.y / 2)
			if opponent_hold == 0:
				b.x -= CELL_SIZE / 2.0
				b.y -= CELL_SIZE / 2.0
			elif opponent_hold == 3:
				b.x -= CELL_SIZE / 2.0
			var color = COLOR[opponent_hold]
			var r = Cell(c, b)
			r.position += Vector2(OPPONENT_BIAS - BIAS)
			draw_rect(r, color)

	# Enemy Next
	area.y = area.y * show_next
	area_rect = Rect2(OPPONENT_BIAS.x - area.x + CELL_SIZE * (COLS + 5), OPPONENT_BIAS.y, area.x, area.y)
	draw_rect(area_rect, Color.BLACK)
	draw_rect(area_rect, Color.WHITE, false, 2)
	for i in range(min(show_next, opponent_next.size())):
		for c in TYPE[opponent_next[i]]:
			var b = Vector2i(- (CELL_SIZE + area.x) / 2, area.y / 2)
			if opponent_next[i] == 0:
				b.x -= CELL_SIZE / 2.0
				b.y -= CELL_SIZE / 2.0
			elif opponent_next[i] == 3:
				b.x -= CELL_SIZE / 2.0
			b += Vector2i(CELL_SIZE * (COLS + 5), CELL_SIZE * i * 3 - (area.y - CELL_SIZE * 3) / 2.0)
			var r = Cell(c, b)
			r.position += Vector2(OPPONENT_BIAS - BIAS)
			draw_rect(r, COLOR[opponent_next[i]])
				# 顯示消除行數
	var font = ThemeDB.fallback_font
	var font_size = 32
	draw_string(font, Vector2(BIAS.x, BIAS.y + ROWS * CELL_SIZE + 40), "Lines: %d" % lines_cleared, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size)
	
	# 顯示接收到的攻擊
	if incoming_attack_lines > 0:
		draw_string(font, Vector2(BIAS.x + 200, BIAS.y + ROWS * CELL_SIZE + 40), "Incoming: %d" % incoming_attack_lines, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, Color.RED)
func Reset() -> void:
	grid = []
	for y in range(ROWS):
		grid.append([])
		for x in range(COLS):
			grid[y].append(null)
	rng = RandomNumberGenerator.new()
	rng.seed = rng_seed
	seven_bag = []
	Spawn()
	hold = null
	gaming = true
	op_times = 0
	is_on_ground = false
	lines_cleared = 0
	incoming_attack_lines = 0
	last_move_was_tspin = false
	b2b = false
	combo = -1
	last_rotated = false
	Send_Data()

func Send_Data() -> void:
	# --- 新增同步發送 ---
	var sync_data = []
	for y in range(ROWS):
		var row_data = []
		for x in range(COLS):
			if grid[y][x] == null: row_data.append(null)
			else: row_data.append(grid[y][x].to_html()) # 轉成 hex 字串
		sync_data.append(row_data)
	# 傳送 hold 和 next (取前 show_next 個)
	Network.send_sync(sync_data, hold, seven_bag.slice(0, show_next), type, cells, pos, ghost_pos)
	# ------------------

func _ready():
	print("visible:", get_viewport().get_visible_rect().size)
	print("board pos:", global_position)
	print("board scale:", global_scale)
	Reset()
	for y in range(ROWS):
		opponent_grid.append([])
		for x in range(COLS):
			opponent_grid[y].append(null)
			
	# 監聽網路信號
	Network.opponent_grid_updated.connect(_on_opponent_grid_updated)
	Network.win_respond.connect(_on_win_respond)
	Network.attack_received.connect(_on_attack_received)
	print("正在連線到伺服器...")
	if Network.socket.get_ready_state() != WebSocketPeer.STATE_OPEN:
		Network.socket.connect_to_url(Network.url)

func _process(delta):
	if gaming:
		drop_timer += delta
		if drop_timer > DROP_TIME:
			Fall()
			drop_timer = 0
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
				
		if OnGround():
			if not is_on_ground:
				is_on_ground = true
				lock_timer = 0.0
		else:
			is_on_ground = false
		if is_on_ground:
			lock_timer += delta
			if lock_timer > LOCK_DELAY - 0.03 * op_times:
				Lock()
		Ghost()
	else:
		Network.send_game_end()
		print("Player %s lose" % [Global.player_name])
		get_tree().change_scene_to_file("res://lobby.tscn")
	queue_redraw()

func _input(e):
	if gaming:
		if e.is_action_pressed("SPACE"):
			Hard_Drop()
		elif e.is_action_pressed("ui_left"):
			horiz_dir = -1
			horiz_time = BUTTON_DELAY
			if is_on_ground and op_times < OPERATION_LIMIT:
				lock_timer = 0.0
				op_times += 1
			Move(-1)
		elif e.is_action_released("ui_left"):
			if horiz_dir == -1:
				horiz_dir = 0
		elif e.is_action_pressed("ui_right"):
			horiz_dir = 1
			horiz_time = BUTTON_DELAY
			if is_on_ground and op_times < OPERATION_LIMIT:
				lock_timer = 0.0
				op_times += 1
			Move(1)
		elif e.is_action_released("ui_right"):
			if horiz_dir == 1:
				horiz_dir = 0
		elif e.is_action_pressed("ui_down"):
			verti_dir = 1
			verti_time = BUTTON_DELAY
			Drop()
		elif e.is_action_released("ui_down"):
			if verti_dir == 1:
				verti_dir = 0
		elif e.is_action_pressed("x") or e.is_action_pressed("ui_up"):
			spin_dir = 1
			spin_time = BUTTON_DELAY
			if is_on_ground and op_times < OPERATION_LIMIT:
				lock_timer = 0.0
				op_times += 1
			Rotate(1)
		elif e.is_action_released("x") or e.is_action_released("ui_up"):
			if spin_dir == 1:
				spin_dir = 0
		elif e.is_action_pressed("z"):
			spin_dir = -1
			spin_time = BUTTON_DELAY
			if is_on_ground and op_times < OPERATION_LIMIT:
				lock_timer = 0.0
				op_times += 1
			Rotate(-1)
		elif e.is_action_released("z"):
			if spin_dir == -1:
				spin_dir = 0
		elif e.is_action_pressed("c"):
			if not is_holded:
				if hold == null:
					hold = type
					Spawn()
				else:
					var temp = type
					type = hold
					hold = temp
					pos = Vector2i(0, 5)
					dir = 0
					cells = TYPE[type]
					op_times = 0
					is_on_ground = OnGround()
					if Collide(pos, cells):
						gaming = false
				is_holded = true
				Send_Data()
	if e.is_action_pressed("r"):
		Reset()
		
func Random_Shuffle(arr, _seed) -> Array:
	var RNG = RandomNumberGenerator.new()
	RNG.seed = _seed
	var shuffled_arr = arr.duplicate()
	var n = arr.size() - 1
	while n > 0:
		var p = RNG.randi_range(0, n)
		var temp = shuffled_arr[n]
		shuffled_arr[n] = shuffled_arr[p]
		shuffled_arr[p] = temp
		n -= 1
	return shuffled_arr
	
func Spawn()-> void:
	while seven_bag.size() < 8:
		seven_bag += Random_Shuffle([0, 1, 2, 3, 4, 5, 6], rng.randi())
	type = seven_bag.pop_front()
	pos = Vector2i(0, 5)
	dir = 0
	cells = TYPE[type]
	is_holded = false
	op_times = 0
	is_on_ground = OnGround()
	if Collide(pos, cells):
		gaming = false

func Collide(new_p, new_cells) -> bool:
	for c in new_cells:
		var cp = new_p + c
		if cp.x >= ROWS or cp.y < 0 or cp.y >= COLS or (cp.x >= 0 and grid[cp.x][cp.y] != null):
			return true
	return false
	
func OnGround() -> bool:
	var new_pos = pos + Vector2i(1, 0)
	return Collide(new_pos, cells)
	
func Lock() -> void:
	# 檢查 T-spin
	last_move_was_tspin = false
	if type == 5 and last_rotated: # 5 is T-piece
		var corners = [Vector2i(-1, -1), Vector2i(-1, 1), Vector2i(1, -1), Vector2i(1, 1)]
		var occupied_corners = 0
		for corner in corners:
			var check_pos = pos + corner
			if check_pos.x >= ROWS or check_pos.y < 0 or check_pos.y >= COLS or (check_pos.x >= 0 and grid[check_pos.x][check_pos.y] != null):
				occupied_corners += 1
		if occupied_corners >= 3:
			last_move_was_tspin = true
			print("T-Spin Detected!")

	for c in cells:
		var cp = pos + c
		grid[cp.x][cp.y] = COLOR[type]
	Eliminate_Line()	
	Spawn()
	Send_Data()
	
func Fall() -> void:
	if not OnGround():
		pos.x += 1
		last_rotated = false # 下落後重置旋轉標記
		Send_Data()
		
func Move(d) -> void:
	var new_pos = pos
	new_pos.y += d
	if not Collide(new_pos, cells):
		pos = new_pos
		last_rotated = false # 移動後重置旋轉標記
		
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
			last_rotated = true # 記錄旋轉
			Send_Data()
			break;
			
func Drop() -> void:
	var next_pos = pos
	next_pos.x += 1
	if not Collide(next_pos, cells):
		pos = next_pos
		last_rotated = false # 下落後重置旋轉標記
		Send_Data()
		
	
func Hard_Drop() -> void:
	while not Collide(pos, cells):
		pos.x += 1
	pos.x -= 1
	last_rotated = false # 硬降視為移動
	Lock()
	Send_Data()
	
func Ghost() -> void:
	var old_ghost_pos = ghost_pos
	ghost_pos = pos
	while not Collide(ghost_pos, cells):
		ghost_pos.x += 1
	ghost_pos.x -= 1
	if old_ghost_pos != ghost_pos:
		Send_Data()
	
func Eliminate_Line():
	var lines_cleared_now = 0
	for y in range(ROWS):
		var is_full_line = true
		for x in range(COLS):
			if grid[y][x] == null:
				is_full_line = false
		if is_full_line:
			lines_cleared_now += 1
			for x in COLS:
				grid[y][x] = null
	
	lines_cleared += lines_cleared_now
	
	# 計算攻擊行數
	var attack = 0
	if last_move_was_tspin:
		if lines_cleared_now == 0:
			attack = 2 if b2b else 1
		elif lines_cleared_now == 1:
			attack = 3 if b2b else 2
		elif lines_cleared_now == 2:
			attack = 6 if b2b else 4
		elif lines_cleared_now == 3:
			attack = 9 if b2b else 6
		b2b = true
	else:
		if lines_cleared_now == 2:
			attack = 1
		elif lines_cleared_now == 3:
			attack = 2
		elif lines_cleared_now == 4:
			attack = 6 if b2b else 4
		b2b = (lines_cleared_now == 4)
		
	# ren
	combo = -1 if (lines_cleared_now == 0) else combo + 1
	attack += min(4, int((combo + 1) / 2.0))
			
	if attack > 0:
		print("Sending attack: ", attack)
		Network.send_attack(attack)
		
	# 抵銷攻擊
	if incoming_attack_lines > 0:
		if incoming_attack_lines >= attack:
			incoming_attack_lines -= attack
			attack = 0
		else:
			attack -= incoming_attack_lines
			incoming_attack_lines = 0
	
	# 處理接收到的攻擊 (如果沒有消除行，或者消除後還有剩餘攻擊)
	if lines_cleared_now == 0 and incoming_attack_lines > 0:
		add_garbage_lines(incoming_attack_lines)
		incoming_attack_lines = 0
	
	for y in range(ROWS - 1, -1, -1):
		var ny = y + 1
		while ny < ROWS:
			var is_empty_line = true
			for x in range(COLS):
				if grid[ny][x] != null:
					is_empty_line = false
			if not is_empty_line:
				break
			ny += 1
		ny -= 1
		if ny == y:
			continue
		var temp = grid[y]
		grid[y] = grid[ny]
		grid[ny] = temp
	
	
func _on_opponent_grid_updated(new_grid_data, new_hold, new_next, new_type, new_cells, new_pos, new_ghost_pos):
	# 後端傳來的是字串或陣列，我們需要轉回顏色
	# 這裡假設傳來的是顏色 hex string 陣列
	opponent_grid = new_grid_data
	opponent_hold = new_hold
	opponent_next = new_next
	opponent_type = new_type
	opponent_cells = new_cells
	opponent_pos = new_pos
	opponent_ghost_pos = new_ghost_pos
	
func _on_win_respond():
	gaming = false
	print("Player %s win" % [Global.player_name])
	get_tree().change_scene_to_file("res://lobby.tscn")

func _on_attack_received(lines):
	print("Received attack: ", lines)
	incoming_attack_lines += lines

func add_garbage_lines(count):
	# 將現有方塊上移
	for y in range(count, ROWS):
		grid[y - count] = grid[y]
	
	# 底部新增垃圾行
	var hole = rng.randi_range(0, COLS - 1)
	for i in range(count):
		var y = ROWS - 1 - i
		grid[y] = []
		for x in range(COLS):
			if x == hole:
				grid[y].append(null)
			else:
				grid[y].append(Color.GRAY) # 垃圾行顏色
	
	Send_Data()
