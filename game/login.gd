extends Control

func _ready():
	Network.login_success.connect(_on_login_success)


func _on_button_pressed():
	var player_name = $VBoxContainer/LineEdit.text # 注意路徑要對
	if player_name.strip_edges() != "":
		# 顯示狀態
		$VBoxContainer/Button.disabled = true # 防止重複點擊
		Global.player_name = player_name
		$VBoxContainer/Label.text = "Connecting..."
		
		# 確保連線已建立
		if Network.socket.get_ready_state() != WebSocketPeer.STATE_OPEN:
			if Network.socket.get_ready_state() == WebSocketPeer.STATE_CLOSED:
				Network.connect_to_server()
			await Network.connected_to_server
			
		Network.send_login(player_name)
			

func _on_login_success():
	get_tree().change_scene_to_file("res://lobby.tscn")
