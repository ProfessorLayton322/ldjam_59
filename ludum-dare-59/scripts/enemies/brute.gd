class_name Brute
extends Enemy


func _ready() -> void:
	damage = 4
	move_duration = 1.5
	modulate = Color(1.0, 0.3, 0.3)
	super._ready()
