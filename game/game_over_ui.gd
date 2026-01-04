extends Control

signal retry_pressed
signal lobby_pressed

@onready var result_label := $Panel/VBoxContainer/WinnerLabel
@onready var status_label := $Panel/VBoxContainer/Label
@onready var retry := $Panel/VBoxContainer/Retry

func _ready():
	visible = false
	
	Network.rematch_offer.connect(_on_rematch_offer)
	Network.opponent_left.connect(_on_opponent_left)
	

func show_result(winner: String):
	visible = true
	status_label.visible = false
	retry.disabled = false
	match winner:
		"win":
			result_label.text = "You Win!"
		"lose":
			result_label.text = "You Lose"

func hide_ui():
	visible = false

func _on_retry_pressed():
	retry.disabled = true
	emit_signal("retry_pressed")

func _on_lobby_pressed():
	emit_signal("lobby_pressed")
	
func _on_rematch_offer():
	status_label.visible = true
	status_label.text = "Opponent Sent Rematch Offer"
	
func _on_opponent_left():
	status_label.visible = true
	status_label.text = "Opponent Left"
	retry.disabled = true
