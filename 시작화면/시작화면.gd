extends Control

func _on_game_start_button_pressed():
	# Assuming SceneTransition is an autoloaded singleton
	# The path to the stage selection scene is taken from its location in the file system.
	SceneTransition.change_scene("res://스테이지3/stage_selection.tscn")
