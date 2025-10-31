# Player.gd (최종 통합본 - ⚠️ 색상 버그 수정)
extends CharacterBody2D

# 1. 변수 설정
@export var bullet_scene: PackedScene

@onready var cannon_pivot = $CannonPivot
@onready var fire_point = $CannonPivot/FirePoint
@onready var progress_bar = $ChargeBar # ProgressBar 노드 (이름 확인!)
@onready var cooldown_timer = $CooldownTimer # Timer 노드 (이름 확인!)

# --- 이동 변수 ---
const MAX_SPEED = 300.0
const ACCELERATION = 1000.0
const FRICTION = 1000.0

# --- 조준 변수 ---
const AIM_SPEED = 2.0

# --- 통합 시스템 변수 ---
const MIN_FIRE_POWER = 500.0   # 최소 파워
const MAX_FIRE_POWER = 2000.0  # 최대 파워
const CHARGE_RATE = 1000.0   # 1초당 차오르는 파워 양
const COOLDOWN_DURATION = 3.0 # 쿨다운 시간

# --- 색상 변수 ---
const CHARGE_COLOR = Color.YELLOW # 차징 시 색상 (원하는 색으로 변경하세요)
const COOLDOWN_COLOR = Color.RED   # 쿨다운 시 색상

var is_charging = false
var current_power = MIN_FIRE_POWER
var can_fire = true


# _ready 함수: ProgressBar 설정
func _ready():
	# ⚠️ 중요: 인스펙터 창에서 'Show Percentage' 체크를 해제하세요!
	progress_bar.show_percentage = false 
	
	# 차징 모드(노란색)로 시작
	setup_bar_for_charging()


# ProgressBar를 '차징' 모드(0% ~ 100%)로 설정하는 함수
func setup_bar_for_charging():
	progress_bar.min_value = MIN_FIRE_POWER
	progress_bar.max_value = MAX_FIRE_POWER
	progress_bar.value = MIN_FIRE_POWER
	
	# "foreground" 스타일을 가져옵니다.
	var stylebox_original = progress_bar.get_theme_stylebox("foreground")
	if stylebox_original:
		# 1. 스타일을 복제(duplicate)해서 고유한 사본을 만듭니다.
		var stylebox_copy = stylebox_original.duplicate()
		# 2. 사본의 색상을 '차징 색' (노란색)으로 변경합니다.
		stylebox_copy.bg_color = CHARGE_COLOR
		# 3. 이 사본을 'override' (덮어쓰기)로 적용합니다.
		progress_bar.add_theme_stylebox_override("foreground", stylebox_copy)
	else:
		print("경고: ChargeBar의 'Theme Overrides' > 'Styles' > 'Foreground'에 StyleBoxFlat이 설정되지 않았습니다.")


# ProgressBar를 '쿨다운' 모드(3초 ~ 0초)로 설정하는 함수
func setup_bar_for_cooldown():
	progress_bar.min_value = 0.0
	progress_bar.max_value = COOLDOWN_DURATION
	progress_bar.value = COOLDOWN_DURATION # 3초로 꽉 채움
	
	# "foreground" 스타일을 가져옵니다.
	var stylebox_original = progress_bar.get_theme_stylebox("foreground")
	if stylebox_original:
		# 1. 스타일을 다시 복제합니다.
		var stylebox_copy = stylebox_original.duplicate()
		# 2. 사본의 색상을 '쿨다운 색' (빨간색)으로 변경합니다.
		stylebox_copy.bg_color = COOLDOWN_COLOR
		# 3. 이 사본을 'override' (덮어쓰기)로 적용합니다.
		progress_bar.add_theme_stylebox_override("foreground", stylebox_copy)
	else:
		print("경고: ChargeBar의 'Theme Overrides' > 'Styles' > 'Foreground'에 StyleBoxFlat이 설정되지 않았습니다.")


# 2. 물리 업데이트
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
			progress_bar.value = current_power

		# [A-2] 차징 중
		if is_charging and Input.is_action_pressed("fire"):
			current_power += CHARGE_RATE * delta
			current_power = min(current_power, MAX_FIRE_POWER)
			progress_bar.value = current_power

		# [A-3] 발사 및 쿨다운 시작
		if is_charging and Input.is_action_just_released("fire"):
			is_charging = false
			can_fire = false 
			
			fire_bullet(current_power)
			
			cooldown_timer.start()
			setup_bar_for_cooldown() # 쿨다운 모드 (빨간색, 3초)로 변경
	
	else: # [B] 발사 불가능 (쿨다운 중)
		progress_bar.value = cooldown_timer.time_left


# 3. 발사 함수
func fire_bullet(power: float):
	if not bullet_scene:
		print("!!! 중요: Player 노드의 인스펙터 창에서 'Bullet Scene'을 연결해주세요! !!!")
		return

	var bullet = bullet_scene.instantiate()
	get_parent().add_child(bullet)

	bullet.global_position = fire_point.global_position
	bullet.global_rotation = cannon_pivot.global_rotation
	bullet.linear_velocity = bullet.transform.x * power


# 4. 쿨다운 타이머(3초)가 끝나면 호출되는 함수
func _on_cooldown_timer_timeout():
	can_fire = true
	setup_bar_for_charging() # 차징 모드 (원래 색)로 변경
