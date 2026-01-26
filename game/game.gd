extends Control

@onready var board := $Board

@onready var skill_slots = [
	$UI/SkillContainer/Slot1,
	$UI/SkillContainer/Slot2,
	$UI/SkillContainer/Slot3
]

# 記錄每個欄位的冷卻時間 [剩餘時間1, 剩餘時間2, 剩餘時間3]
var current_cooldowns = [0.0, 0.0, 0.0]
# 記錄每個欄位的最大冷卻時間 (從 Global 讀取)
var max_cooldowns = [0.0, 0.0, 0.0]
# 記錄欄位對應的技能 ID
var slot_skill_ids = []

func _ready():
	# 原本的邏輯
	board.game_over.connect(_on_game_over)
	$UI/GameOverUI.retry_pressed.connect(_on_retry)
	$UI/GameOverUI.lobby_pressed.connect(_on_lobby)
	Network.rematch_start.connect(_on_rematch_start)
	
	# === 新增：初始化技能 UI ===
	_setup_skills()

# === 新增：每一幀處理冷卻時間顯示 ===
func _process(delta):
	for i in range(3):
		if current_cooldowns[i] > 0:
			current_cooldowns[i] -= delta # 扣除時間
			
			# 更新 UI 顯示數字
			var slot = skill_slots[i]
			slot.get_node("CDLabel").text = "%.1f" % current_cooldowns[i]
			
			# 如果倒數結束
			if current_cooldowns[i] <= 0:
				current_cooldowns[i] = 0
				_update_slot_visual(i, false) # 取消冷卻狀態顯示

# === 新增：按鍵輸入偵測 ===
func _input(event):
	# 只有按下按鍵的那一瞬間觸發，且不是長按 (echo)
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_Q:
			_try_use_skill(0)
		elif event.keycode == KEY_W:
			_try_use_skill(1)
		elif event.keycode == KEY_E:
			_try_use_skill(2)

# === 新增：初始化技能資料 ===
func _setup_skills():
	# 確保 Global 有選擇技能，沒有的話就防呆
	if Global.selected_skills.size() < 3:
		print("警告：技能未選滿，可能導致錯誤")
		return

	slot_skill_ids = Global.selected_skills
	
	for i in range(3):
		var skill_id = slot_skill_ids[i]
		var info = Global.skill_info[skill_id]
		
		# 設定最大冷卻時間
		max_cooldowns[i] = info["cd"]
		
		# 設定 UI 名稱
		var slot = skill_slots[i]
		slot.get_node("NameLabel").text = info["name"]
		
		# 確保一開始沒有冷卻遮罩
		_update_slot_visual(i, false)

# === 新增：嘗試使用技能 ===
func _try_use_skill(slot_index):
	# 1. 檢查索引是否合法
	if slot_index >= slot_skill_ids.size(): return
	
	# 2. 檢查是否正在冷卻中
	if current_cooldowns[slot_index] > 0:
		print("技能冷卻中！剩餘:", current_cooldowns[slot_index])
		return

	# 3. 觸發技能 (這裡先只印出文字，之後你在這寫效果)
	var skill_id = slot_skill_ids[slot_index]
	var skill_name = Global.skill_info[skill_id]["name"]
	print(">>> 發動技能 (Slot %d): %s" % [slot_index, skill_name])

	# 新技能寫在這裡
	match skill_id:
		Global.Skills.SEVEN_I:
			board.Skill_Seven_I()
		Global.Skills.SWAP_FIELD:
			board.Skill_Swap_Field()
		Global.Skills.SPEED_UP:
			board.Skill_Speed_Up(10.0, 0.5)
		Global.Skills.BLIND_TOP:
			board.Skill_Blind_Top(10.0, 3)
		Global.Skills.INVERT_LR:
			board.Skill_Invert_LR()
		Global.Skills.STOP_OPP:
			board.Skill_Stop_Opponent(5.0)
		Global.Skills.REFLECT:
			board.Skill_Reflect(5.0)
		Global.Skills.INVINCIBLE:
			board.Skill_Invincible(5.0)
		Global.Skills.INVERT_SCR:
			board.Skill_Invert_Screen(10.0) 
		Global.Skills.SEND_LINES:
			board.Skill_Send_Lines(3)
		Global.Skills.CLEAR_BOT:
			board.Skill_Clear_Bottom(3)
		Global.Skills.FLASHBANG:
			board.Skill_FlashBang(12.0)
		Global.Skills.HIDE_NEXT:
			board.Skill_Hide_Next(10.0)
		_:
			pass
	
	# 4. 開始冷卻
	current_cooldowns[slot_index] = max_cooldowns[slot_index]
	_update_slot_visual(slot_index, true)

# === 新增：更新 UI 遮罩狀態 ===
func _update_slot_visual(index, is_cooling_down):
	var slot = skill_slots[index]
	var mask = slot.get_node("CDMask")
	var label = slot.get_node("CDLabel")
	
	if is_cooling_down:
		mask.visible = true
		label.visible = true
	else:
		mask.visible = false
		label.visible = false

# --- 以下是你原本的程式碼，保持不變 ---

func _on_game_over(game_status):
	$UI/GameOverUI.show_result(game_status)

func _on_retry():
	$UI/GameOverUI/Panel/VBoxContainer/Label.visible = true
	$UI/GameOverUI/Panel/VBoxContainer/Label.text = "Waiting for Opponent"
	Network.send_rematch()

func _on_lobby():
	Network.send_leave()
	get_tree().change_scene_to_file("res://lobby.tscn")
	
func _on_rematch_start():
	$UI/GameOverUI.hide_ui()
	# 重置時重置技能冷卻
	current_cooldowns = [0.0, 0.0, 0.0]
	for i in range(3):
		_update_slot_visual(i, false)
		
	board.Reset(true)
