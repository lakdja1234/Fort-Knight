extends StaticBody2D

signal boss_died

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

const WARNING_DURATION = 1.5
const EXPLOSION_RADIUS = 100.0 # 보스 공격의 폭발 반경 (임의로 100으로 설정)

# --- Node References ---
@onready var fire_point = $FirePoint
@onready var attack_timer = $AttackTimer
@onready var gimmick_50_timer = Timer.new()
@onready var regen_timer = Timer.new()
@onready var gimmick_30_timer = Timer.new()
@onready var heal_pause_timer = Timer.new()

var player: CharacterBody2D = null
var game_manager: Node = null

# --- Scene UI References ---
@onready var health_bar_frame: TextureRect = $BossUICanvas/HealthBarFrame
@onready var health_bar_fg: Panel = $BossUICanvas/HealthBarFG
@onready var health_bar_label: Label = $BossUICanvas/HealthBarLabel
var max_health_bar_width: float = 0.0

func _ready():
	add_to_group("boss")
	randomize()
	
	_setup_health_bar_styles()
	# The max width is the initial width of the FG panel itself
	max_health_bar_width = health_bar_fg.size.x
	update_custom_health_bar() # Initialize the health bar with values

	if attack_timer:
		attack_timer.connect("timeout", Callable(self, "_on_attack_timer_timeout"))
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
	if health_bar_fg:
		var health_ratio = clamp(float(hp) / float(max_hp), 0.0, 1.0)
		health_bar_fg.size.x = max_health_bar_width * health_ratio

		# Update color based on health via the StyleBox
		var fg_style = health_bar_fg.get_theme_stylebox("panel")
		if fg_style:
			if health_ratio > 0.5:
				fg_style.bg_color = Color(0.2, 0.8, 0.2, 0.7) # Green
			elif health_ratio > 0.2:
				fg_style.bg_color = Color(0.8, 0.8, 0.2, 0.7) # Yellow
			else:
				fg_style.bg_color = Color(0.8, 0.2, 0.2, 0.7) # Red
	
	if health_bar_label:
		health_bar_label.text = str(hp) + " / " + str(max_hp)


func _physics_process(delta):
	if not has_gimmick_50_triggered and hp <= max_hp * 0.5:
		has_gimmick_50_triggered = true
		start_gimmick_50()
	
	if not has_gimmick_30_triggered and hp <= max_hp * 0.3:
		has_gimmick_30_triggered = true
		start_gimmick_30()

func start_gimmick_50():
	print("[GIMMICK 1] START. HP: ", hp)
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
	print("[GIMMICK 1] END. HP: ", hp)
	in_gimmick_50 = false
	regen_timer.stop()
	heal_pause_timer.stop()

	var bright_spots = get_tree().get_nodes_in_group("bright_spots")
	for spot in bright_spots:
		if is_instance_valid(spot):
			spot.queue_free()

	await get_tree().create_timer(1.0).timeout

	show()
	$CollisionShape2D.disabled = false
	$WeakPoint/CollisionShape2D.disabled = false
	
	var tween_boss = create_tween()
	tween_boss.tween_property(self, "modulate:a", 1.0, 1.0)
	await tween_boss.finished
	
	attack_timer.start()

func _on_regen_timer_timeout():
	var old_hp = hp
	hp = min(hp + 10, max_hp)
	print("[GIMMICK 1] HEAL. HP: %d -> %d" % [old_hp, hp])
	update_custom_health_bar()

func spawn_bright_spot():
	if not in_gimmick_50: return

	var bright_spot = BrightSpotScene.instantiate()
	bright_spot.collision_layer = 8 # Enemy layer (bitmask value for layer 4)
	bright_spot.collision_mask = 36
	
	get_tree().root.add_child(bright_spot)
	bright_spot.add_to_group("bright_spots")
	
	bright_spot.global_position = _find_spawn_point_on_wall()
	
	bright_spot.connect("hit", Callable(self, "_on_bright_spot_hit"))

func _find_spawn_point_on_wall() -> Vector2:
	var space_state = get_world_2d().direct_space_state
	var max_attempts = 20
	
	for i in range(max_attempts):
		var surface = randi_range(0, 2)
		var query = PhysicsRayQueryParameters2D.new()
		query.collision_mask = 1

		if surface == 0:
			var x = randf_range(50, 1230)
			query.from = Vector2(x, 0)
			query.to = Vector2(x, 720)
		elif surface == 1:
			var y = randf_range(50, 670)
			query.from = Vector2(0, y)
			query.to = Vector2(1280, y)
		else:
			var y = randf_range(50, 670)
			query.from = Vector2(1280, y)
			query.to = Vector2(0, y)

		var result = space_state.intersect_ray(query)
		if result:
			return result.position - result.normal * 50
	
	return Vector2(randf_range(200, 1000), randf_range(100, 300))

func _on_bright_spot_hit():
	print("[GIMMICK 1] Bright spot hit. Pausing heal.")
	regen_timer.stop()
	heal_pause_timer.start()
	take_damage(10, true)

func _on_heal_pause_timer_timeout():
	spawn_bright_spot()
	if in_gimmick_50:
		regen_timer.start()

func start_gimmick_30():
	in_gimmick_30 = true
	
	var torch = get_tree().get_first_node_in_group("torch")
	if torch and torch.has_method("force_extinguish"):
		torch.force_extinguish()
	
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
		print("[DAMAGE] BLOCKED due to Gimmick 1. HP: ", hp)
		return
	
	var old_hp = hp
	hp -= amount
	print("[DAMAGE] Applied. Amount: %d, Force: %s. HP: %d -> %d" % [amount, str(force), old_hp, hp])
	
	var tween = create_tween().set_loops(2)
	tween.tween_property(self, "modulate", Color.RED, 0.15)
	tween.tween_property(self, "modulate", Color.WHITE, 0.15)
	
	update_custom_health_bar()
	if hp <= 0:
		emit_signal("boss_died")
		if in_gimmick_30:
			gimmick_30_timer.stop()
		queue_free()

func _on_weak_point_body_entered(body):
	if body.is_in_group("bullets"):
		take_damage(10)
		if body.has_method("explode"):
			body.explode()

const WALL_LAYER_MASK = 1

func _on_attack_timer_timeout():
	if player == null:
		player = get_tree().get_first_node_in_group("player")
		if player == null:
			return

	var target_pos = player.global_position
	var gravity = ProjectSettings.get_setting("physics/2d/default_gravity")
	
	var current_speed = 1200.0
	var speed_decrement = 50.0
	var num_attempts = 15

	var final_impact_point = Vector2.ZERO
	var final_velocity = Vector2.ZERO

	for i in range(num_attempts):
		var initial_velocity = GlobalPhysics.calculate_parabolic_velocity(
			fire_point.global_position,
			target_pos,
			current_speed,
			gravity
		)
		
		var impact_point = get_trajectory_impact_point(
			fire_point.global_position,
			initial_velocity,
			gravity
		)
		
		if impact_point != Vector2.ZERO and impact_point.y > target_pos.y - 50:
			final_impact_point = impact_point
			final_velocity = initial_velocity
			break
		
		current_speed -= speed_decrement

	var warning_target_ground_pos = Vector2.ZERO
	var has_valid_impact_point = false

	if final_impact_point != Vector2.ZERO:
		var space_state = get_world_2d().direct_space_state
		var query = PhysicsRayQueryParameters2D.create(final_impact_point + Vector2(0, -50), final_impact_point + Vector2(0, 1000))
		query.collision_mask = WALL_LAYER_MASK
		var result = space_state.intersect_ray(query)
		
		if result:
			warning_target_ground_pos = result.position
			has_valid_impact_point = true
	
	if not has_valid_impact_point:
		if player:
			var space_state = get_world_2d().direct_space_state
			var query = PhysicsRayQueryParameters2D.create(player.global_position + Vector2(0, -50), player.global_position + Vector2(0, 1000))
			query.collision_mask = WALL_LAYER_MASK
			var result = space_state.intersect_ray(query)
			if result:
				warning_target_ground_pos = result.position
				has_valid_impact_point = true
			else:
				warning_target_ground_pos = Vector2(get_viewport_rect().size.x / 2, get_viewport_rect().size.y)
				has_valid_impact_point = true
		else:
			warning_target_ground_pos = Vector2(get_viewport_rect().size.x / 2, get_viewport_rect().size.y)
			has_valid_impact_point = true

	if has_valid_impact_point:
		var warning = WarningScene.instantiate()
		get_tree().root.add_child(warning)
		warning.global_position = warning_target_ground_pos
		if warning.has_method("set_radius"):
			warning.set_radius(EXPLOSION_RADIUS * 0.7)
		
		var visual_node = warning.get_node("Sprite2D")
		if visual_node and visual_node.texture:
			var half_height = visual_node.texture.get_height() * visual_node.scale.y / 2.0
			warning.global_position.y -= half_height

		var fire_timer = get_tree().create_timer(WARNING_DURATION)
		fire_timer.timeout.connect(_fire_projectile.bind(final_velocity))
	else:
		print("보스: 모든 시도에서 유효한 발사 경로를 찾지 못했습니다. 경고 및 발사 없음.")


func _fire_projectile(velocity: Vector2):
	# 단순화된 발사 함수: 미리 계산된 속도로 발사체 생성 및 발사
	var projectile = ProjectileScene.instantiate()
	projectile.collision_layer = 16
	projectile.collision_mask = 7
	get_tree().root.add_child(projectile)
	projectile.global_position = fire_point.global_position
	projectile.owner_node = self
	projectile.linear_velocity = velocity

	if projectile.has_method("set_explosion_radius"):
		projectile.set_explosion_radius(EXPLOSION_RADIUS)


func get_trajectory_impact_point(start_pos: Vector2, initial_vel: Vector2, gravity: float) -> Vector2:
	var space_state = get_world_2d().direct_space_state
	var prev_pos = start_pos
	var current_pos = start_pos
	var current_vel = initial_vel
	var delta = 0.02
	var steps = 150 # 3 seconds of simulation time

	var shape = CircleShape2D.new()
	shape.radius = 8.0

	var query_params = PhysicsShapeQueryParameters2D.new()
	query_params.shape = shape
	query_params.collision_mask = WALL_LAYER_MASK
	query_params.exclude = [self]

	for i in range(steps):
		prev_pos = current_pos
		current_vel.y += gravity * delta
		current_pos += current_vel * delta
		
		query_params.transform = Transform2D(0, current_pos)
		var shape_result = space_state.intersect_shape(query_params)
		
		if not shape_result.is_empty():
			# A collision occurred. Now find the exact point and normal with a raycast.
			var ray_query = PhysicsRayQueryParameters2D.create(prev_pos, current_pos)
			ray_query.collision_mask = WALL_LAYER_MASK
			ray_query.exclude = [self]
			var ray_result = space_state.intersect_ray(ray_query)

			if ray_result:
				var normal = ray_result.normal
				# Ignore floor collisions (normal pointing up)
				if normal.y > -0.7:
					return ray_result.position # Return the precise impact point
			# else: ray_result is null, but shape collision happened.
			# This can happen if the shape starts inside a collider.
			# We can't determine a normal, so we can't ignore the floor.
			# To be safe, we'll treat it as a non-valid impact point by returning ZERO.
		
	return Vector2.ZERO # No non-floor collision detected

func _setup_health_bar_styles():
	# Style for the foreground
	var fg_style = StyleBoxFlat.new()
	fg_style.bg_color = Color(0.2, 0.8, 0.2, 0.7) # Initial green color
	fg_style.corner_radius_top_left = 4
	fg_style.corner_radius_top_right = 4
	fg_style.corner_radius_bottom_left = 4
	fg_style.corner_radius_bottom_right = 4
	health_bar_fg.add_theme_stylebox_override("panel", fg_style)
