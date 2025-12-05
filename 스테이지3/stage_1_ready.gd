extends Node2D

@onready var description_label = $DescriptionLabel
@onready var start_prompt_label = $StartPromptLabel
@onready var initial_wait_timer = $InitialWaitTimer
@onready var description_wait_timer = $DescriptionWaitTimer
@onready var blink_timer = $BlinkTimer
@onready var animation_player = $AnimationPlayer

var can_start = false

func _ready():
	initial_wait_timer.start()

func _on_initial_wait_timer_timeout():
	# Play the fade-in animations sequentially
	animation_player.play("overlay_fade_in")
	await animation_player.animation_finished
	
	animation_player.play("description_fade_in")
	await animation_player.animation_finished
	
	# Now that the description is visible, start the timer for the prompt
	description_wait_timer.start()

func _on_description_wait_timer_timeout():
	start_prompt_label.show()
	blink_timer.start()
	can_start = true

func _on_blink_timer_timeout():
	start_prompt_label.visible = not start_prompt_label.visible

func _unhandled_input(event):
	if can_start and event is InputEventKey and event.keycode == KEY_SPACE and event.pressed:
<<<<<<< HEAD
		SceneTransition.change_scene("res://스테이지1/Scenes/stage1.tscn")
=======
		get_tree().change_scene_to_file("res://스테이지1/Scenes/stage1.tscn")
>>>>>>> KimWooJoo
