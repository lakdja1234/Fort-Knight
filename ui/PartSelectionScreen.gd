extends Control

@onready var player_preview_instance: Node2D = $PlayerPreviewPanel/SubViewportContainer/SubViewport/PlayerPreview
@onready var parts_list_container: VBoxContainer = $OwnedPartsPanel/ScrollContainer/PartsListContainer
@onready var back_button: Button = $BackButton

var slot_icon_textures: Array[TextureRect]
var slot_name_labels: Array[Label]
var slot_buttons: Array[Button]

var current_selected_slot: int = 0

func _ready():
	slot_icon_textures = [
		get_node("EquippedPartsPanel/VBoxContainer/Slot1Container/Part1Icon"), 
		get_node("EquippedPartsPanel/VBoxContainer/Slot2Container/Part2Icon"), 
		get_node("EquippedPartsPanel/VBoxContainer/Slot3Container/Part3Icon")
	]
	slot_name_labels = [
		get_node("EquippedPartsPanel/VBoxContainer/Slot1Container/Part1Name"), 
		get_node("EquippedPartsPanel/VBoxContainer/Slot2Container/Part2Name"), 
		get_node("EquippedPartsPanel/VBoxContainer/Slot3Container/Part3Name")
	]
	slot_buttons = [
		get_node("EquippedPartsPanel/VBoxContainer/Slot1Container/Slot1Button"), 
		get_node("EquippedPartsPanel/VBoxContainer/Slot2Container/Slot2Button"), 
		get_node("EquippedPartsPanel/VBoxContainer/Slot3Container/Slot3Button")
	]

	# Default to selecting slot 1 initially
	_on_slot_1_button_pressed() # This will call update_player_preview and update_equipped_parts_status

	# Initial updates
	update_owned_parts_list()
	update_equipped_parts_status() # Call this initially and after any changes
	
	# Initial player preview update
	var player_data = get_node("/root/PlayerData")
	if is_instance_valid(player_data):
		player_preview_instance.update_preview(player_data.equipped_parts)


func update_player_preview():
	var player_data = get_node("/root/PlayerData") # Assuming PlayerData is an autoload singleton
	if is_instance_valid(player_data):
		player_preview_instance.update_preview(player_data.equipped_parts)
	else:
		printerr("PlayerData autoload not found for Player Preview update!")

func update_equipped_parts_status():
	var player_data = get_node("/root/PlayerData")
	if not is_instance_valid(player_data):
		printerr("PlayerData autoload not found for Equipped Parts Status!")
		return

	for i in range(player_data.equipped_parts.size()):
		if i < slot_icon_textures.size() and i < slot_name_labels.size():
			var equipped_part = player_data.equipped_parts[i]
			var icon_tr = slot_icon_textures[i]
			var name_lbl = slot_name_labels[i]

			if equipped_part and equipped_part is Part and equipped_part.part_texture: # Ensure equipped_part is a valid Part resource
				icon_tr.texture = equipped_part.part_texture
				name_lbl.text = equipped_part.part_name
			else:
				icon_tr.texture = null
				name_lbl.text = "Empty"
		
		# Update visual feedback for the currently selected slot button (e.g., highlight)
		if i < slot_buttons.size():
			# This is a basic way to show selected state, custom styles would be better.
			slot_buttons[i].modulate = Color.WHITE if i == current_selected_slot else Color.GRAY


func update_owned_parts_list():
	var player_data = get_node_or_null("/root/PlayerData")
	if not is_instance_valid(player_data):
		printerr("PlayerData autoload not found!")
		return

	for child in parts_list_container.get_children():
		child.queue_free() # Clear existing buttons

	# Add "No Part" option to unequip
	var no_part_button = Button.new()
	no_part_button.text = "No Part (Unequip)"
	# Add style for the button
	var style = StyleBoxFlat.new()
	style.bg_color = Color(0.3, 0.3, 0.3, 1)
	style.set_border_width_all(2)
	style.border_color = Color.GRAY
	no_part_button.add_theme_stylebox_override("normal", style)
	var hover_style = style.duplicate()
	hover_style.bg_color = Color(0.4, 0.4, 0.4, 1)
	no_part_button.add_theme_stylebox_override("hover", hover_style)
	
	no_part_button.pressed.connect(Callable(self, "_on_part_selected").bind("")) # Empty string for no part
	parts_list_container.add_child(no_part_button)

	var global_owned_parts = []
	if player_data.has_method("add_owned_part"): # Check if the new data structure is available
		global_owned_parts = player_data.owned_part_paths

	for part_path in global_owned_parts:
		var part_resource = load(part_path)
		if part_resource and part_resource is Part: # Check if it's a valid Part resource
			var part_button = Button.new()
			part_button.text = part_resource.part_name
			
			var is_already_equipped = false
			for equipped_part in player_data.equipped_parts:
				if is_instance_valid(equipped_part) and equipped_part.resource_path == part_resource.resource_path:
					is_already_equipped = true
					break
			
			if is_already_equipped:
				part_button.disabled = true
				part_button.modulate = Color.DARK_GRAY # Visually indicate it's equipped/disabled
			
			# Add style for the button
			var part_style = StyleBoxFlat.new()
			part_style.bg_color = Color(0.3, 0.3, 0.3, 1)
			part_style.set_border_width_all(2)
			part_style.border_color = Color.GRAY
			part_button.add_theme_stylebox_override("normal", part_style)
			var part_hover_style = part_style.duplicate()
			part_hover_style.bg_color = Color(0.4, 0.4, 0.4, 1)
			part_button.add_theme_stylebox_override("hover", part_hover_style)
			
			if part_resource.part_texture:
				var icon = TextureRect.new()
				icon.texture = part_resource.part_texture
				icon.custom_minimum_size = Vector2(32, 32)
				icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
				icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
				part_button.add_child(icon)
			
			part_button.pressed.connect(Callable(self, "_on_part_selected").bind(part_path))
			parts_list_container.add_child(part_button)
		else:
			printerr("Failed to load or invalid Part resource at: ", part_path)


func _on_part_selected(part_resource_path: String):
	# This function will handle equipping the selected part to current_selected_slot
	var player_data = get_node("/root/PlayerData") # Assuming PlayerData is an autoload singleton
	if not is_instance_valid(player_data):
		printerr("PlayerData autoload not found!")
		return

	if part_resource_path.is_empty():
		# Unequip the part
		player_data.equip_part(null, current_selected_slot)
	else:
		var part_resource = load(part_resource_path)
		if part_resource and part_resource is Part:
			# Check if this part is already equipped in another slot
			for i in range(player_data.equipped_parts.size()):
				if i != current_selected_slot: # Check only other slots
					var equipped_part = player_data.equipped_parts[i]
					if is_instance_valid(equipped_part) and equipped_part.resource_path == part_resource.resource_path:
						printerr("PartSelectionScreen: Part '", part_resource.part_name, "' is already equipped in another slot (Slot ", i + 1, ")!")
						# Optionally, display a UI message to the user here.
						return # Prevent equipping
			
			player_data.equip_part(part_resource, current_selected_slot)
		else:
			printerr("Invalid part resource selected: ", part_resource_path)
			
	# After equipping/unequipping, refresh UI
	update_player_preview()
	update_equipped_parts_status() # Refresh equipped parts status


func _on_slot_1_button_pressed():
	current_selected_slot = 0
	print("Selected Slot: ", current_selected_slot + 1) # For debugging
	update_player_preview() # Update preview when slot selected
	update_equipped_parts_status() # Update equipped status to highlight selected slot
	# TODO: Filter owned parts list based on selected slot if needed

func _on_slot_2_button_pressed():
	current_selected_slot = 1
	print("Selected Slot: ", current_selected_slot + 1) # For debugging
	update_player_preview() # Update preview when slot selected
	update_equipped_parts_status() # Update equipped status to highlight selected slot
	# TODO: Filter owned parts list based on selected slot if needed

func _on_slot_3_button_pressed():
	current_selected_slot = 2
	print("Selected Slot: ", current_selected_slot + 1) # For debugging
	update_player_preview() # Update preview when slot selected
	update_equipped_parts_status() # Update equipped status to highlight selected slot
	# TODO: Filter owned parts list based on selected slot if needed

func _on_back_button_pressed(): # Add this function
	SceneTransition.change_scene("res://스테이지3/stage_selection.tscn")
