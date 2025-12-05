extends Node2D

@onready var animated_explosion = $AnimatedExplosion # AnimatedSprite2D 노드의 이름

func _ready():
	add_to_group("explosions")
	$AnimationPlayer.play("explosion")
	
	# --- 폭발 사운드 재생 ---
	var sfx_player = AudioStreamPlayer.new()
	sfx_player.stream = load("res://스테이지3/sound/explosionSound.mp3")
	sfx_player.volume_db = -2
	add_child(sfx_player)
	sfx_player.play()
	sfx_player.finished.connect(sfx_player.queue_free)

	# "camera" 그룹이 존재하는지 확인 후 shake 함수 호출
	if get_tree().has_group("camera"):
		get_tree().call_group("camera", "shake", 15.0, 0.3)
	
	await $AnimationPlayer.animation_finished
	queue_free()

func _on_animation_finished():
	# 애니메이션이 끝나면 이 씬(폭발)을 제거합니다.
	queue_free()
