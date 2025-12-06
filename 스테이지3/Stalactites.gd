extends Node2D

@export var stalactite_scene: PackedScene
const STALACTITE_COUNT = 7
const MIN_DISTANCE_BETWEEN_STALACTITES = 50 # 최소 간격 축소

var boss_is_enraged: bool = false
var enrage_fall_timer: Timer
var active_stalactite_positions: Array[Vector2] = []
var spawn_count: int = 0

func _ready():
	randomize()
	add_to_group("stalactite_manager")
	
	# 보스의 체력이 일정 수준 이하로 떨어졌을 때의 '격노' 상태를 감지하기 위해 신호를 연결함
	var boss = get_tree().get_first_node_in_group("boss")
	if boss:
		if boss.has_signal("enraged"):
			boss.enraged.connect(_on_boss_enraged)
		if boss.has_signal("boss_died"):
			boss.boss_died.connect(_on_boss_died)

	if not stalactite_scene:
		printerr("Stalactite scene is not set!")
		return
	
	_start_initial_spawn()

# 일회성 사운드를 재생하는 헬퍼 함수
func _play_sound(sound_path, volume_db = 0):
	var sfx_player = AudioStreamPlayer.new()
	sfx_player.stream = load(sound_path)
	sfx_player.volume_db = volume_db
	add_child(sfx_player)
	sfx_player.play()
	sfx_player.finished.connect(sfx_player.queue_free)

# 보스가 사망했을 때 호출됨
func _on_boss_died():
	# 격노 상태 타이머가 실행 중이면 중지시켜 더 이상 종유석이 떨어지지 않게 함
	if enrage_fall_timer and not enrage_fall_timer.is_stopped():
		enrage_fall_timer.stop()

# 보스가 격노 상태가 되면 호출됨
func _on_boss_enraged():
	boss_is_enraged = true
	# 격노 상태에서는 5초마다 주기적으로 종유석을 떨어뜨리는 타이머를 시작함
	enrage_fall_timer = Timer.new()
	enrage_fall_timer.wait_time = 5.0
	enrage_fall_timer.timeout.connect(_on_enrage_fall_timer_timeout)
	add_child(enrage_fall_timer)
	enrage_fall_timer.start()

# 5초마다 실행되는 격노 타이머의 핸들러
func _on_enrage_fall_timer_timeout():
	# 지진 효과음 재생 후 카메라 흔들림
	_play_sound("res://스테이지3/sound/earthquake1Sec.mp3", -5)
	var camera = get_tree().get_first_node_in_group("camera")
	if camera and camera.has_method("shake"):
		camera.shake(7.0, 1.0) # 보스 포탄보다 2배 강한 흔들림

	# 1초 후 3개의 종유석을 순차적으로 떨어뜨림
	var timer = get_tree().create_timer(1.0)
	timer.timeout.connect(_drop_enrage_stalactites.bind(3))

# bind를 통해 count를 전달받아, 정해진 수만큼 종유석을 떨어뜨리는 재귀적 함수
func _drop_enrage_stalactites(count: int):
	if count <= 0:
		return
	
	drop_random_stalactite()
	
	# 0.1초의 짧은 딜레이를 두고 다음 종유석을 떨어뜨림
	var timer = get_tree().create_timer(0.1)
	timer.timeout.connect(_drop_enrage_stalactites.bind(count - 1))

func _start_initial_spawn():
	var timer = get_tree().create_timer(5.0)
	timer.timeout.connect(_spawn_initial_stalactite.bind(STALACTITE_COUNT))

func _spawn_initial_stalactite(count: int):
	if count <= 0:
		return
	
	spawn_stalactite(false)
	
	var timer = get_tree().create_timer(0.5)
	timer.timeout.connect(_spawn_initial_stalactite.bind(count - 1))

func _get_random_non_overlapping_x() -> float:
	# 1. 무작위 위치를 100번 시도
	for i in 100:
		var x_pos = randf_range(50, 1270)
		var is_valid = true
		for pos in active_stalactite_positions:
			if abs(pos.x - x_pos) < MIN_DISTANCE_BETWEEN_STALACTITES:
				is_valid = false
				break
		if is_valid:
			return x_pos

	# 2. 100번 실패 시, 가장 넓은 빈 공간을 찾아 그곳에 생성 (겹침 방지 보장)
	if active_stalactite_positions.is_empty():
		return randf_range(50, 1270)

	var sorted_x = []
	for pos in active_stalactite_positions:
		sorted_x.append(pos.x)
	sorted_x.sort()

	var largest_gap_start = 50.0
	var largest_gap_size = (sorted_x[0] - MIN_DISTANCE_BETWEEN_STALACTITES) - 50.0
	var best_spawn_pos = (50.0 + sorted_x[0] - MIN_DISTANCE_BETWEEN_STALACTITES) / 2.0

	# 왼쪽 끝과 첫 종유석 사이의 공간 확인
	if largest_gap_size < 0:
		largest_gap_size = -INF # 사실상 빈 공간 없음

	# 종유석들 사이의 공간 확인
	for i in range(sorted_x.size() - 1):
		var gap_start = sorted_x[i] + MIN_DISTANCE_BETWEEN_STALACTITES
		var gap_end = sorted_x[i+1] - MIN_DISTANCE_BETWEEN_STALACTITES
		var gap_size = gap_end - gap_start
		
		if gap_size > largest_gap_size:
			largest_gap_size = gap_size
			best_spawn_pos = (gap_start + gap_end) / 2.0

	# 마지막 종유석과 오른쪽 끝 사이의 공간 확인
	var last_gap_start = sorted_x[-1] + MIN_DISTANCE_BETWEEN_STALACTITES
	var last_gap_size = 1270.0 - last_gap_start
	
	if last_gap_size > largest_gap_size:
		largest_gap_size = last_gap_size
		best_spawn_pos = (last_gap_start + 1270.0) / 2.0
	
	if largest_gap_size < 0:
		printerr("Could not find any valid spawn location for a stalactite!")
		return randf_range(50, 1270) # 최후의 수단

	return best_spawn_pos

func spawn_stalactite(spawn_on_boss := false):
	spawn_count += 1
	var stalactite = stalactite_scene.instantiate()
	
	var x_pos
	var boss = get_tree().get_first_node_in_group("boss")

	if spawn_on_boss and is_instance_valid(boss):
		var target_x = boss.global_position.x
		var is_clear_above_boss = true
		
		# 보스 위 영역이 비어있는지 확인
		for pos in active_stalactite_positions:
			if abs(pos.x - target_x) < MIN_DISTANCE_BETWEEN_STALACTITES + 50: # 여유 공간 추가
				is_clear_above_boss = false
				break
		
		if is_clear_above_boss:
			# 보스 위가 비어있으면 해당 위치에 생성 시도
			x_pos = randf_range(target_x - 100.0, target_x + 100.0)
		else:
			# 막혀있으면 보스를 피해 생성
			x_pos = _get_safe_random_x_away_from_boss(boss)
	else:
		# 4번째가 아니거나 보스가 없으면 항상 보스를 피해 생성
		x_pos = _get_safe_random_x_away_from_boss(boss)
			
	var new_pos = Vector2(x_pos, 25.0)
	stalactite.global_position = new_pos
	active_stalactite_positions.append(new_pos)
	
	stalactite.destroyed.connect(_on_stalactite_destroyed.bind(new_pos))
	
	add_child(stalactite)
	
	var tween = create_tween()
	stalactite.modulate.a = 0
	tween.tween_property(stalactite, "modulate:a", 1.0, 1.0)

# 보스를 피해 안전한 x좌표를 찾는 헬퍼 함수
func _get_safe_random_x_away_from_boss(boss_node) -> float:
	if not is_instance_valid(boss_node):
		return _get_random_non_overlapping_x()

	var boss_x = boss_node.global_position.x
	var danger_zone_radius = 100.0 # Reduced from 250
	
	# 50번 시도하여 안전한 위치를 찾음
	for i in 50:
		var candidate_x = _get_random_non_overlapping_x()
		if abs(candidate_x - boss_x) > danger_zone_radius:
			return candidate_x
			
	# 찾지 못하면 그냥 겹치지 않는 무작위 위치를 반환
	return _get_random_non_overlapping_x()

func _on_stalactite_destroyed(pos):
	if active_stalactite_positions.has(pos):
		active_stalactite_positions.erase(pos)
	
	spawn_count += 1
	var spawn_on_boss = (spawn_count % 4 == 0)
	
	var respawn_time = 5.0
	# 보스가 격노 상태이면 재생성 시간을 2초로, 숨어있는 상태이면 1초로, 그 외에는 5초로 설정
	if boss_is_enraged:
		respawn_time = 2.0
	else:
		var boss = get_tree().get_first_node_in_group("boss")
		if boss and boss.has_method("get") and boss.get("is_hiding"):
			respawn_time = 1.0
	
	var respawn_timer = Timer.new()
	add_child(respawn_timer)
	respawn_timer.wait_time = respawn_time
	respawn_timer.one_shot = true
	
	respawn_timer.timeout.connect(spawn_stalactite.bind(spawn_on_boss))
	respawn_timer.timeout.connect(respawn_timer.queue_free)
	
	respawn_timer.start()

# --- Boss-called functions ---
func drop_random_stalactite():
	var droppable = get_children().filter(func(s): return s is Area2D and s.visible and not s.is_falling)
	if not droppable.is_empty():
		droppable.pick_random().start_fall()

func drop_stalactite_near_player():
	var player = get_tree().get_first_node_in_group("player")
	if not player:
		drop_random_stalactite()
		return

	var droppable = get_children().filter(func(s): return s is Area2D and s.visible and not s.is_falling)
	if droppable.is_empty(): return

	var closest = null
	var min_dist = INF
	for s in droppable:
		var dist = abs(s.global_position.x - player.global_position.x)
		if dist < min_dist:
			min_dist = dist
			closest = s
	
	if closest:
		closest.start_fall()
