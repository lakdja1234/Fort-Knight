extends StaticBody2D

# 인스펙터에서 켜진/꺼진 이미지를 할당
@export var texture_on: Texture2D
@export var texture_off: Texture2D

@onready var sprite: Sprite2D = $Sprite2D
@onready var warm_aura: Area2D = $WarmAura
@onready var range_visual = $WarmAura/RangeVisual

var is_on: bool = false

func _ready():
	# "map_heaters" 그룹에 자신을 추가
	add_to_group("map_heaters")
	
<<<<<<< Updated upstream:스테이지2/heater.gd
	
=======
>>>>>>> Stashed changes:heater.gd
	# 시작 상태는 '꺼짐'
	turn_off()

func turn_on():
	if is_on:
		return
	print("맵 온열장치: 켜짐!")
	is_on = true
	sprite.texture = texture_on
	warm_aura.monitoring = true
	
	# 범위 표시 켜기
	if is_instance_valid(range_visual):
		range_visual.show_range()
	
	for body in warm_aura.get_overlapping_bodies():
		_on_warm_aura_body_entered(body)

func turn_off():
	if not is_on:
		return
	print("맵 온열장치: 꺼짐!")
	is_on = false
	sprite.texture = texture_off
	warm_aura.monitoring = false

	# 범위 표시 끄기
	if is_instance_valid(range_visual):
		range_visual.hide_range()

	for body in warm_aura.get_overlapping_bodies():
		_on_warm_aura_body_exited(body)

# --- Aura 시그널 함수 ---

func _on_warm_aura_body_entered(body: Node2D):
	# 플레이어가 범위에 들어왔고, 온열장치가 켜져있다면
	if body.is_in_group("player") and is_on:
		if body.has_method("start_warming_up"):
			body.start_warming_up()
			print("온열장치: 플레이어 웜업 시작")

func _on_warm_aura_body_exited(body: Node2D):
	# 플레이어가 범위에서 나갔다면
	if body.is_in_group("player"):
		if body.has_method("stop_warming_up"):
			body.stop_warming_up()
			print("온열장치: 플레이어 웜업 중지")
