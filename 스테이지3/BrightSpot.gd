extends CharacterBody2D

signal hit

const SPEED = 450.0
const WANDER_RATE = PI # 초당 회전할 수 있는 최대 각도 (라디안)

@onready var sprite = find_child("Sprite2D")
@onready var collision_shape = $CollisionShape2D

func _ready():
	_initialize_position_and_direction()

	if sprite:
		var mat = CanvasItemMaterial.new()
		mat.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
		sprite.material = mat

func _initialize_position_and_direction():
	var viewport_rect = get_viewport_rect()
	# 화면 안쪽에 생성되도록 여백 설정
	var margin = 100
	var spawn_rect = viewport_rect.grow(-margin)

	# 맵 내부의 무작위 위치에서 시작
	global_position.x = randf_range(spawn_rect.position.x, spawn_rect.end.x)
	global_position.y = randf_range(spawn_rect.position.y, spawn_rect.end.y)
	
	# 무작위 방향으로 초기 속도 설정
	velocity = Vector2.RIGHT.rotated(randf_range(0, TAU)) * SPEED

func _physics_process(delta):
	# 1. 방황: 방향을 부드럽게 변경
	var target_direction = velocity.rotated(randf_range(-WANDER_RATE, WANDER_RATE) * delta).normalized()

	# 2. 이동 및 슬라이드
	velocity = target_direction * SPEED
	move_and_slide()

	# 3. 충돌 처리
	for i in range(get_slide_collision_count()):
		var collision = get_slide_collision(i)
		if not collision:
			continue

		var collider = collision.get_collider()
		
		# 플레이어 총알과 충돌했는지 먼저 확인
		if collider is RigidBody2D and 'owner_node' in collider and is_instance_valid(collider.owner_node) and collider.owner_node.is_in_group("player"):
			if collider.has_method("explode"):
				collider.explode()
			on_hit()
			return # 피격 처리 후에는 더 이상 진행하지 않음

		# 총알이 아니라면 벽으로 간주하고 튕겨나옴
		var bounced_velocity = velocity.bounce(collision.get_normal())
		velocity = bounced_velocity.normalized() * SPEED # 속도 유지

func on_hit():
	if is_queued_for_deletion(): return
	
	emit_signal("hit")
	
	set_physics_process(false)
	velocity = Vector2.ZERO
	collision_shape.set_deferred("disabled", true)
	
	var tween = create_tween()
	tween.tween_property(sprite, "modulate:a", 0.0, 2.0)
	tween.tween_callback(queue_free)
