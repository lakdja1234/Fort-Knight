# PlayerData.gd
# Autoload singleton to store persistent player data.
extends Node

const SAVE_PATH = "user://parts_data.cfg"

var selected_part_path: String = "res://parts/HomingMissilePart.tres"

# --- Add equipped_parts and equip_part function ---
var equipped_parts: Array[Part] = [null, null, null] # Initialize with 3 empty slots

# New variables and functions for owning parts
var owned_part_paths: Array[String] = [] # Start with an empty list of owned parts

func _ready():
	load_parts_data()

func add_owned_part(part_path: String):
	if not owned_part_paths.has(part_path):
		owned_part_paths.append(part_path)
		print("Acquired new part: ", part_path)
		save_parts_data()
	else:
		print("Part already owned: ", part_path)


func equip_part(new_part: Part, slot_index: int):
	if slot_index < 0 or slot_index >= equipped_parts.size():
		printerr("Invalid slot_index for equip_part in PlayerData: ", slot_index)
		return
	
	equipped_parts[slot_index] = new_part
	print("Equipped part '", new_part.part_name if new_part else "None", "' into slot ", slot_index)
	save_parts_data()
	# TODO: Emit a signal here if other parts of the game need to know about equipped parts changes

func save_parts_data():
	var config = ConfigFile.new()
	
	# Save owned parts
	config.set_value("player", "owned_part_paths", owned_part_paths)
	
	# Save equipped parts by their resource paths
	var equipped_part_paths = []
	for part in equipped_parts:
		if part is Part:
			equipped_part_paths.append(part.resource_path)
		else:
			equipped_part_paths.append("") # Use an empty string for an empty slot
			
	config.set_value("player", "equipped_part_paths", equipped_part_paths)
	
	# Save the file
	var err = config.save(SAVE_PATH)
	if err == OK:
		print("Player parts data saved successfully.")
	else:
		printerr("Failed to save player parts data.")

func load_parts_data():
	var config = ConfigFile.new()
	
	if config.load(SAVE_PATH) != OK:
		print("No player parts data file found. Using defaults.")
		return

	# Load owned parts
	owned_part_paths = config.get_value("player", "owned_part_paths", [])
	
	# Load equipped parts
	var equipped_part_paths = config.get_value("player", "equipped_part_paths", ["", "", ""])
	for i in range(equipped_part_paths.size()):
		var path = equipped_part_paths[i]
		if !path.is_empty() and ResourceLoader.exists(path):
			var part_resource = load(path)
			if part_resource is Part:
				equipped_parts[i] = part_resource
			else:
				equipped_parts[i] = null
		else:
			equipped_parts[i] = null
			
	print("Player parts data loaded.")

func reset():
	equipped_parts = [null, null, null]
	owned_part_paths = []
	print("Player data reset in memory.")
