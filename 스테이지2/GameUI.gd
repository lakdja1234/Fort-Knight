extends CanvasLayer

# --- UI 노드 참조 ---
@onready var player_health_label: Label = $PlayerHealthLabel
@onready var freeze_gauge_label: Label = $FreezeGaugeLabel
@onready var boss_health_bar: Control = $BossHealthBar

# --- 동적 UI 관리 변수 ---
var main_container: VBoxContainer
var heater_labels: Dictionary = {}

# --- 시그널 연결 상태 플래그 ---
var player_connected = false
var boss_connected = false
var heaters_connected = false

func _ready():
	# 1. 모든 UI 요소를 담을 메인 컨테이너를 생성하고 설정합니다.
	main_container = VBoxContainer.new()
	main_container.name = "MainUIContainer"
	main_container.set_anchors_preset(Control.PRESET_TOP_LEFT)
	main_container.position = Vector2(20, 20) # 화면 좌측 상단 여백
	add_child(main_container)

	# 2. 기존 레이블들을 컨테이너 안으로 재배치합니다.
	# 이렇게 하면 컨테이너가 자동으로 위치를 정렬해줍니다.
	player_health_label.reparent(main_container)
	freeze_gauge_label.reparent(main_container)
	
	# 3. 구분을 위한 빈 레이블 추가 (선택 사항)
	var separator = Label.new()
	separator.text = "--- Heaters ---"
	main_container.add_child(separator)
	
	# --- 보스와 시그널 연결 (한 번만 실행) ---
	var boss = get_tree().get_first_node_in_group("boss")
	if is_instance_valid(boss):
		if boss.has_signal("health_updated"):
			boss.health_updated.connect(boss_health_bar.update_health)
			# 초기 체력 설정
			if "hp" in boss and "max_hp" in boss:
				boss_health_bar.update_health(boss.hp, boss.max_hp)
		boss_connected = true


func _process(_delta):
	# --- 플레이어와 시그널 연결 (한 번만 실행) ---
	if not player_connected:
		var player = get_tree().get_first_node_in_group("player")
		if is_instance_valid(player):
			if player.has_signal("health_updated"):
				player.health_updated.connect(_on_player_health_updated)
			if player.has_signal("freeze_gauge_changed"):
				player.freeze_gauge_changed.connect(_on_player_freeze_gauge_updated)
			player_connected = true

	# --- 온열장치와 시그널 연결 (한 번만 실행) ---
	if not heaters_connected:
		var heaters = get_tree().get_nodes_in_group("heaters")
		if not heaters.is_empty():
			for heater in heaters:
				if heater.has_signal("health_updated"):
					var new_label = Label.new()
					new_label.name = heater.name
					# 메인 컨테이너에 추가합니다.
					main_container.add_child(new_label)
					heater_labels[heater.name] = new_label
					
					heater.health_updated.connect(_on_heater_health_updated)
					
					if "hp" in heater and "max_hp" in heater:
						_on_heater_health_updated(heater.hp, heater.max_hp, heater.name)

			heaters_connected = true


# --- 시그널 수신 함수 ---
func _on_player_health_updated(current_hp):
	player_health_label.text = "Player HP: %d" % current_hp

func _on_player_freeze_gauge_updated(current_value, max_value):
	freeze_gauge_label.text = "Freeze: %d / %d" % [int(current_value), int(max_value)]

# --- 온열장치 체력 업데이트 함수 ---
func _on_heater_health_updated(current_hp, max_hp, heater_name):
	if heater_labels.has(heater_name):
		var label_to_update = heater_labels[heater_name]
		label_to_update.text = "%s: %d / %d" % [heater_name, current_hp, max_hp]
		
		if current_hp <= 0:
			label_to_update.visible = false
