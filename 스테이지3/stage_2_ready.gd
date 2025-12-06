extends Node2D

@onready var description_label = $DescriptionScrollContainer/DescriptionLabel
@onready var previous_button = $PreviousButton
@onready var next_button = $NextButton
@onready var overlay = $Overlay # Overlay 노드를 가져옵니다.

var current_page_index = 0

const BOSS_DESCRIPTION_PAGES = [
	# Page 1
	"""[color=white][center][font_size=32][b] 혹한의 추위 (냉동 게이지)[/b][/font_size][/center]
[center]\n\n[img=200x200]res://스테이지2/튜토리얼_냉동게이지.png[/img]
\n\n이곳은 매우 춥습니다!
시간이 지나거나 얼음 위에 있으면 '냉동 게이지'가 차오릅니다.
게이지가 가득 차면 기동력이 떨어지니 주의하세요![/center]
[/color]""",
	# Page 2
	"""[color=white][center][font_size=32][b] 생존 수단 (맵 온열장치)[/b][/font_size][/center]
[center]\n\n[img=200x200]res://스테이지2/온열(꺼짐)-Photoroom.png[/img]
\n\n맵 곳곳에 있는 '온열장치'를 찾으세요.
포탄을 맞춰 켜면 따뜻한 열기가 나와 냉동 게이지를 낮춰줍니다.
단, 15초마다 부는 강풍에 의해 다시 꺼질 수 있습니다.[/center]
[/color]""",
	# Page 3
	"""[color=white][center][font_size=32][b] 보스 공략 (약점 파괴)[/b][/font_size][/center]
[center]\n\n[img=200x200]res://스테이지2/튜토리얼_보스 약점.png[/img]
\n\n보스(쇄빙선)는 매우 단단합니다.
보스 몸체에 붙은 붉은색 '온도유지장치(약점)'를 모두 파괴하세요.
약점이 모두 파괴되면 보스는 시스템 동결 상태에 빠집니다.[/center]
[/color]"""
]

func _ready():
	description_label.modulate = Color(1, 1, 1, 1) # 설명 레이블을 보이도록 설정합니다.
	overlay.modulate = Color(1, 1, 1, 1) # 오버레이를 보이도록 설정합니다.
	_update_page_display() # Display the first page

func _update_page_display():
	description_label.text = "[color=white]" + BOSS_DESCRIPTION_PAGES[current_page_index] + "[/color]"
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
