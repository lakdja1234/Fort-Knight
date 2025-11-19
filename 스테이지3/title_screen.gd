extends Node2D

@onready var press_any_key_label = $PressAnyKeyLabel
@onready var timer = $Timer

func _ready():
	timer.start()

func _unhandled_input(event):
	if event is InputEventKey and event.pressed:
		SceneTransition.change_scene("res://stage_selection.tscn")

func _on_timer_timeout():
	press_any_key_label.visible = not press_any_key_label.visible
