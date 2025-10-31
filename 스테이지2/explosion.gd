extends Node2D

# 인스펙터에서 폭발 피해량을 설정할 수 있도록 export
@export var damage: int = 10 # 폭발 데미지

# 노드 참조 (씬 구조에 맞게 경로 수정 필요)
@onready var animation_player: AnimatedSprite2D = $AnimatedSprite2D # AnimatedSprite2D 사용 시
# @onready var particles: CPUParticles2D = $CPUParticles2D # CPUParticles2D 사용 시
@onready var damage_area: Area2D = $Area2D
# Area2D의 CollisionShape2D 노드 참조 추가
@onready var damage_shape: CollisionShape2D = $Area2D/CollisionShape2D
# TileMap 노드를 찾아서 저장할 변수
@onready var tilemap = get_tree().get_first_node_in_group("ground_tilemap")

func _ready():
	# 1. 폭발 애니메이션/파티클 시작
	animation_player.play("default") # AnimatedSprite2D 사용 시

	# 2. 폭발 범위 내 객체들에게 데미지 주기
	apply_area_damage()

	# 3. 애니메이션/파티클 재생이 끝나면 스스로 소멸
	animation_player.animation_finished.connect(queue_free)

# 외부에서 반경 값을 받아 크기를 조절하는 함수 추가
func set_radius(radius: float):
	# 1.1. 피해 범위(CollisionShape2D) 크기 조절
	if damage_shape.shape is CircleShape2D:
		damage_shape.shape.radius = radius

	# 1. 시각 효과(Sprite/Particles) 크기 조절
	# Sprite의 경우: 원본 이미지 크기를 기준으로 스케일 계산
	var original_sprite_width = 128.0
	var target_scale = (radius * 2.0) / original_sprite_width
	animation_player.scale = Vector2(target_scale, target_scale)
	
	# 2. 광역 피해 적용 로직 호출
	
	# --- 3. 얼음 녹이기 로직 호출 ---
	if tilemap and tilemap.has_method("melt_ice_in_area"):
		tilemap.melt_ice_in_area(self.global_position, radius)
	else:
		printerr("Explosion: 'ground_tilemap' 그룹에서 TileMap을 찾지 못했거나 melt_ice_in_area 함수가 없습니다.")
	# --- 3. 얼음 녹이기 로직 끝 ---

# 폭발 범위 내의 객체들에게 데미지를 주는 함수
func apply_area_damage():
	# 현재 Area2D와 겹쳐있는 모든 PhysicsBody2D 또는 Area2D를 가져옴
	var overlapping_bodies = damage_area.get_overlapping_bodies()

	for body in overlapping_bodies:
		# 대상에게 'take_damage' 함수가 있는지 확인하고 호출
		if body.has_method("take_damage"):
			body.take_damage(damage)
			print(body.name + "에게 폭발 데미지 " + str(damage) + " 적용!")
