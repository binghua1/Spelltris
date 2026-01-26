extends Node

var player_name
var room_id

enum Skills {
	SEVEN_I = 0,
	SWAP_FIELD = 1,
	SPEED_UP = 2,
	BLIND_TOP = 3,
	INVERT_LR = 4,
	STOP_OPP = 5,
	REFLECT = 6,
	INVINCIBLE = 7,
	INVERT_SCR = 8,
	SEND_LINES = 9,
	CLEAR_BOT = 10,
	FLASHBANG = 11,
	HIDE_NEXT = 12
}

var skill_info = {
	Skills.SEVEN_I: {"name": "7個I", "cd": 15.0},
	Skills.SWAP_FIELD: {"name": "交換場地", "cd": 30.0},
	Skills.SPEED_UP: {"name": "對手加速", "cd": 15.0},
	Skills.BLIND_TOP: {"name": "遮擋頂部", "cd": 20.0},
	Skills.INVERT_LR: {"name": "左右顛倒", "cd": 30.0},
	Skills.STOP_OPP: {"name": "時間暫停", "cd": 25.0},
	Skills.REFLECT: {"name": "反彈攻擊", "cd": 30.0},
	Skills.INVINCIBLE: {"name": "無敵", "cd": 20.0},
	Skills.INVERT_SCR: {"name": "畫面顛倒", "cd": 30.0},
	Skills.SEND_LINES: {"name": "送行攻擊", "cd": 10.0},
	Skills.CLEAR_BOT: {"name": "消除底部", "cd": 10.0},
	Skills.FLASHBANG: {"name": "閃光彈", "cd": 15.0},
	Skills.HIDE_NEXT: {"name": "遮擋預告", "cd": 15.0}
}

var selected_skills: Array = [0, 1, 2]
