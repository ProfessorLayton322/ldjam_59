class_name RaiderStunner
extends Enemy


func _get_balance_id() -> String:
	return "raider_stunner"


func _on_gate_stun_consumed(_gate: Gate) -> void:
	DebugTrace.event("enemy_stun", "raider_stunner_visual_change", {
		"enemy": DebugTrace.enemy_state(self),
		"gate": DebugTrace.gate_state(_gate),
	})
	modulate = Color(0.65, 0.62, 0.35)
