extends CanvasLayer

# --- UI 노드 참조 ---
@onready var player_health_label: Label = $PlayerHealthLabel

# --- 동적 UI 관리 변수 ---
var main_container: VBoxContainer

# --- 시그널 연결 상태 플래그 ---
var player_connected = false

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

func _process(_delta):
	# --- 플레이어와 시그널 연결 (한 번만 실행) ---
	if not player_connected:
		var player = get_tree().get_first_node_in_group("player")
		if is_instance_valid(player):
			if player.has_signal("health_updated"):
				player.health_updated.connect(_on_player_health_updated)
			player_connected = true

# --- 시그널 수신 함수 ---
func _on_player_health_updated(current_hp):
	player_health_label.text = "Player HP: %d" % current_hp
