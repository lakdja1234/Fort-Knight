# BrightSpot.gd (Merged by Gemini)
extends CharacterBody2D

signal hit

const SPEED = 450.0
const WANDER_RATE = PI # 초당 회전할 수 있는 최대 각도 (라디안)

@onready var sprite = $Sprite2D
@onready var collision_shape = $CollisionShape2D

func _ready():
	# 무작위 방향으로 초기 속도 설정 (위치는 보스 스크립트에서 지정)
	velocity = Vector2.RIGHT.rotated(randf_range(0, TAU)) * SPEED
	
	# HEAD 버전의 빛나는 효과 적용
	if sprite:
		var mat = CanvasItemMaterial.new()
		mat.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
		sprite.material = mat
	
	# Area2D 노드가 있다면 충돌 신호를 연결 (씬 수정을 권장)
	var area = find_child("Area2D", false)
	if area:
		area.area_entered.connect(_on_area_entered)


func _physics_process(delta):
	# 1. 방황: 방향을 부드럽게 변경
	var target_direction = velocity.rotated(randf_range(-WANDER_RATE, WANDER_RATE) * delta).normalized()

	# 2. 이동 및 슬라이드
	velocity = target_direction * SPEED
	move_and_slide()

	# 3. 벽 및 총알 충돌 처리
	for i in range(get_slide_collision_count()):
		var collision = get_slide_collision(i)
		if not collision:
			continue

		var collider = collision.get_collider()
		
		# 플레이어 총알과 충돌했는지 확인
		if collider and 'owner_node' in collider and is_instance_valid(collider.owner_node) and collider.owner_node.is_in_group("player"):
			if collider.has_method("explode"):
				collider.explode()
			else:
				# 총알이 explode 메서드가 없을 경우를 대비
				collider.queue_free()
			on_hit()
			return # 피격 처리 후에는 더 이상 진행하지 않음

		# 총알이 아니라면 벽으로 간주하고 튕겨나옴
		var bounced_velocity = velocity.bounce(collision.get_normal())
		velocity = bounced_velocity.normalized() * SPEED # 속도 유지

# Area2D(예: 종유석)와의 충돌을 처리하기 위한 함수 (HEAD 버전 기능)
func _on_area_entered(area):
	# 떨어지는 종유석과 충돌했는지 확인
	if area.is_in_group("stalactites") and area.has_method("is_falling") and area.is_falling():
		on_hit()

func on_hit():
	if is_queued_for_deletion(): return
	
	emit_signal("hit")
	
	# 물리 프로세스를 중지하고 충돌을 비활성화
	set_physics_process(false)
	velocity = Vector2.ZERO
	collision_shape.set_deferred("disabled", true)
	
	# bolt6281 버전의 부드러운 사라짐 효과 적용
	var tween = create_tween()
	tween.tween_property(sprite, "modulate:a", 0.0, 2.0)
	tween.tween_callback(queue_free)
