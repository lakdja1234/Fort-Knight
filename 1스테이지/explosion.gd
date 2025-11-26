extends Node2D

@onready var animated_explosion = $AnimatedExplosion # AnimatedSprite2D 노드의 이름

func _ready():
	# Emit a global signal to request a camera shake.
	GlobalSignals.camera_shake_requested.emit(15.0, 0.3)

	# 애니메이션 재생이 끝나면 _on_animation_finished 함수를 호출하도록 연결
	animated_explosion.animation_finished.connect(_on_animation_finished)
	animated_explosion.play("explode") # 또는 설정한 애니메이션 이름 (예: "explode")

func _on_animation_finished():
	# 애니메이션이 끝나면 이 씬(폭발)을 제거합니다.
	queue_free()
