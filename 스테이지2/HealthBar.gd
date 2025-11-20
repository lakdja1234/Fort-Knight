extends Control

@onready var progress_bar: ProgressBar = $ProgressBar
@onready var label: Label = $Label

func update_health(current_hp: float, max_hp: float):
	if progress_bar and max_hp > 0:
		progress_bar.value = (current_hp / max_hp) * 100.0
	elif progress_bar:
		progress_bar.value = 0
	
	if label:
		label.text = "%d / %d" % [current_hp, max_hp]
