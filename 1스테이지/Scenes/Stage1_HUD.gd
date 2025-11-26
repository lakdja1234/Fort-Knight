extends CanvasLayer

@onready var player_health_bar: ProgressBar = $VBoxContainer/PlayerHPBar
@onready var boss_health_bar: ProgressBar = $VBoxContainer/BossHPBar
@onready var charge_bar: ProgressBar = $VBoxContainer/ChargeBar

var player_connected = false
var boss_connected = false

func _process(_delta):
	if not player_connected:
		var player = get_tree().get_first_node_in_group("player")
		if is_instance_valid(player):
			player.health_updated.connect(_on_player_health_updated)
			player.charge_updated.connect(_on_player_charge_updated)
			player_connected = true
			# Set initial values
			if "hp" in player:
				_on_player_health_updated(player.hp)

	if not boss_connected:
		var boss = get_tree().get_first_node_in_group("boss")
		if is_instance_valid(boss):
			boss.health_updated.connect(_on_boss_health_updated)
			boss_connected = true
			# Set initial values
			if "hp" in boss:
				_on_boss_health_updated(boss.hp)


func _on_player_health_updated(current_hp):
	player_health_bar.value = current_hp

func _on_boss_health_updated(current_hp):
	boss_health_bar.value = current_hp

func _on_player_charge_updated(current_power, min_power, max_power):
	charge_bar.min_value = min_power
	charge_bar.max_value = max_power
	charge_bar.value = current_power
