# player.gd (Refactored for Ammo Type Toggle)
extends CharacterBody2D

# --- Signals ---
signal game_over
signal health_updated(current_hp)
signal freeze_gauge_changed(current_value, max_value)

# --- Physics ---
var gravity = ProjectSettings.get_setting("physics/2d/default_gravity")

# --- Scene References & Part System ---
@export var bullet_scene: PackedScene

# Part System
@export var equipped_parts: Array[Part] = [null, null, null] # Array to hold Part resources for up to 3 slots
@onready var skill_slots: Array[Node2D] = [
	$SkillSlot1, # Assuming SkillSlot1, SkillSlot2, SkillSlot3 are children of Player
	$SkillSlot2,
	$SkillSlot3
]
var current_skill_nodes: Array[Node] = [null, null, null] # To hold instantiated skill nodes
var next_shot_skill_data: Dictionary = {} # Stores {scene: PackedScene, power: float, skill_node: Node}
										  # to tell fire_projectile what to use for next shot

# --- HUD & Node References ---
@onready var health_bar = $PlayerHUD/HUDContainer/PlayerInfoUI/VBoxContainer/HealthBar
@onready var charge_bar = $PlayerHUD/HUDContainer/PlayerInfoUI/VBoxContainer/ChargeBar
@onready var cooldown_timer = $CooldownTimer
@onready var cannon_pivot = $CannonPivot
@onready var fire_point = $CannonPivot/FirePoint
@onready var ice_map_layer: TileMapLayer = null # For Stage 2
@onready var background = get_node_or_null("/root/TitleMap/Background") # For Stage 3
@onready var skill_cooldown_progress_bars: Array[ProgressBar] = [
	get_node("PlayerHUD/HUDContainer/SlotUI/Slot1/ProgressBar"),
	get_node("PlayerHUD/HUDContainer/SlotUI/Slot2/ProgressBar"),
	get_node("PlayerHUD/HUDContainer/SlotUI/Slot3/ProgressBar")
]
@onready var skill_icon_textures: Array[TextureRect] = [
	get_node("PlayerHUD/HUDContainer/SlotUI/Slot1/TextureRect"),
	get_node("PlayerHUD/HUDContainer/SlotUI/Slot2/TextureRect"),
	get_node("PlayerHUD/HUDContainer/SlotUI/Slot3/TextureRect")
]
@onready var part_icon_sprite: Sprite2D = $PartIconSprite

# --- Movement Variables ---
const SPEED_ORIGINAL = 400.0
const ACCELERATION_NORMAL_ORIGINAL = 1000.0
const ACCELERATION_ICE_ORIGINAL = 500.0
const FRICTION_NORMAL = 1000.0
const FRICTION_ICE = 0.001
var current_speed = SPEED_ORIGINAL
var current_accel_normal = ACCELERATION_NORMAL_ORIGINAL
var current_accel_ice = ACCELERATION_ICE_ORIGINAL
var is_on_ice = false
var current_floor_type: String = "NORMAL"

# --- Aiming Variables ---
const AIM_SPEED = 2.0

# --- Firing System Variables ---
const MIN_FIRE_POWER = 500.0
const MAX_FIRE_POWER = 2000.0
const CHARGE_RATE = 1000.0
const COOLDOWN_DURATION = 2.0
var is_charging = false
var current_power = MIN_FIRE_POWER
var can_fire = true

# --- Player Stats ---
var max_hp = 100
var hp = max_hp

# --- Stage 2 Specific Exportable Settings ---
@export var player_explosion_radius: float = 100.0
@export var player_projectile_scale: Vector2 = Vector2(1.0, 1.0)

# --- HUD Color Variables ---
const CHARGE_COLOR = Color("orange")
const COOLDOWN_COLOR = Color.RED
const HEALTH_FULL_COLOR = Color.GREEN
const HEALTH_EMPTY_COLOR = Color.RED

# --- Freeze Gauge Variables (for Stage 2) ---
var max_freeze_gauge: float = 100.0
var current_freeze_gauge: float = 0.0
const FREEZE_RATE_ICE: float = 7.0
const FREEZE_RATE_MELTED: float = 2.0
var warm_rate: float = 20.0
var is_warming_up: bool = false
var is_frozen: bool = false

# --- Misc ---
var bullet_path_points = []
const BULLET_PATH_DURATION = 2.0


# ==============================================================================
#  CORE FUNCTIONS
# ==============================================================================

func _ready():
	add_to_group("player")
	
	# --- HUD Initialization ---
	if health_bar:
		health_bar.max_value = max_hp
		update_health_bar()
	if charge_bar:
		setup_bar_for_charging()
	
	# --- Stage 2 Specific Initialization ---
	ice_map_layer = get_tree().get_first_node_in_group("ground_tilemap")
	if ice_map_layer != null:
		# Only emit freeze gauge signal if the ice map exists
		emit_signal("freeze_gauge_changed", current_freeze_gauge, max_freeze_gauge)
	
	# Emit health for any listening UIs
	emit_signal("health_updated", hp)
	
	# --- Part System Initialization ---
	var player_data = get_node_or_null("/root/PlayerData")
	if is_instance_valid(player_data):
		# Overwrite the inspector-defined parts with the globally selected parts
		for i in range(player_data.equipped_parts.size()):
			if i < equipped_parts.size():
				equipped_parts[i] = player_data.equipped_parts[i]
				
	for i in range(equipped_parts.size()):
		equip_part(equipped_parts[i], i)
	_update_part_icon_display(equipped_parts[0])

	

func _physics_process(delta):
	# --- Skill Activation ---
	if Input.is_action_just_pressed("skill_1"):
		if is_instance_valid(current_skill_nodes[0]):
			current_skill_nodes[0].activate()
	if Input.is_action_just_pressed("skill_2"):
		if is_instance_valid(current_skill_nodes[1]):
			current_skill_nodes[1].activate()
	if Input.is_action_just_pressed("skill_3"):
		if is_instance_valid(current_skill_nodes[2]):
			current_skill_nodes[2].activate()	
	# --- Gravity ---
	if not is_on_floor():
		velocity.y += gravity * delta

	# --- Stage 2: Floor Type Check & Freeze Gauge Update ---
	if is_instance_valid(ice_map_layer):
		# Check floor type for ice physics
		if ice_map_layer.has_method("get_player_floor_type"):
			current_floor_type = ice_map_layer.get_player_floor_type(self)
			is_on_ice = (current_floor_type == "ICE")
		else:
			is_on_ice = false
		# Update freeze gauge
		update_freeze_gauge(delta)
	else:
		is_on_ice = false

	# --- Movement ---
	var direction = Input.get_axis("move_left", "move_right")
	var accel = ACCELERATION_NORMAL_ORIGINAL
	var friction = FRICTION_NORMAL
	var speed = SPEED_ORIGINAL

	# Apply debuffs if frozen
	if is_frozen:
		speed = SPEED_ORIGINAL * 0.5
		accel = ACCELERATION_NORMAL_ORIGINAL * 0.5

	# Apply ice physics if on ice
	if is_on_ice:
		if is_frozen: # Apply ice debuff multiplier
			accel = ACCELERATION_ICE_ORIGINAL * 0.5
		else:
			accel = ACCELERATION_ICE_ORIGINAL
		friction = FRICTION_ICE

	# Apply movement
	if direction:
		velocity.x = move_toward(velocity.x, direction * speed, accel * delta)
	else:
		velocity.x = move_toward(velocity.x, 0.0, friction * delta)
	
	move_and_slide()

	# --- Aiming ---
	var aim_direction = Input.get_axis("aim_up", "aim_down")
	if cannon_pivot:
		cannon_pivot.rotation += aim_direction * AIM_SPEED * delta
		cannon_pivot.rotation = clamp(cannon_pivot.rotation, -PI, 0.0)
	
	# --- Firing & Cooldown ---
	if can_fire:
		if Input.is_action_just_pressed("fire"):
			is_charging = true
			current_power = MIN_FIRE_POWER
			if charge_bar: charge_bar.value = current_power
		if is_charging and Input.is_action_pressed("fire"):
			current_power = min(current_power + CHARGE_RATE * delta, MAX_FIRE_POWER)
			if charge_bar: charge_bar.value = current_power
		if is_charging and Input.is_action_just_released("fire"):
			is_charging = false
			can_fire = false 
			fire_bullet(current_power)
			if cooldown_timer: 
				cooldown_timer.start()
				setup_bar_for_cooldown()
	elif charge_bar and cooldown_timer:
		charge_bar.value = cooldown_timer.time_left

	# --- Stage 3: Shader Update ---
	if is_instance_valid(background) and background.material:
		update_shader_lights()


# ==============================================================================
#  ACTION FUNCTIONS
# ==============================================================================

func equip_part(new_part: Part, slot_index: int):
	# Ensure slot_index is valid
	if slot_index < 0 or slot_index >= skill_slots.size():
		printerr("Invalid slot_index for equip_part: ", slot_index)
		return

	var target_slot_node = skill_slots[slot_index]
	var current_skill_node_in_slot = current_skill_nodes[slot_index]

	# Clear any existing skill from the slot
	if is_instance_valid(current_skill_node_in_slot):
		current_skill_node_in_slot.queue_free()
		current_skill_nodes[slot_index] = null

	equipped_parts[slot_index] = new_part
	
	if slot_index == 0:
		_update_part_icon_display(equipped_parts[0])
	
	# Handle icon display
	if slot_index < skill_icon_textures.size() and is_instance_valid(skill_icon_textures[slot_index]):
		if is_instance_valid(new_part) and is_instance_valid(new_part.part_texture):
			skill_icon_textures[slot_index].texture = new_part.part_texture
			skill_icon_textures[slot_index].visible = true
		else:
			skill_icon_textures[slot_index].texture = null
			skill_icon_textures[slot_index].visible = false # Hide icon if no part or texture

	# If the new part is valid and has a scene, instantiate it
	if is_instance_valid(new_part) and new_part.skill_scene:
		var skill_instance = new_part.skill_scene.instantiate()
		target_slot_node.add_child(skill_instance)
		current_skill_nodes[slot_index] = skill_instance
		# print("Equipped part '", new_part.part_name, "' into slot ", slot_index) # Optional: for debugging

		# Connect skill signals for UI feedback (e.g., cooldown progress bars)
		if skill_instance.has_signal("cooldown_started"):
			skill_instance.cooldown_started.connect(Callable(self, "_on_skill_cooldown_started").bind(slot_index))
		if skill_instance.has_signal("cooldown_progress"):
			skill_instance.cooldown_progress.connect(Callable(self, "_on_skill_cooldown_progress").bind(slot_index))
		if skill_instance.has_signal("cooldown_finished"):
			skill_instance.cooldown_finished.connect(Callable(self, "_on_skill_cooldown_finished").bind(slot_index))
	#else:
		# print("Equipped an empty part or part with no scene into slot ", slot_index) # Optional: for debugging
		pass

func _update_part_icon_display(part_resource: Part):
	if not is_instance_valid(part_icon_sprite):
		printerr("PartIconSprite (Sprite2D) is not valid!")
		return
	
	if is_instance_valid(part_resource) and is_instance_valid(part_resource.part_texture):
		part_icon_sprite.texture = part_resource.part_texture
		part_icon_sprite.visible = true
	else:
		part_icon_sprite.texture = null
		part_icon_sprite.visible = false


func set_next_projectile(projectile_scene: PackedScene, power: float, skill_node: Node):
	next_shot_skill_data = {
		"scene": projectile_scene,
		"power": power,
		"skill_node": skill_node # Store reference to the skill node
	}
	# print("Next projectile set by ", skill_node.name) # Optional: for debugging


func fire_projectile(projectile_scene: PackedScene, power: float):
	if not projectile_scene:
		printerr("Player cannot fire: projectile_scene is not set!")
		return

	var bullet = projectile_scene.instantiate()
	get_parent().add_child(bullet)
	
	# --- Set the current stage on the bullet so it knows which explosion to use ---
	if bullet.has_method("set_current_stage"):
		var current_scene_path = get_tree().current_scene.scene_file_path
		bullet.set_current_stage(current_scene_path)

	# --- Primary Bullet Specific Setup (Collision Layer/Mask) ---
	if projectile_scene == bullet_scene: # Check if this is the primary bullet
		bullet.set_collision_layer_value(3, true)
		bullet.collision_mask = (1 << 0) | (1 << 3) | (1 << 7) | (1 << 31)

	# --- Set projectile properties based on the current stage ---
	if bullet.has_method("set_explosion_radius"):
		if get_tree().current_scene.scene_file_path.contains("스테이지2"):
			bullet.set_explosion_radius(player_explosion_radius)
		else:
			bullet.set_explosion_radius(1.0)
			
	if bullet.has_method("set_projectile_scale"):
		# Make homing missile bigger, a bit of a hack but preserves old behavior
		if projectile_scene.resource_path.contains("homing"):
			bullet.set_projectile_scale(Vector2(2.0, 2.0))
		else:
			bullet.set_projectile_scale(player_projectile_scale) # Default scale for primary bullets
	
	# This works for both S2 and S3 bullets as long as they have the methods.
	if bullet.has_method("set_shooter"):
		bullet.set_shooter(self)
	# S3 bullets use owner_node instead of a setter
	if "owner_node" in bullet:
		bullet.owner_node = self
	
	# Fire the bullet
	bullet.global_position = fire_point.global_position
	bullet.global_rotation = cannon_pivot.global_rotation
	bullet.linear_velocity = bullet.transform.x * power


func fire_bullet(power: float): # Name remains fire_bullet as per user request
	var projectile_scene_to_use: PackedScene
	var projectile_power_to_use: float
	var skill_node_that_fired: Node = null

	if not next_shot_skill_data.is_empty() and is_instance_valid(next_shot_skill_data["skill_node"]):
		# Use skill's projectile and power
		projectile_scene_to_use = next_shot_skill_data["scene"]
		projectile_power_to_use = next_shot_skill_data["power"]
		skill_node_that_fired = next_shot_skill_data["skill_node"]
		next_shot_skill_data = {} # Clear the skill shot data after use
		
		# Notify the skill node that its projectile has been fired
		if is_instance_valid(skill_node_that_fired) and skill_node_that_fired.has_method("_on_shot_fired"):
			skill_node_that_fired._on_shot_fired()
	else:
		# Use primary weapon's projectile and charged power
		projectile_scene_to_use = bullet_scene
		projectile_power_to_use = power

	if not projectile_scene_to_use:
		printerr("Player cannot fire: No projectile scene set for primary weapon or skill!")
		return
	
	fire_projectile(projectile_scene_to_use, projectile_power_to_use)


func take_damage(amount):
	hp = max(hp - amount, 0)
	
	if health_bar:
		update_health_bar()
	emit_signal("health_updated", hp)
	
	# Blink effect
	var tween = create_tween().set_loops(2)
	tween.tween_property(self, "modulate", Color.RED, 0.15)
	tween.tween_property(self, "modulate", Color.WHITE, 0.15)
	
	if hp <= 0:
		await tween.finished
		emit_signal("game_over")
		queue_free()


# --- Skill Cooldown UI Handlers ---
func _on_skill_cooldown_started(duration: float, slot_index: int):
	if slot_index < 0 or slot_index >= skill_cooldown_progress_bars.size(): return
	var progress_bar = skill_cooldown_progress_bars[slot_index]
	if is_instance_valid(progress_bar):
		progress_bar.max_value = duration
		progress_bar.value = duration
		progress_bar.visible = true

func _on_skill_cooldown_progress(time_left: float, slot_index: int):
	if slot_index < 0 or slot_index >= skill_cooldown_progress_bars.size(): return
	var progress_bar = skill_cooldown_progress_bars[slot_index]
	if is_instance_valid(progress_bar):
		progress_bar.value = time_left

func _on_skill_cooldown_finished(slot_index: int):
	if slot_index < 0 or slot_index >= skill_cooldown_progress_bars.size(): return
	var progress_bar = skill_cooldown_progress_bars[slot_index]
	if is_instance_valid(progress_bar):
		progress_bar.value = 0
		progress_bar.visible = false # Hide when cooldown is finished
# ==============================================================================
#  HUD AND VISUALS
# ==============================================================================

func update_health_bar():
	if not health_bar: return
	health_bar.value = hp
	var health_ratio = float(hp) / float(max_hp)
	var current_color = HEALTH_FULL_COLOR.lerp(HEALTH_EMPTY_COLOR, 1.0 - health_ratio)
	
	var stylebox_original = health_bar.get_theme_stylebox("fill")
	if stylebox_original:
		var stylebox_copy = stylebox_original.duplicate()
		stylebox_copy.bg_color = current_color
		health_bar.add_theme_stylebox_override("fill", stylebox_copy)

func setup_bar_for_charging():
	if not charge_bar: return
	charge_bar.fill_mode = ProgressBar.FILL_BEGIN_TO_END
	charge_bar.min_value = MIN_FIRE_POWER
	charge_bar.max_value = MAX_FIRE_POWER
	charge_bar.value = MIN_FIRE_POWER
	
	var stylebox_original = charge_bar.get_theme_stylebox("fill")
	if stylebox_original:
		var stylebox_copy = stylebox_original.duplicate()
		stylebox_copy.bg_color = CHARGE_COLOR
		charge_bar.add_theme_stylebox_override("fill", stylebox_copy)

func setup_bar_for_cooldown():
	if not charge_bar or not cooldown_timer: return
	charge_bar.fill_mode = ProgressBar.FILL_BEGIN_TO_END
	charge_bar.min_value = 0.0
	charge_bar.max_value = COOLDOWN_DURATION
	charge_bar.value = COOLDOWN_DURATION
	
	var stylebox_original = charge_bar.get_theme_stylebox("fill")
	if stylebox_original:
		var stylebox_copy = stylebox_original.duplicate()
		stylebox_copy.bg_color = COOLDOWN_COLOR
		charge_bar.add_theme_stylebox_override("fill", stylebox_copy)


func update_shader_lights():
	var light_positions = []
	light_positions.append(background.to_local(global_position))
	var bullets = get_tree().get_nodes_in_group("bullets")
	for bullet in bullets:
		bullet_path_points.append({"position": background.to_local(bullet.global_position), "timestamp": Time.get_ticks_msec()})

	var current_time = Time.get_ticks_msec()
	bullet_path_points = bullet_path_points.filter(func(point):
		return current_time - point.timestamp < BULLET_PATH_DURATION * 1000
	)
	bullet_path_points.sort_custom(func(a, b): return a.timestamp > b.timestamp)

	var max_points = 127
	var points_to_add = bullet_path_points.slice(0, min(bullet_path_points.size(), max_points))

	for point in points_to_add:
		light_positions.append(point.position)

	background.material.set_shader_parameter("light_positions", light_positions)
	background.material.set_shader_parameter("light_count", light_positions.size())

# ==============================================================================
#  SIGNAL CALLBACKS
# ==============================================================================

func _on_cooldown_timer_timeout():
	can_fire = true
	setup_bar_for_charging()

func _on_hitbox_body_entered(body):
	if body.is_in_group("bullets"):
		# Make sure it's not the player's own bullet
		if "shooter" in body and body.shooter == self:
			return
		if "owner_node" in body and body.owner_node == self:
			return

		take_damage(10) # Assume all enemy bullets deal 10 damage
		if body.has_method("explode"):
			body.explode()
		else:
			body.queue_free()

func _on_hitbox_area_entered(area):
	if area.is_in_group("stalactites") and area.is_falling:
		take_damage(20)

# ==============================================================================
#  STAGE 2 SPECIFIC FUNCTIONS
# ==============================================================================

func update_freeze_gauge(delta: float):
	if is_warming_up:
		current_freeze_gauge = max(current_freeze_gauge - warm_rate * delta, 0.0)
	elif current_floor_type == "ICE":
		current_freeze_gauge = min(current_freeze_gauge + FREEZE_RATE_ICE * delta, max_freeze_gauge)
	elif current_floor_type == "MELTED":
		current_freeze_gauge = min(current_freeze_gauge + FREEZE_RATE_MELTED * delta, max_freeze_gauge)
	
	emit_signal("freeze_gauge_changed", current_freeze_gauge, max_freeze_gauge)
	
	if current_freeze_gauge >= max_freeze_gauge and not is_frozen:
		is_frozen = true
		apply_freeze_debuff(true)
	elif current_freeze_gauge == 0 and is_frozen:
		is_frozen = false
		apply_freeze_debuff(false)

func apply_freeze_debuff(frozen: bool):
	if frozen:
		pass # print("!!! 얼어붙음! 기동력 저하 !!!")
	else:
		pass # print("!!! 해동됨! 기동력 복구 !!!")
	# The actual speed change is handled in _physics_process now

func start_warming_up():
	is_warming_up = true

func stop_warming_up():
	is_warming_up = false
