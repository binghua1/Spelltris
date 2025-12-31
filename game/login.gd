extends Control

func _ready():
	# 監聽 Network 的 match_found 訊號
	# 寫法解析：當 Network 發出 match_found 時，執行後面的 lambda 函式
	Network.match_found.connect(_on_match_found)

func _on_button_pressed():
	var player_name = $VBoxContainer/LineEdit.text # 注意路徑要對
	if player_name.strip_edges() != "":
		# 顯示狀態
		$VBoxContainer/Label.text = "Connecting..."
		$VBoxContainer/Button.disabled = true # 防止重複點擊
		
		# 確保連線已建立
		if Network.socket.get_ready_state() != WebSocketPeer.STATE_OPEN:
			if Network.socket.get_ready_state() == WebSocketPeer.STATE_CLOSED:
				Network.connect_to_server()
			await Network.connected_to_server
		
		# 直接發送加入請求
		Network.send_join(player_name)
		
		$VBoxContainer/Label.text = "Looking for match..."

# 當配對成功時觸發
func _on_match_found(_opp_info):
	# 切換到遊戲場景
	get_tree().change_scene_to_file("res://game.tscn")
