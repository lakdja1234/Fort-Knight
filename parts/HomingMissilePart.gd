extends Node

# 스킬 파츠가 공통적으로 가질 신호들
signal cooldown_started(duration)
signal cooldown_progress(time_left)
signal cooldown_finished

# --- 스킬 설정 ---
const HOMING_COOLDOWN = 10.0
const HomingMissileScene = preload("res://스테이지2/player_homing_missile.tscn")

@onready var cooldown_timer: Timer = $Timer
var is_on_cooldown = false
var player = null

func _ready():
	# 부모(SkillSlot)의 부모(Player)에 대한 참조를 저장
	# 이 파츠는 항상 플레이어의 '스킬 슬롯' 자식으로 존재해야 합니다.
	call_deferred("_initialize_player_reference") # Defer this until scene tree is fully ready

	cooldown_timer.wait_time = HOMING_COOLDOWN
	cooldown_timer.one_shot = true
	cooldown_timer.timeout.connect(_on_cooldown_timer_timeout)

func _initialize_player_reference():
	# This function will be called after _ready() when the scene tree is more stable
	player = get_parent().get_parent()
	if not is_instance_valid(player):
		printerr("HomingMissilePart Error: Player reference is invalid after deferred initialization.")
		return
	if not player.has_method("set_next_projectile"):
		printerr("HomingMissilePart Error: Parent Player node does not have 'set_next_projectile' method.")

func _physics_process(_delta):
	if is_on_cooldown:
		emit_signal("cooldown_progress", cooldown_timer.time_left)

# 플레이어가 이 함수를 호출하여 스킬을 활성화
func activate():
	if is_on_cooldown:
		print("Homing Missile is on cooldown.")
		return

	if not is_instance_valid(player):
		printerr("HomingMissilePart Error: Invalid player reference.")
		return

	# 플레이어에게 다음 기본 공격 시 유도 미사일 발사를 요청.
	player.set_next_projectile(HomingMissileScene, 1500.0, self) # Pass 'self' as the skill_node

	# 쿨타임은 발사 후 시작되므로, 여기서 시작하지 않습니다.
	# print("Homing Missile Part prepared for next shot.") # Optional: for debugging

func _on_shot_fired():
	# 발사체가 실제로 발사된 후 쿨타임 시작
	is_on_cooldown = true
	cooldown_timer.start()
	emit_signal("cooldown_started", HOMING_COOLDOWN)
	print("Homing Missile Part shot fired, cooldown started.")

func _on_cooldown_timer_timeout():
	is_on_cooldown = false
	emit_signal("cooldown_finished")
	print("Homing Missile Part cooldown finished.")
