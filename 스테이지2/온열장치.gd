extends Area2D # 또는 온열장치의 기본 노드 타입

@export var debug_action_name: String = ""

# 에디터 인스펙터에서 '꺼진 상태' 이미지를 할당할 변수
@export var texture_off: Texture2D 

@export var hp: int = 100 # 온열장치의 현재 체력 (예시)
var max_hp: int = 100 # 최대 체력 저장 변수

# 이미 파괴되었는지 확인하는 플래그
var is_destroyed: bool = false
var wall_spawn_triggered: bool = false # 50% 방어벽 생성 플래그


signal heat_sink_destroyed
signal spawn_wall_requested

# 이 Area2D의 CollisionShape2D 노드 경로 (에디터에서 설정)
@onready var collision_shape: CollisionShape2D = $CollisionShape2D
# 이 Area2D의 Sprite2D 노드 경로 (에디터에서 설정)
@onready var sprite: Sprite2D = $Sprite2D

# ✅ 2. _process 함수로 디버그 입력 확인 (이전 _input 함수 대체)
func _process(_delta):
	# debug_action_name이 비어있지 않고, 해당 키가 눌렸는지 확인
	if debug_action_name != "" and Input.is_action_just_pressed(debug_action_name):
		if not is_destroyed:
			print("--- (디버그 키 '%s' 입력) %s에 데미지 34 적용 ---" % [debug_action_name, name])
			take_damage(34) # 예시: 34 데미지
			
			
func _ready():
	# ✅ 1. "heaters" 그룹에 자신을 추가
	add_to_group("heaters")
	max_hp = hp
	
	
# 포탄 등 다른 객체와 충돌했을 때 호출되는 함수 (body_entered 시그널에 연결)
func _on_body_entered(body):
	# 이미 파괴되었거나, 들어온 것이 포탄이 아니면 무시
	if is_destroyed or not body.is_in_group("projectiles"): 
		return

	# 포탄으로부터 데미지를 받는 로직 (예시)
	take_damage(body.damage) # body(포탄)에 damage 변수가 있다고 가정

	# 포탄은 소멸
	body.queue_free()


# 데미지를 받는 함수
func take_damage(amount: int):
	if is_destroyed:
		return
		
	hp -= amount
	
	print("온열장치 현재 HP:", hp, "(", name, ")") # (어떤 온열장치인지 이름도 출력)
	
	# HP 50% 이하 체크
	# 아직 50% 방어벽이 생성되지 않았고, HP가 50% 이하로 떨어졌다면
	if not wall_spawn_triggered and hp <= (max_hp / 2.0):
		wall_spawn_triggered = true # 플래그 설정 (한 번만 실행)
		emit_signal("spawn_wall_requested") # 보스에게 방어벽 생성 요청
		print("온열장치 50% HP 도달! 방어벽 생성 요청.")
	
	# 체력이 0 이하가 되면 파괴 처리
	if hp <= 0:
		destroy()


# 파괴 처리 함수
func destroy():
	is_destroyed = true
	hp = 0
	
	# 1. 스프라이트 이미지를 '꺼진 상태'로 변경!
	if texture_off: # texture_off 변수에 이미지가 할당되었는지 확인
		sprite.texture = texture_off
	else:
		# 이미지가 없으면 그냥 투명하게 만듦 (선택 사항)
		sprite.visible = false 
		
	# 2. 더 이상 충돌 감지하지 않도록 CollisionShape 비활성화
	collision_shape.disabled = true
	
	# 3. 부모(IceBoss)에게 파괴되었다는 시그널 발송
	emit_signal("heat_sink_destroyed")

	# (선택 사항) 파괴 이펙트(폭발 등)를 여기서 재생
	# var explosion = ExplosionScene.instantiate()
	# add_child(explosion)
	# explosion.global_position = global_position
