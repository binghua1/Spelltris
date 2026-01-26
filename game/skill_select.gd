extends Control

@onready var grid_container = $VBoxContainer/GridContainer
@onready var status_label = $VBoxContainer/StatusLabel
# 請注意：如果你場景裡的按鈕叫做 "Button"，就用下面這行；如果叫 "StartButton"，請自己改一下名字
@onready var start_button = $VBoxContainer/Button 

# 暫存目前頁面選了什麼
var current_picks = []
const MAX_SLOTS = 3

func _ready():
	# 初始化時先隱藏自己
	self.hide()
	
	# 連接確認按鈕
	start_button.pressed.connect(_on_start_pressed)

# ==========================================
#  這就是你缺少的關鍵函式，Lobby 會呼叫它
# ==========================================
func open_menu():
	# 1. 把 Global 裡之前選過的技能讀進來 (這樣再次打開時，上次選的還會在)
	current_picks = Global.selected_skills.duplicate()
	
	# 2. 如果按鈕還沒生成過 (Grid 是空的)，就生成一次
	if grid_container.get_child_count() == 0:
		generate_buttons()
	
	# 3. 更新畫面顏色與文字
	update_ui()
	
	# 4. 顯示這個視窗，並移到最上層
	self.show()
	self.move_to_front()

func generate_buttons():
	# 讀取 Global 裡的資料
	for id in Global.skill_info:
		var info = Global.skill_info[id]
		
		var btn = Button.new()
		btn.text = info["name"]
		btn.custom_minimum_size = Vector2(120, 60)
		btn.set_meta("skill_id", id)
		btn.pressed.connect(_on_skill_btn_clicked.bind(btn))
		grid_container.add_child(btn)

func _on_skill_btn_clicked(btn: Button):
	var id = btn.get_meta("skill_id")
	
	if id in current_picks:
		current_picks.erase(id)
	else:
		if current_picks.size() < MAX_SLOTS:
			current_picks.append(id)
	
	update_ui()

func update_ui():
	status_label.text = "已選擇: %d / %d" % [current_picks.size(), MAX_SLOTS]
	
	for btn in grid_container.get_children():
		var id = btn.get_meta("skill_id")
		if id in current_picks:
			btn.modulate = Color(0, 1, 0) # 綠色
		else:
			btn.modulate = Color(1, 1, 1) # 白色
			
	# 如果沒選滿 3 個，禁止按下確認 (看你需求，若允許少選可拿掉這行)
	start_button.disabled = (current_picks.size() != MAX_SLOTS)

func _on_start_pressed():
	# 把選擇結果存回 Global
	Global.selected_skills = current_picks.duplicate()
	Global.selected_skills.sort()
	print("技能已儲存:", Global.selected_skills)
	
	# 隱藏視窗 (回到 Lobby)
	self.hide()
