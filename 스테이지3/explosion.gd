extends Node2D

@onready var animated_explosion = $AnimatedExplosion # AnimatedSprite2D 노드의 이름

func _ready():
	# 애니메이션 재생이 끝나면 _on_animation_finished 함수를 호출하도록 연결
	animated_explosion.animation_finished.connect(_on_animation_finished)
	animated_explosion.play("explode") # 또는 설정한 애니메이션 이름 (예: "explode")

func _on_animation_finished():
	# 애니메이션이 끝나면 이 씬(폭발)을 제거합니다.
	queue_free()

func set_radius(new_radius: float):
	# AnimatedExplosion 스프라이트의 스케일을 조절하여 시각적인 폭발 반경을 나타냅니다.
	animated_explosion.scale = Vector2(new_radius, new_radius)