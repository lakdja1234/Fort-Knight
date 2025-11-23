# RangeVisual.gd
extends Node2D

var radius: float = 0.0
# 주황색 (R=1, G=0.6, B=0), 투명도 0 (완전 투명)
var draw_color: Color = Color(1.0, 0.6, 0.0, 0.0)

func _ready():
	# 1. 부모(WarmAura)의 CollisionShape2D 노드를 찾음
	var parent_aura = get_parent()
	var collision_shape = parent_aura.get_node("CollisionShape2D") # 경로 확인!

	# 2. CollisionShape2D에서 원의 반지름(radius) 값을 가져옴
	if collision_shape and collision_shape.shape is CircleShape2D:
		radius = collision_shape.shape.radius
	
	# 3. 그리기 요청
	queue_redraw()

# Godot가 이 노드를 그리도록 요청할 때마다 호출됨
func _draw():
	# 4. 원점을 중심으로, 계산된 반지름과 색상으로 원을 그림
	draw_circle(Vector2.ZERO, radius, draw_color)

# 5. 부모(Heater.gd)가 호출할 함수
func show_range():
	# 색상을 '반투명' 주황색으로 변경
	draw_color = Color(1.0, 0.6, 0.0, 0.3) # 0.5 = 50% 투명도
	queue_redraw() # 변경된 색상으로 다시 그리도록 요청

func hide_range():
	# 색상을 '완전 투명'으로 변경
	draw_color = Color(1.0, 0.6, 0.0, 0.0)
	queue_redraw() # 변경된 색상으로 다시 그리도록 요청
