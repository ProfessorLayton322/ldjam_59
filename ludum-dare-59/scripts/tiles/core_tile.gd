class_name CoreTile
extends BaseTile


func OnTrigger(source: Node = null) -> void:
	super.OnTrigger(source)


func OnEnter(source: Node = null) -> void:
	super.OnEnter(source)

	if source != null:
		source.queue_free()
