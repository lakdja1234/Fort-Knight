# Player.gd (HUD 재설계 및 오류 수정 버전)
extends CharacterBody2D

signal game_over

# 1. 변수 설정
@export var bullet_scene: PackedScene

# --- HUD 및 노드 참조 ---
@onready var health_bar = $PlayerHUD/HUDContainer/PlayerInfoUI/VBoxContainer/HealthBar
@onready var charge_bar = $PlayerHUD/HUDContainer/PlayerInfoUI/VBoxContainer/ChargeBar
@onready var cooldown_timer = $CooldownTimer
@onready var cannon_pivot = $CannonPivot
@onready var fire_point = $CannonPivot/FirePoint

# --- 이동 변수 ---
const MAX_SPEED = 300.0
const ACCELERATION = 1000.0
const FRICTION = 1000.0

# --- 조준 변수 ---
const AIM_SPEED = 2.0

# --- 발사 시스템 변수 ---
const MIN_FIRE_POWER = 500.0
const MAX_FIRE_POWER = 2000.0
const CHARGE_RATE = 1000.0
const COOLDOWN_DURATION = 2.0

# --- 색상 변수 ---
const CHARGE_COLOR = Color("orange") # 차지 시 색상 (주황색)
const COOLDOWN_COLOR = Color.RED   # 쿨다운 시 색상
const HEALTH_FULL_COLOR = Color.GREEN
const HEALTH_EMPTY_COLOR = Color.RED

# --- 상태 변수 ---
var is_charging = false
var current_power = MIN_FIRE_POWER
var can_fire = true
var max_hp = 100
var hp = max_hp


# _ready: 초기화
func _ready():
	add_to_group("player")
	
	# 체력바 초기화
	health_bar.max_value = max_hp
	update_health_bar()
	
	# 차지바 초기화 (차징 모드로 시작)
	setup_bar_for_charging()


# --- 체력바 관리 ---
func update_health_bar():
	health_bar.value = hp
	
	# 체력 비율 계산 (0.0 ~ 1.0)
	var health_ratio = float(hp) / float(max_hp)
	
	# 색상 보간
	var current_color = HEALTH_FULL_COLOR.lerp(HEALTH_EMPTY_COLOR, 1.0 - health_ratio)
	
	# 체력바 스타일에 새 색상 적용
	var stylebox_original = health_bar.get_theme_stylebox("fill")
	if stylebox_original:
		var stylebox_copy = stylebox_original.duplicate()
		stylebox_copy.bg_color = current_color
		health_bar.add_theme_stylebox_override("fill", stylebox_copy)


# --- 차지/쿨다운 바 관리 ---

# ProgressBar를 '차징' 모드로 설정
func setup_bar_for_charging():
	charge_bar.fill_mode = ProgressBar.FILL_BEGIN_TO_END # 왼쪽에서 오른쪽으로 채우기
	charge_bar.min_value = MIN_FIRE_POWER
	charge_bar.max_value = MAX_FIRE_POWER
	charge_bar.value = MIN_FIRE_POWER
	
	var stylebox_original = charge_bar.get_theme_stylebox("fill")
	if stylebox_original:
		var stylebox_copy = stylebox_original.duplicate()
		stylebox_copy.bg_color = CHARGE_COLOR
		charge_bar.add_theme_stylebox_override("fill", stylebox_copy)

# ProgressBar를 '쿨다운' 모드로 설정
func setup_bar_for_cooldown():
	charge_bar.fill_mode = ProgressBar.FILL_BEGIN_TO_END # 왼쪽에서 오른쪽으로 채우기
	charge_bar.min_value = 0.0
	charge_bar.max_value = COOLDOWN_DURATION
	charge_bar.value = COOLDOWN_DURATION
	
	var stylebox_original = charge_bar.get_theme_stylebox("fill")
	if stylebox_original:
		var stylebox_copy = stylebox_original.duplicate()
		stylebox_copy.bg_color = COOLDOWN_COLOR
		charge_bar.add_theme_stylebox_override("fill", stylebox_copy)


@onready var background = get_node_or_null("/root/TitleMap/Background")

var bullet_path_points = []
const BULLET_PATH_DURATION = 2.0


# _physics_process: 매 프레임 실행
func _physics_process(delta):
	
	# --- 1. 이동 처리 ---
	var direction = Input.get_axis("move_left", "move_right")
	if direction:
		velocity.x = move_toward(velocity.x, direction * MAX_SPEED, ACCELERATION * delta)
	else:
		velocity.x = move_toward(velocity.x, 0.0, FRICTION * delta)
	move_and_slide()

	# --- 2. 포신 각도 조절 ---
	var aim_direction = Input.get_axis("aim_up", "aim_down")
	cannon_pivot.rotation += aim_direction * AIM_SPEED * delta
	cannon_pivot.rotation = clamp(cannon_pivot.rotation, -PI, 0.0)
	
	
	# --- 3. 통합 발사/쿨다운 로직 ---
	if can_fire: # [A] 발사 가능 상태
		# [A-1] 차징 시작
		if Input.is_action_just_pressed("fire"):
			is_charging = true
			current_power = MIN_FIRE_POWER
			charge_bar.value = current_power

		# [A-2] 차징 중
		if is_charging and Input.is_action_pressed("fire"):
			current_power += CHARGE_RATE * delta
			current_power = min(current_power, MAX_FIRE_POWER)
			charge_bar.value = current_power

		# [A-3] 발사 및 쿨다운 시작
		if is_charging and Input.is_action_just_released("fire"):
			is_charging = false
			can_fire = false 
			
			fire_bullet(current_power)
			
			cooldown_timer.start()
			setup_bar_for_cooldown()
	
	else: # [B] 발사 불가능 (쿨다운 중)
		charge_bar.value = cooldown_timer.time_left

	# --- 4. 쉐이더 업데이트 ---
	var game_manager = get_node_or_null("/root/TitleMap/GameManager")
	if background and background.material and game_manager and not game_manager.is_darkness_active:
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


# 발사 함수
func fire_bullet(power: float):
	if not bullet_scene:
		return

	var bullet = bullet_scene.instantiate()
	get_parent().add_child(bullet)
	bullet.owner_node = self

	bullet.global_position = fire_point.global_position
	bullet.global_rotation = cannon_pivot.global_rotation
	bullet.linear_velocity = bullet.transform.x * power


# 쿨다운 종료 시 호출
func _on_cooldown_timer_timeout():
	can_fire = true
	setup_bar_for_charging()


# 데미지 처리 함수
func take_damage(amount):
	hp -= amount
	hp = max(hp, 0) # HP가 0 미만으로 내려가지 않도록
	update_health_bar() # 체력바 업데이트
	
	# --- Blink Effect ---
	var tween = create_tween().set_loops(2)
	tween.tween_property(self, "modulate", Color.RED, 0.15)
	tween.tween_property(self, "modulate", Color.WHITE, 0.15)
	
	if hp <= 0:
		await tween.finished # 깜빡임 효과가 끝날 때까지 대기
		emit_signal("game_over")
		queue_free()

# 충돌 처리
func _on_hitbox_body_entered(body):
	if body.is_in_group("bullets"):
		take_damage(10)
		if body.has_method("explode"):
			body.explode()
		else:
			body.queue_free()

func _on_hitbox_area_entered(area):
	if area.is_in_group("stalactites") and area.is_falling:
		take_damage(20)
