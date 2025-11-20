extends Camera2D

# --- 카메라 설정 ---
@export var follow_speed: float = 5.0
# 플레이어를 화면 하단에 위치시키기 위한 Y축 오프셋 값
@export var vertical_offset: float = 250.0 

# --- 노드 및 맵 경계 변수 ---
var player: CharacterBody2D = null
var tilemap: TileMapLayer = null
var map_limits: Rect2

func _ready():
	add_to_group("camera")
	
	# --- 1. 필수 노드 찾기 ---
	player = get_tree().get_first_node_in_group("player")
	if not is_instance_valid(player):
		printerr("MainCamera: 'player' 그룹에서 플레이어를 찾을 수 없습니다!")
		print("DEBUG: Player not found!")
		
	# 'ground_tilemap' 그룹에서 TileMapLayer 노드를 찾습니다.
	# (TileMapLayer 노드의 인스펙터 -> Node -> Groups에 'ground_tilemap'이 추가되어 있어야 합니다)
	tilemap = get_tree().get_first_node_in_group("ground_tilemap")
	if not is_instance_valid(tilemap):
		printerr("MainCamera: 'ground_tilemap' 그룹에서 TileMapLayer를 찾을 수 없습니다!")
		print("DEBUG: Tilemap not found!")
		# 타일맵을 못 찾으면 카메라 제한을 할 수 없으므로 함수를 종료합니다.
		return
		
	# --- 2. 타일맵 경계 계산 ---
	# get_used_rect()는 타일이 사용된 영역을 타일 좌표로 반환합니다.
	var used_rect = tilemap.get_used_rect()
	# 타일 좌표를 실제 픽셀 좌표로 변환합니다.
	# position은 시작점, size는 전체 크기가 됩니다.
	map_limits = Rect2(
		tilemap.map_to_local(used_rect.position),
		used_rect.size * tilemap.tile_set.tile_size
	)
	print("카메라: 맵 경계 계산 완료 - ", map_limits)


func shake(strength: float = 10.0, duration: float = 0.5):
	var tween = get_tree().create_tween().set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	var shake_offset = Vector2(randf_range(-strength, strength), randf_range(-strength, strength))
	
	# 0.05초 동안 랜덤한 위치로 이동했다가 다시 원래 위치로 돌아오는 것을 반복
	tween.tween_property(self, "offset", shake_offset, duration / 10)
	tween.tween_property(self, "offset", Vector2.ZERO, duration / 10)
	tween.tween_property(self, "offset", -shake_offset, duration / 10)
	tween.tween_property(self, "offset", Vector2.ZERO, duration / 10)
	tween.tween_property(self, "offset", shake_offset, duration / 10)
	tween.tween_property(self, "offset", Vector2.ZERO, duration / 10)
	tween.tween_property(self, "offset", -shake_offset, duration / 10)
	tween.tween_property(self, "offset", Vector2.ZERO, duration / 10)
	tween.tween_property(self, "offset", shake_offset, duration / 10)
	tween.tween_property(self, "offset", Vector2.ZERO, duration / 10)


func _physics_process(delta):
	# 플레이어나 타일맵이 없으면 아무것도 하지 않음
	if not is_instance_valid(player) or not is_instance_valid(tilemap):
		print("DEBUG: Camera not moving because player or tilemap is invalid.")
		return

	# --- 1. 목표 위치 계산 (Y축 오프셋 적용) ---
	var target_pos = player.global_position
	target_pos.y -= vertical_offset
	
	# --- 2. 부드럽게 목표 위치로 이동 ---
	var new_pos = self.global_position.lerp(target_pos, follow_speed * delta)

	# --- 3. 카메라 위치를 맵 경계 안에 있도록 제한 ---
	# 뷰포트(화면)의 절반 크기를 구하고, 카메라 줌(zoom)을 적용하여 월드 좌표 기준으로 변환합니다.
	var viewport_half_size = (get_viewport_rect().size / zoom) / 2.0
	
	# clamp 함수를 사용하여 new_pos의 x, y 값을 지정된 최소/최대값 사이로 제한합니다.
	new_pos.x = clamp(new_pos.x, map_limits.position.x + viewport_half_size.x, map_limits.end.x - viewport_half_size.x)
	new_pos.y = clamp(new_pos.y, map_limits.position.y + viewport_half_size.y, map_limits.end.y - viewport_half_size.y)
	
	# --- 4. 최종 위치 적용 ---
	self.global_position = new_pos
