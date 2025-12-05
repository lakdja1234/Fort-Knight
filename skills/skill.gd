# skill.gd
# Base class for all skills.
class_name Skill
extends Node

# A reference to the player who owns this skill.
var player: CharacterBody2D

# Called when the skill is equipped.
func on_equip():
	pass

# Called when the skill is unequipped.
func on_unequip():
	pass

# Called when the player uses the skill.
# This method is meant to be overridden by specific skills.
func activate():
	print("Base skill activated. Override this method in your skill script.")
