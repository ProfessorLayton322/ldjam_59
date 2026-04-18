class_name CoreGate
extends Gate

signal enemy_reached(damage: int)


func on_enter(enemy: Enemy) -> void:
	enemy_reached.emit(enemy.hp)
	enemy.queue_free()
