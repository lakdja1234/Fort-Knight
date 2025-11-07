extends Node2D

@export var stalactite_scene: PackedScene
const STALACTITE_COUNT = 5
const MIN_DISTANCE_BETWEEN_STALACTITES = 100

var stalactite_positions = []
var destruction_count = 0

func _ready():
	randomize()
	add_to_group("stalactite_manager")
	if not stalactite_scene:
		return
	
	var spawn_timer = Timer.new()
	add_child(spawn_timer)
	spawn_timer.wait_time = 3
	spawn_timer.one_shot = true
	spawn_timer.timeout.connect(_on_initial_spawn_timer_timeout)
	spawn_timer.start()

func _on_initial_spawn_timer_timeout():
	stalactite_positions.clear()
	for i in range(STALACTITE_COUNT):
		spawn_stalactite()

func spawn_stalactite(on_boss = false):
	var stalactite = stalactite_scene.instantiate()
	var x_pos

	if on_boss:
		var boss = get_tree().get_first_node_in_group("boss")
		if boss:
			x_pos = boss.global_position.x
		else: # Boss not found, fallback to random
			x_pos = randf_range(50, 1270)
	else:
		var valid_position = false
		var attempts = 0
		while not valid_position and attempts < 50:
			x_pos = randf_range(50, 1270)
			valid_position = true
			for pos in stalactite_positions:
				if abs(pos.x - x_pos) < MIN_DISTANCE_BETWEEN_STALACTITES:
					valid_position = false
					break
			attempts += 1
		if not valid_position:
			x_pos = randf_range(50, 1270)
	
	# 종유석 이미지의 높이 절반만큼 위로 올려 천장에 붙도록 조정
	var stalactite_height = 0.0
	if stalactite.get_node("Sprite2D") and stalactite.get_node("Sprite2D").texture:
		stalactite_height = stalactite.get_node("Sprite2D").texture.get_height() * stalactite.get_node("Sprite2D").scale.y
	var new_pos = Vector2(x_pos, 0 + stalactite_height / 2.0)
	stalactite.position = new_pos
	stalactite_positions.append(new_pos)
	
	stalactite.destroyed.connect(_on_stalactite_destroyed.bind(new_pos))
	
	# Fade-in effect
	var tween = create_tween()
	stalactite.modulate.a = 0
	tween.tween_property(stalactite, "modulate:a", 1.0, 1.0)
	
	add_child(stalactite)

func _on_stalactite_destroyed(pos):
	destruction_count += 1
	stalactite_positions.erase(pos)
	
	var spawn_on_boss = (destruction_count % 3 == 0)
	
	var respawn_timer = Timer.new()
	add_child(respawn_timer)
	respawn_timer.wait_time = 5
	respawn_timer.one_shot = true
	respawn_timer.timeout.connect(spawn_stalactite.bind(spawn_on_boss))
	respawn_timer.timeout.connect(respawn_timer.queue_free)
	respawn_timer.start()

func drop_stalactite_at(position):
	var stalactite = stalactite_scene.instantiate()
	add_child(stalactite)
	stalactite.global_position = position
	stalactite.start_fall()
