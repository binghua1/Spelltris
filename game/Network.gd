extends Node

# 定義訊號
signal match_found(opponent_info)
signal opponent_grid_updated(grid_data, hold, next_queue) # 當收到對手盤面時發出
signal connected_to_server

var socket = WebSocketPeer.new()
var url = "ws://127.0.0.1:8765"
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

# 發送加入請求
func send_join(name):
	send_packet("join", { "name": name })

# --- 【新增】發送盤面同步 ---
func send_sync(grid_data, hold, next_queue):
	# grid_data 已經在 board.gd 轉成 hex string 了，直接傳
	send_packet("sync_grid", { 
		"grid": grid_data,
		"hold": hold,
		"next": next_queue
	})

# 處理收到的訊息
func handle_message(data):
	match data.type:
		"match_success":
			match_found.emit(data)
			
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
			
			# 發出訊號給 board.gd
			opponent_grid_updated.emit(converted_grid, hold, next_queue)
