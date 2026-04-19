extends RigidBody2D

const ENGINE_POWER = 40000.0
const CELL_SIZE = 32

var modules_data = [] 
var ship_forward_dir = Vector2(0, -1) 

# Добавляем переменную для хранения безопасной скорости вращения
var safe_spin_speed: float = 5.0 

func _ready():
	gravity_scale = 0
	linear_damp = 0.0 
	angular_damp = 0.0 

	var total_mass = 0.0
	var com_sum = Vector2.ZERO
	
	for mod in modules_data:
		if mod.get("node_ref"):
			var m = mod["node_ref"].mass
			total_mass += m
			com_sum += mod["node_ref"].position * m
			
	if total_mass > 0:
		mass = total_mass
		center_of_mass_mode = RigidBody2D.CENTER_OF_MASS_MODE_CUSTOM
		center_of_mass = com_sum / total_mass
		
		# --- НОВАЯ ЛОГИКА: Расчет предела прочности ---
		# Для массы 100кг будет 5.0. Для 500кг будет 1.0. 
		# clamp не даст скорости упасть ниже 0.5 (чтобы огромные баржи хоть как-то крутились) 
		# и не даст превысить 10.0 (чтобы сверхлегкие дроны не сходили с ума).
		safe_spin_speed = clamp(500.0 / mass, 0.5, 10.0)
		
		print("Корабль собран! Масса: ", mass)
		print("Центр тяжести: ", center_of_mass)
		print("Безопасная скорость вращения: ", safe_spin_speed, " рад/с")

func _physics_process(delta):
	var forward = Vector2(ship_forward_dir)
	var right = Vector2(-forward.y, forward.x)
	
	# --- 2. УМНОЕ ПРИЦЕЛИВАНИЕ (Бортовой контроллер) ---
	var target_angle = global_position.direction_to(get_global_mouse_position()).angle()
	var forward_angle = forward.angle()
	var angle_diff = wrapf(target_angle - (rotation + forward_angle), -PI, PI)
	
	# ИСПОЛЬЗУЕМ ВЫСЧИТАННЫЙ ПРЕДЕЛ СКОРОСТИ
	var desired_angular_vel = clamp(angle_diff * 5.0, -safe_spin_speed, safe_spin_speed)
	
	var torque_needed = desired_angular_vel - angular_velocity
	var desired_torque_dir = sign(torque_needed)
	
	# Мертвая зона, чтобы кораблем не трясло, когда он навелся на цель
	var needs_rotation = abs(torque_needed) > 0.1 
	
	var target_dir = Vector2.ZERO
	if Input.is_physical_key_pressed(KEY_W): target_dir += forward
	if Input.is_physical_key_pressed(KEY_S): target_dir -= forward
	if Input.is_physical_key_pressed(KEY_D): target_dir += right
	if Input.is_physical_key_pressed(KEY_A): target_dir -= right
		
	for mod in modules_data:
		if mod["is_engine"] and mod.get("node_ref"):
			var engine_node = mod["node_ref"]
			var target_power = 0.0
			
			var exhaust_dir = Vector2(mod["clear_dir"])
			var thrust_dir = -exhaust_dir
			var pos_from_com = engine_node.position - center_of_mass
			
			# Маршевая тяга
			if target_dir != Vector2.ZERO and thrust_dir.dot(target_dir) > 0.5:
				target_power = 1.0
				
			# Ротационная тяга (Бортовой компьютер сам подбирает двигатели!)
			#if needs_rotation:
				#var engine_torque = pos_from_com.cross(thrust_dir)
				#if sign(engine_torque) == desired_torque_dir and abs(engine_torque) > 0.1:
					#target_power = 1.0
			
			#var current_power = mod.get("power", 0.0)
			#var new_power = lerp(current_power, target_power, engine_node.dynamic_ramp * 10.0 * delta)
			#mod["power"] = new_power
			
			#if new_power > 0.01:
				#var force_mag = ENGINE_POWER * engine_node.thrust_multiplier * new_power
				#var global_force = (thrust_dir * force_mag).rotated(rotation)
				#var global_offset = engine_node.position.rotated(rotation)
				#apply_force(global_force, global_offset)

	# 2. ИСПРАВЛЕНИЕ: Всегда перерисовываем космос каждый кадр!
	queue_redraw()

func _draw():
	# --- ФОН (Движущаяся сетка космоса) ---
	draw_set_transform(Vector2.ZERO, -rotation, Vector2.ONE)
	var grid_step = 100
	var offset = Vector2(fmod(global_position.x, grid_step), fmod(global_position.y, grid_step))
	for i in range(-15, 15):
		var x = i * grid_step - offset.x
		draw_line(Vector2(x, -1500), Vector2(x, 1500), Color(1, 1, 1, 0.05), 1)
		var y = i * grid_step - offset.y
		draw_line(Vector2(-1500, y), Vector2(1500, y), Color(1, 1, 1, 0.05), 1)
	draw_set_transform(Vector2.ZERO, 0, Vector2.ONE)

	# --- КОРАБЛЬ И МОДУЛИ ---
	for mod in modules_data:
		if not mod.get("has_scene", false):
			draw_rect(mod["rect"], mod["color"], true)
			draw_rect(mod["rect"], Color.BLACK, false, 1.0)
			if mod["has_marker"]:
				var m_color = Color(0, 0, 0, 0.5); var th = 6; var m_rect = Rect2(); var rot = mod["visual_rot"]; var rect = mod["rect"]
				if rot == 0: m_rect = Rect2(rect.position.x, rect.position.y + rect.size.y - th, rect.size.x, th)
				elif rot == 1: m_rect = Rect2(rect.position.x, rect.position.y, th, rect.size.y)
				elif rot == 2: m_rect = Rect2(rect.position.x, rect.position.y, rect.size.x, th)
				elif rot == 3: m_rect = Rect2(rect.position.x + rect.size.x - th, rect.position.y, th, rect.size.y)
				draw_rect(m_rect, m_color, true)

	# --- ВЫХЛОП ДВИГАТЕЛЕЙ ---
	for mod in modules_data:
		if mod["is_engine"] and mod.get("power", 0.0) > 0.01:
			var base_c = Color(1.0, 0.2, 0.2) if mod["is_main_engine"] else Color(0.2, 0.6, 1.0)
			var power = mod["power"]
			var len_px = mod["engine_length"] * CELL_SIZE * power
			var dir = mod["clear_dir"]
			var p1 = Vector2(); var p2 = Vector2(); var p3 = Vector2(); var p4 = Vector2()
			var px = mod["rect"].position.x; var py = mod["rect"].position.y
			var sx = mod["rect"].size.x; var sy = mod["rect"].size.y
			if dir == Vector2i(0, 1): p1 = Vector2(px, py + sy); p2 = Vector2(px + sx, py + sy); p3 = p2 + Vector2(0, len_px); p4 = p1 + Vector2(0, len_px)
			elif dir == Vector2i(0, -1): p1 = Vector2(px, py); p2 = Vector2(px + sx, py); p3 = p2 - Vector2(0, len_px); p4 = p1 - Vector2(0, len_px)
			elif dir == Vector2i(1, 0): p1 = Vector2(px + sx, py); p2 = Vector2(px + sx, py + sy); p3 = p2 + Vector2(len_px, 0); p4 = p1 + Vector2(len_px, 0)
			elif dir == Vector2i(-1, 0): p1 = Vector2(px, py); p2 = Vector2(px, py + sy); p3 = p2 - Vector2(len_px, 0); p4 = p1 - Vector2(len_px, 0)
			var pts = PackedVector2Array([p1, p2, p3, p4])
			var cols = PackedColorArray([Color(base_c.r, base_c.g, base_c.b, power), Color(base_c.r, base_c.g, base_c.b, power), Color(base_c.r, base_c.g, base_c.b, 0.0), Color(base_c.r, base_c.g, base_c.b, 0.0)])
			draw_primitive(pts, cols, PackedVector2Array())
