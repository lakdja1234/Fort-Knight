extends CharacterBody2D

@export var min_speed = 100.0
@export var max_speed = 800.0

# --- (✨ 이 줄을 추가하세요!) ---
@export var explosion_scene: PackedScene

# 1. (추가) 중력 변수를 가져옵니다.
@export var gravity = ProjectSettings.get_setting("physics/2d/default_gravity")

# set_power_ratio는 탱크가 호출하여 '초기 속도'를 설정합니다.
func set_power_ratio(power_ratio: float):
	var current_speed = lerp(min_speed, max_speed, power_ratio)
	# velocity는 CharacterBody2D에 내장된 속성입니다.
	# transform.x (발사 방향)에 속도를 곱해 초기 속도를 설정합니다.
	velocity = transform.x * current_speed

func _physics_process(delta):
	if not is_on_floor():
		velocity.y += gravity * delta
	
	# (✨ 수정) move_and_slide()는 충돌 시 물리 정보를 반환합니다.
	var collision_info = move_and_slide()

	# (✨ 추가) 만약 충돌이 발생했다면
	if collision_info:
		# 폭발 애니메이션을 생성하고 재생합니다.
		spawn_explosion()
		# 포탄은 자신을 제거합니다.
		queue_free()


func _on_screen_exited():
	queue_free()

# (✨ 추가) 폭발 씬을 생성하는 함수
func spawn_explosion():
	if not explosion_scene:
		return
		
	var explosion = explosion_scene.instantiate()
	# 현재 포탄의 위치에 폭발을 생성합니다.
	explosion.global_position = global_position
	
	# 현재 씬에 폭발 노드를 추가합니다.
	get_tree().current_scene.add_child(explosion)
