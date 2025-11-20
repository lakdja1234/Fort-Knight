extends Node2D

# 노드를 미리 가져오기 위한 변수 선언
@onready var player = $Player
@onready var game_over_ui = $GameOverUI
@onready var boss = $쇄빙선
@onready var health_bar = $GameUI/HealthBar

func _ready():
	# 플레이어 노드와 UI 노드가 모두 유효한지 확인
	if is_instance_valid(player) and is_instance_valid(game_over_ui):
		# 플레이어의 game_over 신호를 이 스크립트의 _on_player_game_over 함수에 연결
		player.game_over.connect(_on_player_game_over)
	else:
		if not is_instance_valid(player):
			printerr("스테이지2 Error: 'Player' 노드를 찾을 수 없습니다.")
		if not is_instance_valid(game_over_ui):
			printerr("스테이지2 Error: 'GameOverUI' 노드를 찾을 수 없습니다.")

	# 보스와 체력 바 연결
	if is_instance_valid(boss) and is_instance_valid(health_bar):
		boss.health_updated.connect(health_bar.update_health)
		# 초기 체력 설정
		if "boss_hp" in boss and "max_hp" in boss:
			health_bar.update_health(boss.boss_hp, boss.max_hp)
	else:
		if not is_instance_valid(boss):
			printerr("스테이지2 Error: '쇄빙선' (보스) 노드를 찾을 수 없습니다.")
		if not is_instance_valid(health_bar):
			printerr("스테이지2 Error: 'GameUI/HealthBar' 노드를 찾을 수 없습니다.")

# 플레이어의 game_over 신호를 받았을 때 실행될 함수
func _on_player_game_over():
	# 게임오버 UI를 화면에 표시
	game_over_ui.show()
	# 게임을 일시정지
	get_tree().paused = true
