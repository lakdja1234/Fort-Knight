# Player.gd
extends CharacterBody2D

# 플레이어의 게임 오버 상태를 알리는 시그널
signal game_over

# ==============================================================================
# 1. 변수 및 상수 설정
# ==============================================================================

# --- 외부 씬 참조 ---
var bullet_scene: PackedScene # 발사할 총알 씬

# --- HUD 및 노드 참조 ---
@onready var health_bar = $PlayerHUD/HUDContainer/PlayerInfoUI/VBoxContainer/HealthBar
@onready var charge_bar = $PlayerHUD/HUDContainer/PlayerInfoUI/VBoxContainer/ChargeBar
@onready var cooldown_timer = $CooldownTimer # 기본 발사 쿨다운 타이머
@onready var cannon_pivot = $CannonPivot # 포신 회전의 중심점
@onready var fire_point = $CannonPivot/FirePoint # 총알이 생성될 위치
@onready var trajectory_drawer = $TrajectoryDrawer # 포탄 궤적을 그리는 노드
@onready var skill_slot_1 = get_node("/root/TitleMap/GameUI/PlayerUI/SkillSlot1") # 스킬 슬롯 UI 참조

# --- 사운드 플레이어 ---
var barrel_sound_player: AudioStreamPlayer
var charge_sound_player: AudioStreamPlayer

# --- 이동 상수 ---
var MAX_SPEED = 300.0 # 스킬 사용 시 변경될 수 있으므로 const 대신 var로 선언
const ACCELERATION = 1000.0 # 가속도
const FRICTION = 1000.0 # 마찰력

# --- 조준 상수 ---
const AIM_SPEED = 2.0 # 포신 회전 속도

# --- 발사 시스템 상수 ---
const MIN_FIRE_POWER = 500.0 # 최소 발사 파워
const MAX_FIRE_POWER = 1200.0 # 최대 발사 파워
const CHARGE_RATE = 700.0    # 초당 파워 충전 속도
const COOLDOWN_DURATION = 2.0 # 발사 후 재사용 대기시간

# --- 드릴 스킬 상수 ---
const DRILL_COOLDOWN = 30.0 # 드릴 스킬 재사용 대기시간
const DRILL_DURATION = 3.0 # 드릴 스킬 효과 지속시간
const DRILL_SPEED_MULTIPLIER = 1.5 # 드릴 스킬 사용 시 속도 증가 배율

# --- 상태 변수 ---
var is_charging = false # 현재 발사 파워를 모으고 있는지 여부
var current_power = MIN_FIRE_POWER # 현재 충전된 파워
var charge_direction = 1 # 차지 방향 (1: 증가, -1: 감소)
var can_fire = true # 기본 발사 가능 여부
var max_hp = 100 # 최대 체력
var hp = max_hp # 현재 체력
var is_drill_active = false # 드릴 스킬이 활성화되었는지 여부
var original_max_speed: float # 스킬 사용 후 복원을 위한 원래 최대 속도
var drill_cooldown_timer: Timer # 드릴 스킬 재사용 대기시간 타이머
var drill_duration_timer: Timer # 드릴 스킬 지속시간 타이머
var player_bright_spot_scene: PackedScene = preload("res://스테이지3/PlayerBrightSpot.tscn") # 드릴 스킬 시각 효과 씬
var current_bright_spot_instance: Node2D = null # 현재 생성된 스킬 이펙트 인스턴스

# ==============================================================================
# 2. Godot 내장 함수
# ==============================================================================

# _ready: 노드가 씬에 처음 추가될 때 한 번 호출되는 Godot 내장 함수입니다.
func _ready():
	add_to_group("player") # "player" 그룹에 자신을 추가하여 다른 노드에서 쉽게 찾을 수 있게 합니다.
	bullet_scene = load("res://스테이지3/Bullet.tscn")
	health_bar.max_value = max_hp
	update_health_bar()
	setup_bar_for_charging()

	# 스킬 사용 후 복원을 위해 원래 최대 속도를 저장합니다.
	original_max_speed = MAX_SPEED
	
	# --- 지속성 사운드 플레이어 설정 ---
	# 1. 포신 이동 사운드
	barrel_sound_player = AudioStreamPlayer.new()
	barrel_sound_player.stream = load("res://스테이지3/sound/movingBarrel.mp3")
	barrel_sound_player.finished.connect(barrel_sound_player.play) # 반복 재생
	add_child(barrel_sound_player)
	
	# 2. 차지 사운드
	charge_sound_player = AudioStreamPlayer.new()
	charge_sound_player.stream = load("res://스테이지3/sound/charge6s.mp3")
	charge_sound_player.finished.connect(charge_sound_player.play) # 반복 재생
	add_child(charge_sound_player)


	# --- 드릴 스킬 타이머 설정 ---
	# 1. 쿨다운 타이머: 스킬을 다시 사용하기까지의 전체 대기시간을 관리합니다.
	drill_cooldown_timer = Timer.new()
	drill_cooldown_timer.wait_time = DRILL_COOLDOWN
	drill_cooldown_timer.one_shot = true # 한 번만 실행됩니다.
	drill_cooldown_timer.timeout.connect(_on_drill_cooldown_finished)
	add_child(drill_cooldown_timer)

	# 2. 지속시간 타이머: 스킬 효과가 유지되는 시간을 관리합니다.
	drill_duration_timer = Timer.new()
	drill_duration_timer.wait_time = DRILL_DURATION
	drill_duration_timer.one_shot = true
	drill_duration_timer.timeout.connect(deactivate_drill)
	add_child(drill_duration_timer)

# _physics_process: 물리 연산과 관련된 로직을 처리하는 Godot 내장 함수입니다. 고정된 주기로 호출됩니다.
func _physics_process(delta):
	# --- 스킬 활성화 처리 ---
	# 'skill_1' 액션이 입력되고 쿨다운이 끝난 상태(타이머가 멈춘 상태)일 때 스킬을 활성화합니다.
	if Input.is_action_just_pressed("skill_1") and drill_cooldown_timer.is_stopped():
		activate_drill()

	# 드릴 스킬이 활성화된 동안, 플레이어를 따라 '파란 점' 이펙트가 움직이도록 위치를 계속 업데이트합니다.
	if is_drill_active and is_instance_valid(current_bright_spot_instance):
		current_bright_spot_instance.global_position = global_position

	# --- 이동 처리 ---
	var direction = Input.get_axis("move_left", "move_right")
	if is_drill_active:
		# 드릴 스킬 활성화 시: 관성 없이 즉시 최대 속도로 이동
		velocity.x = direction * MAX_SPEED
	else:
		# 평상시: 가속 및 감속(관성)을 적용하여 부드럽게 이동
		if direction:
			velocity.x = move_toward(velocity.x, direction * MAX_SPEED, ACCELERATION * delta)
		else:
			velocity.x = move_toward(velocity.x, 0.0, FRICTION * delta)
	move_and_slide()

	# --- 포신 각도 조절 및 사운드 ---
	var aim_direction = Input.get_axis("aim_up", "aim_down")
	if aim_direction != 0:
		cannon_pivot.rotation += aim_direction * AIM_SPEED * delta
		cannon_pivot.rotation = clamp(cannon_pivot.rotation, -PI, 0.0)
		if not barrel_sound_player.playing:
			barrel_sound_player.play()
	else:
		if barrel_sound_player.playing:
			barrel_sound_player.stop()

	# --- 발사 및 차지 로직 ---
	if can_fire and not is_drill_active:
		if Input.is_action_just_pressed("fire"):
			is_charging = true
			charge_sound_player.play()
			current_power = MIN_FIRE_POWER
			charge_direction = 1
			charge_bar.value = current_power

		if is_charging and Input.is_action_pressed("fire"):
			current_power += CHARGE_RATE * charge_direction * delta
			if current_power >= MAX_FIRE_POWER:
				current_power = MAX_FIRE_POWER
				charge_direction = -1
			elif current_power <= MIN_FIRE_POWER:
				current_power = MIN_FIRE_POWER
				charge_direction = 1
			charge_bar.value = current_power
			update_trajectory_guide()

		if is_charging and Input.is_action_just_released("fire"):
			is_charging = false
			charge_sound_player.stop()
			can_fire = false 
			trajectory_drawer.update_trajectory([])
			fire_bullet(current_power)
			cooldown_timer.start()
			setup_bar_for_cooldown()
	else: 
		if not is_drill_active:
			charge_bar.value = cooldown_timer.time_left

	# --- 스킬 UI 업데이트 ---
	if not drill_cooldown_timer.is_stopped():
		skill_slot_1.update_display(drill_cooldown_timer.time_left)

# ==============================================================================
# 3. 커스텀 함수
# ==============================================================================

# --- 발사 및 데미지 관련 ---
# fire_bullet: 총알을 발사하는 함수
func fire_bullet(power: float):
	# --- 발사 사운드 재생 ---
	_play_sound("res://스테이지3/sound/fireSound.mp3", -3)
	if not bullet_scene: return
	var bullet = bullet_scene.instantiate()
	get_parent().add_child(bullet)
	bullet.owner_node = self
	bullet.global_position = fire_point.global_position
	bullet.global_rotation = cannon_pivot.global_rotation
	bullet.linear_velocity = bullet.transform.x * power

# take_damage: 데미지를 입었을 때 처리하는 함수
func take_damage(amount):
	if is_drill_active: return
	# --- 플레이어 피격 사운드 재생 ---
	_play_sound("res://스테이지3/sound/playerHit.mp3", 5)
	hp -= amount
	hp = max(hp, 0)
	update_health_bar()
	var tween = create_tween().set_loops(2)
	tween.tween_property(self, "modulate", Color.RED, 0.15)
	tween.tween_property(self, "modulate", Color.WHITE, 0.15)
	if hp <= 0:
		await tween.finished
		emit_signal("game_over")
		queue_free()

# --- HUD 관련 ---
func update_health_bar():
	health_bar.value = hp
	var health_ratio = float(hp) / float(max_hp)
	var current_color = Color.GREEN.lerp(Color.RED, 1.0 - health_ratio)
	var stylebox_copy = health_bar.get_theme_stylebox("fill").duplicate()
	stylebox_copy.bg_color = current_color
	health_bar.add_theme_stylebox_override("fill", stylebox_copy)

func setup_bar_for_charging():
	charge_bar.min_value = MIN_FIRE_POWER
	charge_bar.max_value = MAX_FIRE_POWER
	charge_bar.value = MIN_FIRE_POWER
	var stylebox_copy = charge_bar.get_theme_stylebox("fill").duplicate()
	stylebox_copy.bg_color = Color("orange")
	charge_bar.add_theme_stylebox_override("fill", stylebox_copy)

func setup_bar_for_cooldown():
	charge_bar.min_value = 0.0
	charge_bar.max_value = COOLDOWN_DURATION
	charge_bar.value = COOLDOWN_DURATION
	var stylebox_copy = charge_bar.get_theme_stylebox("fill").duplicate()
	stylebox_copy.bg_color = Color.RED
	charge_bar.add_theme_stylebox_override("fill", stylebox_copy)

# --- 충돌 및 타이머 신호 처리 ---
func _on_cooldown_timer_timeout():
	can_fire = true
	setup_bar_for_charging()

func _on_hitbox_body_entered(body):
	if body.is_in_group("bullets"):
		take_damage(10)
		if body.has_method("explode"): body.explode()
		else: body.queue_free()
	elif body.is_in_group("boss_bullets"):
		take_damage(10)
		if body.has_method("explode"):
			body.explode()
		else:
			body.queue_free()

func _on_hitbox_area_entered(area):
	if area.is_in_group("stalactites") and area.is_falling:
		take_damage(20)

# --- 유틸리티 함수 ---
func _play_sound(sound_path, volume_db = 0):
	var sfx_player = AudioStreamPlayer.new()
	sfx_player.stream = load(sound_path)
	sfx_player.volume_db = volume_db
	add_child(sfx_player)
	sfx_player.play()
	sfx_player.finished.connect(sfx_player.queue_free)

# --- 드릴 스킬 관련 ---
func activate_drill():
	_play_sound("res://스테이지3/sound/drillSkill.mp3", -5)
	is_drill_active = true
	drill_duration_timer.start()
	drill_cooldown_timer.start()
	skill_slot_1.start_cooldown(DRILL_COOLDOWN)
	$CannonPivot.hide()
	$Sprite2D.hide()
	$PointLight2D.hide()
	$CollisionShape2D.set_deferred("disabled", true)
	$Hitbox/CollisionShape2D.set_deferred("disabled", true)
	MAX_SPEED = original_max_speed * DRILL_SPEED_MULTIPLIER
	if player_bright_spot_scene:
		current_bright_spot_instance = player_bright_spot_scene.instantiate()
		get_parent().add_child(current_bright_spot_instance)
		current_bright_spot_instance.global_position = global_position

func deactivate_drill():
	is_drill_active = false
	if is_instance_valid(current_bright_spot_instance):
		current_bright_spot_instance.queue_free()
	MAX_SPEED = original_max_speed
	$CollisionShape2D.set_deferred("disabled", false)
	$Hitbox/CollisionShape2D.set_deferred("disabled", false)
	var tween = create_tween()
	$CannonPivot.modulate.a = 0
	$Sprite2D.modulate.a = 0
	$PointLight2D.modulate.a = 0
	$CannonPivot.show()
	$Sprite2D.show()
	$PointLight2D.show()
	tween.tween_property($CannonPivot, "modulate:a", 1.0, 1.0)
	tween.parallel().tween_property($Sprite2D, "modulate:a", 1.0, 1.0)
	tween.parallel().tween_property($PointLight2D, "modulate:a", 1.0, 1.0)

func _on_drill_cooldown_finished():
	skill_slot_1.update_display(0)
	GlobalMessageBox.add_message("Drill 스킬 사용 가능합니다!")

# --- 궤적 예측 ---
func update_trajectory_guide():
	var points = calculate_trajectory_points()
	var local_points = []
	for p in points:
		local_points.append(to_local(p))
	trajectory_drawer.update_trajectory(local_points)

func calculate_trajectory_points() -> Array:
	var points = []
	var gravity = ProjectSettings.get_setting("physics/2d/default_gravity")
	var current_pos = fire_point.global_position
	var current_velocity = Vector2.RIGHT.rotated(cannon_pivot.global_rotation) * current_power
	var time_step = 0.05
	var max_steps = 100
	var space_state = get_world_2d().direct_space_state
	var query = PhysicsRayQueryParameters2D.new()
	query.exclude = [self]
	query.collision_mask = 1
	
	for i in range(max_steps):
		current_velocity.y += gravity * time_step
		var next_pos = current_pos + current_velocity * time_step
		query.from = current_pos
		query.to = next_pos
		var result = space_state.intersect_ray(query)
		if result:
			points.append(result.position)
			break
		else:
			if i % 2 == 0:
				points.append(current_pos)
			current_pos = next_pos
	return points
