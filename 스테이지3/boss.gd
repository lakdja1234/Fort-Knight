extends StaticBody2D

@export var bullet_scene: PackedScene
@export var hitbox_indicator_scene: PackedScene

const ProjectileScene = preload("res://스테이지3/Bullet.tscn") # 보스 포탄 씬
const WarningScene = preload("res://스테이지3/HitboxIndicator.tscn") # 경고 표시 씬
const BrightSpotScene = preload("res://스테이지3/BrightSpot.tscn")

var max_hp = 300
var hp = 300
var in_gimmick_50 = false
var in_gimmick_30 = false
var has_gimmick_50_triggered = false
var has_gimmick_30_triggered = false

const PROJECTILE_SPEED = 600.0
const WARNING_DURATION = 1.5
const EXPLOSION_RADIUS = 100.0 # 보스 공격의 폭발 반경 (임의로 100으로 설정)

@onready var health_bar = $HealthBar
@onready var fire_point = $FirePoint
@onready var attack_timer = $AttackTimer
@onready var gimmick_50_timer = Timer.new()
@onready var regen_timer = Timer.new()
@onready var gimmick_30_timer = Timer.new()
@onready var heal_pause_timer = Timer.new()

var player: CharacterBody2D = null

# Custom Health Bar UI Nodes
var health_bar_bg: ColorRect
var health_bar_fg: ColorRect
var health_bar_label: Label


func _ready():
	add_to_group("boss")
	randomize()
	
	# --- Custom Health Bar Setup on a new CanvasLayer ---
	var health_bar_canvas = CanvasLayer.new()
	add_child(health_bar_canvas)

	var bar_width = 400
	var bar_height = 60 # Increased height
	# Use get_viewport_rect() to be compatible with any screen resolution
	var screen_width = get_viewport_rect().size.x
	var position_x = (screen_width - bar_width) / 2
	var position_y = 40 # Moved further down

	health_bar_bg = ColorRect.new()
	health_bar_bg.position = Vector2(position_x, position_y)
	health_bar_bg.size = Vector2(bar_width, bar_height)
	health_bar_bg.color = Color(0.2, 0.2, 0.2, 0.3) # Made even more transparent
	health_bar_canvas.add_child(health_bar_bg)
	
	health_bar_fg = ColorRect.new()
	health_bar_fg.color = Color(0.2, 0.8, 0.2, 0.3) # Made even more transparent
	health_bar_bg.add_child(health_bar_fg) # Add as child of BG
	
	health_bar_label = Label.new()
	health_bar_label.text = "Driller"
	health_bar_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	health_bar_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	health_bar_label.size = health_bar_bg.size
	health_bar_bg.add_child(health_bar_label)
	# --- End Custom Health Bar Setup ---
	
	health_bar.max_value = max_hp
	health_bar.value = hp
	update_custom_health_bar() # Update the new bar
	
	if attack_timer:		attack_timer.connect("timeout", Callable(self, "_on_attack_timer_timeout"))
	else:
		printerr("Boss: AttackTimer node not found!")
	
	gimmick_50_timer.wait_time = 15
	gimmick_50_timer.one_shot = true
	gimmick_50_timer.connect("timeout", Callable(self, "_on_gimmick_50_timer_timeout"))
	add_child(gimmick_50_timer)
	
	regen_timer.wait_time = 1
	regen_timer.connect("timeout", Callable(self, "_on_regen_timer_timeout"))
	add_child(regen_timer)
	
	gimmick_30_timer.wait_time = 3
	gimmick_30_timer.connect("timeout", Callable(self, "_on_gimmick_30_timer_timeout"))
	gimmick_30_timer.one_shot = false
	add_child(gimmick_30_timer)

	heal_pause_timer.wait_time = 3
	heal_pause_timer.one_shot = true
	heal_pause_timer.connect("timeout", Callable(self, "_on_heal_pause_timer_timeout"))
	add_child(heal_pause_timer)
	
	player = get_tree().get_first_node_in_group("player")

func update_custom_health_bar():
	if health_bar_bg and health_bar_fg:
		var percent = clamp(float(hp) / float(max_hp), 0.0, 1.0)
		health_bar_fg.size = Vector2(health_bar_bg.size.x * percent, health_bar_bg.size.y)

func _physics_process(_delta):
	if not has_gimmick_50_triggered and hp <= max_hp * 0.5:
		has_gimmick_50_triggered = true
		start_gimmick_50()
	
	if not has_gimmick_30_triggered and hp <= max_hp * 0.3:
		has_gimmick_30_triggered = true
		start_gimmick_30()

func start_gimmick_50():
	in_gimmick_50 = true
	attack_timer.stop()
	
	var tween = create_tween()
	tween.tween_property(self, "modulate:a", 0.0, 1.0)
	await tween.finished
	
	$CollisionShape2D.disabled = true
	$WeakPoint/CollisionShape2D.disabled = true
	hide()
	
	gimmick_50_timer.start()
	regen_timer.start()
	spawn_bright_spot()

func _on_gimmick_50_timer_timeout():
	in_gimmick_50 = false # This flag indicates if the gimmick is *currently active*
	regen_timer.stop()
	
	for child in get_tree().get_nodes_in_group("bright_spots"):
		child.queue_free()

	show()
	$CollisionShape2D.disabled = false
	$WeakPoint/CollisionShape2D.disabled = false
	
	var tween = create_tween()
	tween.tween_property(self, "modulate:a", 1.0, 1.0)
	await tween.finished
	
	attack_timer.start()

func _on_regen_timer_timeout():
	hp = min(hp + 10, max_hp)
	health_bar.value = hp
	update_custom_health_bar()

func spawn_bright_spot():
	print("DEBUG: spawn_bright_spot() called.")
	var bright_spot = BrightSpotScene.instantiate()
	# Set collision to match the boss
	bright_spot.collision_layer = 4
	bright_spot.collision_mask = 36
	
	get_tree().root.add_child(bright_spot) # Add to root, not self
	bright_spot.add_to_group("bright_spots")
	
	bright_spot.global_position = _find_spawn_point_on_wall()
	
	bright_spot.connect("hit", Callable(self, "_on_bright_spot_hit"))

func _find_spawn_point_on_wall() -> Vector2:
	var space_state = get_world_2d().direct_space_state
	var max_attempts = 20
	
	for i in range(max_attempts):
		# 0 = ceiling, 1 = left wall, 2 = right wall
		var surface = randi_range(0, 2)
		var query = PhysicsRayQueryParameters2D.new()
		query.collision_mask = 1 # World layer

		if surface == 0: # Ceiling
			var x = randf_range(50, 1230)
			query.from = Vector2(x, 0)
			query.to = Vector2(x, 720)
		elif surface == 1: # Left wall
			var y = randf_range(50, 670)
			query.from = Vector2(0, y)
			query.to = Vector2(1280, y)
		else: # Right wall
			var y = randf_range(50, 670)
			query.from = Vector2(1280, y)
			query.to = Vector2(0, y)

		var result = space_state.intersect_ray(query)
		if result:
			return result.position - result.normal * 50 # Offset slightly from the wall
	
	# Fallback if no wall was found
	print("WARNING: Could not find a wall to spawn BrightSpot. Using fallback position.")
	return Vector2(randf_range(200, 1000), randf_range(100, 300))

func _on_bright_spot_hit():
	print("DEBUG: BrightSpot hit! Stopping healing and starting 3s pause.")
	regen_timer.stop()
	heal_pause_timer.start()
	take_damage(10, true) # Force damage even during gimmick

func _on_heal_pause_timer_timeout():
	print("DEBUG: 3s pause finished. Spawning new BrightSpot.")
	spawn_bright_spot()
	if in_gimmick_50:
		print("DEBUG: Resuming healing.")
		regen_timer.start()

func start_gimmick_30():
	in_gimmick_30 = true
	
	# Force darkness by extinguishing the torch
	var torch = get_tree().get_first_node_in_group("torch")
	if torch and torch.has_method("force_extinguish"):
		torch.force_extinguish()
	
	# This CanvasModulate logic seems to be handled by the torch system now
	# get_node("/root/TitleMap/GameManager").is_darkness_active = true
	gimmick_30_timer.start()

func _on_gimmick_30_timer_timeout():
	var manager = get_tree().get_first_node_in_group("stalactite_manager")
	if manager and manager.get_child_count() > 0:
		var stalactites = manager.get_children()
		var actual_stalactites = []
		for s in stalactites:
			if s.has_method("start_fall"):
				actual_stalactites.append(s)
		
		if not actual_stalactites.is_empty():
			var random_stalactite = actual_stalactites.pick_random()
			random_stalactite.start_fall()

func take_damage(amount, force=false):
	if in_gimmick_50 and not force:
		return
	hp -= amount
	
	# --- Blink Effect ---
	var tween = create_tween().set_loops(2)
	tween.tween_property(self, "modulate", Color.RED, 0.15)
	tween.tween_property(self, "modulate", Color.WHITE, 0.15)
	# --- End Blink Effect ---
	
	health_bar.value = hp
	update_custom_health_bar()
	if hp <= 0:
		if health_bar_bg:
			health_bar_bg.visible = false
		if in_gimmick_30:
			get_node("/root/TitleMap/GameManager").is_darkness_active = false
			gimmick_30_timer.stop()
		queue_free()

func _on_weak_point_body_entered(body):
	if body.is_in_group("bullets"):
		take_damage(10) # Additive weak point damage
		if body.has_method("explode"):
			body.explode()

func _on_attack_timer_timeout():
	if player == null:
		player = get_tree().get_first_node_in_group("player")
		if player == null:
			return

	var distance_to_player = global_position.distance_to(player.global_position)
	var player_size = 100
	var max_error = player_size * 2
	var error_margin = clamp(inverse_lerp(200.0, 1000.0, distance_to_player), 0.0, 1.0) * max_error

	var target_x_position = player.global_position.x + randf_range(-error_margin, error_margin)

	var space_state = get_world_2d().direct_space_state
	
	var ray_start = Vector2(target_x_position, -5000)
	var ray_end = Vector2(target_x_position, 5000)
	
	var query = PhysicsRayQueryParameters2D.create(ray_start, ray_end)
	query.collision_mask = 1

	var result = space_state.intersect_ray(query)

	var final_target_position: Vector2
	if result:
		final_target_position = result.position
	else:
		final_target_position = player.global_position + Vector2(randf_range(-error_margin, error_margin), 0)

	var warning = WarningScene.instantiate()
	get_tree().root.add_child(warning)

	var visual_node = warning.get_node("Sprite2D")
	var warning_height = 0.0
	if visual_node:
		if visual_node is Sprite2D and visual_node.texture:
			warning_height = visual_node.texture.get_height() * visual_node.scale.y
		elif visual_node is ColorRect:
			warning_height = visual_node.size.y * visual_node.scale.y

	var adjusted_warning_position = final_target_position - Vector2(0, warning_height / 7.0)
	
	warning.global_position = adjusted_warning_position

	if warning.has_method("set_radius"):
		warning.set_radius(EXPLOSION_RADIUS)

	var fire_timer = get_tree().create_timer(WARNING_DURATION)
	fire_timer.timeout.connect(_fire_projectile.bind(final_target_position, EXPLOSION_RADIUS))

func calculate_parabolic_velocity(launch_pos: Vector2, target_pos: Vector2, desired_speed: float, gravity: float) -> Vector2:
	var delta = target_pos - launch_pos
	var delta_x = delta.x
	var delta_y = -delta.y

	if abs(delta_x) < 0.1:
		var vertical_speed = -desired_speed if delta_y > 0 else desired_speed
		return Vector2(0, vertical_speed)

	var min_speed_sq = gravity * (delta_y + sqrt(delta_x * delta_x + delta_y * delta_y))
	
	var min_launch_speed = 0.0
	if min_speed_sq >= 0:
		min_launch_speed = sqrt(min_speed_sq)
	else:
		var fallback_angle = deg_to_rad(45.0)
		return Vector2(cos(fallback_angle) * desired_speed, -sin(fallback_angle) * desired_speed)

	var actual_launch_speed = max(desired_speed, min_launch_speed)
	var actual_speed_sq = actual_launch_speed * actual_launch_speed

	var gx = gravity * delta_x
	var term_under_sqrt_calc = actual_speed_sq * actual_speed_sq - gravity * (gravity * delta_x * delta_x + 2 * delta_y * actual_speed_sq)
	if term_under_sqrt_calc < 0:
		term_under_sqrt_calc = 0
	var sqrt_term = sqrt(term_under_sqrt_calc)

	var launch_angle_rad = atan2(actual_speed_sq + sqrt_term, gx)

	var vel_x = cos(launch_angle_rad) * actual_launch_speed
	var vel_y_math = sin(launch_angle_rad) * actual_launch_speed

	var vel_y_godot = -vel_y_math

	var initial_velocity = Vector2(vel_x, vel_y_godot)

	return initial_velocity

func _fire_projectile(fire_target_position: Vector2, radius: float):
	if player == null:
		return

	var projectile = ProjectileScene.instantiate()
	projectile.collision_layer = 5
	projectile.collision_mask = 35
	get_tree().root.add_child(projectile)
	projectile.global_position = fire_point.global_position
	if projectile.has_method("set_shooter"):
		projectile.set_shooter(self) # 'self'는 보스 자신
	else:
		printerr("오류: 포탄 씬에 set_shooter 함수가 없습니다!")

	var gravity = ProjectSettings.get_setting("physics/2d/default_gravity")
	var initial_velocity = calculate_parabolic_velocity(fire_point.global_position,
														  fire_target_position,
														  PROJECTILE_SPEED,
														  gravity)

	projectile.linear_velocity = initial_velocity

	if projectile.has_method("set_explosion_radius"):
		projectile.set_explosion_radius(radius)
