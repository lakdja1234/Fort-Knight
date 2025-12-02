extends Node

const SAVE_PATH = "user://keybinds.cfg"
# A list of actions that this manager will handle.
# This should ideally be the same as in KeybindScreen.gd
const MANAGED_ACTIONS = [
	"move_left", "move_right", "aim_up", "aim_down", 
	"fire", "skill_1", "skill_2", "skill_3"
]

const DEFAULT_KEYBINDS = {
	"move_left": [KEY_A],
	"move_right": [KEY_D],
	"aim_up": [KEY_UP],
	"aim_down": [KEY_DOWN],
	"fire": [KEY_SPACE],
	"skill_1": [KEY_1],
	"skill_2": [KEY_2],
	"skill_3": [KEY_3]
}

func _ready():
	load_keybinds()

func load_keybinds():
	var config = ConfigFile.new()
	var loaded_actions = []

	if config.load(SAVE_PATH) == OK:
		for action in MANAGED_ACTIONS:
			if config.has_section(action):
				loaded_actions.append(action)
				InputMap.action_erase_events(action)
				var events = config.get_value(action, "events", [])
				for event_info in events:
					if event_info is Dictionary and event_info.has("type"):
						if event_info["type"] == "InputEventKey":
							var key_event = InputEventKey.new()
							key_event.physical_keycode = event_info.get("physical_keycode", 0)
							key_event.keycode = event_info.get("keycode", 0)
							key_event.unicode = event_info.get("unicode", 0)
							key_event.echo = event_info.get("echo", false)
							InputMap.action_add_event(action, key_event)
	else:
		print("No keybinds config file found. Applying hardcoded default keybindings.")

	# For any action that was not loaded from config, apply the hardcoded default
	for action in MANAGED_ACTIONS:
		if not action in loaded_actions:
			_apply_hardcoded_default(action)

func _apply_hardcoded_default(action_name):
	InputMap.action_erase_events(action_name)
	if DEFAULT_KEYBINDS.has(action_name):
		for key_code in DEFAULT_KEYBINDS[action_name]:
			var default_event = InputEventKey.new()
			default_event.keycode = key_code
			default_event.physical_keycode = key_code
			InputMap.action_add_event(action_name, default_event)
			print("Set default keybind for ", action_name, ": ", OS.get_keycode_string(key_code))

func save_keybinds():
	var config = ConfigFile.new()
	
	for action in MANAGED_ACTIONS:
		var events_to_save = []
		var events = InputMap.action_get_events(action)
		for event in events:
			if event is InputEventKey:
				var event_info = {
					"type": "InputEventKey",
					"physical_keycode": event.physical_keycode,
					"keycode": event.keycode,
					"unicode": event.unicode,
					"echo": event.echo
				}
				events_to_save.append(event_info)
		
		config.set_value(action, "events", events_to_save)

	config.save(SAVE_PATH)
	print("Keybinds saved to: " + SAVE_PATH)

func reset_all_data():
	print("Resetting all player data...")
	
	# Path for the parts data file, defined in PlayerData.gd
	var parts_save_path = "user://parts_data.cfg"
	
	# Remove keybinds config file
	if DirAccess.remove_absolute(SAVE_PATH) == OK:
		print("Removed keybinds save file: ", SAVE_PATH)
	else:
		print("Could not remove keybinds save file (it may not exist).")
		
	# Remove parts data config file
	if DirAccess.remove_absolute(parts_save_path) == OK:
		print("Removed parts data save file: ", parts_save_path)
	else:
		print("Could not remove parts data save file (it may not exist).")

	# Reset the in-memory data for the singletons
	if get_tree().get_root().has_node("PlayerData"):
		PlayerData.reset()
	
	# Reload the keybinds to apply defaults
	load_keybinds()
	
	# Reload the entire game by going to the main menu
	# This ensures all singletons are reset and load default data.
	# Make sure the path to your main menu/entry scene is correct.
	get_tree().change_scene_to_file("res://스테이지3/title_screen.tscn")
