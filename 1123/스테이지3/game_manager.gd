extends Node

# --- UI Node References ---
@onready var game_over_ui = get_node("/root/TitleMap/GameOverUI")
@onready var game_clear_ui = get_node("/root/TitleMap/GameClearUI")

func _ready():
	var player = get_node("/root/TitleMap/Player")
	if player:
		player.game_over.connect(_on_game_over)
		
	var boss = get_tree().get_first_node_in_group("boss")
	if boss:
		boss.boss_died.connect(_on_boss_died)

	# --- Create Debug UI for Gimmicks ---
	var debug_canvas = CanvasLayer.new()
	debug_canvas.layer = 100 # Ensure debug UI is always on top
	add_child(debug_canvas)
	
	var hbox = HBoxContainer.new()
	hbox.position = Vector2(10, 10) # Top-left corner
	debug_canvas.add_child(hbox)
	
	var gimmick1_button = Button.new()
	gimmick1_button.text = "1기믹 (HP 50%)"
	gimmick1_button.pressed.connect(_on_gimmick_1_button_pressed)
	hbox.add_child(gimmick1_button)
	
	var gimmick2_button = Button.new()
	gimmick2_button.text = "2기믹 (HP 30%)"
	gimmick2_button.pressed.connect(_on_gimmick_2_button_pressed)
	hbox.add_child(gimmick2_button)
	# --- End of Debug UI ---

func _on_game_over():
	game_over_ui.show()
	get_tree().paused = true

func _on_boss_died():
	game_clear_ui.show()
	get_tree().paused = true

func _on_retry_button_pressed():
	get_tree().paused = false
	get_tree().reload_current_scene()

func _on_gimmick_1_button_pressed():
	var boss = get_tree().get_first_node_in_group("boss")
	if boss:
		boss.hp = boss.max_hp * 0.5
		print("DEBUG: Boss HP set to 50% to trigger Gimmick 1.")

func _on_gimmick_2_button_pressed():
	var boss = get_tree().get_first_node_in_group("boss")
	if boss:
		boss.hp = boss.max_hp * 0.3
		print("DEBUG: Boss HP set to 30% to trigger Gimmick 2.")
