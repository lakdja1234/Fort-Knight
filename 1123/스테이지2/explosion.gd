extends Node2D

# 포탄으로부터 데미지 값을 전달받을 변수
var damage: int = 10 # 기본 데미지 10
var damaged_targets: Array[Node] = [] # 데미지를 입은 대상 저장

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
	animation_player.play("default")

	# 2. 물리 프레임을 한 번 기다린 후, 폭발 범위 내 객체들에게 데미지 주기
	# 이를 통해 물리 엔진이 충돌을 감지할 시간을 확보합니다.
	await get_tree().physics_frame
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
		var target_node: Node = body # 기본적으로 감지된 body를 타겟으로 설정

		# 감지된 body가 Area2D(예: 플레이어의 Hitbox)라면, 그 부모 노드(플레이어 CharacterBody2D)를 가져옴
		if body is Area2D:
			# Area2D의 owner는 해당 Area2D를 소유하는 Scene의 Root Node이다.
			# Player.tscn의 경우 Hitbox(Area2D)의 Owner는 Player(CharacterBody2D)이다.
			# 따라서 owner를 사용하여 최상위 노드를 가져온다.
			if body.owner != null:
				target_node = body.owner
			else:
				# owner가 null이면 get_parent()를 시도 (예외적인 경우)
				target_node = body.get_parent()
				
		# 동일한 최상위 노드에 대해 한 번만 데미지를 적용
		if not damaged_targets.has(target_node):
			if target_node.has_method("take_damage"):
				target_node.take_damage(damage)
				damaged_targets.append(target_node) # 데미지를 입힌 대상을 기록
