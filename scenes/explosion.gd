extends Node2D
func _ready():
	# Удаляем узел после окончания взрыва (например, через 1 секунду)
	await get_tree().create_timer(1.0).timeout
	queue_free()
