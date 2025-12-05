extends Node

# --- UI Node References ---
# These nodes are expected to be siblings of the GameManager node
@onready var game_over_ui = get_parent().get_node("GameOverUI")
@onready var game_clear_ui = get_parent().get_node("GameClearUI")

func _ready():
	# Centrally disable all projectile lights for this stage
	get_tree().call_group("player", "set_lights_disabled", true)
	get_tree().call_group("boss", "set_lights_disabled", true)

	# Connect to player signals
	var player = get_tree().get_first_node_in_group("player")
	if is_instance_valid(player) and player.has_signal("game_over"):
		player.game_over.connect(_on_game_over)
		
	# Connect to boss signals
	var boss = get_tree().get_first_node_in_group("boss")
	if is_instance_valid(boss) and boss.has_signal("boss_died"):
		boss.boss_died.connect(_on_boss_died)

func _on_game_over():
	game_over_ui.show()
	get_tree().paused = true

func _on_boss_died():
	game_clear_ui.show()
	get_tree().paused = true

func _on_retry_button_pressed():
	get_tree().paused = false
	get_tree().reload_current_scene()
