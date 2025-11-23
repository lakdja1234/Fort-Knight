extends CanvasLayer

# 1. 보스가 호출할 시그널(신호) 정의
signal debug_toggle_homing_pressed
signal debug_spawn_wall_pressed

func _ready():
	# 각 버튼 노드를 안전하게 찾고, 'pressed' 시그널을 연결합니다.
	var toggle_homing_button = get_node_or_null("ToggleHomingButton")
	if is_instance_valid(toggle_homing_button):
		toggle_homing_button.pressed.connect(_on_toggle_homing_pressed)
	else:
		printerr("DebugUI Error: 'ToggleHomingButton' 노드를 찾을 수 없습니다.")

	var spawn_wall_button = get_node_or_null("SpawnWallButton")
	if is_instance_valid(spawn_wall_button):
		spawn_wall_button.pressed.connect(_on_spawn_wall_pressed)
	else:
		printerr("DebugUI Error: 'SpawnWallButton' 노드를 찾을 수 없습니다.")

	var damage_heaters_button = get_node_or_null("DamageHeatersButton")
	if is_instance_valid(damage_heaters_button):
		damage_heaters_button.pressed.connect(_on_damage_heaters_pressed)
	else:
		printerr("DebugUI Error: 'DamageHeatersButton' 노드를 찾을 수 없습니다.")

	var reset_button = get_node_or_null("ResetButton")
	if is_instance_valid(reset_button):
		reset_button.pressed.connect(_on_reset_button_pressed)
	else:
		printerr("DebugUI Error: 'ResetButton' 노드를 찾을 수 없습니다.")


# 3. 버튼이 눌리면, 이 함수가 호출됨
func _on_toggle_homing_pressed():
	# 4. 보스에게 "유도탄 토글" 신호를 보냄
	emit_signal("debug_toggle_homing_pressed")

func _on_spawn_wall_pressed():
	# 4. 보스에게 "방어벽 생성" 신호를 보냄
	emit_signal("debug_spawn_wall_pressed")

# --- 새 디버그 기능 ---
func _on_damage_heaters_pressed():
	print("디버그: 모든 온열장치에 50 데미지")
	var heaters = get_tree().get_nodes_in_group("heaters")
	for heater in heaters:
		if heater.has_method("take_damage"):
			heater.take_damage(50)

func _on_reset_button_pressed():
	print("디버그: 씬을 다시 시작합니다.")
	get_tree().reload_current_scene()
