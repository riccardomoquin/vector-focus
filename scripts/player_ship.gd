extends RigidBody2D

const ENGINE_POWER = 800.0
const ROTATION_TORQUE = 6000.0
const CELL_SIZE = 32

# Сюда конструктор передаст все данные о модулях после сборки
var modules_data = [] 

func _ready():
	# Настройки космического вакуума
	gravity_scale = 0
	linear_damp = 1.5
	angular_damp = 3.0

func _physics_process(delta):
	# 1. ПРИЦЕЛИВАНИЕ
	var target_angle = global_position.direction_to(get_global_mouse_position()).angle()
	var angle_diff = wrapf(target_angle - rotation, -PI, PI)
	apply_torque(angle_diff * ROTATION_TORQUE)
	
	# 2. МАНЕВРИРОВАНИЕ
	var local_dir = Vector2.ZERO
	if Input.is_physical_key_pressed(KEY_W): local_dir.x += 1 
	if Input.is_physical_key_pressed(KEY_S): local_dir.x -= 1 
	if Input.is_physical_key_pressed(KEY_A): local_dir.y += 1 
	if Input.is_physical_key_pressed(KEY_D): local_dir.y -= 1 
		
	if local_dir != Vector2.ZERO:
		apply_central_force(local_dir.normalized().rotated(rotation) * ENGINE_POWER)

	# 3. РАСЧЕТ МОЩНОСТИ ВЫХЛОПА
	var redraw_needed = false
	for mod in modules_data:
		if mod["is_engine"]:
			var target_power = 0.0
			var dir = mod["clear_dir"]
			
			if local_dir != Vector2.ZERO:
				if (dir.x != 0 and dir.x == -local_dir.x) or (dir.y != 0 and dir.y == -local_dir.y):
					target_power = 1.0
			
			var current_power = mod.get("power", 0.0)
			var new_power = lerp(current_power, target_power, 10.0 * delta)
			mod["power"] = new_power
			
			if abs(current_power - new_power) > 0.01 or new_power > 0.01:
				redraw_needed = true

	if redraw_needed:
		queue_redraw()

# --- ОТРИСОВКА В ПОЛЕТЕ ---
func _draw():
	# Сначала рисуем корпуса
	for mod in modules_data:
		draw_rect(mod["rect"], mod["color"], true)
		draw_rect(mod["rect"], Color.BLACK, false, 1.0)
		
		# Рисуем маркеры направления
		if mod["has_marker"]:
			var marker_color = Color(0, 0, 0, 0.5)
			var thickness = 6
			var m_rect = Rect2()
			var rot = mod["visual_rot"]
			var rect = mod["rect"]
			
			if rot == 0: m_rect = Rect2(rect.position.x, rect.position.y + rect.size.y - thickness, rect.size.x, thickness)
			elif rot == 1: m_rect = Rect2(rect.position.x, rect.position.y, thickness, rect.size.y)
			elif rot == 2: m_rect = Rect2(rect.position.x, rect.position.y, rect.size.x, thickness)
			elif rot == 3: m_rect = Rect2(rect.position.x + rect.size.x - thickness, rect.position.y, thickness, rect.size.y)
			draw_rect(m_rect, marker_color, true)

	# Затем рисуем градиентные шлейфы
	for mod in modules_data:
		if mod["is_engine"] and mod.get("power", 0.0) > 0.01:
			var base_c = Color(1.0, 0.2, 0.2) if mod["is_main_engine"] else Color(0.2, 0.6, 1.0)
			var power = mod["power"]
			var current_length_px = mod["engine_length"] * CELL_SIZE * power
			
			var p1 = Vector2(); var p2 = Vector2(); var p3 = Vector2(); var p4 = Vector2()
			var px = mod["rect"].position.x; var py = mod["rect"].position.y
			var sx = mod["rect"].size.x; var sy = mod["rect"].size.y
			var dir = mod["clear_dir"]
			
			if dir == Vector2i(0, 1):
				p1 = Vector2(px, py + sy); p2 = Vector2(px + sx, py + sy)
				p3 = p2 + Vector2(0, current_length_px); p4 = p1 + Vector2(0, current_length_px)
			elif dir == Vector2i(0, -1):
				p1 = Vector2(px, py); p2 = Vector2(px + sx, py)
				p3 = p2 - Vector2(0, current_length_px); p4 = p1 - Vector2(0, current_length_px)
			elif dir == Vector2i(1, 0):
				p1 = Vector2(px + sx, py); p2 = Vector2(px + sx, py + sy)
				p3 = p2 + Vector2(current_length_px, 0); p4 = p1 + Vector2(current_length_px, 0)
			elif dir == Vector2i(-1, 0):
				p1 = Vector2(px, py); p2 = Vector2(px, py + sy)
				p3 = p2 - Vector2(current_length_px, 0); p4 = p1 - Vector2(current_length_px, 0)
				
			var points = PackedVector2Array([p1, p2, p3, p4])
			var colors = PackedColorArray([
				Color(base_c.r, base_c.g, base_c.b, power), Color(base_c.r, base_c.g, base_c.b, power),
				Color(base_c.r, base_c.g, base_c.b, 0.0), Color(base_c.r, base_c.g, base_c.b, 0.0)
			])
			draw_primitive(points, colors, PackedVector2Array())
