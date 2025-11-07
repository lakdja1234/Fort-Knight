extends CharacterBody2D

@export var gravity = ProjectSettings.get_setting("physics/2d/default_gravity")
@export var speed = 300.0
@export var rotation_speed = 100.0
@export var bullet_scene: PackedScene

# --- 쿨다운 관련 변수 ---
@export var charge_speed = 80.0
var current_power = 0.0
var max_power = 100.0 

var is_ready_to_fire = true
@onready var fire_cooldown_timer = $FireCooldownTimer
@onready var power_bar = $PowerBar

# --- (✨ 다시 추가!) 색상 변수 ---
@export var charge_color: Color = Color("GREEN") # 차징 시 녹색
@export var cooldown_color: Color = Color("RED") # 쿨다운 시 빨간색


func _ready():
	power_bar.visible = false
	power_bar.value = 0.0
	fire_cooldown_timer.timeout.connect(_on_fire_cooldown_timeout)
	
	# (✨ 추가) 시작할 때 기본 색상(녹색)으로 설정
	(power_bar.get_theme_stylebox("fill") as StyleBoxFlat).bg_color = charge_color


func _physics_process(delta):
	
	if not is_on_floor():
		velocity.y += gravity * delta
	
	# --- 1. 좌우 이동 처리 ---
	# (이동 코드는 동일)
	var direction = 0.0
	if Input.is_action_pressed("ui_right"):
		direction += 1.0
	if Input.is_action_pressed("ui_left"):
		direction -= 1.0
	velocity.x = direction * speed
	move_and_slide()
	
	# --- 2. 포탑 회전 처리 (a, d 키) ---
	# (회전 코드는 동일)
	var rotation_input = 0.0
	if Input.is_action_pressed("rotate_left"):
		rotation_input -= 1.0
	if Input.is_action_pressed("rotate_right"):
		rotation_input += 1.0
	$TurretPivot.rotation_degrees += rotation_input * rotation_speed * delta
	$TurretPivot.rotation_degrees = clamp($TurretPivot.rotation_degrees, -180, 0)
	
	
	# --- 3. (✨ 수정) 파워 게이지 및 발사/쿨다운 처리 ---
	if is_ready_to_fire:
		# --- 발사 준비 완료 상태 (차징 가능) ---
		if Input.is_action_pressed("fire"):
			power_bar.visible = true
			# (✨ 수정) 스타일박스의 'bg_color'를 녹색으로 설정
			(power_bar.get_theme_stylebox("fill") as StyleBoxFlat).bg_color = charge_color
			
			current_power = min(current_power + charge_speed * delta, max_power)
			power_bar.value = current_power
		
		if Input.is_action_just_released("fire"):
			power_bar.visible = true 
			var power_ratio = current_power / max_power
			fire_bullet(power_ratio)
			
			current_power = 0.0
			is_ready_to_fire = false
			fire_cooldown_timer.start() # 3초 타이머 시작
			
			# (✨ 추가) 발사 직후 색상을 빨간색으로
			(power_bar.get_theme_stylebox("fill") as StyleBoxFlat).bg_color = cooldown_color

		if not Input.is_action_pressed("fire") and not Input.is_action_just_released("fire"):
			if current_power > 0: 
				current_power = 0.0
				power_bar.value = 0.0
			power_bar.visible = false
	
	else:
		# --- 쿨다운 상태 (발사 불가능) ---
		power_bar.visible = true
		# (✨ 수정) 스타일박스의 'bg_color'를 빨간색으로 설정
		(power_bar.get_theme_stylebox("fill") as StyleBoxFlat).bg_color = cooldown_color
		
		var remaining_ratio = fire_cooldown_timer.time_left / fire_cooldown_timer.wait_time
		power_bar.value = remaining_ratio * max_power


# (✨ 수정) 타이머 완료 함수
func _on_fire_cooldown_timeout():
	is_ready_to_fire = true 
	power_bar.visible = false
	# (✨ 추가) 쿨다운이 끝나면 다시 녹색으로 원복
	(power_bar.get_theme_stylebox("fill") as StyleBoxFlat).bg_color = charge_color


func fire_bullet(power_ratio: float):
	# (발사 코드는 동일)
	if not bullet_scene:
		return
	var bullet = bullet_scene.instantiate()
	bullet.global_position = $TurretPivot/Muzzle.global_position
	bullet.global_rotation = $TurretPivot/Muzzle.global_rotation
	bullet.set_power_ratio(power_ratio)
	get_tree().current_scene.add_child(bullet)
