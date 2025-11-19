extends CanvasLayer

func _ready():
	# 씬이 시작될 때 이 UI를 숨깁니다.
	visible = false
	
	# 'RetryButton'의 'pressed' 시그널을 내부 함수에 연결합니다.
	var retry_button = get_node_or_null("ColorRect/RetryButton")
	if is_instance_valid(retry_button):
		retry_button.pressed.connect(_on_retry_button_pressed)
	else:
		printerr("GameOverUI Error: 'RetryButton' 노드를 찾을 수 없습니다.")

# 외부에서 호출할 공개 함수
func show_game_over_screen():
	# 이 UI를 화면에 표시합니다.
	visible = true
	# 게임을 일시정지하여 다른 입력이 들어가지 않도록 합니다.
	get_tree().paused = true

# 'Retry' 버튼을 눌렀을 때 실행될 함수
func _on_retry_button_pressed():
	# 게임 일시정지를 먼저 해제합니다.
	get_tree().paused = false
	# 현재 씬을 다시 로드하여 게임을 재시작합니다.
	get_tree().reload_current_scene()
