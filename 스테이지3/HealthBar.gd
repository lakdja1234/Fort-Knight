extends Control

@onready var progress_bar: ProgressBar = $ProgressBar
@onready var label: Label = $Label

func _ready():
	# 노드가 완전히 준비될 때까지 한 프레임 기다린 후, 보스의 현재 체력을 가져와 UI를 초기화함
	# 이는 게임 시작 시 체력바가 즉시 정확한 값으로 표시되도록 보장함 (초기화 경쟁 상태 방지)
	var timer = get_tree().create_timer(0.01) # A very short delay
	timer.timeout.connect(_initialize_health)

func _initialize_health():
	var boss = get_tree().get_first_node_in_group("boss")
	if boss and boss.has_method("get_health_status"):
		var health_status = boss.get_health_status()
		update_health(health_status.current, health_status.max)

func update_health(current_hp: float, max_hp: float):
	if progress_bar == null:
		return # Node not ready yet.

	if max_hp > 0:
		progress_bar.value = (current_hp / max_hp) * 100.0
		label.text = "%d / %d" % [current_hp, max_hp]
	else:
		progress_bar.value = 0
		label.text = "0 / 0"
