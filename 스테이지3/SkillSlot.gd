# fortknight-godot/스테이지3/SkillSlot.gd
extends Control

# 이 스크립트는 개별 스킬 슬롯 UI를 제어합니다.
# 쿨다운 애니메이션을 시작하고, 진행 상황을 업데이트하는 역할을 담당합니다.

# --- 노드 참조 ---
# @onready는 씬 트리가 준비되었을 때 노드를 안전하게 가져옵니다.
# CooldownProgress는 쿨다운 효과(셰이더)를 표시하는 자식 노드입니다.
@onready var cooldown_progress = $CooldownProgress

# --- 상태 변수 ---
# total_cooldown_time: 스킬의 전체 재사용 대기시간을 저장합니다.
# 이 값은 진행률(progress)을 0과 1 사이의 값으로 계산하는 데 사용됩니다.
var total_cooldown_time: float = 0.0

# _ready: 노드가 씬에 처음 추가될 때 한 번 호출되는 Godot 내장 함수입니다.
func _ready():
	# 게임 시작 시에는 쿨다운 UI 요소들을 숨깁니다.
	cooldown_progress.visible = false
	# 셰이더의 progress 값을 0으로 초기화하여 완전히 채워진 상태로 만듭니다.
	cooldown_progress.material.set_shader_parameter("progress", 0.0)

# start_cooldown: 스킬의 재사용 대기시간을 시작하는 함수입니다.
# player 스크립트에서 스킬을 사용했을 때 호출됩니다.
func start_cooldown(duration: float):
	total_cooldown_time = duration
	cooldown_progress.visible = true # 숨겨져 있던 쿨다운 오버레이를 표시합니다.
	update_display(duration) # UI를 초기 상태로 업데이트합니다.

# update_display: 남은 시간을 기반으로 쿨다운 UI를 업데이트합니다.
# player 스크립트의 _physics_process에서 매 프레임 호출됩니다.
func update_display(remaining_time: float):
	if remaining_time > 0:
		# 남은 시간을 백분율(0.0 ~ 1.0)로 변환하여 셰이더의 progress 값으로 전달합니다.
		# (전체 시간 - 남은 시간) / 전체 시간 = 진행된 시간의 비율
		var progress = (total_cooldown_time - remaining_time) / total_cooldown_time
		cooldown_progress.material.set_shader_parameter("progress", progress)
	else:
		# 남은 시간이 0 이하면 쿨다운이 끝난 것이므로 UI를 다시 숨깁니다.
		cooldown_progress.visible = false
		cooldown_progress.material.set_shader_parameter("progress", 0.0)
		total_cooldown_time = 0.0
