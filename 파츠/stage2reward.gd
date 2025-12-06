# Stage2Reward.gd
extends Control

func _ready():
	# AcquireButton의 pressed 시그널을 연결합니다.
	$Panel/VBoxContainer/AcquireButton.pressed.connect(_on_acquire_button_pressed)

func _on_acquire_button_pressed():
	# 유도 미사일 파츠를 로드합니다.
	var homing_missile_part = load("res://parts/homing_missile_part.tres")
	
	# PlayerData 오토로드를 가져옵니다.
	var player_data = get_node_or_null("/root/PlayerData")
	
	if is_instance_valid(player_data):
		# PlayerData의 add_owned_part 함수를 사용하여 파츠를 추가합니다.
		player_data.add_owned_part(homing_missile_part.resource_path)
		
		# 메시지를 표시합니다.
		GlobalMessageBox.add_message("새로운 파츠 '유도 미사일 MK-1'을 획득했습니다!", 5.0)
	else:
		printerr("PlayerData 오토로드를 찾을 수 없습니다!")

	# 타이틀 화면으로 페이드인 전환합니다.
	SceneTransition.change_scene("res://스테이지3/title_screen.tscn")
	queue_free()
