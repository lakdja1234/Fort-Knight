extends StaticBody2D

# 1. AnimationPlayer 참조 대신 AnimatedSprite2D 참조
@onready var sprite: AnimatedSprite2D = $AnimatedSprite2D # (노드 이름이 "AnimatedSprite2D"인지 확인)

# 2. 포탄 2회 타격으로 파괴되도록 HP 설정
@export var hp: int = 2

func _ready():
	# 3. AnimatedSprite2D에 "build" 애니메이션이 있는지 확인하고 재생
	if sprite.sprite_frames.has_animation("build"):
		sprite.play("build")
		# 'build' 애니메이션이 끝나면 'idle' 재생
		await sprite.animation_finished
		if sprite.sprite_frames.has_animation("idle"):
			sprite.play("idle")
	# 'build'가 없으면 'idle'이라도 재생
	elif sprite.sprite_frames.has_animation("idle"):
		sprite.play("idle")

# 4. 포탄이 호출할 데미지 함수
func take_damage(amount: int):
	if hp <= 0: # 이미 파괴 중이면 무시
		return
		
	hp -= amount
	print("방어벽 HP:", hp)
	
	if hp <= 0:
		# (선택 사항) 파괴 애니메이션 재생
		if sprite.sprite_frames.has_animation("destroy"):
			sprite.play("destroy")
			await sprite.animation_finished # 파괴 애니메이션 끝날 때까지 대기
		
		queue_free() # 방어벽 파괴
