extends RigidBody2D

const ENGINE_POWER = 800.0
# Новая константа: сила маневровых двигателей, отвечающих за поворот носа
const ROTATION_TORQUE = 6000.0 

func _physics_process(_delta):
	# 1. ПРИЦЕЛИВАНИЕ (Физическое вращение к мыши)
	var target_pos = get_global_mouse_position()
	# Узнаем, под каким углом находится мышь относительно корабля
	var target_angle = global_position.direction_to(target_pos).angle()
	
	# Вычисляем кратчайшую разницу между тем, куда мы смотрим, и куда надо смотреть
	# Функция wrapf не дает кораблю крутиться через невыгодную сторону (на 270 градусов вместо 90)
	var angle_diff = wrapf(target_angle - rotation, -PI, PI)
	
	# Прикладываем силу вращения. Чем дальше мышь от носа, тем сильнее толкаем.
	apply_torque(angle_diff * ROTATION_TORQUE)
	
	
	# 2. МАНЕВРИРОВАНИЕ (Относительное)
	var local_dir = Vector2.ZERO
	
	if Input.is_physical_key_pressed(KEY_W):
		local_dir.x += 1 
	if Input.is_physical_key_pressed(KEY_S):
		local_dir.x -= 1 
		
	if Input.is_physical_key_pressed(KEY_D):
		local_dir.y += 1 
	if Input.is_physical_key_pressed(KEY_A):
		local_dir.y -= 1 
		
	if local_dir != Vector2.ZERO:
		local_dir = local_dir.normalized()
		var global_force = local_dir.rotated(rotation)
		apply_central_force(global_force * ENGINE_POWER)
