extends Camera2D

var shake_strength = 0.0
var shake_timer = Timer.new()

func _ready():
	add_to_group("camera")
	shake_timer.timeout.connect(_on_shake_timer_timeout)
	add_child(shake_timer)

	# TileMap이 완전히 준비될 때까지 잠시 기다린 후, 맵 크기에 맞춰 카메라를 조절하는 함수를 호출
	var timer = get_tree().create_timer(0.1)
	timer.timeout.connect(_adjust_camera_to_map)

func _adjust_camera_to_map():
	# 맵(TileMap) 전체가 화면에 보이도록 카메라의 위치와 줌을 자동으로 조절
	var tilemap = get_node_or_null("/root/TitleMap")
	if tilemap:
		var used_rect = tilemap.get_used_rect()
		var tile_size = tilemap.tile_set.tile_size
		
		# TileMap의 실제 월드 크기를 계산
		var map_local_pos = tilemap.map_to_local(used_rect.position)
		var map_local_size = used_rect.size * tile_size
		var map_local_rect = Rect2(map_local_pos, map_local_size)

		# 맵의 중앙으로 카메라 위치를 이동
		global_position = tilemap.to_global(map_local_rect.get_center())

		# 맵의 가로 또는 세로가 화면에 꽉 차도록 줌 레벨을 계산 (더 큰 값을 기준으로 설정)
		var viewport_size = get_viewport_rect().size
		var zoom_x = map_local_rect.size.x / viewport_size.x
		var zoom_y = map_local_rect.size.y / viewport_size.y
		var new_zoom = max(zoom_x, zoom_y)
		
		if new_zoom > 0:
			zoom = Vector2(new_zoom, new_zoom)
	else:
		print("DEBUG: TileMap node not found for auto-zoom.")

func _physics_process(delta):
	# shake_strength 값이 0보다 크면 매 프레임 카메라를 무작위로 흔듦
	if shake_strength > 0:
		offset = Vector2(randf_range(-shake_strength, shake_strength), randf_range(-shake_strength, shake_strength))

# 맵 경계를 설정하는 함수
func setup_boundaries(map_rect: Rect2):
	limit_left = int(map_rect.position.x)
	limit_top = int(map_rect.position.y)
	limit_right = int(map_rect.end.x)
	limit_bottom = int(map_rect.end.y)

# 카메라 흔들림 함수: 강도(strength)와 지속시간(duration)을 받아 타이머를 시작
func shake(strength: float = 10.0, duration: float = 0.5):
	shake_strength = strength
	shake_timer.wait_time = duration
	shake_timer.start()

# 흔들림 타이머가 끝나면 호출되어, 흔들림 강도를 0으로 만들고 카메라 오프셋을 초기화
func _on_shake_timer_timeout():
	shake_strength = 0.0
	offset = Vector2.ZERO
