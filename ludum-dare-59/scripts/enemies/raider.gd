class_name Raider
extends Enemy


func _ready() -> void:
	damage = 2
	hp = 15
	move_duration = 1.0
	modulate = Color(0.4, 0.6, 1.0)
	super._ready()
