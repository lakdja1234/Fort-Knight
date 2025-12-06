# BossHealthBar.gd
extends CanvasLayer

# ==============================================================================
# 노드 참조
# ==============================================================================
@onready var primary_health_bar = $Control/PrimaryHealthBar # 기본 체력 바 (붉은색)
@onready var label = $Control/Label # 체력 수치를 표시하는 텍스트 라벨

# ==============================================================================
# Godot 내장 함수
# ==============================================================================
func _ready():
	# 씬이 시작될 때 UI를 즉시 표시하면 보스 노드를 찾지 못할 수 있으므로,
	# 처음에는 숨겨둡니다.
	visible = false 
	# 다음 프레임까지 잠시 대기하여 씬 트리가 완전히 로드되도록 보장합니다.
	await get_tree().create_timer(0.1).timeout
	
	# "boss" 그룹에서 보스 노드를 찾아 신호를 연결합니다.
	var boss = get_tree().get_first_node_in_group("boss")
	if boss:
		# 보스의 체력이 변경될 때마다 _on_health_updated 함수가 호출되도록 신호를 연결합니다.
		boss.health_updated.connect(_on_health_updated)
		
		# 게임 시작 시 보스의 현재 체력 정보를 가져와 UI를 초기화합니다.
		var health_status = boss.get_health_status()
		if health_status:
			_on_health_updated(health_status.current, health_status.max)
		
		# 모든 설정이 끝나면 UI를 화면에 표시합니다.
		visible = true

# ==============================================================================
# 시그널 핸들러
# ==============================================================================

# 보스의 'health_updated' 신호가 발생할 때마다 호출되는 함수입니다.
func _on_health_updated(current_hp, max_hp):
	# 텍스트 라벨을 "현재 체력 / 최대 체력" 형식으로 업데이트합니다.
	label.text = "%d / %d" % [current_hp, max_hp]
	
	# ProgressBar의 최대값과 현재 값을 업데이트합니다.
	primary_health_bar.max_value = max_hp
	primary_health_bar.value = current_hp

	# 만약 UI가 숨겨져 있었다면 다시 표시합니다.
	if not visible:
		visible = true
