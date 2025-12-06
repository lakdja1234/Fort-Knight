# hitbox_indicator.gd (Merged by Gemini)
extends Node2D

@onready var timer = $Timer # Timer 노드를 참조

var visual_node: Sprite2D # _ready에서 할당될 Sprite2D

func _ready():
	# 물리 및 일반 프로세스를 비활성화하여 성능 최적화
	set_process(false)
	set_physics_process(false)
	
	visual_node = $Sprite2D
	
	if timer:
		timer.timeout.connect(_on_timer_timeout)
		# 시작 시 반투명 효과 적용 (HEAD 버전 기능)
		visual_node.modulate.a = 0.5
	else:
		printerr("HitboxIndicator: Timer 노드를 찾을 수 없습니다!")

# 외부에서 반경 값을 받아 크기를 조절하는 함수
func set_radius(radius: float):
	if not is_instance_valid(visual_node):
		visual_node = $Sprite2D

	# 텍스처가 로드되었는지 확인하고, 안되어있으면 직접 로드 (안전 코드)
	if not visual_node.texture:
		visual_node.texture = load("res://스테이지3/Img/warning.png") # bolt6281 버전 경로

	if not visual_node.texture:
		printerr("경고 표시의 텍스처를 로드할 수 없습니다!")
		return

	var base_texture_width = visual_node.texture.get_width()
	if base_texture_width <= 0:
		printerr("경고 표시 텍스처의 너비가 0보다 작거나 같습니다!")
		return

	# 목표 지름 계산
	var target_diameter = radius * 2.0

	# 원본 텍스처 크기 대비 스케일 값 계산 (bolt6281 버전 로직)
	# 실제 폭발 범위보다 약간 작게 표시하여 플레이어가 피할 여지를 줌
	var target_scale = (target_diameter / base_texture_width) * 0.7

	visual_node.scale = Vector2(target_scale, target_scale)

	# 스프라이트의 하단 중앙을 (0, 0)에 맞추기 위해 Y 위치만 조정 (bolt6281 버전 로직)
	var scaled_height = visual_node.texture.get_height() * visual_node.scale.y
	visual_node.position.y = -scaled_height / 2.0

# Timer가 끝나면 호출될 함수
func _on_timer_timeout():
	# 자기 자신(씬 전체)을 씬 트리에서 제거
	queue_free()
