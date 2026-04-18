class_name Crytter
extends Enemy


func _ready() -> void:
	damage = 1
	hp = 8
	move_duration = 0.7
	modulate = Color(0.4, 1.0, 0.4)
	super._ready()
