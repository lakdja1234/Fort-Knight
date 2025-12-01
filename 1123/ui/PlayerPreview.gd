extends Node2D

@onready var player_instance = $Player # Reference to the instantiated player scene
@onready var player_hud: CanvasLayer = player_instance.get_node("PlayerHUD")

var default_player_body_texture: Texture2D
var default_player_cannon_texture: Texture2D

func _ready():
	# Disable player's physics and input if it's not meant to be interactive in preview
	if is_instance_valid(player_instance):
		# Hide PlayerHUD elements in preview
		if is_instance_valid(player_hud):
			player_hud.visible = false
		
		if player_instance.has_method("set_physics_process"):
			player_instance.set_physics_process(false)
		if player_instance.has_method("set_process_input"):
			player_instance.set_process_input(false)
			# Optionally disable collision shapes
			var collision_shape_main = player_instance.get_node_or_null("CollisionShape2D")
			if is_instance_valid(collision_shape_main):
				collision_shape_main.disabled = true
				
			var collision_shape_hitbox = player_instance.get_node_or_null("Hitbox/CollisionShape2D")
			if is_instance_valid(collision_shape_hitbox):
				collision_shape_hitbox.disabled = true
		
		# Store default textures from the instantiated player scene
		var player_body_sprite = player_instance.find_child("Sprite2D")
		var player_cannon_sprite = player_instance.get_node("CannonPivot/CannonSprite")		
		
		if is_instance_valid(player_body_sprite):
			default_player_body_texture = player_body_sprite.texture
		else:
			printerr("PlayerPreview: Player body sprite 'Sprite2D' not found or invalid. Cannot store default body texture.")
		
		if is_instance_valid(player_cannon_sprite):
			default_player_cannon_texture = player_cannon_sprite.texture
		else:
			printerr("PlayerPreview: Player cannon sprite 'CannonPivot/CannonSprite' not found or invalid. Cannot store default cannon texture.")
	else:
		printerr("PlayerPreview: player_instance is not valid in _ready(). Check if '$Player' node exists and is properly set up.")

	# Initial update (will be called by PartSelectionScreen)
	update_preview([]) # Pass an empty array initially


func update_preview(equipped_parts: Array[Part]):
	# Ensure we have valid player and sprite nodes
	if not is_instance_valid(player_instance): 
		printerr("PlayerPreview: player_instance is not valid in update_preview(). Returning.")
		return
	
	# Reset cannon to default state
	var player_cannon_sprite = player_instance.get_node("CannonPivot/CannonSprite")
	if is_instance_valid(player_cannon_sprite):
		player_cannon_sprite.texture = default_player_cannon_texture
		player_cannon_sprite.scale = Vector2(0.5, 0.5) # Restore original scale

	# Update the part icon on the player body
	var part_in_slot_0 = equipped_parts[0] if equipped_parts.size() > 0 else null
	if player_instance.has_method("_update_part_icon_display"):
		player_instance._update_part_icon_display(part_in_slot_0)

	# The player body texture is constant
	var player_body_sprite = player_instance.find_child("Sprite2D")
	if is_instance_valid(player_body_sprite):
		player_body_sprite.texture = default_player_body_texture
