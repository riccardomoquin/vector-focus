extends RigidBody2D

const ENGINE_POWER = 800.0
const ROTATION_TORQUE = 6000.0
const CELL_SIZE = 32

var modules_data = [] 
var ship_forward_dir = Vector2(0, -1) 

func _ready():
	gravity_scale = 0
	linear_damp = 1.5
	angular_damp = 3.0

func _physics_process(delta):
	# ИСПРАВЛЕНИЕ ОШИБКИ: Жестко конвертируем Vector2i в Vector2 для математики
	var forward = Vector2(ship_forward_dir)
	var right = Vector2(-forward.y, forward.x)
	
	# 1. ПРИЦЕЛИВАНИЕ
	var target_angle = global_position.direction_to(get_global_mouse_position()).angle()
	var forward_angle = forward.angle()
	var angle_diff = wrapf(target_angle - (rotation + forward_angle), -PI, PI)
	apply_torque(angle_diff * ROTATION_TORQUE)
	
	# 2. МАНЕВРИРОВАНИЕ (Генерация вектора тяги для физики)
	var local_dir = Vector2.ZERO
	
	if Input.is_physical_key_pressed(KEY_W): local_dir += forward
	if Input.is_physical_key_pressed(KEY_S): local_dir -= forward
	if Input.is_physical_key_pressed(KEY_D): local_dir += right
	if Input.is_physical_key_pressed(KEY_A): local_dir -= right
		
	if local_dir != Vector2.ZERO:
		apply_central_force(local_dir.normalized().rotated(rotation) * ENGINE_POWER)

	# 3. ЛОГИКА ВКЛЮЧЕНИЯ ДВИГАТЕЛЕЙ (Отрисовка выхлопа)
	for mod in modules_data:
		if mod["is_engine"]:
			var target_power = 0.0
			# Вектор выхлопа тоже переводим в Vector2
			var ex_dir = Vector2(mod["clear_dir"]) 
			
			# Строгое правило включения по ориентации выхлопа:
			# W -> летим вперед -> работают двигатели с выхлопом "назад" (-forward)
			# S -> летим назад -> работают двигатели с выхлопом "вперед" (forward)
			# D -> летим вправо -> работают двигатели с выхлопом "влево" (-right)
			# A -> летим влево -> работают двигатели с выхлопом "вправо" (right)
			if Input.is_physical_key_pressed(KEY_W) and ex_dir.dot(-forward) > 0.5: target_power = 1.0
			if Input.is_physical_key_pressed(KEY_S) and ex_dir.dot(forward) > 0.5: target_power = 1.0
			if Input.is_physical_key_pressed(KEY_D) and ex_dir.dot(-right) > 0.5: target_power = 1.0
			if Input.is_physical_key_pressed(KEY_A) and ex_dir.dot(right) > 0.5: target_power = 1.0
			
			var current_power = mod.get("power", 0.0)
			mod["power"] = lerp(current_power, target_power, 10.0 * delta)

	queue_redraw()

func _draw():
	# --- 1. ФОН (Движущаяся сетка космоса) ---
	draw_set_transform(Vector2.ZERO, -rotation, Vector2.ONE)
	
	var grid_step = 100
	var offset = Vector2(fmod(global_position.x, grid_step), fmod(global_position.y, grid_step))
	
	for i in range(-15, 15):
		var x = i * grid_step - offset.x
		draw_line(Vector2(x, -1500), Vector2(x, 1500), Color(1, 1, 1, 0.05), 1)
		var y = i * grid_step - offset.y
		draw_line(Vector2(-1500, y), Vector2(1500, y), Color(1, 1, 1, 0.05), 1)

	draw_set_transform(Vector2.ZERO, 0, Vector2.ONE)

	# --- 2. КОРАБЛЬ И МОДУЛИ ---
	for mod in modules_data:
		draw_rect(mod["rect"], mod["color"], true)
		draw_rect(mod["rect"], Color.BLACK, false, 1.0)
		
		if mod["has_marker"]:
			var m_color = Color(0, 0, 0, 0.5)
			var th = 6
			var m_rect = Rect2()
			var rot = mod["visual_rot"]
			var rect = mod["rect"]
			
			if rot == 0: m_rect = Rect2(rect.position.x, rect.position.y + rect.size.y - th, rect.size.x, th)
			elif rot == 1: m_rect = Rect2(rect.position.x, rect.position.y, th, rect.size.y)
			elif rot == 2: m_rect = Rect2(rect.position.x, rect.position.y, rect.size.x, th)
			elif rot == 3: m_rect = Rect2(rect.position.x + rect.size.x - th, rect.position.y, th, rect.size.y)
			draw_rect(m_rect, m_color, true)

	# --- 3. ВЫХЛОП ДВИГАТЕЛЕЙ ---
	for mod in modules_data:
		if mod["is_engine"] and mod.get("power", 0.0) > 0.01:
			var base_c = Color(1.0, 0.2, 0.2) if mod["is_main_engine"] else Color(0.2, 0.6, 1.0)
			var power = mod["power"]
			var len_px = mod["engine_length"] * CELL_SIZE * power
			var dir = mod["clear_dir"]
			
			var p1 = Vector2(); var p2 = Vector2(); var p3 = Vector2(); var p4 = Vector2()
			var px = mod["rect"].position.x; var py = mod["rect"].position.y
			var sx = mod["rect"].size.x; var sy = mod["rect"].size.y
			
			if dir == Vector2i(0, 1):
				p1 = Vector2(px, py + sy); p2 = Vector2(px + sx, py + sy)
				p3 = p2 + Vector2(0, len_px); p4 = p1 + Vector2(0, len_px)
			elif dir == Vector2i(0, -1):
				p1 = Vector2(px, py); p2 = Vector2(px + sx, py)
				p3 = p2 - Vector2(0, len_px); p4 = p1 - Vector2(0, len_px)
			elif dir == Vector2i(1, 0):
				p1 = Vector2(px + sx, py); p2 = Vector2(px + sx, py + sy)
				p3 = p2 + Vector2(len_px, 0); p4 = p1 + Vector2(len_px, 0)
			elif dir == Vector2i(-1, 0):
				p1 = Vector2(px, py); p2 = Vector2(px, py + sy)
				p3 = p2 - Vector2(len_px, 0); p4 = p1 - Vector2(len_px, 0)
				
			var pts = PackedVector2Array([p1, p2, p3, p4])
			var cols = PackedColorArray([Color(base_c.r, base_c.g, base_c.b, power), Color(base_c.r, base_c.g, base_c.b, power), Color(base_c.r, base_c.g, base_c.b, 0.0), Color(base_c.r, base_c.g, base_c.b, 0.0)])
			draw_primitive(pts, cols, PackedVector2Array())
