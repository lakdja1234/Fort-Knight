extends TileMapLayer

# 1. TileSet에서 '녹은 얼음' 타일의 정보를 미리 알아내서 입력해야 합니다.
@export var melted_tile_source_id: int = 5
@export var melted_tile_atlas_coords: Vector2i = Vector2i(0, 0)

# 2. 현재 녹아있는 타일을 관리하는 딕셔너리
var melted_tiles = {}

# 15초짜리 '얼어붙는 바람' 타이머 노드 참조
@onready var refreeze_wind_timer = $RefreezeWindTimer

func _ready():
	# 15초 타이머의 timeout 시그널을 새 함수에 연결
	refreeze_wind_timer.timeout.connect(_on_refreeze_wind_timeout)

# 3. 폭발(Explosion) 씬에서 호출할 공개 함수
func melt_ice_in_area(epicenter: Vector2, radius: float):
	if tile_set == null: # TileSet이 할당되었는지 확인
		printerr("TileMapLayer에 TileSet이 할당되지 않았습니다.")
		return
		
	var tile_size = tile_set.tile_size.x
	var radius_squared = radius * radius
	var radius_in_tiles = int(ceil(radius / tile_size))
	
	# local_to_map을 'self'에서 바로 호출
	var center_tile_coords = local_to_map(to_local(epicenter))

	for x in range(-radius_in_tiles, radius_in_tiles + 1):
		for y in range(-radius_in_tiles, radius_in_tiles + 1):
			var tile_coords = center_tile_coords + Vector2i(x, y)
			
			# map_to_local을 'self'에서 바로 호출
			var tile_world_pos = map_to_local(tile_coords)
			if tile_world_pos.distance_squared_to(to_local(epicenter)) <= radius_squared:
				_melt_individual_tile(tile_coords)

	# --- 주변 온열장치 켜는 로직 추가 ---
	var heaters = get_tree().get_nodes_in_group("map_heaters")
	for heater in heaters:
		if heater.global_position.distance_to(epicenter) <= radius:
			if heater.has_method("turn_on"):
				heater.turn_on()

# 4. '녹이기' 함수 (타이머 생성 로직 제거)
func _melt_individual_tile(coords: Vector2i):
	# 이미 녹아있는 타일인지 확인 (중복 방지)
	if melted_tiles.has(coords):
		return

	var tile_data = get_cell_tile_data(coords)

	if tile_data and tile_data.get_custom_data("is_ice") == true:
		var original_source_id = get_cell_source_id(coords)
		var original_atlas_coords = get_cell_atlas_coords(coords)
		
		# '녹은 얼음' 타일로 변경
		set_cell(coords, melted_tile_source_id, melted_tile_atlas_coords)
		
		# '녹아있는' 타일 목록에 [원래 타일 정보]를 저장
		melted_tiles[coords] = [original_source_id, original_atlas_coords]
		
# '전역 얼리기' 함수
func _on_refreeze_wind_timeout():
	# print("15초 경과: 얼어붙는 바람이 불어 모든 녹은 타일을 복구합니다!")

	# 딕셔너리에 저장된 모든 '녹은 타일'을 순회
	for coords in melted_tiles:
		var original_data = melted_tiles[coords]
		var source_id = original_data[0]
		var atlas_coords = original_data[1]
		
		# 원래의 얼음 타일로 복구
		set_cell(coords, source_id, atlas_coords)
	
	# 모든 타일을 복구했으므로, 딕셔너리를 비움
	melted_tiles.clear()
	
	# --- 모든 온열장치를 찾는 로직 추가 ---
	# "heaters" 그룹에 속한 모든 노드를 가져옴
	var heaters = get_tree().get_nodes_in_group("map_heaters")
	
	for heater in heaters:
		if heater.has_method("turn_off"):
			heater.turn_off() # 모든 온열장치 끄기

# 플레이어가 호출할 함수. 타일의 상태를 문자열로 반환합니다.
func get_tile_freeze_type(world_position: Vector2) -> String:
	var tile_coords = local_to_map(to_local(world_position))
	
	# 1. 타일 데이터가 없으면 "NORMAL"
	var tile_data = get_cell_tile_data(tile_coords)
	if not tile_data:
		return "NORMAL"
		
	# 2. 커스텀 데이터에 is_ice == true 이면 "ICE"
	if tile_data.get_custom_data("is_ice") == true:
		return "ICE"
		
	# 3. 녹은 타일 목록(melted_tiles)에 포함되어 있으면 "MELTED"
	if melted_tiles.has(tile_coords):
		return "MELTED"
		
	# 4. 그 외에는 모두 "NORMAL"
	return "NORMAL"

# 플레이어 노드를 직접 받아 발밑 타일 타입을 반환하는 새 함수
func get_player_floor_type(player: CharacterBody2D) -> String:
	# 플레이어로부터 CollisionShape2D 노드를 가져옴
	var collision_shape = player.get_node_or_null("CollisionShape2D")
	if not is_instance_valid(collision_shape):
		return "NORMAL"

	var floor_check_position = Vector2.ZERO
	var player_global_pos = player.global_position
	
	# 플레이어의 충돌체 모양에 따라 발밑 위치 계산
	if collision_shape.shape is CircleShape2D:
		var radius = collision_shape.shape.radius
		var shape_bottom_y = collision_shape.global_position.y + radius
		floor_check_position = Vector2(player_global_pos.x, shape_bottom_y + 30)
	elif collision_shape.shape is RectangleShape2D:
		var half_height = collision_shape.shape.size.y / 2.0
		var shape_bottom_y = collision_shape.global_position.y + half_height
		floor_check_position = Vector2(player_global_pos.x, shape_bottom_y + 30)
	
	if floor_check_position == Vector2.ZERO:
		return "NORMAL"
		
	# 계산된 위치를 사용하여 기존 함수 호출
	return get_tile_freeze_type(floor_check_position)
