# game_manager.gd (Merged by Gemini)
extends Node

# --- UI 및 노드 참조 ---
@onready var game_over_ui = get_node("/root/TitleMap/GameOverUI")
@onready var game_clear_ui = get_node("/root/TitleMap/GameClearUI") # HEAD의 on_boss_died에서 사용했지만, clear 씬으로 전환하므로 현재는 사용 안 함
@onready var canvas_modulate = get_node_or_null("/root/TitleMap/CanvasModulate")
var transition_rect: ColorRect # 씬 전환 시 페이드 효과를 위한 검은색 사각형

# --- 사운드 ---
var bgm_player: AudioStreamPlayer

# --- 상태 ---
var is_darkness_active = false # 횃불 기믹용 변수 (미사용)

func _ready():
	# 스테이지 시작 시 메시지 박스 표시 및 메시지 추가
	GlobalMessageBox.visible = true
	var start_messages = [
		"여긴 어두운 동굴이에요! 분명 어딘가 빛을 밝힐만한게 있을텐데..",
		"아무리 녀석이라도 종유석을 무시할 순 없을거에요!"
	]
	GlobalMessageBox.add_message(start_messages.pick_random())

	# --- 플레이어 및 보스 신호 연결 ---
	var player = get_tree().get_first_node_in_group("player")
	if player:
		player.game_over.connect(_on_game_over)

	var boss_node = get_tree().get_first_node_in_group("boss")
	if is_instance_valid(boss_node):
		boss_node.boss_died.connect(_on_boss_died)
		boss_node.boss_animation_finished.connect(_on_boss_animation_finished)

	# --- 씬 전환 효과용 ColorRect 생성 ---
	transition_rect = ColorRect.new()
	transition_rect.color = Color(0, 0, 0, 0)
	transition_rect.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(transition_rect)
	transition_rect.hide()
	
	# --- 배경 음악 재생 ---
	bgm_player = AudioStreamPlayer.new()
	bgm_player.stream = load("res://스테이지3/sound/caveBGM.mp3")
	bgm_player.volume_db = -10
	add_child(bgm_player)
	bgm_player.play()
	bgm_player.finished.connect(bgm_player.play)
	
	# --- HEAD 버전의 디버그 UI 생성 ---
	var debug_canvas = CanvasLayer.new()
	debug_canvas.layer = 100 # 항상 위에 표시
	add_child(debug_canvas)
	
	var hbox = HBoxContainer.new()
	hbox.position = Vector2(10, 10)
	debug_canvas.add_child(hbox)
	
	var gimmick1_button = Button.new()
	gimmick1_button.text = "1기믹 (HP 50%)"
	gimmick1_button.pressed.connect(_on_gimmick_1_button_pressed)
	hbox.add_child(gimmick1_button)
	
	var gimmick2_button = Button.new()
	gimmick2_button.text = "2기믹 (HP 30%)"
	gimmick2_button.pressed.connect(_on_gimmick_2_button_pressed)
	hbox.add_child(gimmick2_button)
	# --- 디버그 UI 끝 ---

func _exit_tree():
	if bgm_player:
		bgm_player.stop()

# ==============================================================================
# 신호 핸들러
# ==============================================================================

func _on_game_over():
	GlobalMessageBox.visible = false
	if is_instance_valid(game_over_ui):
		game_over_ui.show()
	get_tree().paused = true

# 보스 HP가 0이 되는 즉시 호출
func _on_boss_died():
	# 보스 사망 애니메이션이 시작될 때 필요한 로직 (예: 플레이어 무적)
	# 현재는 특별한 동작 없음
	pass

# 보스의 모든 사망 애니메이션이 끝난 후 호출 (bolt6281 버전 로직)
func _on_boss_animation_finished():
	GlobalMessageBox.visible = false
	
	transition_rect.show()
	var tween = create_tween()
	tween.tween_property(transition_rect, "color", Color(0, 0, 0, 1), 2.0)
	await tween.finished
	get_tree().change_scene_to_file("res://스테이지3/stage3_clear.tscn")

# ==============================================================================
# 유틸리티 및 디버그 함수
# ==============================================================================

# Game Over UI에서 재시도 버튼을 누를 때 호출 (HEAD 버전 기능)
func _on_retry_button_pressed():
	get_tree().paused = false
	get_tree().reload_current_scene()

func stop_bgm():
	if bgm_player and bgm_player.playing:
		bgm_player.stop()

# --- 디버그 버튼 콜백 ---
func _on_gimmick_1_button_pressed():
	var boss = get_tree().get_first_node_in_group("boss")
	if boss and boss.has_method("take_damage"):
		var damage_to_deal = boss.hp - (boss.max_hp * 0.5) + 1
		boss.take_damage(damage_to_deal)
		print("DEBUG: Boss HP set to < 50% to trigger Gimmick 1.")

func _on_gimmick_2_button_pressed():
	var boss = get_tree().get_first_node_in_group("boss")
	if boss and boss.has_method("take_damage"):
		var damage_to_deal = boss.hp - (boss.max_hp * 0.3) + 1
		boss.take_damage(damage_to_deal)
		print("DEBUG: Boss HP set to < 30% to trigger Gimmick 2.")
		
# --- 미사용 함수 (호환성을 위해 유지) ---
func darken_screen():
	if is_instance_valid(canvas_modulate):
		var tween = create_tween()
		tween.tween_property(canvas_modulate, "color", Color(0.1, 0.1, 0.1), 1.0)

func lighten_screen():
	if is_instance_valid(canvas_modulate):
		var tween = create_tween()
		tween.tween_property(canvas_modulate, "color", Color.WHITE, 1.0)
