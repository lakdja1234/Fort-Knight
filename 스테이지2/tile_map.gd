extends TileMapLayer

# 1. TileSet에서 '녹은 얼음' 타일의 정보를 미리 알아내서 입력해야 합니다.
@export var melted_tile_source_id: int = 5
@export var melted_tile_atlas_coords: Vector2i = Vector2i(0, 1)

# 2. 현재 녹아있는 타일과 타이머를 관리하는 딕셔너리
var melting_tiles = {}

# 3. 폭발(Explosion) 씬에서 호출할 공개 함수
func melt_ice_in_area(epicenter: Vector2, radius: float):
	if tile_set == null: # TileSet이 할당되었는지 확인
		printerr("TileMapLayer에 TileSet이 할당되지 않았습니다.")
		return
		
	var tile_size = tile_set.tile_size.x
	var radius_squared = radius * radius
	var radius_in_tiles = int(ceil(radius / tile_size))
	
	# ✅ local_to_map을 'self'에서 바로 호출
	var center_tile_coords = local_to_map(to_local(epicenter))

	for x in range(-radius_in_tiles, radius_in_tiles + 1):
		for y in range(-radius_in_tiles, radius_in_tiles + 1):
			var tile_coords = center_tile_coords + Vector2i(x, y)
			
			# ✅ map_to_local을 'self'에서 바로 호출
			var tile_world_pos = map_to_local(tile_coords)
			if tile_world_pos.distance_squared_to(to_local(epicenter)) <= radius_squared:
				_melt_individual_tile(tile_coords)

# 4. 개별 타일을 녹이고 타이머를 시작하는 내부 함수
func _melt_individual_tile(coords: Vector2i):
	if melting_tiles.has(coords):
		return

	# get_cell_tile_data를 'self'에서 바로 호출
	var tile_data = get_cell_tile_data(coords)

	if tile_data and tile_data.get_custom_data("is_ice") == true:
		var original_source_id = tile_data.source_id
		var original_atlas_coords = tile_data.atlas_coords
		
		# set_cell을 'self'에서 바로 호출
		set_cell(coords, melted_tile_source_id, melted_tile_atlas_coords)
		
		var timer = get_tree().create_timer(3.0)
		timer.one_shot = true
		timer.timeout.connect(_on_refreeze_timer_timeout.bind(coords, original_source_id, original_atlas_coords))
		melting_tiles[coords] = timer

# 5. 타이머가 끝나면 타일을 다시 얼리는 함수
func _on_refreeze_timer_timeout(coords: Vector2i, source_id: int, atlas_coords: Vector2i):
	# set_cell을 'self'에서 바로 호출
	set_cell(coords, source_id, atlas_coords)
	melting_tiles.erase(coords)

# 플레이어가 호출할 함수 (is_ice 확인용)
func is_tile_ice(world_position: Vector2) -> bool:
	var tile_coords = local_to_map(to_local(world_position))
	var tile_data = get_cell_tile_data(tile_coords)
	
	if tile_data and tile_data.get_custom_data("is_ice") == true:
		return true
	else:
		return false
