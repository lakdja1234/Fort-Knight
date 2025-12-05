extends Control

# Helper function to check if a bus with a given name exists
func _bus_exists(bus_name):
	for i in range(AudioServer.bus_count):
		if AudioServer.get_bus_name(i) == bus_name:
			return true
	return false

func _ready():
	# Initialize sliders with current audio bus volumes
	var master_bus_index = AudioServer.get_bus_index("Master")
	$Panel/ScrollContainer/VBoxContainer/MasterVolumeMarginContainer/MasterVolumeSlider.value = AudioServer.get_bus_volume_db(master_bus_index)
	
	# Check if Music and SFX buses exist before trying to set their initial values
	if _bus_exists("Music"):
		var music_bus_index = AudioServer.get_bus_index("Music")
		$Panel/ScrollContainer/VBoxContainer/MusicVolumeMarginContainer/MusicVolumeSlider.value = AudioServer.get_bus_volume_db(music_bus_index)
	if _bus_exists("SFX"):
		var sfx_bus_index = AudioServer.get_bus_index("SFX")
		$Panel/ScrollContainer/VBoxContainer/SfxVolumeMarginContainer/SfxVolumeSlider.value = AudioServer.get_bus_volume_db(sfx_bus_index)

func _on_master_volume_slider_value_changed(value):
	var master_bus_index = AudioServer.get_bus_index("Master")
	AudioServer.set_bus_volume_db(master_bus_index, value)

func _on_music_volume_slider_value_changed(value):
	if _bus_exists("Music"):
		var music_bus_index = AudioServer.get_bus_index("Music")
		AudioServer.set_bus_volume_db(music_bus_index, value)
	else:
		# Handle case where Music bus does not exist (e.g., print an error or log a warning)
		push_warning("Audio bus 'Music' not found. Please ensure it's configured in Project Settings -> Audio Bus Layout.")

func _on_sfx_volume_slider_value_changed(value):
	if _bus_exists("SFX"):
		var sfx_bus_index = AudioServer.get_bus_index("SFX")
		AudioServer.set_bus_volume_db(sfx_bus_index, value)
	else:
		# Handle case where SFX bus does not exist
		push_warning("Audio bus 'SFX' not found. Please ensure it's configured in Project Settings -> Audio Bus Layout.")

func _on_keybinds_button_pressed():
	SceneTransition.change_scene("res://ui/KeybindScreen.tscn")

func _on_reset_button_pressed():
	$ResetConfirmationDialog.popup_centered()

func _on_reset_confirmed():
	SettingsManager.reset_all_data()

func _on_back_button_pressed():
	SceneTransition.change_scene("res://스테이지3/stage_selection.tscn")
