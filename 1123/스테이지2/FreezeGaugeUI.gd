extends CanvasLayer

@onready var progress_bar = $MarginContainer/VBoxContainer/ProgressBarContainer/ProgressBar
@onready var freeze_image = $MarginContainer/VBoxContainer/ImageContainer/TextureRect
@onready var progress_bar_text = $MarginContainer/VBoxContainer/ProgressBarContainer/ProgressBarText

@export var default_texture: Texture2D
@export var frozen_texture: Texture2D

# 플레이어 노드를 찾기 위한 참조
var player: CharacterBody2D

func _ready():
	# 초기 텍스처 및 라벨 상태 설정
	freeze_image.texture = default_texture
	progress_bar_text.visible = false
	progress_bar.show_percentage = true # 평소에는 퍼센티지를 보여줌

	# 씬 트리가 준비된 후 플레이어를 찾는 것이 더 안정적입니다.
	await get_tree().process_frame
	
	# 'player' 그룹에서 플레이어 노드를 찾습니다.
	player = get_tree().get_first_node_in_group("player")
	
	if player:
		# 플레이어의 시그널에 연결합니다.
		player.freeze_gauge_changed.connect(_on_player_freeze_gauge_changed)
		
		# 초기값을 설정합니다.
		if "max_freeze_gauge" in player and "current_freeze_gauge" in player:
			progress_bar.max_value = player.max_freeze_gauge
			progress_bar.value = player.current_freeze_gauge
		
		# 초기 이미지 및 라벨 상태를 설정합니다.
		update_freeze_status_ui()

# 플레이어의 냉동 게이지가 변경될 때 호출될 함수
func _on_player_freeze_gauge_changed(current_value, max_value):
	progress_bar.max_value = max_value
	progress_bar.value = current_value
	
	# 플레이어의 얼어붙음 상태가 변경되었을 수 있으므로 UI를 업데이트합니다.
	update_freeze_status_ui()

func update_freeze_status_ui():
	if not is_instance_valid(player):
		return

	if player.is_frozen:
		freeze_image.texture = frozen_texture
		progress_bar_text.visible = true
		progress_bar.show_percentage = false # 얼어붙으면 퍼센티지 숨김
	else:
		freeze_image.texture = default_texture
		progress_bar_text.visible = false
		progress_bar.show_percentage = true # 얼지 않으면 퍼센티지 보여줌
