extends Node

var is_darkness_active = false

@onready var game_over_ui = get_node("../GameOverUI")
 
func _ready():
	var player = get_node("/root/TitleMap/Player")
	if player:
		player.game_over.connect(_on_game_over)
	
	# The retry button connection was already in the .tscn file.
	# My previous programmatic connection was redundant and the is_a() bug is now fixed.
	# Let's rely on the editor's connection.
	# var retry_button = game_over_ui.find_child("RetryButton", true, false)
	# if retry_button and retry_button.is_class("Button"):
	# 	retry_button.pressed.connect(_on_retry_button_pressed)

	# --- Create Debug UI for Gimmicks ---
	var debug_canvas = CanvasLayer.new()
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

func _on_retry_button_pressed():
	get_tree().paused = false
	get_tree().reload_current_scene()

func _on_gimmick_1_button_pressed():
	var boss = get_tree().get_first_node_in_group("boss")
	if boss:
		# Set HP to 150 (50%) to trigger the first gimmick.
		# The gimmick logic in boss.gd checks for hp <= 150.
		boss.hp = 150
		print("DEBUG: Boss HP set to 150 to trigger Gimmick 1.")

func _on_gimmick_2_button_pressed():
	var boss = get_tree().get_first_node_in_group("boss")
	if boss:
		# Set HP to 90 (30%) to trigger the second gimmick.
		# The gimmick logic in boss.gd checks for hp <= 90.
		boss.hp = 90
		print("DEBUG: Boss HP set to 90 to trigger Gimmick 2.")
