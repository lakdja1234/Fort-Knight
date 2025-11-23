extends Node2D

@onready var timer = $Timer # Timer 노드를 참조

var visual_node: Sprite2D # Will be assigned in _ready()

func _ready():
	visual_node = $Sprite2D # Get the Sprite2D node
	visual_node.texture = load("res://Img/warning.png") # Load texture directly
	
	if timer:
		timer.timeout.connect(_on_timer_timeout)
		# 시작 시 투명도 설정 (예: 50% 반투명)
		visual_node.modulate.a = 0.5
	else:
		printerr("HitboxIndicator: Timer 노드를 찾을 수 없습니다!")

# ✅ 1. 외부에서 반경 값을 받아 크기를 조절하는 함수 추가
func set_radius(radius: float):
	if not visual_node or not visual_node.texture:
		printerr("경고 표시의 visual_node 또는 텍스처가 없습니다!")
		return

	var base_texture_width = visual_node.texture.get_width()
	if base_texture_width <= 0:
		printerr("경고 표시 텍스처의 너비가 0보다 작거나 같습니다!")
		return

	# 목표 크기 계산 (폭발 반경의 2배 = 지름)
	var target_diameter = radius * 2.0

	# 원본 텍스처 크기 대비 얼마나 커져야 하는지 스케일 값 계산
	var target_scale = target_diameter / base_texture_width

	# visual_node의 스케일(크기 배율)을 조절
	visual_node.scale = Vector2(target_scale, target_scale)

# Timer가 끝나면 호출될 함수
func _on_timer_timeout():
	# 자기 자신(WarningIndicator 씬 전체)을 씬 트리에서 제거하여 사라지게 함
	queue_free()
