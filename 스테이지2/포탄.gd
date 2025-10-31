extends RigidBody2D

# 인스펙터에서 데미지 양을 설정할 변수 export
@export var damage: int = 10 # 기본 데미지 10
# 폭발 반경 변수 추가 (인스펙터에서 조절 가능)
@export var explosion_radius: float = 300.0 # 기본 반경 50 픽셀
# 폭발 씬을 미리 로드
const ExplosionScene = preload("res://explosion.tscn")
# WarningIndicator 씬 로드
const WarningScene = preload("res://warning_indicator.tscn")

func _ready():
	# 이 노드를 "projectiles" 그룹에 추가합니다.
	# 다른 곳에서 충돌 검사 시 식별하는 데 도움이 됩니다.
	add_to_group("projectiles")

	# body_entered 시그널을 연결하여 충돌을 처리합니다.
	body_entered.connect(_on_body_entered)

	# (선택 사항) 아무것도 맞히지 않고 너무 멀리 날아갈 경우
	# 발사체를 자동으로 파괴하는 타이머를 설정합니다.
	var despawn_timer = get_tree().create_timer(5.0) # 5초 후 자동 소멸
	despawn_timer.timeout.connect(queue_free)


# 다른 물리 바디와 충돌했을 때 호출되는 함수
func _on_body_entered(body: Node):
	# 충돌한 바디에 'take_damage' 함수가 있는지 확인합니다.
	# (플레이어 탱크나 다른 파괴 가능한 객체 등)
	if body.has_method("take_damage"):
		body.take_damage(damage) # 대상의 take_damage 함수 호출
		
	print("포탄 폭발 위치:", global_position)
		
	create_explosion() # 직접 폭발 생성 함수 호출

## 💥 폭발 생성 함수 (body_entered 내부에서 호출)
func create_explosion():
	# 1. 폭발 씬 인스턴스 생성
	var explosion = ExplosionScene.instantiate()

	# 2. 부모 노드(월드)에 폭발 씬 추가
	get_tree().root.add_child(explosion)

	# 3. 폭발 위치 설정
	explosion.global_position = self.global_position

	# ✅ 4. 폭발 씬에 반경 값 전달 (새 함수 호출)
	if explosion.has_method("set_radius"):
		explosion.set_radius(explosion_radius)

	# 5. 포탄 자신은 소멸
	queue_free()

# ⚠️ 경고 생성 함수 (이 함수를 보스 스크립트 등이 호출하게 변경)
func create_warning(target_pos: Vector2):
	var warning = WarningScene.instantiate()
	get_tree().root.add_child(warning)
	warning.global_position = target_pos

	# ✅ 경고 씬에 반경 값 전달
	if warning.has_method("set_radius"):
		warning.set_radius(explosion_radius)

	return warning # 필요하다면 생성된 경고 노드 반환

	# (선택 사항) 필요한 경우 여기에 얼음 녹이는 로직 추가.
	# 하지만 타일 변경 처리는 TileMap 스크립트에서 하거나,
	# TileMap이 수신하는 시그널을 보내는 것이 더 좋을 수 있습니다.
	# 예시:
	# if body is TileMap:
	#	  var tilemap = body
	#	  var collision_point = global_position # 근사치
	#	  var tile_coords = tilemap.local_to_map(tilemap.to_local(collision_point))
	#	  # 시그널을 보내거나 TileMap의 함수를 직접 호출
	#	  # tilemap.melt_ice_at(tile_coords) # tilemap에 이 함수가 있다고 가정
