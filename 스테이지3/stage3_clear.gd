extends Control

@onready var transition_rect = $TransitionRect
@onready var button = $AcquireButton

func _ready():
	# 씬이 시작될 때 1초 페이드인 효과
	transition_rect.show()
	var tween = create_tween()
	tween.tween_property(transition_rect, "modulate", Color(0, 0, 0, 0), 1.0)
	tween.tween_callback(func(): transition_rect.hide())

	button.pressed.connect(_on_acquire_pressed)
	
func _unhandled_input(event):
	if event.is_action_pressed("ui_accept"): # 'ui_accept'는 보통 스페이스바나 Enter에 매핑됩니다.
		_on_acquire_pressed()

func _on_acquire_pressed():
	# 버튼이 이미 눌렸으면 다시 실행하지 않음
	if button.disabled: return
	button.disabled = true
	
	# 씬 전환 전 메시지 박스를 숨김
	GlobalMessageBox.visible = false
	
	# 1초 페이드아웃 후 씬 전환
	transition_rect.show()
	var tween = create_tween()
	tween.tween_property(transition_rect, "modulate", Color(0, 0, 0, 1), 1.0)
	await tween.finished
	
	# 스테이지 선택 씬 경로. 만약 다를 경우 이 부분을 수정해야 합니다.
	get_tree().change_scene_to_file("res://시작화면/시작화면.tscn")	
