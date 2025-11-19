extends CanvasLayer

@onready var animation_player = $AnimationPlayer
var current_scene_path = ""

func _ready():
	# Connect to the scene_changed signal
	get_tree().scene_changed.connect(_on_scene_changed)
	
	# Fade in the very first scene
	animation_player.play("fade_out")


func change_scene(scene_path):
	# Don't allow changing scene while a transition is already in progress
	if animation_player.is_playing():
		return
		
	current_scene_path = scene_path
	animation_player.play("fade_in")
	# The actual scene change will be triggered by the animation_finished signal
	# connected in the editor or by code. Let's assume it's connected to a function.

func _on_animation_player_animation_finished(anim_name):
	if anim_name == "fade_in":
		get_tree().change_scene_to_file(current_scene_path)

func _on_scene_changed():
	# This is called after the new scene has been loaded and added to the tree.
	# Now we can fade out to reveal the new scene.
	animation_player.play("fade_out")
