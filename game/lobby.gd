extends Control

var rooms = [] # 保存所有房間 {"name": "", "host": ""}
@onready var skill_menu = $SkillSelect
@onready var open_skill_btn = $MainLayout/HBoxContainer2/SkillButton

func _ready():
	# 連接按鈕事件 (Godot 4 使用 Callable)
	$MainLayout/HBoxContainer/search_btn.connect("pressed", Callable(self, "_on_search_pressed"))
	$MainLayout/HBoxContainer2/create_room_btn.connect("pressed", Callable(self, "_on_create_room_pressed"))
	$MainLayout/HBoxContainer2/join_room_btn.connect("pressed", Callable(self, "_on_join_room_pressed"))
	$MainLayout/HBoxContainer2/create_room_btn.disabled = false
	$MainLayout/HBoxContainer2/join_room_btn.disabled = false
	
	$create_room_dialog/VBoxContainer/confirm_create_btn.connect("pressed", Callable(self, "_on_confirm_create_pressed"))
	$create_room_dialog.hide()
	
	$waiting_for_match/VBoxContainer/cancel.connect("pressed", Callable(self, "_on_cancel_room_pressed"))
	$waiting_for_match.hide()
	
	var line_height = $MainLayout/ScrollContainer/room_list.get_fixed_icon_size().y
	$MainLayout/ScrollContainer.custom_minimum_size.y = line_height * 10
	
	Network.create_success.connect(_on_create_success)
	Network.delete_success.connect(_on_delete_success)
	Network.match_found.connect(_on_match_found)
	Network.get_room_list.connect(_on_get_room_list)
	
	Network.send_room_list_request()

func _on_create_success(new_room):
	rooms.append(new_room)
	Global.room_id = new_room.get("room_id")
	_refresh_room_list()
	
func _on_delete_success(new_room_id):
	rooms = rooms.filter(func(room):
		return room.get("room_id", "") != new_room_id
	)
	_refresh_room_list()
	
func _on_match_found(room_id):
	Global.room_id = room_id
	rooms = rooms.filter(func(room):
		return room.get("room_id", "") != room_id
	)
	get_tree().change_scene_to_file("res://game.tscn")
	
func _on_get_room_list(new_rooms):
	rooms = new_rooms
	_refresh_room_list()

# === 搜尋房間 ===
func _on_search_pressed():
	var keyword = $MainLayout/HBoxContainer/search_input.text.strip_edges()
	_refresh_room_list(keyword)

# === 更新房間列表 ===
func _refresh_room_list(filter_keyword=""):
	var room_list = $MainLayout/ScrollContainer/room_list
	room_list.clear()
	
	for room in rooms:
		if filter_keyword == "" or filter_keyword.to_lower() in room.name.to_lower():
			room_list.add_item("Host: %s | Room: %s" % [room.host, room.name])
			
func _on_create_room_dialog_close_requested():
	$create_room_dialog.hide()
	
func _on_waiting_for_match_close_requested() -> void:
	Network.send_delete(Global.room_id)
	$MainLayout/HBoxContainer2/create_room_btn.disabled = false
	$MainLayout/HBoxContainer2/join_room_btn.disabled = false
	$waiting_for_match.hide()

# === 創建房間按鈕 ===
func _on_create_room_pressed():
	$create_room_dialog.popup_centered() # 彈出創房視窗
	
func _on_cancel_room_pressed():
	Network.send_delete(Global.room_id)
	$MainLayout/HBoxContainer2/create_room_btn.disabled = false
	$MainLayout/HBoxContainer2/join_room_btn.disabled = false
	$waiting_for_match.hide()

# === 確認創建房間 ===
func _on_confirm_create_pressed():
	var room_name = $create_room_dialog/VBoxContainer/room_name_input.text
	if room_name.strip_edges() != "":
		var room = {"name": room_name, "host": Global.player_name}
		Network.send_create(room)
		$create_room_dialog/VBoxContainer/room_name_input.text = ""
		$create_room_dialog.hide()
		$waiting_for_match.popup_centered()
		$MainLayout/HBoxContainer2/create_room_btn.disabled = true
		$MainLayout/HBoxContainer2/join_room_btn.disabled = true

# === 加入房間按鈕 ===
func _on_join_room_pressed():
	var room_list = $MainLayout/ScrollContainer/room_list
	var selected = room_list.get_selected_items()
	if selected.size() == 0:
		print("請先選擇一個房間")
		return
	
	var index = selected[0]
	var room = rooms[index]
	Network.send_join(room.room_id)
	print("加入房間: %s，由 %s 建立" % [room.name, room.host])


func _on_skill_button_pressed() -> void:
	skill_menu.open_menu() # 呼叫 skill_select.gd 裡面的函數

# 檢查技能是否選好 (這是守門員)
func _check_skills_ready() -> bool:
	# 檢查 Global 裡的技能數量 (假設你需要選 3 個)
	if Global.selected_skills.size() < 3:
		print("技能未完成，強制開啟選單")
		skill_menu.open_menu() # 自動打開選單
		return false # 回傳 false 代表「還沒準備好」
	return true # 回傳 true 代表「通過」
