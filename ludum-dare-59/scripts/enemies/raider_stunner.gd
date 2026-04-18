class_name RaiderStunner
extends Raider


func _ready() -> void:
	can_stun_gate = true
	gate_stun_duration = 3.0
	super._ready()
	modulate = Color(0.95, 0.85, 0.2)


func _on_gate_stun_consumed(_gate: Gate) -> void:
	modulate = Color(0.4, 0.6, 1.0)
