# explosion.gd (Merged by Gemini)
extends Node2D

func _ready():
	add_to_group("explosions")
	
	# 애니메이션 플레이어가 있다면 "explosion" 애니메이션을 재생합니다.
	if has_node("AnimationPlayer"):
		$AnimationPlayer.play("explosion")
	# AnimatedSprite2D가 있다면 "explode" 애니메이션을 재생합니다.
	elif has_node("AnimatedExplosion"):
		$AnimatedExplosion.play("explode")

	# --- 폭발 사운드 재생 ---
	var sfx_player = AudioStreamPlayer.new()
	sfx_player.stream = load("res://스테이지3/sound/explosionSound.mp3")
	sfx_player.volume_db = -2
	add_child(sfx_player)
	sfx_player.play()
	sfx_player.finished.connect(sfx_player.queue_free)

	# 카메라 흔들림 효과
	var camera = get_tree().get_first_node_in_group("camera")
	if is_instance_valid(camera) and camera.has_method("shake"):
		camera.shake(15.0, 0.3)
	
	# 애니메이션이 끝나면 씬을 제거합니다.
	if has_node("AnimationPlayer"):
		await $AnimationPlayer.animation_finished
	elif has_node("AnimatedExplosion"):
		await $AnimatedExplosion.animation_finished
		
	queue_free()

# 총알 스크립트에서 폭발 반경(크기)을 설정하기 위한 함수
func set_radius(new_radius: float):
	# 이 노드 자체의 스케일을 조절하여 전체 폭발 효과의 크기를 변경합니다.
	self.scale = Vector2(new_radius, new_radius)
