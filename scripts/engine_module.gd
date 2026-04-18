extends Node2D
class_name EngineModule

@export var power: float = 1000000.0 # МИЛЛИОН - это база для RigidBody
var parent_ship: RigidBody2D

func _ready() -> void:
	# Ищем RigidBody вверх по дереву
	var current: Node = get_parent()
	while current != null:
		if current is RigidBody2D:
			parent_ship = current
			print("--- [LOG] Двигатель '", name, "' подключен к ", parent_ship.name, " ---")
			break
		current = current.get_parent()

func fire() -> void:
	if parent_ship:
		# Прикладываем силу вперед (по оси X двигателя)
		var force_vector: Vector2 = global_transform.x * power
		var force_pos: Vector2 = global_position - parent_ship.global_position
		parent_ship.apply_force(force_vector, force_pos)
