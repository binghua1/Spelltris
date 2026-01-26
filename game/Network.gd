extends Node

# 定義訊號
signal login_success()
signal match_found(room_id)
signal create_success(room)
signal delete_success(room)
signal get_room_list(rooms)
signal opponent_grid_updated(grid_data, hold, next_queue, type, cells, pos, ghost_pos) # 當收到對手盤面時發出
signal win_respond()
signal connected_to_server
signal attack_received(lines) # 收到對手攻擊行時發出
signal rematch_offer()
signal rematch_start()
signal opponent_left()
signal swap_grid_received(grid_data) # 收到交換場地請求
signal swap_grid_response_received(grid_data) # 收到交換場地回應
signal speed_up_received(duration)
signal blind_top_received(duration, lines)
signal invert_lr_received()
signal freeze_received(duration)
signal invert_screen_received(duration) # 收到畫面顛倒效果
signal flashbang_received(duration)
signal hide_next_received(duration)

var socket = WebSocketPeer.new()
var url = "wss://spelltris.onrender.com/ws"
#var url = "ws://127.0.0.1:8765"
#var url = "wss://centrolecithal-unglobular-makena.ngrok-free.dev"
var last_state = WebSocketPeer.STATE_CLOSED

func _ready():
	if OS.has_feature("debug"):
		url = "ws://127.0.0.1:8765/ws"
	connect_to_server()

func connect_to_server():
	if socket.get_ready_state() != WebSocketPeer.STATE_OPEN:
		socket.connect_to_url(url)

func _process(_delta):
	socket.poll()
	var state = socket.get_ready_state()
	
	if state == WebSocketPeer.STATE_OPEN and last_state != WebSocketPeer.STATE_OPEN:
		connected_to_server.emit()
	last_state = state
	
	if state == WebSocketPeer.STATE_OPEN:
		while socket.get_available_packet_count() > 0:
			var data = JSON.parse_string(socket.get_packet().get_string_from_utf8())
			handle_message(data)

# 通用發送函式
func send_packet(type: String, content: Dictionary):
	if socket.get_ready_state() == WebSocketPeer.STATE_OPEN:
		content["type"] = type
		socket.send_text(JSON.stringify(content))
		
func send_login(Name):
	send_packet("login", { "name": Name })
	
func send_room_list_request():
	send_packet("room_list_request", {})
	
func send_create(room):
	send_packet("create", { "room": room })
	
func send_delete(room_id):
	send_packet("delete", { "room_id": room_id })

func send_join(room_id):
	send_packet("join", { "room_id": room_id })
	
func send_game_end():
	send_packet("game_end", {})

func send_attack(lines: int):
	send_packet("attack", { "lines": lines })

func send_rematch():
	send_packet("rematch", {})
	
func send_leave():
	send_packet("leave", {})

# 交換場地：發送自己的 grid 給對手
func send_swap_grid(grid_data):
	send_packet("skill", { "skill": "swap_grid", "grid": grid_data })

# 交換場地回應：對手收到後回傳自己的 grid
func send_swap_grid_response(grid_data):
	send_packet("skill", { "skill": "swap_grid_response", "grid": grid_data })

func send_speed_up(duration: float, rate: float):
	send_packet("skill", { "skill": "speed_up", "duration": duration, "rate": rate })
	
func send_blind_top(duration: float, count: int):
	send_packet("skill", { "skill": "blind_top", "duration": duration, "lines": count})
	
func send_invert_lr():
	send_packet("skill", { "skill": "invert_lr" })
	
func send_stop_opponent(duration: float):
	send_packet("skill", { "skill": "freeze", "duration": duration })
	
# 畫面顛倒：發送給對手
func send_invert_screen(duration: float):
	send_packet("skill", { "skill": "invert_screen", "duration": duration })
	
func send_flashbang(duration: float):
	send_packet("skill", { "skill": "flashbang", "duration": duration })
	
func send_hide_next(duration: float):
	send_packet("skill", { "skill": "hide_next", "duration": duration })

# --- 【新增】發送盤面同步 ---
func send_sync(grid_data, hold, next_queue, type, cells, pos, ghost_pos):
	# grid_data 已經在 board.gd 轉成 hex string 了，直接傳
	send_packet("sync_grid", { 
		"grid": grid_data,
		"hold": hold,
		"next": next_queue,
		"tetro_type": type,
		"cells": vecarray2json(cells),
		"pos": vec2json(pos),
		"ghost_pos": vec2json(ghost_pos)
	})
	
	
func vec2json(v) -> Array:
	return [v.x, v.y]
	
func json2vec(arr) -> Vector2i:
	return Vector2i(arr[0], arr[1])

func vecarray2json(arr) -> Array:
	var out := []
	for v in arr:
		out.append([v.x, v.y])
	return out
	
func json2vecarray(arr) -> Array:
	var out := []
	for v in arr:
		out.append(Vector2i(v[0], v[1]))
	return out

# 輔助函式：將 hex string grid 轉換為 Color grid
func _convert_grid(raw_grid) -> Array:
	var converted_grid = []
	for y in range(raw_grid.size()):
		converted_grid.append([])
		for x in range(raw_grid[y].size()):
			var hex_str = raw_grid[y][x]
			if hex_str == null:
				converted_grid[y].append(null)
			else:
				converted_grid[y].append(Color(hex_str))
	return converted_grid

# 處理收到的訊息
func handle_message(data):
	match data.type:
		"login_success":
			login_success.emit()
			
		"room_list_respond":
			get_room_list.emit(data.get("rooms"))
			
		"create_success":
			create_success.emit(data.get("room"))
			
		"delete_success":
			delete_success.emit(data.get("room_id"))
			
		"match_success":
			match_found.emit(data.get("room_id"))
			
		# --- 【新增】處理對手盤面 ---
		"sync_grid":
			# 收到的是 Hex String 的二維陣列，我們需要轉回 Color 物件
			var raw_grid = data.grid
			var converted_grid = []
			
			for y in range(raw_grid.size()):
				converted_grid.append([])
				for x in range(raw_grid[y].size()):
					var hex_str = raw_grid[y][x]
					if hex_str == null:
						converted_grid[y].append(null)
					else:
						# 將字串 "#RRGGBB" 轉回 Color 物件
						converted_grid[y].append(Color(hex_str))
			
			var hold = data.get("hold")
			var next_queue = data.get("next")
			var type = data.get("tetro_type")
			var cells = json2vecarray(data.get("cells"))
			var pos = json2vec(data.get("pos"))
			var ghost_pos = json2vec(data.get("ghost_pos"))
			
			# 發出訊號給 board.gd
			opponent_grid_updated.emit(converted_grid, hold, next_queue, type, cells, pos, ghost_pos)
			
		"win_game":
			win_respond.emit()
	
		"attack":
			attack_received.emit(data.get("lines"))
			
		"skill":
			match data.skill:
				"swap_grid":
					# 收到對手的 grid，轉換為 Color 物件
					var raw_grid = data.get("grid")
					var converted_grid = _convert_grid(raw_grid)
					swap_grid_received.emit(converted_grid)
					
				"swap_grid_response":
					# 收到對手回傳的 grid
					var raw_grid = data.get("grid")
					var converted_grid = _convert_grid(raw_grid)
					swap_grid_response_received.emit(converted_grid)
					
				"speed_up":
					var duration = data.get("duration")
					var rate = data.get("rate")
					speed_up_received.emit(duration, rate)
				
				"blind_top":
					var duration = data.get("duration")
					var lines = data.get("lines")
					blind_top_received.emit(duration, lines)
					
				"invert_lr":
					invert_lr_received.emit()
					
				"freeze":
					var duration = data.get("duration")
					freeze_received.emit(duration)
					
				"invert_screen":
					var duration = data.get("duration")
					invert_screen_received.emit(duration)
					
				"flashbang":
					var duration = data.get("duration")
					flashbang_received.emit(duration)
					
				"hide_next":
					var duration = data.get("duration")
					hide_next_received.emit(duration)
			
		"rematch_offer":
			rematch_offer.emit()
			
		"rematch_start":
			rematch_start.emit()
			
		"opponent_left":
			opponent_left.emit()
	
		"error":
			print(data.message)
