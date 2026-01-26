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
# 用來讓掉落速度變快
var total_gametime := 0.0 
const MIN_DROP_TIME := 0.03
const SPEED_DECAY := 0.017 
const INITIAL_DROP_TIME := 0.7

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

var nums_of_game := 1

# 攻擊相關變數
var lines_cleared = 0 # 累計消除的行數
var incoming_attack_lines = 0 # 即將到來的攻擊行數
var last_move_was_tspin = false # 上一次動作是否為T-spin
var last_rotated = false # 上次是否旋轉
var b2b = false
var combo = -1

var my_score = 0
var opponent_score = 0
const WIN_SCORE = 3

# 加速效果
var speed_up_rate = 1.0
var is_speed_up = false
var speed_up_timer = 0.0

# 遮擋頂部效果
var is_blind_top = false
var blind_top_timer = 0.0
var blind_top_lines = 0

# 時間暫停效果
var is_time_stop = false
var time_stop_timer = 0.0

# 畫面顛倒效果
var is_screen_inverted = false
var invert_timer = 0.0

# 反彈效果
var is_reflected = false
var reflected_timer = 0.0

# 無敵較果
var is_invincible = false
var invincible_timer = 0.0

# 閃光彈
var is_flashbang = false
var flashbang_timer = 0.0
var flashbang_duration = 12.0  
var flashbang_texture: Texture2D = null
var show_flashbang_image = false  # 50% 機率顯示圖片
const FLASHBANG_IMAGE_DELAY = 0  # 圖片延遲出現時間
const FLASHBANG_FADE_IN_TIME = 2.0  

# 遮擋預告效果
var is_hide_next = false
var hide_next_timer = 0.0

signal game_over(game_status)

func Cell(p, b=Vector2i(0, 0)) -> Rect2:
	return Rect2(BIAS.x + b.x + p.y * CELL_SIZE, BIAS.y + b.y + p.x * CELL_SIZE, CELL_SIZE, CELL_SIZE)

func Opp_Cell(p, b=Vector2i(0, 0)) -> Rect2:
	return Rect2(OPPONENT_BIAS.x + b.x + p.y * CELL_SIZE, OPPONENT_BIAS.y + b.y + p.x * CELL_SIZE, CELL_SIZE, CELL_SIZE)

func _draw() -> void:
	# 如果畫面顛倒，設定變換矩陣
	if is_screen_inverted:
		#var center_x = BIAS.x + (COLS * CELL_SIZE) / 2.0
		var center_y = BIAS.y + (ROWS * CELL_SIZE) / 2.0
		# 將畫面繞著自己盤面中心旋轉 180 度
		draw_set_transform(Vector2(0, center_y * 2), 0, Vector2(1, -1))
	# BackGround & Placed Tetromino
	for y in range(ROWS):
		for x in range(COLS):
			var color = Color(0.07, 0.07, 0.07) if (x + y) % 2 == 0 else Color(0.09, 0.09, 0.09)
			if is_blind_top and y < blind_top_lines:
				color = Color(0.2, 0.1, 0.2)
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
	if not is_hide_next:
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

	#var bar_gap = 10
	var max_visible_lines = 17
	
	var bar_width = 20
	var bar_x = BIAS.x - bar_width
	var bar_bottom_y = BIAS.y + ROWS * CELL_SIZE 
	var full_bar_height = max_visible_lines * CELL_SIZE 
	var full_bar_y = bar_bottom_y - full_bar_height 
	draw_rect(Rect2(bar_x, full_bar_y, bar_width, full_bar_height), Color.WHITE, false, 2)
	if incoming_attack_lines > 0:
		# cal height
		var visible_lines = min(incoming_attack_lines, max_visible_lines)
		var fill_height = visible_lines * CELL_SIZE
		var fill_y = bar_bottom_y - fill_height 
		var bar_color = Color.GREEN
		if incoming_attack_lines >= 12:
			bar_color = Color.RED
		elif incoming_attack_lines >= 6:
			bar_color = Color.ORANGE
		elif incoming_attack_lines >= 3:
			bar_color = Color.YELLOW
		draw_rect(Rect2(bar_x, fill_y, bar_width, fill_height), bar_color)
	# 這行以上的都會倒過來	
	if is_screen_inverted:
		draw_set_transform(Vector2.ZERO, 0, Vector2.ONE)
	
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

	# Score
	draw_string(font, Vector2(BIAS.x, BIAS.y - 20), "Score: %d" % my_score, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size)
	draw_string(font, Vector2(OPPONENT_BIAS.x, OPPONENT_BIAS.y - 20), "Score: %d" % opponent_score, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size)
	
	if is_flashbang:
		var alpha = flashbang_timer / flashbang_duration
		var color := Color(1, 1, 1, alpha)
		var screen_size = get_viewport().get_visible_rect().size / global_scale

		draw_rect(
			Rect2(
				Vector2i.ZERO,
				screen_size
			),
			color,
			true
		)
		
		# 圓神
		var elapsed_time = flashbang_duration - flashbang_timer
		if flashbang_texture != null and show_flashbang_image and elapsed_time >= FLASHBANG_IMAGE_DELAY:
			# 圖片已顯示的時間
			var image_elapsed = elapsed_time - FLASHBANG_IMAGE_DELAY
			var image_total = flashbang_duration - FLASHBANG_IMAGE_DELAY
			var image_alpha: float
			
			if image_elapsed < FLASHBANG_FADE_IN_TIME:
				# 淡入階段：alpha 從 0 到 1
				image_alpha = image_elapsed / FLASHBANG_FADE_IN_TIME
			else:
				# 淡出階段：alpha 從 1 到 0
				var fade_out_total = image_total - FLASHBANG_FADE_IN_TIME
				image_alpha = flashbang_timer / fade_out_total
			
			image_alpha = clamp(image_alpha, 0.0, 1.0)
			# 將圖片縮放填滿整個畫面
			draw_texture_rect(flashbang_texture, Rect2(Vector2.ZERO, screen_size), false, Color(1, 1, 1, image_alpha))
	
func Reset(reset_scores = true) -> void:
	grid = []
	for y in range(ROWS):
		grid.append([])
		for x in range(COLS):
			grid[y].append(null)
	rng = RandomNumberGenerator.new()
	rng_seed = 114514 * Global.room_id.to_int() - 1919810 * nums_of_game
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
	total_gametime = 0
	DROP_TIME = INITIAL_DROP_TIME
	horiz_dir = 0
	verti_dir = 0
	spin_dir = 0
	if reset_scores:
		my_score = 0
		opponent_score = 0
	Send_Data()

func HandleLoss() -> void:
	Network.send_game_end()
	opponent_score += 1
	nums_of_game += 1
	if opponent_score >= WIN_SCORE:
		gaming = false
		game_over.emit("lose")
	else:
		Reset(false)

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

# 新技能寫在這裡
func Skill_Seven_I() -> void:
	# 將接下來的七個方塊改成 I
	if not gaming:
		return
	while seven_bag.size() < 7:
		seven_bag += Random_Shuffle([0, 1, 2, 3, 4, 5, 6], rng.randi())
	for i in range(7):
		seven_bag[i] = 0
	Send_Data()
	
func Skill_Swap_Field() -> void:
	# 發送自己的 grid 給對手，並請求交換
	if not gaming:
		return
	var my_grid_data = []
	for y in range(ROWS):
		var row_data = []
		for x in range(COLS):
			if grid[y][x] == null: row_data.append(null)
			else: row_data.append(grid[y][x].to_html())
		my_grid_data.append(row_data)
	Network.send_swap_grid(my_grid_data)
	
func Skill_Speed_Up(duration: float, rate: float) -> void:
	if not gaming:
		return
	Network.send_speed_up(duration, rate)
	
func Skill_Blind_Top(duration: float, count: int) -> void:
	if not gaming:
		return
	Network.send_blind_top(duration, count)

func Skill_Invert_LR() -> void:
	if not gaming:
		return
	Network.send_invert_lr()

func Skill_Stop_Opponent(duration: float) -> void:
	if not gaming:
		return
	Network.send_stop_opponent(duration)
	
func Skill_Reflect(duration: float) -> void:
	if not gaming:
		return
	is_reflected = true
	reflected_timer = duration
	
func Skill_Invincible(duration: float) -> void:
	if not gaming:
		return
	is_invincible = true
	invincible_timer = duration
	
func Skill_Invert_Screen(duration: float) -> void:
	# 發送畫面顛倒給對手
	if not gaming:
		return
	Network.send_invert_screen(duration)
	
func Skill_Send_Lines(count: int) -> void:
	# 直接送給對手 count 行
	if not gaming:
		return
	var lines_to_send = max(0, count)
	if lines_to_send > 0:
		Network.send_attack(lines_to_send)

func Skill_Clear_Bottom(count: int) -> void:
	# 清除底部 count 行，不造成攻擊
	if not gaming:
		return
	var lines_to_clear = clamp(count, 1, ROWS)
	for times in range(lines_to_clear):
		for y in range(ROWS - 1, 1, -1):
			for x in range(COLS):
				grid[y][x] = grid[y - 1][x]
	Send_Data()
	
func Skill_FlashBang(duration: float) -> void:
	if not gaming:
		return
	Network.send_flashbang(duration)
	

func Skill_Hide_Next(duration: float) -> void:
	if not gaming:
		return
	Network.send_hide_next(duration)

# 處理收到交換場地請求
func _on_swap_grid_received(incoming_grid):
	# 保存自己目前的 grid
	var my_old_grid = []
	for y in range(ROWS):
		var row_data = []
		for x in range(COLS):
			if grid[y][x] == null: row_data.append(null)
			else: row_data.append(grid[y][x].to_html())
		my_old_grid.append(row_data)
	
	# 回傳自己的 grid 給對方
	Network.send_swap_grid_response(my_old_grid)
	
	# 套用對方的 grid
	for y in range(ROWS):
		for x in range(COLS):
			grid[y][x] = incoming_grid[y][x]
	Send_Data()

# 處理收到交換場地回應
func _on_swap_grid_response_received(incoming_grid):
	# 套用對方的 grid (這是發起者收到的回應)
	for y in range(ROWS):
		for x in range(COLS):
			grid[y][x] = incoming_grid[y][x]
	Send_Data()
	
func _on_speed_up_received(duration):
	is_speed_up = true
	speed_up_timer = duration
	speed_up_rate = 1.5
	
func _on_blind_top_received(duration, lines):
	is_blind_top = true
	blind_top_timer = duration
	blind_top_lines = lines
	
func _on_invert_lr_received():
	for y in range(ROWS):
		for x in range(int(COLS/2.0)):
			var temp = grid[y][x]
			grid[y][x] = grid[y][COLS - x - 1]
			grid[y][COLS - x - 1] = temp
			
func _on_freeze_received(duration):
	is_time_stop = true
	time_stop_timer = duration
	
# 處理收到畫面顛倒效果
func _on_invert_screen_received(duration):
	is_screen_inverted = true
	invert_timer = duration
	
func _on_flashbang_received(duration):
	is_flashbang = true
	flashbang_timer = duration
	flashbang_duration = duration  # 記錄總時長用於計算 alpha
	# 50% 機率顯示圖片
	show_flashbang_image = randf() < 0.5
	
func _on_hide_next_received(duration):
	is_hide_next = true
	hide_next_timer = duration

func _ready():
	print("visible:", get_viewport().get_visible_rect().size)
	print("board pos:", global_position)
	print("board scale:", global_scale)

	if ResourceLoader.exists("res://genshin.png"):
		flashbang_texture = load("res://genshin.png")
	
	Reset()
	for y in range(ROWS):
		opponent_grid.append([])
		for x in range(COLS):
			opponent_grid[y].append(null)
			
	# 監聽網路信號
	Network.opponent_grid_updated.connect(_on_opponent_grid_updated)
	Network.win_respond.connect(_on_win_respond)
	Network.attack_received.connect(_on_attack_received)
	Network.swap_grid_received.connect(_on_swap_grid_received)
	Network.swap_grid_response_received.connect(_on_swap_grid_response_received)
	Network.speed_up_received.connect(_on_speed_up_received)
	Network.blind_top_received.connect(_on_blind_top_received)
	Network.invert_lr_received.connect(_on_invert_lr_received)
	Network.freeze_received.connect(_on_freeze_received)
	Network.invert_screen_received.connect(_on_invert_screen_received)
	Network.flashbang_received.connect(_on_flashbang_received)
	Network.hide_next_received.connect(_on_hide_next_received)
	print("正在連線到伺服器...")
	if Network.socket.get_ready_state() != WebSocketPeer.STATE_OPEN:
		Network.socket.connect_to_url(Network.url)

func _process(delta):
	if gaming:
		if not is_time_stop:
			drop_timer += delta
			DROP_TIME = max(MIN_DROP_TIME, INITIAL_DROP_TIME - (lines_cleared * SPEED_DECAY)) * speed_up_rate
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
					if is_on_ground and op_times < OPERATION_LIMIT:
						lock_timer = 0.0
						op_times += 1
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
				if lock_timer > LOCK_DELAY - 0.033 * op_times:
					Lock()
				
		# 處理畫面顛倒計時
		if is_screen_inverted:
			invert_timer -= delta
			if invert_timer <= 0:
				is_screen_inverted = false
				invert_timer = 0.0
		
		if is_speed_up:
			speed_up_timer -= delta
			if speed_up_timer <= 0:
				is_speed_up = false
				speed_up_timer = 0.0
				speed_up_rate = 1.0
				
		if is_blind_top:
			blind_top_timer -= delta
			if blind_top_timer <= 0:
				is_blind_top = false
				blind_top_timer = 0.0
		
		if is_time_stop:
			time_stop_timer -= delta
			if time_stop_timer <= 0:
				is_time_stop = false
				time_stop_timer = 0.0
				
		if is_reflected:
			reflected_timer -= delta
			if reflected_timer <= 0:
				is_reflected = false
				reflected_timer = 0.0
				
		if is_invincible:
			invincible_timer -= delta
			if invincible_timer <= 0:
				is_invincible = false
				invincible_timer = 0.0
				
		if is_flashbang:
			flashbang_timer -= delta
			if flashbang_timer <= 0:
				is_flashbang = false
				flashbang_timer = 0.0
				
		if is_hide_next:
			hide_next_timer -= delta
			if hide_next_timer <= 0:
				is_hide_next = false
				hide_next_timer = 0.0
		
		Ghost()
	queue_redraw()

func _input(e):
	if gaming:
		if not is_time_stop:
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
							HandleLoss()
					is_holded = true
					Send_Data()
		
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
		HandleLoss()

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
	my_score += 1
	nums_of_game += 1
	if my_score >= WIN_SCORE:
		gaming = false
		game_over.emit("win")
	else:
		Reset(false)

func _on_attack_received(lines):
	print("Received attack: ", lines)
	if is_reflected:
		lines = int(lines / 2.0)
		Network.send_attack(lines)
	if not is_invincible:
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
