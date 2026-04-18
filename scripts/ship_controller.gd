extends RigidBody2D # ЭТО ДОЛЖНО БЫТЬ В ПЕРВОЙ СТРОКЕ!

func _physics_process(_delta: float) -> void:
	# 1. Сначала мышь (проверим, исчезла ли красная ошибка)
	var mouse_pos = get_global_mouse_position()
	look_at(mouse_pos)

	if Input.is_action_pressed("ship_accelerate"):
		$BaseSprite.modulate = Color.RED
		_fire_engines()
	else:
		$BaseSprite.modulate = Color.WHITE

func _fire_engines() -> void:
	# Безопасный поиск узла Modules
	var mods = get_node_or_null("Modules")
	if mods:
		for m in mods.get_children():
			if m.has_method("fire"):
				m.fire()
