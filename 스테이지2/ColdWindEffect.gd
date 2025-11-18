extends Node2D

@onready var particles = $GPUParticles2D

func _ready():
	# 파티클 시스템이 한 번의 방출을 완료하면 스스로를 파괴합니다.
	await particles.finished
	queue_free()
