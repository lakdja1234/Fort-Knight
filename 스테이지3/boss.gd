extends StaticBody2D

# ==============================================================================
# 시그널 목록
# ==============================================================================
signal hiding_started          # 보스가 은신을 시작했을 때 발생
signal hiding_ended            # 보스가 은신을 종료했을 때 발생
signal boss_died               # 보스의 체력이 0이 되었을 때 발생 (애니메이션 시작 전)
signal enraged                 # 보스가 격노 상태에 진입했을 때 발생
signal health_updated(current_hp, max_hp) # 보스의 체력이 변경될 때마다 발생
signal boss_animation_finished  # 보스의 모든 사망 애니메이션이 끝났을 때 발생

# ==============================================================================
# 변수 및 상수 설정
# ==============================================================================

# --- 외부 씬 및 리소스 ---
@export var bullet_scene: PackedScene
@export var hitbox_indicator_scene: PackedScene
@export var explosion_scene: PackedScene
var bright_spot_scene: PackedScene
@export var max_hp = 100

# --- 상태 변수 ---
var hp
var is_hiding = false
var is_dying = false
var is_enraged = false
var game_manager: Node
var player: CharacterBody2D = null
var current_bright_spot: Node = null
var hiding_end_message_shown: bool = false

# --- 공격 상수 ---
const PROJECTILE_SPEED = 800.0
const WARNING_DURATION = 0.75
const EXPLOSION_RADIUS = 100.0
var normal_attack_speed = 1.33
var fast_attack_speed = 1.13

# --- 노드 참조 ---
@onready var attack_timer = $AttackTimer
@onready var fire_point = $FirePoint
@onready var hide_pattern_timer = Timer.new()
@onready var hiding_duration_timer = Timer.new()
@onready var stalactite_fall_timer = Timer.new()
@onready var collision_shape = $CollisionShape2D
var hiding_message_timer: Timer
var rage_music_intro: AudioStreamPlayer
var rage_music_loop: AudioStreamPlayer

# ==============================================================================
# Godot 내장 함수
# ==============================================================================

func _physics_process(delta):
	# 플레이어가 맵 오른쪽에 있으면 보스의 공격 속도를 높임
	if not is_hiding and is_instance_valid(player):
		if player.global_position.x > 640:
			attack_timer.wait_time = fast_attack_speed
		else:
			attack_timer.wait_time = normal_attack_speed

func _ready():
	bright_spot_scene = load("res://스테이지3/BrightSpot.tscn")
	explosion_scene = load("res://스테이지3/explosion.tscn")

	game_manager = get_node("/root/TitleMap/GameManager")
	add_to_group("boss")
	hp = max_hp
	player = get_tree().get_first_node_in_group("player")
	
	# 타이머 신호 연결
	attack_timer.connect("timeout", self._on_attack_timer_timeout)
	hide_pattern_timer.connect("timeout", self.start_hiding_pattern)
	hiding_duration_timer.connect("timeout", self.end_hiding_pattern)
	stalactite_fall_timer.connect("timeout", self._on_stalactite_fall_timer_timeout)
	
	# 각종 타이머 설정 및 자식으로 추가
	hide_pattern_timer.wait_time = 20.0
	hide_pattern_timer.one_shot = true
	add_child(hide_pattern_timer)
	
	hiding_duration_timer.wait_time = 15.0
	hiding_duration_timer.one_shot = true
	add_child(hiding_duration_timer)

	hiding_message_timer = Timer.new()
	hiding_message_timer.one_shot = true
	hiding_message_timer.timeout.connect(_show_hiding_end_message)
	add_child(hiding_message_timer)
	
	stalactite_fall_timer.wait_time = 1.0
	add_child(stalactite_fall_timer)
	
	# 격노 모드 음악 플레이어 설정
	rage_music_intro = AudioStreamPlayer.new()
	rage_music_intro.stream = load("res://스테이지3/sound/rageModeFirst.mp3")
	rage_music_intro.finished.connect(_on_rage_intro_finished)
	add_child(rage_music_intro)

	rage_music_loop = AudioStreamPlayer.new()
	rage_music_loop.stream = load("res://스테이지3/sound/rageMode.mp3")
	rage_music_loop.finished.connect(rage_music_loop.play) # 무한 반복
	add_child(rage_music_loop)

	hide_pattern_timer.start()
	attack_timer.start()

# ==============================================================================
# 유틸리티 함수
# ==============================================================================

# 일회성 사운드를 재생하는 헬퍼 함수
func _play_sound(sound_path, volume_db = 0):
	var sfx_player = AudioStreamPlayer.new()
	sfx_player.stream = load(sound_path)
	sfx_player.volume_db = volume_db
	add_child(sfx_player)
	sfx_player.play()
	sfx_player.finished.connect(sfx_player.queue_free)

# ==============================================================================
# 기믹 로직: 숨기 패턴
# ==============================================================================

func _show_hiding_end_message():
	if hiding_end_message_shown: return
	hiding_end_message_shown = true
	var hiding_end_messages = ["드릴러가 모습을 드러냅니다... 전투에 대비하세요!"]
	GlobalMessageBox.add_message(hiding_end_messages.pick_random())

func start_hiding_pattern():
	if is_dying: return
	
	# --- 모든 횃불을 끄고 잠금 ---
	for torch in get_tree().get_nodes_in_group("torch"):
		if torch.has_method("extinguish_and_lock"):
			torch.extinguish_and_lock()

	var hiding_start_messages = ["드릴러가 모습을 감춥니다... 숨어있는 드릴러를 맞춰 동굴의 붕괴를 막으세요!", "횃불이 꺼져버리다니! 일단 녀석을 먼저 찾아보죠!"]
	GlobalMessageBox.add_message(hiding_start_messages.pick_random())
	emit_signal("hiding_started")
	is_hiding = true
	attack_timer.stop()
	hiding_end_message_shown = false
	hiding_message_timer.wait_time = hiding_duration_timer.wait_time - 1.0
	hiding_message_timer.start()
	var tween = create_tween()
	tween.tween_property(self, "modulate:a", 0.0, 1.0)
	await tween.finished
	$CollisionShape2D.set_deferred("disabled", true)
	$BodyHitbox.set_deferred("monitoring", false)
	$WeakPoint.set_deferred("monitoring", false)
	hide()
	if bright_spot_scene:
		current_bright_spot = bright_spot_scene.instantiate()
		get_tree().root.add_child(current_bright_spot)
		current_bright_spot.connect("hit", Callable(self, "_on_bright_spot_hit"))
	hiding_duration_timer.start()
	var stalactite_manager = get_tree().get_first_node_in_group("stalactite_manager")
	if stalactite_manager and stalactite_manager.has_method("set_respawn_time"):
		stalactite_manager.set_respawn_time(1.0)
	stalactite_fall_timer.start()

func end_hiding_pattern():
	if not is_hiding: return

	# --- 모든 횃불 잠금 해제 ---
	for torch in get_tree().get_nodes_in_group("torch"):
		if torch.has_method("unlock"):
			torch.unlock()

	hiding_message_timer.stop()
	emit_signal("hiding_ended")
	is_hiding = false
	if is_instance_valid(current_bright_spot):
		current_bright_spot.queue_free()
		current_bright_spot = null
	var stalactite_manager = get_tree().get_first_node_in_group("stalactite_manager")
	if stalactite_manager and stalactite_manager.has_method("set_respawn_time"):
		stalactite_manager.set_respawn_time(5.0)
	stalactite_fall_timer.stop()
	visible = true
	modulate.a = 0.0
	$CollisionShape2D.set_deferred("disabled", false)
	$BodyHitbox.set_deferred("monitoring", true)
	$WeakPoint.set_deferred("monitoring", true)
	var tween_boss = create_tween()
	tween_boss.tween_property(self, "modulate:a", 1.0, 2.0)
	await tween_boss.finished
	if not is_dying:
		attack_timer.start()
		hide_pattern_timer.start()

func _on_bright_spot_hit():
	_show_hiding_end_message()
	take_damage(20, true)
	await get_tree().create_timer(2.0).timeout
	end_hiding_pattern()

func _on_stalactite_fall_timer_timeout():
	if is_dying: return
	
	# 지진 효과음 재생 후 카메라 흔들림
	_play_sound("res://스테이지3/sound/earthquake1Sec.mp3", -5)
	var camera = get_tree().get_first_node_in_group("camera")
	if camera and camera.has_method("shake"):
		camera.shake(7.0, 1.0)
	
	var timer = get_tree().create_timer(1.0)
	timer.timeout.connect(_drop_stalactite_after_shake)

func _drop_stalactite_after_shake():
	var manager = get_tree().get_first_node_in_group("stalactite_manager")
	if manager and manager.has_method("drop_stalactite_near_player"):
		manager.drop_stalactite_near_player()

# ==============================================================================
# 데미지 처리 및 사망 로직
# ==============================================================================

func take_damage(amount, force=false):
	if is_dying or (is_hiding and not force): return
	
	# --- 보스 피격 사운드 재생 ---
	_play_sound("res://스테이지3/sound/bossHit.mp3")

	hp -= amount
	emit_signal("health_updated", hp, max_hp)
	var tween = create_tween().set_loops(2)
	tween.tween_property(self, "modulate", Color.RED, 0.1)
	tween.tween_property(self, "modulate", Color.WHITE, 0.1)
	
	if not is_enraged and hp <= max_hp * 0.5:
		is_enraged = true
		emit_signal("enraged")
		var enrage_messages = ["(동굴이 붕괴하기 시작합니다.....)"]
		GlobalMessageBox.add_message(enrage_messages.pick_random())
		
		# --- 격노 모드 음악 재생 ---
		if game_manager and game_manager.has_method("stop_bgm"):
			game_manager.stop_bgm()
		rage_music_intro.play()

	if hp <= 0 and not is_dying:
		is_dying = true
		call_deferred("die")

func _on_rage_intro_finished():
	# 인트로 음악이 끝나면 루프 음악을 재생
	if not is_dying:
		rage_music_loop.play()

# 보스 사망 연출을 처리하는 비동기 함수
func die():
	emit_signal("boss_died")
	
	# 격노 음악을 멈춤
	rage_music_intro.stop()
	rage_music_loop.stop()
	
	# 모든 공격 및 기믹 관련 타이머를 중지
	attack_timer.stop()
	hide_pattern_timer.stop()
	hiding_duration_timer.stop()
	stalactite_fall_timer.stop()
	
	if is_hiding:
		end_hiding_pattern()

	# --- 사망 애니메이션 시작 ---
	# 1. 폭발 효과 및 페이드아웃 애니메이션 시간 계산
	var explosion_interval = 0.15 # 개별 폭발 간 간격
	var set_interval = 1.0       # 폭발 세트 간 간격
	var explosion_set_duration = 8 * explosion_interval # 한 세트(8번 폭발)의 지속 시간
	var total_animation_time = (explosion_set_duration * 3) + (set_interval * 2) # 총 애니메이션 시간

	# 2. 총 애니메이션 시간에 걸쳐 보스가 서서히 사라지는 효과(페이드아웃)
	var fade_tween = create_tween()
	fade_tween.tween_property(self, "modulate:a", 0.0, total_animation_time)

	# 3. 보스 흔들림 효과 (애니메이션 시간 동안 계속)
	var shake_tween = create_tween().set_loops() # 무한 반복
	shake_tween.tween_property(self, "position:x", position.x + 5, 0.125)
	shake_tween.tween_property(self, "position:x", position.x - 5, 0.125)

	# 4. 3세트의 폭발을 순차적으로 실행
	for set_num in 3:
		# 한 세트: 8번의 폭발을 0.15초 간격으로 생성
		for i in 8:
			if explosion_scene:
				var explosion = explosion_scene.instantiate()
				get_parent().add_child(explosion)
				var bounds = collision_shape.shape.get_rect()
				var random_pos = Vector2(randf_range(bounds.position.x, bounds.end.x), randf_range(bounds.position.y, bounds.end.y))
				explosion.global_position = global_position + random_pos
			await get_tree().create_timer(explosion_interval).timeout
		
		# 마지막 세트가 아니면 세트 간 간격만큼 대기
		if set_num < 2:
			await get_tree().create_timer(set_interval).timeout
			
	# 모든 폭발이 끝나면 흔들림 효과를 멈춤
	shake_tween.kill()
	
	# 모든 애니메이션이 끝났음을 GameManager에 알림
	emit_signal("boss_animation_finished")
	
# ==============================================================================
# 공격 로직
# ==============================================================================
	
func _on_attack_timer_timeout():
	if is_dying: return # 사망 시 공격 중지
	if not is_instance_valid(player):
		player = get_tree().get_first_node_in_group("player")
		if not is_instance_valid(player): return
	var distance_to_player = global_position.distance_to(player.global_position)
	var time_to_target = distance_to_player / PROJECTILE_SPEED
	var projectile_target_position = player.global_position + player.velocity * time_to_target
	var ground_y = player.global_position.y + 36.0
	var ground_position = Vector2(projectile_target_position.x, ground_y)
	if hitbox_indicator_scene:
		var warning = hitbox_indicator_scene.instantiate()
		get_tree().root.add_child(warning)
		warning.global_position = ground_position
		if warning.has_method("set_radius"):
			warning.set_radius(EXPLOSION_RADIUS)
		var fire_timer = get_tree().create_timer(WARNING_DURATION)
		fire_timer.timeout.connect(_fire_projectile.bind(projectile_target_position, EXPLOSION_RADIUS))

func _fire_projectile(fire_target_position: Vector2, radius: float):
	# --- 발사 사운드 재생 ---
	_play_sound("res://스테이지3/sound/fireSound.mp3")

	if not is_instance_valid(player) or not bullet_scene: return
	var projectile = bullet_scene.instantiate()
	get_tree().root.add_child(projectile)
	projectile.global_position = fire_point.global_position
	projectile.owner_node = self
	projectile.is_boss_bullet = true
	projectile.collision_layer = 16
	projectile.add_to_group("boss_bullets")
	projectile.collision_mask = projectile.collision_mask & ~8 & ~32 & ~128
	var gravity = ProjectSettings.get_setting("physics/2d/default_gravity")
	var initial_velocity = calculate_parabolic_velocity(fire_point.global_position, fire_target_position, PROJECTILE_SPEED, gravity)
	if initial_velocity == Vector2.ZERO: return
	projectile.linear_velocity = initial_velocity
	if projectile.has_method("set_explosion_radius"):
		projectile.set_explosion_radius(radius)

func calculate_parabolic_velocity(launch_pos: Vector2, target_pos: Vector2, desired_speed: float, gravity: float) -> Vector2:
	var delta = target_pos - launch_pos
	var delta_x = delta.x
	var delta_y = -delta.y
	if abs(delta_x) < 0.1:
		return Vector2(0, -sqrt(2 * gravity * delta_y) if delta_y > 0 else -desired_speed)
	var actual_speed = desired_speed
	var speed_sq = actual_speed * actual_speed
	var gx = gravity * delta_x
	var term_under_sqrt = speed_sq * speed_sq - gravity * (gravity * delta_x * delta_x + 2 * delta_y * speed_sq)
	if term_under_sqrt < 0:
		actual_speed = 1000.0
		speed_sq = actual_speed * actual_speed
		term_under_sqrt = speed_sq * speed_sq - gravity * (gravity * delta_x * delta_x + 2 * delta_y * speed_sq)
		if term_under_sqrt < 0:
			return (target_pos - launch_pos).normalized() * actual_speed
	var sqrt_term = sqrt(term_under_sqrt)
	var high_angle_rad = atan2(speed_sq + sqrt_term, gx)
	var v_y = -sin(high_angle_rad) * actual_speed
	var time_to_peak = -v_y / gravity
	var peak_y = launch_pos.y + (v_y * time_to_peak) + (0.5 * gravity * time_to_peak * time_to_peak)
	var launch_angle_rad
	if peak_y < 0:
		launch_angle_rad = atan2(speed_sq - sqrt_term, gx)
	else:
		launch_angle_rad = high_angle_rad
	var vel_x = cos(launch_angle_rad) * actual_speed
	var vel_y_godot = -sin(launch_angle_rad) * actual_speed
	return Vector2(vel_x, vel_y_godot)

# ==============================================================================
# 시그널 핸들러
# ==============================================================================

func _on_body_hitbox_entered(body):
	if body.is_in_group("player_bullets"):
		take_damage(10)
		if body.has_method("explode"): body.explode()

func _on_weak_point_body_entered(body):
	if body.is_in_group("player_bullets"):
		take_damage(20, true)
		if body.has_method("explode"): body.explode()

func get_health_status():
	return {"current": hp, "max": max_hp}

func set_health(amount):
	hp = amount
	emit_signal("health_updated", hp, max_hp)
	if hp <= 0 and not is_dying:
		is_dying = true
		call_deferred("die")
