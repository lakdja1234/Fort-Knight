extends Area2D

@export var on_texture: Texture2D
@export var off_texture: Texture2D

@onready var sprite = $Sprite2D
@onready var light_timer = $LightTimer
@onready var point_light = $PointLight2D

func _ready():
	add_to_group("torch") # Add to group for easy access
	sprite.light_mask = 1
	sprite.texture = off_texture
	light_timer.one_shot = true
	light_timer.wait_time = 30
	body_entered.connect(_on_body_entered)
	light_timer.timeout.connect(_on_light_timer_timeout)

func force_extinguish():
	light_timer.stop()
	_on_light_timer_timeout()

func _on_body_entered(body):
	if body.is_in_group("bullets") and light_timer.is_stopped():
		sprite.texture = on_texture
		point_light.enabled = true
		light_timer.start()
		if body.has_method("explode"):
			body.explode()
		else:
			body.queue_free()

func _on_light_timer_timeout():
	sprite.texture = off_texture
	point_light.enabled = false
