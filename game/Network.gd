extends Node

# 定義訊號
signal login_success()
signal match_found(room_id)
signal create_success(rooms)
signal opponent_grid_updated(grid_data, hold, next_queue, type, cells, pos, ghost_pos) # 當收到對手盤面時發出
signal win_respond()
signal connected_to_server

var socket = WebSocketPeer.new()
var url = "wss://spelltris.onrender.com/ws"
#var url = "ws://127.0.0.1:8765"
#var url = "wss://centrolecithal-unglobular-makena.ngrok-free.dev"
var last_state = WebSocketPeer.STATE_CLOSED

func _ready():
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
	
func send_create(room):
	send_packet("create", { "room": room })

func send_join(room_id):
	send_packet("join", { "room_id": room_id })
	
func send_game_end():
	send_packet("game_end", {})

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

# 處理收到的訊息
func handle_message(data):
	match data.type:
		"login_success":
			login_success.emit()
			
		"create_success":
			create_success.emit(data.get("room"))
			
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
	
		"error":
			print(data.message)
