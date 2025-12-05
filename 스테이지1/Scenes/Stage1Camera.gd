extends Camera2D

func _ready():
	GlobalSignals.camera_shake_requested.connect(shake)

func shake(strength: float = 15.0, duration: float = 0.3):
	var tween = get_tree().create_tween().set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	var shake_offset = Vector2(randf_range(-strength, strength), randf_range(-strength, strength))
	
	# Create a shake sequence
	tween.tween_property(self, "offset", shake_offset, duration / 10)
	tween.tween_property(self, "offset", Vector2.ZERO, duration / 10)
	tween.tween_property(self, "offset", -shake_offset, duration / 10)
	tween.tween_property(self, "offset", Vector2.ZERO, duration / 10)
	tween.tween_property(self, "offset", shake_offset, duration / 10)
	tween.tween_property(self, "offset", Vector2.ZERO, duration / 10)
	
