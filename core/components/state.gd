class_name State
extends Node

signal transition_requested(to: StringName, msg: Dictionary)

var state_machine: Node = null

func enter(_msg: Dictionary = {}) -> void:
	pass

func exit() -> void:
	pass

func update(_delta: float) -> void:
	pass

func physics_update(_delta: float) -> void:
	pass
