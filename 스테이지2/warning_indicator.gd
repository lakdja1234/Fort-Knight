extends Node2D

@onready var timer = $Timer # Timer 노드를 참조

# 경고 표시를 담당하는 노드 참조 (Sprite2D 또는 ColorRect)
@onready var visual_node = $Sprite2D # 또는 $ColorRect

# 원본 이미지 크기
@export var base_size: float = 1024.0

func _ready():
	# Timer의 timeout 시그널을 _on_timer_timeout 함수에 연결
	timer.timeout.connect(_on_timer_timeout)
	
	# 시작 시 투명도 설정 (예: 50% 반투명)
	visual_node.modulate.a = 0.5

# ✅ 1. 외부에서 반경 값을 받아 크기를 조절하는 함수 추가
func set_radius(radius: float):
	print("set_radius 호출됨! 전달받은 radius:", radius) # <-- 디버깅용 print 추가
	if base_size <= 0:
		printerr("경고 표시의 base_size는 0보다 커야 합니다!")
		return

	# 목표 크기 계산 (폭발 반경의 2배 = 지름 = 사각형의 한 변 길이)
	var target_length = radius * 2.0

	# 원본 크기 대비 얼마나 커져야 하는지 스케일 값 계산
	var target_scale = target_length / base_size

	# visual_node의 스케일(크기 배율)을 조절
	visual_node.scale = Vector2(target_scale, target_scale)

	# (선택 사항) 만약 visual_node가 ColorRect이고 중심축이 좌상단이라면,
	# 크기가 커질 때 중심을 유지하도록 위치를 보정해야 할 수 있습니다.
	# visual_node.position = -visual_node.size * target_scale / 2.0

# Timer가 끝나면 호출될 함수
func _on_timer_timeout():
	# 자기 자신(WarningIndicator 씬 전체)을 씬 트리에서 제거하여 사라지게 함
	queue_free()
