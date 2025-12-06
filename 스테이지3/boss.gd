# boss.gd (Merged by Gemini)
extends StaticBody2D

# ==============================================================================
# 시그널 목록
# ==============================================================================
signal boss_died               # 보스의 체력이 0이 되었을 때 발생 (애니메이션 시작 전)
signal boss_animation_finished  # 보스의 모든 사망 애니메이션이 끝났을 때 발생
signal health_updated(current_hp, max_hp) # 보스의 체력이 변경될 때마다 발생

# ==============================================================================
# 변수 및 상수 설정
# ==============================================================================

# --- 외부 씬 및 리소스 ---
@export var bullet_scene: PackedScene
@export var hitbox_indicator_scene: PackedScene
@export var explosion_scene: PackedScene
const BrightSpotScene = preload("res://스테이지3/BrightSpot.tscn")

# --- 보스 스탯 ---
@export var max_hp = 300
var hp = 300

# --- 상태 변수 ---
var in_gimmick_50 = false
var in_gimmick_30 = false
var has_gimmick_50_triggered = false
var has_gimmick_30_triggered = false
var is_enraged = false
var is_dying = false
var player: CharacterBody2D = null
var game_manager: Node = null

# --- 공격 상수 ---
const WARNING_DURATION = 1.5
const EXPLOSION_RADIUS = 100.0

# --- 노드 참조 ---
@onready var fire_point = $FirePoint
@onready var attack_timer = $AttackTimer
@onready var gimmick_50_timer = Timer.new()
@onready var regen_timer = Timer.new()
@onready var gimmick_30_timer = Timer.new()
@onready var heal_pause_timer = Timer.new()
var rage_music_intro: AudioStreamPlayer
var rage_music_loop: AudioStreamPlayer

# --- UI 참조 ---
@onready var health_bar_frame: TextureRect = $BossUICanvas/HealthBarFrame
@onready var health_bar_fg: Panel = $BossUICanvas/HealthBarFG
@onready var health_bar_label: Label = $BossUICanvas/HealthBarLabel
var max_health_bar_width: float = 0.0

# ==============================================================================
# Godot 내장 함수
# ==============================================================================

func _ready():
	add_to_group("boss")
	randomize()
	hp = max_hp
	
	# --- UI 및 타이머 설정 ---
	_setup_health_bar_styles()
	max_health_bar_width = health_bar_fg.size.x
	update_custom_health_bar()

	attack_timer.connect("timeout", Callable(self, "_on_attack_timer_timeout"))
	
	gimmick_50_timer.wait_time = 15
	gimmick_50_timer.one_shot = true
	gimmick_50_timer.connect("timeout", Callable(self, "_on_gimmick_50_timer_timeout"))
	add_child(gimmick_50_timer)
	
	regen_timer.wait_time = 1
	regen_timer.connect("timeout", Callable(self, "_on_regen_timer_timeout"))
	add_child(regen_timer)
	
	gimmick_30_timer.wait_time = 3
	gimmick_30_timer.one_shot = false
	gimmick_30_timer.connect("timeout", Callable(self, "_on_gimmick_30_timer_timeout"))
	add_child(gimmick_30_timer)

	heal_pause_timer.wait_time = 3
	heal_pause_timer.one_shot = true
	heal_pause_timer.connect("timeout", Callable(self, "_on_heal_pause_timer_timeout"))
	add_child(heal_pause_timer)
	
	# --- 격노 모드 음악 플레이어 설정 ---
	rage_music_intro = AudioStreamPlayer.new()
	rage_music_intro.stream = load("res://스테이지3/sound/rageModeFirst.mp3")
	rage_music_intro.finished.connect(_on_rage_intro_finished)
	add_child(rage_music_intro)

	rage_music_loop = AudioStreamPlayer.new()
	rage_music_loop.stream = load("res://스테이지3/sound/rageMode.mp3")
	rage_music_loop.finished.connect(rage_music_loop.play) # 무한 반복
	add_child(rage_music_loop)
	
	player = get_tree().get_first_node_in_group("player")
	game_manager = get_node("/root/TitleMap/GameManager")
	attack_timer.start()


func _physics_process(_delta):
	if is_dying: return

	# --- 격노 상태 돌입 (50% HP) ---
	if not is_enraged and hp <= max_hp * 0.5:
		is_enraged = true
		GlobalMessageBox.add_message("(동굴이 붕괴하기 시작합니다.....)")
		if game_manager and game_manager.has_method("stop_bgm"):
			game_manager.stop_bgm()
		rage_music_intro.play()
		
	# --- 50% HP 기믹 시작 ---
	if not has_gimmick_50_triggered and hp <= max_hp * 0.5:
		has_gimmick_50_triggered = true
		start_gimmick_50()
	
	# --- 30% HP 기믹 시작 ---
	if not has_gimmick_30_triggered and hp <= max_hp * 0.3:
		has_gimmick_30_triggered = true
		start_gimmick_30()

# ==============================================================================
# 기믹 로직 (Gimmicks)
# ==============================================================================

# --- 기믹 1: 은신 및 재생 (50% HP) ---
func start_gimmick_50():
	GlobalMessageBox.add_message("드릴러가 모습을 감춥니다... 숨어있는 드릴러를 맞춰 동굴의 붕괴를 막으세요!")
	in_gimmick_50 = true
	attack_timer.stop()
	
	var tween = create_tween()
	tween.tween_property(self, "modulate:a", 0.0, 1.0)
	await tween.finished
	
	$CollisionShape2D.set_deferred("disabled", true)
	if has_node("WeakPoint/CollisionShape2D"):
		$WeakPoint/CollisionShape2D.set_deferred("disabled", true)
	hide()
	
	gimmick_50_timer.start()
	regen_timer.start()
	spawn_bright_spot()

func _on_gimmick_50_timer_timeout():
	if not in_gimmick_50: return
	
	GlobalMessageBox.add_message("드릴러가 모습을 드러냅니다... 전투에 대비하세요!")
	in_gimmick_50 = false
	regen_timer.stop()
	heal_pause_timer.stop()

	var bright_spots = get_tree().get_nodes_in_group("bright_spots")
	for spot in bright_spots:
		if is_instance_valid(spot):
			spot.queue_free()

	await get_tree().create_timer(1.0).timeout

	show()
	$CollisionShape2D.set_deferred("disabled", false)
	if has_node("WeakPoint/CollisionShape2D"):
		$WeakPoint/CollisionShape2D.set_deferred("disabled", false)
	
	var tween_boss = create_tween()
	tween_boss.tween_property(self, "modulate:a", 1.0, 1.0)
	await tween_boss.finished
	
	if not is_dying:
		attack_timer.start()

func _on_regen_timer_timeout():
	hp = min(hp + 10, max_hp)
	update_custom_health_bar()

func spawn_bright_spot():
	if not in_gimmick_50: return

	var bright_spot = BrightSpotScene.instantiate()
	get_tree().root.add_child(bright_spot)
	bright_spot.add_to_group("bright_spots")
	bright_spot.global_position = _find_spawn_point_on_wall()
	bright_spot.connect("hit", Callable(self, "_on_bright_spot_hit"))

func _find_spawn_point_on_wall() -> Vector2:
	var space_state = get_world_2d().direct_space_state
	for _i in range(20):
		var query = PhysicsRayQueryParameters2D.new()
		query.collision_mask = 1
		# Randomly pick a wall (top, left, right)
		var surface = randi_range(0, 2) 
		if surface == 0: # Top wall
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
			return result.position - result.normal * 50
	return Vector2(randf_range(200, 1000), randf_range(100, 300)) # Fallback

func _on_bright_spot_hit():
	GlobalMessageBox.add_message("약점을 타격당하자 드릴러의 재생이 멈춥니다!")
	regen_timer.stop()
	heal_pause_timer.start()
	take_damage(10, true) # Force damage

func _on_heal_pause_timer_timeout():
	if in_gimmick_50:
		spawn_bright_spot()
		regen_timer.start()

# --- 기믹 2: 종유석 낙하 (30% HP) ---
func start_gimmick_30():
	in_gimmick_30 = true
	# 모든 횃불을 끄고 잠금
	for torch in get_tree().get_nodes_in_group("torch"):
		if torch.has_method("force_extinguish"):
			torch.force_extinguish()
	gimmick_30_timer.start()

func _on_gimmick_30_timer_timeout():
	var manager = get_tree().get_first_node_in_group("stalactite_manager")
	if manager and manager.has_method("drop_stalactite_near_player"):
		manager.drop_stalactite_near_player()

# ==============================================================================
# 데미지 처리 및 사망 로직
# ==============================================================================

func take_damage(amount, force=false):
	if is_dying or (in_gimmick_50 and not force): return
	
	_play_sound("res://스테이지3/sound/bossHit.mp3")
	hp -= amount
	emit_signal("health_updated", hp, max_hp)
	update_custom_health_bar()

	var tween = create_tween().set_loops(2)
	tween.tween_property(self, "modulate", Color.RED, 0.1)
	tween.tween_property(self, "modulate", Color.WHITE, 0.1)
	
	if hp <= 0 and not is_dying:
		is_dying = true
		call_deferred("die")

func die():
	emit_signal("boss_died")
	
	rage_music_intro.stop()
	rage_music_loop.stop()
	
	attack_timer.stop()
	gimmick_50_timer.stop()
	gimmick_30_timer.stop()
	regen_timer.stop()
	heal_pause_timer.stop()
	
	if in_gimmick_50: _on_gimmick_50_timer_timeout()

	var explosion_interval = 0.15
	var set_interval = 1.0
	var explosion_set_duration = 8 * explosion_interval
	var total_animation_time = (explosion_set_duration * 3) + (set_interval * 2)

	var fade_tween = create_tween()
	fade_tween.tween_property(self, "modulate:a", 0.0, total_animation_time)

	var shake_tween = create_tween().set_loops()
	shake_tween.tween_property(self, "position:x", position.x + 5, 0.125)
	shake_tween.tween_property(self, "position:x", position.x - 5, 0.125)

	for set_num in 3:
		for _i in 8:
			if explosion_scene:
				var explosion = explosion_scene.instantiate()
				get_parent().add_child(explosion)
				var bounds = $CollisionShape2D.shape.get_rect()
				var random_pos = Vector2(randf_range(bounds.position.x, bounds.end.x), randf_range(bounds.position.y, bounds.end.y))
				explosion.global_position = global_position + random_pos
			await get_tree().create_timer(explosion_interval).timeout
		if set_num < 2:
			await get_tree().create_timer(set_interval).timeout
			
	shake_tween.kill()
	emit_signal("boss_animation_finished")
	
# ==============================================================================
# 공격 로직
# ==============================================================================

func _on_attack_timer_timeout():
	if is_dying or in_gimmick_50: return
	if not is_instance_valid(player):
		player = get_tree().get_first_node_in_group("player")
		if not is_instance_valid(player): return

	var target_pos = player.global_position
	var gravity = ProjectSettings.get_setting("physics/2d/default_gravity")
	var current_speed = 1200.0
	var final_velocity = Vector2.ZERO

	# GlobalPhysics가 있다면 사용, 없다면 로컬 계산 사용 (안전성 확보)
	if GlobalPhysics.has_method("calculate_parabolic_velocity"):
		final_velocity = GlobalPhysics.calculate_parabolic_velocity(fire_point.global_position, target_pos, current_speed, gravity)
	else: # Fallback to local calculation
		var delta = target_pos - fire_point.global_position
		var a = gravity * delta.x * delta.x / (2 * current_speed * current_speed)
		var b = -delta.x
		var c = delta.y + a
		var tan_theta = (-b - sqrt(b*b - 4*a*c)) / (2*a)
		var angle = atan(tan_theta)
		final_velocity = Vector2(cos(angle), -sin(angle)) * current_speed
	
	# 경고 표시 생성
	var warning_target_ground_pos = Vector2(target_pos.x, player.global_position.y + 36)
	var warning = hitbox_indicator_scene.instantiate()
	get_tree().root.add_child(warning)
	warning.global_position = warning_target_ground_pos
	if warning.has_method("set_radius"):
		warning.set_radius(EXPLOSION_RADIUS)

	var fire_timer = get_tree().create_timer(WARNING_DURATION)
	fire_timer.timeout.connect(_fire_projectile.bind(final_velocity))

func _fire_projectile(velocity: Vector2):
	if velocity == Vector2.ZERO: return
	
	_play_sound("res://스테이지3/sound/fireSound.mp3")
	
	var projectile = bullet_scene.instantiate()
	get_tree().root.add_child(projectile)
	projectile.global_position = fire_point.global_position
	if "owner_node" in projectile: projectile.owner_node = self
	projectile.is_boss_bullet = true
	projectile.add_to_group("boss_bullets")
	projectile.linear_velocity = velocity

	if projectile.has_method("set_explosion_radius"):
		projectile.set_explosion_radius(EXPLOSION_RADIUS)

# ==============================================================================
# 시그널 핸들러 및 유틸리티
# ==============================================================================
func _on_weak_point_body_entered(body):
	if body.is_in_group("bullets") or body.is_in_group("player_bullets"):
		take_damage(20) # 약점은 20 데미지
		if body.has_method("explode"): body.explode()
		else: body.queue_free()

func _on_body_hitbox_entered(body):
	if body.is_in_group("bullets") or body.is_in_group("player_bullets"):
		take_damage(10) # 몸체는 10 데미지
		if body.has_method("explode"): body.explode()
		else: body.queue_free()

func _play_sound(sound_path, volume_db = 0):
	var sfx_player = AudioStreamPlayer.new()
	sfx_player.stream = load(sound_path)
	sfx_player.volume_db = volume_db
	add_child(sfx_player)
	sfx_player.play()
	sfx_player.finished.connect(sfx_player.queue_free)

func _on_rage_intro_finished():
	if not is_dying:
		rage_music_loop.play()

# --- UI 관련 함수 ---
func update_custom_health_bar():
	emit_signal("health_updated", hp, max_hp)
	if health_bar_fg:
		var health_ratio = clamp(float(hp) / float(max_hp), 0.0, 1.0)
		health_bar_fg.size.x = max_health_bar_width * health_ratio

		var fg_style = health_bar_fg.get_theme_stylebox("panel")
		if fg_style:
			if health_ratio > 0.5: fg_style.bg_color = Color(0.2, 0.8, 0.2, 0.7) # Green
			elif health_ratio > 0.2: fg_style.bg_color = Color(0.8, 0.8, 0.2, 0.7) # Yellow
			else: fg_style.bg_color = Color(0.8, 0.2, 0.2, 0.7) # Red
	if health_bar_label:
		health_bar_label.text = str(hp) + " / " + str(max_hp)

func _setup_health_bar_styles():
	var fg_style = StyleBoxFlat.new()
	fg_style.bg_color = Color(0.2, 0.8, 0.2, 0.7) # Initial green
	fg_style.corner_radius_top_left = 4
	fg_style.corner_radius_top_right = 4
	fg_style.corner_radius_bottom_left = 4
	fg_style.corner_radius_bottom_right = 4
	health_bar_fg.add_theme_stylebox_override("panel", fg_style)
