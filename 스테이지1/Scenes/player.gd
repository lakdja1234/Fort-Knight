# Player.gd (최종 통합본 - ⚠️ 색상 버그 수정)
extends CharacterBody2D

signal game_over

var gravity = ProjectSettings.get_setting("physics/2d/default_gravity")

# 1. 변수 설정
@export var bullet_scene: PackedScene

# --- 새로운 스킬 씬 변수 ---
# Godot 에디터에서 Player 노드의 인스펙터 창을 통해 아래 씬들을 연결해주세요.
# - Cluster Skill Scene: res://스테이지1/Scenes/clusterplayer.tscn
# - Big Bullet Skill Scene: res://스테이지1/Scenes/bigbulletplayer.tscn
# - Burst Skill Scene: res://스테이지1/Scenes/burstplayer.tscn
@export var cluster_skill_scene: PackedScene
@export var big_bullet_skill_scene: PackedScene
@export var burst_skill_scene: PackedScene


@onready var cannon_pivot = $CannonPivot
@onready var fire_point = $CannonPivot/FirePoint
@onready var progress_bar = $PlayerHUD/HUDContainer/PlayerInfoUI/VBoxContainer/ChargeBar # ProgressBar 노드 (이름 확인!)
@onready var cooldown_timer = $CooldownTimer # Timer 노드 (이름 확인!)
@onready var health_bar = $PlayerHUD/HUDContainer/PlayerInfoUI/VBoxContainer/HealthBar

# --- 새로운 스킬 쿨다운 타이머 ---
# Godot 에디터에서 Player 노드에 아래 이름으로 3개의 Timer 노드를 추가해주세요.
# 각 Timer의 'timeout' 시그널을 이 스크립트의 해당 함수에 연결해야 합니다.
# (예: ClusterCooldownTimer의 timeout -> _on_cluster_cooldown_timer_timeout)
@onready var cluster_cooldown = $ClusterCooldownTimer
@onready var big_bullet_cooldown = $BigBulletCooldownTimer
@onready var burst_cooldown = $BurstCooldownTimer

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
const HEALTH_FULL_COLOR = Color.GREEN
const HEALTH_EMPTY_COLOR = Color.RED

var charging_action: String = "" # Stores the action name being charged, e.g., "fire", "fire_cluster"
var current_power = MIN_FIRE_POWER
var can_fire = true
var max_hp = 30
var hp = max_hp

# --- 새로운 스킬 쿨다운 상태 변수 ---
var can_fire_cluster = true
var can_fire_big_bullet = true
var can_fire_burst = true
var burst_shots_left = 0
var burst_power: float = MIN_FIRE_POWER # Power for the current burst sequence
var lights_disabled = false

func set_lights_disabled(disabled: bool):
	lights_disabled = disabled

# _ready 함수: ProgressBar 설정
func _ready():
	add_to_group("player")
	health_bar.max_value = max_hp
	update_health_bar()
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

func update_health_bar():
	health_bar.value = hp
	
	var health_ratio = float(hp) / float(max_hp)
	var current_color = HEALTH_FULL_COLOR.lerp(HEALTH_EMPTY_COLOR, 1.0 - health_ratio)
	
	var stylebox_original = health_bar.get_theme_stylebox("fill")
	if stylebox_original:
		var stylebox_copy = stylebox_original.duplicate()
		stylebox_copy.bg_color = current_color
		health_bar.add_theme_stylebox_override("fill", stylebox_copy)



# @onready var background = get_node("/root/TitleMap/Background")


var bullet_path_points = []
const BULLET_PATH_DURATION = 2.0

# 2. 물리 업데이트
func _physics_process(delta):
	# 중력 적용
	if not is_on_floor():
		velocity.y += gravity * delta

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
	
	# --- 3. 통합 발사 로직 (NEW) ---
	handle_charging_and_firing(delta)


func handle_charging_and_firing(delta):
	# Define all chargeable actions and their properties
	var chargeable_actions = {
		"fire": {"can_fire": can_fire, "scene": bullet_scene, "is_skill": false},
		"fire_cluster": {"can_fire": can_fire_cluster, "scene": cluster_skill_scene, "is_skill": true},
		"fire_big_bullet": {"can_fire": can_fire_big_bullet, "scene": big_bullet_skill_scene, "is_skill": true},
		"fire_burst": {"can_fire": can_fire_burst, "scene": burst_skill_scene, "is_skill": true}
	}

	# --- Part 1: Handle ongoing charge ---
	if charging_action != "":
		# If the key is still held, increase power
		if Input.is_action_pressed(charging_action):
			current_power = min(current_power + CHARGE_RATE * delta, MAX_FIRE_POWER)
			progress_bar.value = current_power
		
		# If the key is released, fire the projectile
		if Input.is_action_just_released(charging_action):
			var props = chargeable_actions[charging_action]
			
			# Handle firing based on which action was charged
			match charging_action:
				"fire":
					fire_bullet(current_power)
					can_fire = false
					cooldown_timer.start()
					setup_bar_for_cooldown()
				"fire_cluster":
					fire_skill(props.scene, current_power)
					can_fire_cluster = false
					cluster_cooldown.start()
				"fire_big_bullet":
					fire_skill(props.scene, current_power)
					can_fire_big_bullet = false
					big_bullet_cooldown.start()
				"fire_burst":
					_start_burst_fire(current_power)
					can_fire_burst = false
					burst_cooldown.start()

			# Reset charging state
			charging_action = ""

	# --- Part 2: Handle new charge initiation ---
	else:
		# Check if we can start charging a new action
		for action_name in chargeable_actions.keys():
			var props = chargeable_actions[action_name]
			if props.can_fire and Input.is_action_just_pressed(action_name):
				charging_action = action_name
				current_power = MIN_FIRE_POWER
				setup_bar_for_charging() # Set bar to charging mode
				progress_bar.value = current_power
				break # Only start one charge at a time

	# --- Part 3: Update cooldown bar if basic attack is cooling down ---
	if not can_fire and charging_action == "":
		progress_bar.value = cooldown_timer.time_left

	# --- 4. 쉐이더 업데이트 ---
	# (Shader code remains unchanged)


# 3. 발사 함수
func fire_bullet(power: float):
	if not bullet_scene:
		print("!!! 중요: Player 노드의 인스펙터 창에서 'Bullet Scene'을 연결해주세요! !!!")
		return

	var bullet = bullet_scene.instantiate()
	
	# Disable light if commanded by GameManager
	if lights_disabled:
		var light = bullet.get_node_or_null("PointLight2D")
		if light:
			light.visible = false
			
	get_parent().add_child(bullet)
	bullet.owner_node = self

	bullet.global_position = fire_point.global_position
	bullet.global_rotation = cannon_pivot.global_rotation
	bullet.linear_velocity = bullet.transform.x * power

# --- 새로운 스킬 발사 함수 ---
func fire_skill(skill_scene: PackedScene, power: float = 1200.0):
	if not skill_scene:
		print("!!! 중요: Player 노드의 인스펙터 창에서 스킬 씬을 연결해주세요! !!!")
		return

	var bullet = skill_scene.instantiate()
	
	# Disable light if commanded by GameManager
	if lights_disabled:
		var light = bullet.get_node_or_null("PointLight2D")
		if light:
			light.visible = false
			
	get_tree().root.add_child(bullet)

	bullet.global_position = fire_point.global_position
	bullet.global_rotation = cannon_pivot.global_rotation
	bullet.linear_velocity = bullet.transform.x * power


# 4. 쿨다운 타이머(3초)가 끝나면 호출되는 함수
func _on_cooldown_timer_timeout():
	can_fire = true
	setup_bar_for_charging() # 차징 모드 (원래 색)로 변경

# --- 새로운 스킬 쿨다운 타이머 핸들러 ---
func _on_cluster_cooldown_timer_timeout():
	can_fire_cluster = true

func _on_big_bullet_cooldown_timer_timeout():
	can_fire_big_bullet = true

func _on_burst_cooldown_timer_timeout():
	can_fire_burst = true

func take_damage(amount):
	hp -= amount
	hp = max(hp, 0)
	update_health_bar()
	
	# --- Blink Effect ---
	var tween = create_tween().set_loops(2)
	tween.tween_property(self, "modulate", Color.RED, 0.15)
	tween.tween_property(self, "modulate", Color.WHITE, 0.15)
	# --- End Blink Effect ---
	
	if hp <= 0:
		emit_signal("game_over")
		queue_free()

func _on_hitbox_body_entered(body):
	# Handles collision with enemy bullets
	if body.is_in_group("bullets"):
		# The bullet's own script is responsible for exploding.
		# The player script only determines if it should take DIRECT damage.
		# BigBullets only deal explosion damage, not direct damage.
		if not body is BigBullet:
			take_damage(10) 

func _on_hitbox_area_entered(area):
	# Check for falling stalactites
	if area.is_in_group("stalactites") and area.is_falling:
		take_damage(20)
		# The stalactite will queue_free itself upon collision


# --- 3연발 스킬 로직 (MODIFIED) ---
func _start_burst_fire(power: float):
	# 이미 발사 중이면 중복 실행 방지
	if burst_shots_left > 0:
		return
	burst_power = power
	burst_shots_left = 3
	_fire_one_burst_shot()

func _fire_one_burst_shot():
	if burst_shots_left <= 0:
		return

	burst_shots_left -= 1
	
	# 일반 발사 함수(fire_bullet)를 재사용하여 한 발 발사합니다.
	# 3연발은 이제 저장된 burst_power를 사용합니다.
	fire_bullet(burst_power) 
	
	# 남은 총알이 있으면, 0.2초 후에 다음 발사를 예약합니다.
	if burst_shots_left > 0:
		get_tree().create_timer(0.2).timeout.connect(_fire_one_burst_shot)
