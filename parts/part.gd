# part.gd
# A custom resource that defines a player part.
class_name Part
extends Resource

@export var part_name: String = "New Part"
@export_multiline var description: String = ""
@export var part_texture: Texture2D
@export var skill_scene: PackedScene # The skill this part grants
