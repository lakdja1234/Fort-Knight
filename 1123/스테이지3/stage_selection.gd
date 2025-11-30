extends Node2D

# Double click handling
const DOUBLE_CLICK_TIME = 300 # ms
var last_click_time_1 = 0
var last_click_time_2 = 0
var last_click_time_3 = 0

func _on_stage_1_button_gui_input(event):
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.is_pressed():
		var current_time = Time.get_ticks_msec()
		if current_time - last_click_time_1 < DOUBLE_CLICK_TIME:
			SceneTransition.change_scene("res://스테이지3/stage_1_ready.tscn")
		else:
			last_click_time_1 = current_time

func _on_stage_2_button_gui_input(event):
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.is_pressed():
		var current_time = Time.get_ticks_msec()
		if current_time - last_click_time_2 < DOUBLE_CLICK_TIME:
			SceneTransition.change_scene("res://스테이지3/stage_2_ready.tscn")
		else:
			last_click_time_2 = current_time

func _on_stage_3_button_gui_input(event):
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.is_pressed():
		var current_time = Time.get_ticks_msec()
		if current_time - last_click_time_3 < DOUBLE_CLICK_TIME:
			SceneTransition.change_scene("res://스테이지3/stage_3_ready.tscn")
		else:
			last_click_time_3 = current_time

func _on_part_selection_button_pressed():
	print("Part selection screen will be implemented here!")

