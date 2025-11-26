# part_selection_screen.gd
extends Control

# This dictionary will hold the button node and the path to the part resource.
var part_buttons = {}

# This should be connected to the "pressed" signal of each part button.
func _on_part_button_pressed(part_path: String):
	print("Selected part: ", part_path)
	PlayerData.selected_part_path = part_path
	# Optional: Add visual feedback for selected button
	for button in part_buttons.keys():
		var path = part_buttons[button]
		if path == part_path:
			button.modulate = Color.GOLD
		else:
			button.modulate = Color.WHITE


# This should be connected to the "pressed" signal of the "Start Game" button.
func _on_start_game_button_pressed():
	# Change this to your main game scene (e.g., stage selection or first level)
	var res = get_tree().change_scene_to_file("res://스테이지2/스테이지2.tscn")
	if res != OK:
		printerr("Failed to change scene to Stage 2!")

func add_part_button(button: Button, part_path: String):
	part_buttons[button] = part_path
	button.pressed.connect(_on_part_button_pressed.bind(part_path))
