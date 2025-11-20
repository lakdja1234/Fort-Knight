extends Control

var progress_bar: ProgressBar
var label: Label

func _ready():
	progress_bar = get_node_or_null("ProgressBar")
	if progress_bar == null:
		printerr("HealthBar: 'ProgressBar' node not found at runtime!")
	else:
		print("HealthBar: 'ProgressBar' node found successfully at runtime.")
		
	label = get_node_or_null("Label")
	if label == null:
		printerr("HealthBar: 'Label' node not found at runtime!")
	else:
		print("HealthBar: 'Label' node found successfully at runtime.")

func update_health(current_hp: float, max_hp: float):
	if is_instance_valid(progress_bar) and max_hp > 0:
		progress_bar.value = (current_hp / max_hp) * 100.0
	elif is_instance_valid(progress_bar):
		progress_bar.value = 0
	
	if is_instance_valid(label):
		label.text = "%d / %d" % [current_hp, max_hp]
	else:
		printerr("HealthBar: Cannot update label because it is null!")
