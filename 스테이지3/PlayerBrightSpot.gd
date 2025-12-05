# PlayerBrightSpot.gd
extends CharacterBody2D

@onready var sprite = $Sprite2D

func _ready():
	# Make the sprite additive for a glowy effect
	var mat = CanvasItemMaterial.new()
	mat.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	sprite.material = mat
