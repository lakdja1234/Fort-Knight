extends Area2D

signal hit

func _ready():
	# --- Ensure visibility and light ---
	var sprite = find_child("Sprite2D", true, false) # Find sprite recursively
	if sprite:
		var mat = CanvasItemMaterial.new()
		mat.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
		sprite.material = mat

	var light = find_child("PointLight2D", true, false) # Find light recursively
	if light:
		light.enabled = true
	# --- End of fix ---

	# --- Ensure Collision Shape ---
	var collision_shape = find_child("CollisionShape2D", true, false)
	if not collision_shape:
		print("DEBUG: No CollisionShape2D found in BrightSpot. Creating one.")
		collision_shape = CollisionShape2D.new()
		var rect_shape = RectangleShape2D.new()
		rect_shape.size = Vector2(25, 25) # Set a generous collision box
		collision_shape.shape = rect_shape
		add_child(collision_shape)
	
	# Ensure collision detection is active
	self.monitoring = true
	self.monitorable = true
	# --- End of fix ---

func on_hit():
	if is_queued_for_deletion(): return
	emit_signal("hit")
	queue_free()

func _on_body_entered(body):
	if body.is_in_group("bullets"):
		on_hit()

func _on_area_entered(area):
	# Stalactites are Area2D, so we check for them here
	if area.has_method("start_fall") and area.is_falling:
		on_hit()
