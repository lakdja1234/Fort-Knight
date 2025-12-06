extends Node2D

@onready var description_label = $DescriptionScrollContainer/DescriptionLabel
@onready var previous_button = $PreviousButton
@onready var next_button = $NextButton

var current_page_index = 0

const BOSS_DESCRIPTION_PAGES = [
	# Page 1
	"""[center][b][color=#FFD700]쇄빙선 보스[/b][/center]

[b]등장 배경:[/b]
이 거대한 쇄빙선 보스는 얼음으로 뒤덮인 황무지 깊은 곳에서 발견됩니다. 혹독한 환경을 극복하기 위해 설계된 이 기계는 강력한 동력원과 얼음을 부수는 첨단 기술로 무장하고 있습니다. 원래는 탐사 및 자원 채취를 위한 것이었으나, 알 수 없는 이유로 폭주하여 주변 모든 것을 파괴하는 위협적인 존재가 되었습니다. 플레이어는 이 폭주한 기계 몬스터를 막고 얼어붙은 땅에 평화를 되찾아야 합니다.

[b]주요 공격 패턴:[/b]
- [b]유도 미사일:[/b] 쇄빙선은 플레이어를 추적하는 유도 미사일을 발사합니다. 이 미사일은 느리지만 정확하며, 피격 시 강력한 폭발을 일으킵니다. 미사일의 궤적을 예측하고 회피하는 것이 중요합니다.
- [b]포물선 포탄:[/b] 플레이어의 위치에 포물선 궤적을 그리는 강력한 포물선 포탄을 발사합니다. 포탄이 떨어질 지점에는 사전 경고 표시가 나타나므로, 이를 보고 빠르게 벗어나야 합니다. 지형이나 방어벽에 의해 경로가 막히면 궤도를 변경하여 발사하기도 합니다.
""",
	# Page 2
	"""[center][b][color=#FFD700]특수 기믹: 온열장치와 과열 시스템[/color][/b][/center]

쇄빙선은 극한의 추위 속에서도 효율적으로 작동하기 위해 여러 개의 [b]온열장치[/b]에 의존하고 있습니다. 이 온열장치들은 쇄빙선의 핵심 코어 온도를 유지하는 역할을 합니다.
- [b]취약점:[/b] 쇄빙선 보스는 직접적인 공격에는 매우 강력한 방어력을 가지고 있지만, 몸체 외부에 노출된 온열장치들은 비교적 취약합니다.
- [b]온열장치 파괴 효과:[/b] 온열장치를 파괴할 때마다 쇄빙선의 공격 패턴이 변화하거나, 새로운 공격 방식이 활성화될 수 있습니다. 특히, 모든 온열장치를 파괴하면 쇄빙선의 코어 온도가 급격히 하강하여 [b]과열(Overheat) 상태[/b]에 돌입하게 됩니다.
- [b]과열 상태:[/b] 과열 상태가 된 쇄빙선은 일시적으로 행동 불능이 되며, 지속적으로 막대한 피해를 입게 됩니다. 이 짧은 시간 동안 플레이어는 쇄빙선의 약점을 공략할 수 있는 결정적인 기회를 얻게 됩니다.
- [b]얼음벽과 상호작용:[/b] 쇄빙선이 생성하는 얼음벽은 온열장치와 상호작용할 수 있습니다. 예를 들어, 온열장치가 얼음벽을 녹여 플레이어의 이동 경로를 열어주거나, 반대로 얼음벽이 온열장치를 가려 플레이어의 공격을 방해할 수도 있습니다. 이러한 상호작용을 파악하고 전략적으로 활용해야 합니다.
""",
	# Page 3
	"""[center][b][color=#FFD700]환경적 요인: 동결 게이지[/color][/b][/center]

이 스테이지는 극심한 한파가 몰아치는 얼음 동굴입니다. 플레이어는 끊임없이 [b]동결 게이지[/b]를 관리해야 합니다.
- [b]게이지 상승:[/b] 차가운 지형에 오래 머물거나, 보스의 냉기 공격에 피격되면 동결 게이지가 빠르게 상승합니다.
- [b]게이지 하강:[/b] 맵 곳곳에 배치된 온열장치의 범위 내에 들어가면 동결 게이지가 서서히 감소합니다.
- [b]게이지 100%:[/b] 동결 게이지가 100%에 도달하면 플레이어는 [b]시스템 동결[/b] 상태가 되어 기동력이 50%로 제한되는 치명적인 디버프를 받습니다.
- [b]전략적 활용:[/b] 온열장치를 파괴하거나 활성화하여 동결 게이지를 조절하고, 보스의 공격을 피하면서 얼음 동굴의 환경적 위협에 대처해야 합니다.

[b][color=#FFD700]승리 조건:[/color][/b]
쇄빙선의 모든 온열장치를 파괴하여 과열 상태로 만든 후, 무방비 상태가 된 코어에 집중 공격을 가해 쇄빙선을 완전히 정지시키십시오. 얼음 동굴의 운명이 당신의 손에 달려 있습니다!"""
]

func _ready():
	_update_page_display() # Display the first page

func _update_page_display():
	description_label.text = BOSS_DESCRIPTION_PAGES[current_page_index]
	previous_button.disabled = (current_page_index == 0)
	
	if current_page_index == BOSS_DESCRIPTION_PAGES.size() - 1:
		next_button.text = "시작" # Last page, "Next" becomes "Start"
	else:
		next_button.text = "다음"

func _on_previous_button_pressed():
	if current_page_index > 0:
		current_page_index -= 1
		_update_page_display()

func _on_next_button_pressed():
	if current_page_index < BOSS_DESCRIPTION_PAGES.size() - 1:
		current_page_index += 1
		_update_page_display()
	else:
		# On last page, "Start" button was pressed
		SceneTransition.change_scene("res://스테이지2/스테이지2.tscn")