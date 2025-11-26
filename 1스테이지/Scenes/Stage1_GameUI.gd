extends CanvasLayer

var boss_health_bar: TextureProgressBar
var boss_connected = false

# --- 플레이어 UI 참조 ---
@onready var player_health_label: Label = $PlayerHealthLabel
var player_connected = false
var main_player_ui_container: VBoxContainer


func _ready():
	# --- 플레이어 UI 컨테이너 (기존) ---
	main_player_ui_container = VBoxContainer.new()
	main_player_ui_container.name = "PlayerUIContainer"
	main_player_ui_container.set_anchors_preset(Control.PRESET_TOP_LEFT)
	main_player_ui_container.position = Vector2(20, 20) # 화면 좌측 상단 여백
	add_child(main_player_ui_container)
	player_health_label.reparent(main_player_ui_container)

	# --- 보스 체력바 (수정된 버전) ---
	var boss_ui_center_container = CenterContainer.new()
	boss_ui_center_container.name = "BossUICenterContainer"
	boss_ui_center_container.set_anchors_preset(Control.PRESET_TOP_WIDE) # 상단에 가로로 확장
	boss_ui_center_container.position.y = -100 # 상단에서 20px 아래로 오프셋
	add_child(boss_ui_center_container)

	boss_health_bar = TextureProgressBar.new()
	boss_health_bar.texture_under = load("res://스테이지2/bossHealthbar.png")
	boss_health_bar.texture_progress = load("res://스테이지2/bossHealthbar.png")
	boss_health_bar.tint_progress = Color(0.8, 0, 0)
	boss_health_bar.size = Vector2(300, 20)
	
	# CenterContainer가 이 체력바를 자동으로 중앙에 배치
	boss_ui_center_container.add_child(boss_health_bar)


func _process(_delta):
	# --- 플레이어와 시그널 연결 (한 번만 실행) ---
	if not player_connected:
		var player = get_tree().get_first_node_in_group("player")
		if is_instance_valid(player):
			if player.has_signal("health_updated"):
				player.health_updated.connect(_on_player_health_updated)
				if "hp" in player:
					_on_player_health_updated(player.hp)
			player_connected = true
	
	# --- 보스와 시그널 연결 (한 번만 실행) ---
	if not boss_connected:
		var boss = get_tree().get_first_node_in_group("boss")
		if is_instance_valid(boss):
			if boss.has_signal("health_updated"):
				boss.health_updated.connect(_on_boss_health_updated)
				# 초기 체력 표시를 위해 연결 직후 한 번 호출
				if "hp" in boss and "max_hp" in boss:
					_on_boss_health_updated(boss.hp, boss.max_hp)
			boss_connected = true


# --- 시그널 수신 함수 ---
func _on_player_health_updated(current_hp):
	player_health_label.text = "Player HP: %d" % current_hp

func _on_boss_health_updated(current_hp, max_hp):
	if max_hp > 0:
		boss_health_bar.max_value = max_hp
		boss_health_bar.value = current_hp
