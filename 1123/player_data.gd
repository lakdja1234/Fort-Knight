# PlayerData.gd
# Autoload singleton to store persistent player data.
extends Node

var selected_part_path: String = "res://parts/HomingMissilePart.tres"

# --- Add equipped_parts and equip_part function ---
var equipped_parts: Array[Part] = [null, null, null] # Initialize with 3 empty slots

# New variables and functions for owning parts
var owned_part_paths: Array[String] = [] # Start with an empty list of owned parts

func add_owned_part(part_path: String):
	if not owned_part_paths.has(part_path):
		owned_part_paths.append(part_path)
		print("Acquired new part: ", part_path)
	else:
		print("Part already owned: ", part_path)


func equip_part(new_part: Part, slot_index: int):
	if slot_index < 0 or slot_index >= equipped_parts.size():
		printerr("Invalid slot_index for equip_part in PlayerData: ", slot_index)
		return
	
	equipped_parts[slot_index] = new_part
	print("Equipped part '", new_part.part_name if new_part else "None", "' into slot ", slot_index)
	# TODO: Emit a signal here if other parts of the game need to know about equipped parts changes
