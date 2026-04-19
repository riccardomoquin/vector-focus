extends BaseModule

@export_group("Weapon Specs")
@export var energy_cost_per_sec: float = 30.0
@export var damage_per_sec: float = 150.0 # Урон в секунду
@export var max_range: float = 1200.0

var is_firing: bool = false
var laser_line: Line2D
var raycast: RayCast2D

func _ready():
	super()
	module_id = "weapon_laser"
	
	# 1. Создаем Радар (RayCast2D)
	raycast = RayCast2D.new()
	raycast.target_position = Vector2(0, -max_range) # Локально смотрит вперед
	raycast.enabled = false 
	
	# Исключаем сам корабль из коллизий, чтобы лазер не бил по себе
	var parent_body = get_parent()
	if parent_body is CollisionObject2D:
		raycast.add_exception(parent_body)
		
	add_child(raycast)
	
	# 2. Создаем Кисть (Line2D)
	laser_line = Line2D.new()
	laser_line.width = 4.0
	laser_line.default_color = Color(1.0, 0.2, 0.4, 0.9)
	laser_line.z_index = 5 
	add_child(laser_line)
	laser_line.hide()

func set_firing(firing: bool):
	is_firing = firing
	raycast.enabled = is_firing # Включаем физику только при стрельбе
	if not is_firing:
		laser_line.hide()

func _physics_process(delta):
	if is_firing:
		laser_line.show()
		laser_line.clear_points()
		laser_line.add_point(Vector2.ZERO) # Старт луча из пушки
		
		# Принудительно заставляем движок обновить физику луча именно в этом кадре
		raycast.force_raycast_update()
		
		if raycast.is_colliding():
			# Если радар нашел препятствие:
			var hit_point = raycast.get_collision_point()
			var collider = raycast.get_collider()
			
			# Переводим глобальную точку попадания в локальную, чтобы Линия нарисовалась правильно
			var local_hit_point = to_local(hit_point)
			laser_line.add_point(local_hit_point)
			
			# Наносим урон объекту (Метеориту или врагу)
			if collider.has_method("take_damage"):
				collider.take_damage(damage_per_sec * delta)
				
		else:
			# Если космос пуст - рисуем луч на максимальную дальность
			laser_line.add_point(Vector2(0, -max_range))
