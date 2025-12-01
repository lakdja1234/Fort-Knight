extends Control

# This screen is specifically for the Homing Missile part.
var part_resource_path: String = "res://parts/homing_missile_part.tres" 

# Called when the user clicks the "Acquire" button.
func _on_acquire_button_pressed():
	var player_data = get_node_or_null("/root/PlayerData")
	if is_instance_valid(player_data) and player_data.has_method("add_owned_part"):
		player_data.add_owned_part(part_resource_path)

	# Use the SceneTransition autoload to go back to the stage selection screen.
	SceneTransition.change_scene("res://스테이지3/stage_selection.tscn")
	# Free the reward screen itself.
	queue_free()

