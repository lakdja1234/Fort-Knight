extends Node

@onready var boss_health_bar = get_node_or_null("/root/TitleMap/GameUI/BossHealthBar")
@onready var canvas_modulate = get_node_or_null("/root/TitleMap/CanvasModulate")

var game_over_ui: CanvasLayer
var game_clear_ui: CanvasLayer
var transition_rect: ColorRect # 씬 전환 시 페이드 효과를 위한 검은색 사각형

var bgm_player: AudioStreamPlayer

func _ready():
	# 스테이지 시작 시 메시지 박스를 보이게 함
	GlobalMessageBox.visible = true
	
	var start_messages = [
		"여긴 어두운 동굴이에요! 분명 어딘가 빛을 밝힐만한게 있을텐데..",
		"아무리 녀석이라도 종유석을 무시할 순 없을거에요!"
	]
	GlobalMessageBox.add_message(start_messages.pick_random())

	# 플레이어와 보스 노드를 찾아 신호에 연결
	var player = get_tree().get_first_node_in_group("player")
	if player:
		player.game_over.connect(_on_game_over)

	var boss_node = get_tree().get_first_node_in_group("boss")
	if is_instance_valid(boss_node):
		# 보스의 사망 애니메이션이 모두 끝났을 때의 신호를 받아 _on_boss_animation_finished 함수를 실행
		boss_node.boss_animation_finished.connect(_on_boss_animation_finished)
			
	# 씬 전환 효과를 위한 ColorRect를 동적으로 생성하고 씬 트리에 추가
	transition_rect = ColorRect.new()
	transition_rect.color = Color(0, 0, 0, 0) # 처음에는 완전히 투명
	transition_rect.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT) # 화면 전체를 덮도록 설정
	add_child(transition_rect)
	transition_rect.hide() # 평소에는 숨겨둠
	
	# --- 배경 음악 재생 ---
	bgm_player = AudioStreamPlayer.new()
	bgm_player.stream = load("res://스테이지3/sound/caveBGM.mp3")
	bgm_player.volume_db = -10 # 볼륨을 약간 줄임
	add_child(bgm_player)
	bgm_player.play()
	# AudioStreamPlayer의 finished 신호를 자기 자신에게 다시 연결하여 무한 반복
	bgm_player.finished.connect(bgm_player.play)

func stop_bgm():
	if bgm_player and bgm_player.playing:
		bgm_player.stop()

func _exit_tree():
	# 씬을 나갈 때 배경 음악 정지
	if bgm_player:
		bgm_player.stop()

func _on_game_over():
	# 게임 오버 시 메시지 박스를 숨김
	GlobalMessageBox.visible = false
	
	if not is_instance_valid(game_over_ui):
		# TODO: GameOver UI 씬을 로드하고 인스턴스화하는 코드 추가
		pass
	if is_instance_valid(game_over_ui):
		game_over_ui.show()
	get_tree().paused = true

# 보스의 사망 애니메이션이 모두 끝났을 때 호출되는 함수
func _on_boss_animation_finished():
	# 씬 전환 전 메시지 박스를 숨김
	GlobalMessageBox.visible = false
	
	# 2초 페이드인 효과와 함께 씬 전환
	transition_rect.show()
	var tween = create_tween()
	tween.tween_property(transition_rect, "color", Color(0, 0, 0, 1), 2.0)
	await tween.finished
	get_tree().change_scene_to_file("res://스테이지3/stage3_clear.tscn")

# 화면을 어둡게 하는 효과 (현재 사용되지 않음)
func darken_screen():
	if is_instance_valid(canvas_modulate):
		var tween = create_tween()
		tween.tween_property(canvas_modulate, "color", Color(0.1, 0.1, 0.1), 1.0)

# 화면을 밝게 하는 효과 (현재 사용되지 않음)
func lighten_screen():
	if is_instance_valid(canvas_modulate):
		var tween = create_tween()
		tween.tween_property(canvas_modulate, "color", Color.WHITE, 1.0)
