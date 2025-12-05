# DebugUI.gd
extends CanvasLayer

func _on_set_boss_health_button_pressed():
	var boss = get_tree().get_first_node_in_group("boss")
	if boss and boss.has_method("set_health"):
		boss.set_health(20)
