extends Control

@onready var board := $Board

func _ready():
	board.game_over.connect(_on_game_over)
	
	$UI/GameOverUI.retry_pressed.connect(_on_retry)
	$UI/GameOverUI.lobby_pressed.connect(_on_lobby)
	
	Network.rematch_start.connect(_on_rematch_start)

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
	board.Reset(true)
	
