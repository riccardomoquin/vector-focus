extends RigidBody2D

var hp: float = 100.0

# 1. ЗАГРУЖАЕМ СЦЕНУ ВЗРЫВА
var explosion_scene = preload("res://scenes/explosion.tscn")

func _ready():
	# (Гравитация и трение теперь настраиваются в Инспекторе)
	angular_velocity = randf_range(-2.0, 2.0)
	linear_velocity = Vector2(randf_range(-40, 40), randf_range(-40, 40))

func take_damage(amount: float):
	hp -= amount
	
	# Вспышка урона (белеет на долю секунды)
	var sprite = get_node_or_null("Sprite2D")
	if sprite:
		sprite.modulate = Color(3.0, 3.0, 3.0) 
		var tween = create_tween()
		tween.tween_property(sprite, "modulate", Color(1, 1, 1), 0.1)
	
	# 2. ЛОГИКА СМЕРТИ И ВЗРЫВА
	if hp <= 0:
		if explosion_scene:
			var explosion = explosion_scene.instantiate()
			explosion.global_position = global_position # Ставим взрыв ровно на место метеорита
			
			# Добавляем взрыв в "космос" (родительский узел), чтобы он жил после смерти метеорита
			get_parent().call_deferred("add_child", explosion) 
			
		queue_free() # Камень уничтожен
