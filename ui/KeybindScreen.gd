extends Control

# A variable to store the action we are currently rebinding
var action_to_rebind = ""
# A dictionary to hold the references to the buttons for each action
var action_buttons = {}

func _ready():
	set_process_input(true)
	
	# Manually populate the action_buttons dictionary
	action_buttons = {
		"move_left": $Panel/ScrollContainer/ActionList/HBox_MoveLeft/Button_MoveLeft,
		"move_right": $Panel/ScrollContainer/ActionList/HBox_MoveRight/Button_MoveRight,
		"aim_up": $Panel/ScrollContainer/ActionList/HBox_AimUp/Button_AimUp,
		"aim_down": $Panel/ScrollContainer/ActionList/HBox_AimDown/Button_AimDown,
		"fire": $Panel/ScrollContainer/ActionList/HBox_Fire/Button_Fire,
		"skill_1": $Panel/ScrollContainer/ActionList/HBox_Skill1/Button_Skill1,
		"skill_2": $Panel/ScrollContainer/ActionList/HBox_Skill2/Button_Skill2,
		"skill_3": $Panel/ScrollContainer/ActionList/HBox_Skill3/Button_Skill3
	}
	
	_update_all_button_texts()

func _update_all_button_texts():
	for action in action_buttons.keys():
		var events = InputMap.action_get_events(action)
		if events.size() > 0 and events[0] is InputEventKey:
			action_buttons[action].text = OS.get_keycode_string(events[0].get_physical_keycode_with_modifiers())
		else:
			action_buttons[action].text = "Not bound"

func _start_rebinding(action):
	if action_to_rebind != "":
		# If we were already rebinding, reset the text of the old button
		_update_all_button_texts()

	action_to_rebind = action
	if action_buttons.has(action):
		action_buttons[action].text = "Press a key..."

func _input(event):
	if action_to_rebind != "" and event is InputEventKey and event.is_pressed():
		get_viewport().set_input_as_handled()
		
		InputMap.action_erase_events(action_to_rebind)
		InputMap.action_add_event(action_to_rebind, event)
		
		var button_text = OS.get_keycode_string(event.get_physical_keycode_with_modifiers())
		action_buttons[action_to_rebind].text = button_text
		
		action_to_rebind = ""

# --- Signal Handlers for each button ---

func _on_Button_MoveLeft_pressed():
	_start_rebinding("move_left")

func _on_Button_MoveRight_pressed():
	_start_rebinding("move_right")

func _on_Button_AimUp_pressed():
	_start_rebinding("aim_up")

func _on_Button_AimDown_pressed():
	_start_rebinding("aim_down")

func _on_Button_Fire_pressed():
	_start_rebinding("fire")

func _on_Button_Skill1_pressed():
	_start_rebinding("skill_1")

func _on_Button_Skill2_pressed():
	_start_rebinding("skill_2")

func _on_Button_Skill3_pressed():
	_start_rebinding("skill_3")

func _on_back_button_pressed():
	SettingsManager.save_keybinds()
	SceneTransition.change_scene("res://ui/OptionScreen.tscn")
