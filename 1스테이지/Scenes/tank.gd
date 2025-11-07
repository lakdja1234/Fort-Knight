extends CharacterBody2D

# --- 1. Code 1의 변수 (이동/회전) ---
# 탱크 이동 속도
@export var speed = 300.0
# 포탑 회전 속도 (초당 각도)
@export var rotation_speed = 100.0


# --- 2. Code 2의 변수 (발사/차징/UI) ---
@export var bullet_scene: PackedScene

# ⚠️ 노드 경로 확인!
# Code 1의 $TurretPivot을 기준으로 합니다.
@onready var turret_pivot = $TurretPivot 
# ⚠️ FirePoint가 $TurretPivot의 자식 노드여야 합니다.
@onready var fire_point = $TurretPivot/FirePoint
@onready var progress_bar = $ChargeBar
@onready var cooldown_timer = $CooldownTimer

# --- 발사 시스템 변수 ---
const MIN_FIRE_POWER = 500.0   # 최소 파워
const MAX_FIRE_POWER = 2000.0  # 최대 파워
const CHARGE_RATE = 1000.0   # 1초당 차오르는 파워 양
const COOLDOWN_DURATION = 3.0 # 쿨다운 시간

# --- 색상 변수 ---
const CHARGE_COLOR = Color.YELLOW
const COOLDOWN_COLOR = Color.RED

var is_charging = false
var current_power = MIN_FIRE_POWER
var can_fire = true


# 3. _ready 함수 (Code 2에서 가져옴)
# ProgressBar 초기 설정
func _ready():
	# ⚠️ 중요: 인스펙터 창에서 'Show Percentage' 체크를 해제하세요!
	progress_bar.show_percentage = false 
	
	# 차징 모드(노란색)로 시작
	setup_bar_for_charging()


# 4. _physics_process (Code 1과 2 통합)
func _physics_process(delta):
	
	# --- [유지] 1. 좌우 이동 처리 (Code 1 방식) ---
	var direction = 0.0
	if Input.is_action_pressed("ui_right"):
		direction += 0.5
	if Input.is_action_pressed("ui_left"):
		direction -= 0.5

	velocity.x = direction * speed
	move_and_slide()

	
	# --- [유지] 2. 포탑 회전 처리 (Code 1 방식) ---
	var rotation_input = 0.0
	if Input.is_action_pressed("rotate_left"):
		rotation_input -= 1.0 # 위 (반시계 방향)
	if Input.is_action_pressed("rotate_right"):
		rotation_input += 1.0 # 아래 (시계 방향)
		
	# $TurretPivot 노드를 회전시킵니다.
	turret_pivot.rotation_degrees += rotation_input * rotation_speed * delta
	# 포탑 회전 각도 제한
	turret_pivot.rotation_degrees = clamp(turret_pivot.rotation_degrees, -180, 0)

	
	# --- [추가] 3. 통합 발사/쿨다운 로직 (Code 2 방식) ---
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
			
			cooldown_timer.start(COOLDOWN_DURATION) # 쿨다운 시간 설정
			setup_bar_for_cooldown() # 쿨다운 모드 (빨간색, 3초)로 변경
	
	else: # [B] 발사 불가능 (쿨다운 중)
		progress_bar.value = cooldown_timer.time_left


# 5. ProgressBar 설정 함수 (Code 2에서 가져옴)

# ProgressBar를 '차징' 모드(0% ~ 100%)로 설정하는 함수
func setup_bar_for_charging():
	progress_bar.min_value = MIN_FIRE_POWER
	progress_bar.max_value = MAX_FIRE_POWER
	progress_bar.value = MIN_FIRE_POWER
	
	var stylebox_original = progress_bar.get_theme_stylebox("foreground")
	if stylebox_original:
		var stylebox_copy = stylebox_original.duplicate()
		stylebox_copy.bg_color = CHARGE_COLOR
		progress_bar.add_theme_stylebox_override("foreground", stylebox_copy)
	else:
		print("경고: ChargeBar의 'Theme Overrides' > 'Styles' > 'Foreground'에 StyleBoxFlat이 설정되지 않았습니다.")

# ProgressBar를 '쿨다운' 모드(3초 ~ 0초)로 설정하는 함수
func setup_bar_for_cooldown():
	progress_bar.min_value = 0.0
	progress_bar.max_value = COOLDOWN_DURATION
	progress_bar.value = COOLDOWN_DURATION # 3초로 꽉 채움
	
	var stylebox_original = progress_bar.get_theme_stylebox("foreground")
	if stylebox_original:
		var stylebox_copy = stylebox_original.duplicate()
		stylebox_copy.bg_color = COOLDOWN_COLOR
		progress_bar.add_theme_stylebox_override("foreground", stylebox_copy)
	else:
		print("경고: ChargeBar의 'Theme Overrides' > 'Styles' > 'Foreground'에 StyleBoxFlat이 설정되지 않았습니다.")


# 6. 발사 함수 (Code 2에서 가져옴, 노드 이름 수정)
func fire_bullet(power: float):
	if not bullet_scene:
		print("!!! 중요: Player 노드의 인스펙터 창에서 'Bullet Scene'을 연결해주세요! !!!")
		return

	var bullet = bullet_scene.instantiate()
	get_parent().add_child(bullet)

	bullet.global_position = fire_point.global_position
	bullet.global_rotation = turret_pivot.global_rotation
	bullet.linear_velocity = bullet.transform.x * power


# 7. 쿨다운 타이머 시그널 함수 (Code 2에서 가져옴)
func _on_cooldown_timer_timeout():
	can_fire = true
	setup_bar_for_charging() # 차징 모드 (노란색)로 변경
