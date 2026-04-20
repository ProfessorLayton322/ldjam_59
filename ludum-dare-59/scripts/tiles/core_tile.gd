class_name CoreTile
extends BaseTile

const CPU_Z_INDEX := 2


func _ready() -> void:
	z_index = CPU_Z_INDEX


func OnTrigger(source: Node = null) -> void:
	super.OnTrigger(source)


func OnEnter(source: Node = null) -> void:
	super.OnEnter(source)

	if source != null:
		source.queue_free()
