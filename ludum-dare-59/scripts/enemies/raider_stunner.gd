class_name RaiderStunner
extends Enemy


func _get_balance_id() -> String:
	return "raider_stunner"


func _on_gate_stun_consumed(_gate: Gate) -> void:
	AudioManager.play_raider_stunner_gate_stun()
	DebugTrace.event("enemy_stun", "raider_stunner_visual_change", {
		"enemy": DebugTrace.enemy_state(self),
		"gate": DebugTrace.gate_state(_gate),
	})
	var icon := get_node_or_null("Icon") as Sprite2D
	if icon:
		icon.texture = preload("res://assets/textures/enemies/enemy_raider_stun.svg")
