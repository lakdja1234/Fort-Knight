# Explosion.gd
extends GPUParticles2D # ⚠️ 이 부분이 수정되었습니다!

func _ready():
	# 씬이 생성되자마자 파티클 재생 시작
	emitting = true

func _process(delta):
	# One Shot이 켜져있으면, 재생이 끝난 뒤 emitting이 false가 됨
	if not emitting:
		queue_free() # 파티클 재생이 끝났으니 씬 스스로 삭제
