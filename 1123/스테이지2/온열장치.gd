extends StaticBody2D

@export var debug_action_name: String = ""

# 에디터 인스펙터에서 '꺼진 상태' 이미지를 할당할 변수
@export var texture_off: Texture2D 

@export var hp: int = 100 # 온열장치의 현재 체력 (예시)
var max_hp: int = 100 # 최대 체력 저장 변수

var is_invincible: bool = false # 짧은 무적 상태를 관리할 플래그

# 이미 파괴되었는지 확인하는 플래그
var is_destroyed: bool = false
var wall_spawn_triggered: bool = false # 50% 방어벽 생성 플래그


signal heat_sink_destroyed
signal spawn_wall_requested
signal health_updated(current_hp, max_hp, heater_name)

# 이 Area2D의 CollisionShape2D 노드 경로 (에디터에서 설정)
@onready var collision_shape: CollisionShape2D = $CollisionShape2D
# 이 Area2D의 Sprite2D 노드 경로 (에디터에서 설정)
@onready var sprite: Sprite2D = $Sprite2D

			
func _ready():
	# ✅ 1. "heaters" 그룹에 자신을 추가
	add_to_group("heaters")
	max_hp = hp
	
# 데미지를 받는 함수
func take_damage(amount: int):
	# 이미 파괴되었거나, 짧은 무적 시간 중이면 데미지를 받지 않음
	if is_destroyed or is_invincible:
		return
	
	# 무적 상태로 만들고 데미지 처리 시작
	is_invincible = true
	hp -= amount
	emit_signal("health_updated", hp, max_hp, name)

	# 데미지를 입었을 때 빨갛게 점멸하는 효과
	var tween = create_tween().set_loops(2)
	# 참고: 이 효과는 Sprite2D 노드에만 적용됩니다.
	# 다른 종류의 노드(예: ColorRect)를 사용 중이라면 "modulate" 대신 다른 속성을 사용해야 할 수 있습니다.
	tween.tween_property(sprite, "modulate", Color.RED, 0.15)
	tween.tween_property(sprite, "modulate", Color.WHITE, 0.15)
	
	
	# print("온열장치 현재 HP:", hp, "(", name, ")") # (어떤 온열장치인지 이름도 출력)
	
	# HP 50% 이하 체크
	# 아직 50% 방어벽이 생성되지 않았고, HP가 50% 이하로 떨어졌다면
	if not wall_spawn_triggered and hp <= (max_hp / 2.0):
		wall_spawn_triggered = true # 플래그 설정 (한 번만 실행)
		emit_signal("spawn_wall_requested") # 보스에게 방어벽 생성 요청
		# print("온열장치 50% HP 도달! 방어벽 생성 요청.")
	
	# 체력이 0 이하가 되면 파괴 처리
	if hp <= 0:
		destroy()

	# 0.1초의 짧은 무적 시간이 지나면 다시 데미지를 받을 수 있도록 플래그 해제
	await get_tree().create_timer(0.1).timeout
	is_invincible = false



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
	# StaticBody2D는 물리 바디이므로, 노드 자체를 큐에서 제거하는 것이 일반적입니다.
	# collision_shape.disabled = true
	
	# 3. 부모(IceBoss)에게 파괴되었다는 시그널 발송
	emit_signal("heat_sink_destroyed")

	# (선택 사항) 파괴 이펙트(폭발 등)를 여기서 재생
	# var explosion = ExplosionScene.instantiate()
	# add_child(explosion)
	# explosion.global_position = global_position
