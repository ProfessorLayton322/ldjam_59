class_name BaseTile
extends Node2D

@export var node_id: int = -1

signal triggered(source: Node)
signal entered(source: Node)


func OnTrigger(source: Node = null) -> void:
	triggered.emit(source)


func OnEnter(source: Node = null) -> void:
	entered.emit(source)
