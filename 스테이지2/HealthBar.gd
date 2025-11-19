extends Control

@onready var progress_bar: ProgressBar = $ProgressBar
@onready var label: Label = $ProgressBar/Label

func update_health(current: float, max_val: float):
	progress_bar.max_value = max_val
	progress_bar.value = current
	label.text = "%d / %d" % [current, max_val]
