extends Control

@onready var progress_bar: ProgressBar = $ProgressBar
@onready var label: Label = $Label

func update_health(current_hp: float, max_hp: float):
	if max_hp > 0:
		progress_bar.value = (current_hp / max_hp) * 100.0
		label.text = "%d / %d" % [current_hp, max_hp]
	else:
		progress_bar.value = 0
		label.text = "0 / 0"
