extends Node2D

const GRID_SIZE_X = 20
const GRID_SIZE_Y = 20
const CELL_SIZE = 32 

var grid_data = [] 
var hovered_cell = Vector2i(-1, -1)
var module_rotation = 0 
var is_building_mode = true 

var module_db = {
	"hull": {"name": "Корпус", "cat": "Корпуса", "size": Vector2i(1, 1), "can_drag": true, "is_system": false, "color": Color.GRAY, "has_marker": false},
	"armor": {"name": "Броня", "cat": "Корпуса", "size": Vector2i(1, 1), "can_drag": true, "is_system": false, "color": Color.DARK_SLATE_GRAY, "has_marker": false},
	"core": {"name": "Ядро", "cat": "Системы", "size": Vector2i(3, 3), "can_drag": false, "is_system": true, "color": Color.YELLOW, "has_marker": false},
	"cockpit": {"name": "Кокпит", "cat": "Системы", "size": Vector2i(2, 2), "can_drag": false, "is_system": true, "color": Color.CYAN, "has_marker": true},
	"shield": {"name": "Генератор щита", "cat": "Системы", "size": Vector2i(2, 3), "can_drag": false, "is_system": true, "color": Color.AQUA, "has_marker": false},
	"engine_m": {"name": "Маневровый", "cat": "Двигатели", "size": Vector2i(1, 1), "can_drag": false, "is_system": false, "color": Color.ORANGE, "has_marker": true, "is_main_engine": false},
	"engine_t1": {"name": "Силовой T1", "cat": "Двигатели", "size": Vector2i(2, 2), "can_drag": false, "is_system": false, "color": Color.ORANGE_RED, "has_marker": true, "is_main_engine": true},
	"engine_t2": {"name": "Силовой T2", "cat": "Двигатели", "size": Vector2i(2, 3), "can_drag": false, "is_system": false, "color": Color.RED, "has_marker": true, "is_main_engine": true}
}

var selected_module = "hull" 
var active_category = "Корпуса" 
var ui_modules_container = null 

func _ready():
	initialize_grid()
	create_vertical_ui()
	
	# ИСПРАВЛЕНИЕ: Сдвигаем всю сетку вправо на 300 пикселей
	self.position = Vector2(300, 50)
	
	var cam = get_node_or_null("Camera2D")
	if cam:
		cam.position = Vector2(320, 320) # Центрируем камеру относительно самой сетки

func initialize_grid():
	grid_data = []
	for x in range(GRID_SIZE_X):
		var column = []
		for y in range(GRID_SIZE_Y): column.append(null)
		grid_data.append(column)

func get_rotated_size(base_size: Vector2i, rot: int) -> Vector2i:
	if rot == 1 or rot == 3: return Vector2i(base_size.y, base_size.x)
	return base_size

func is_path_clear(start_x, start_y, width, dir: Vector2i) -> bool:
	var cur_x = start_x; var cur_y = start_y
	for w in range(width):
		var check_x = cur_x + (w if dir.y != 0 else 0)
		var check_y = cur_y + (w if dir.x != 0 else 0)
		while check_x >= 0 and check_x < GRID_SIZE_X and check_y >= 0 and check_y < GRID_SIZE_Y:
			if grid_data[check_x][check_y] != null: return false
			check_x += dir.x; check_y += dir.y
	return true

func is_cell_in_any_clearance(x, y) -> bool:
	for gx in range(GRID_SIZE_X):
		for gy in range(GRID_SIZE_Y):
			var data = grid_data[gx][gy]
			if data and data["origin"] == Vector2i(gx, gy):
				var m_id = data["id"]; var m_rot = data["rotation"]
				var m_size = get_rotated_size(module_db[m_id]["size"], m_rot)
				var clear_dir = get_clearance_direction(m_id, m_rot)
				if clear_dir != Vector2i.ZERO:
					if is_point_in_clearance_beam(gx, gy, m_size, m_rot, clear_dir, x, y): return true
	return false

func get_clearance_direction(id, rot) -> Vector2i:
	if id == "cockpit": return Vector2i(0, -1)
	if "engine" in id:
		if rot == 0: return Vector2i(0, 1)  
		if rot == 1: return Vector2i(-1, 0) 
		if rot == 2: return Vector2i(0, -1) 
		if rot == 3: return Vector2i(1, 0)  
	return Vector2i.ZERO

func is_point_in_clearance_beam(ox, oy, size, _rot, dir, px, py) -> bool:
	var start_rect = Rect2()
	if dir == Vector2i(0, -1): start_rect = Rect2(ox, 0, size.x, oy)
	elif dir == Vector2i(0, 1): start_rect = Rect2(ox, oy + size.y, size.x, GRID_SIZE_Y - (oy + size.y))
	elif dir == Vector2i(-1, 0): start_rect = Rect2(0, oy, ox, size.y)
	elif dir == Vector2i(1, 0): start_rect = Rect2(ox + size.x, oy, GRID_SIZE_X - (ox + size.x), size.y)
	return start_rect.has_point(Vector2(px, py))

func _process(_delta):
	if not is_building_mode: return
	
	var mouse_pos = get_local_mouse_position()
	var grid_pos = Vector2i(int(mouse_pos.x / CELL_SIZE), int(mouse_pos.y / CELL_SIZE))
	
	if grid_pos.x >= 0 and grid_pos.x < GRID_SIZE_X and grid_pos.y >= 0 and grid_pos.y < GRID_SIZE_Y:
		if hovered_cell != grid_pos:
			hovered_cell = grid_pos
			queue_redraw()
			if Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT) and module_db[selected_module]["can_drag"]:
				place_module(hovered_cell.x, hovered_cell.y)
			elif Input.is_mouse_button_pressed(MOUSE_BUTTON_RIGHT):
				var data = grid_data[hovered_cell.x][hovered_cell.y]
				if data and not module_db[data["id"]]["is_system"]:
					remove_module(hovered_cell.x, hovered_cell.y)
	else:
		if hovered_cell != Vector2i(-1, -1):
			hovered_cell = Vector2i(-1, -1)
			queue_redraw()

func _unhandled_input(event):
	if not is_building_mode: return
	
	if event is InputEventMouseButton and event.pressed:
		# ИСПРАВЛЕНИЕ: Блокируем клик, если мышь вне сетки
		if hovered_cell != Vector2i(-1, -1):
			if event.button_index == MOUSE_BUTTON_LEFT: place_module(hovered_cell.x, hovered_cell.y)
			elif event.button_index == MOUSE_BUTTON_RIGHT: remove_module(hovered_cell.x, hovered_cell.y)
			
	elif event is InputEventKey and event.pressed and event.keycode == KEY_R:
		if selected_module != "cockpit":
			module_rotation = (module_rotation + 1) % 4
			queue_redraw()

func place_module(x, y):
	var r_size = get_rotated_size(module_db[selected_module]["size"], module_rotation)
	for i in range(x, x + r_size.x):
		for j in range(y, y + r_size.y):
			if i >= GRID_SIZE_X or j >= GRID_SIZE_Y or grid_data[i][j] != null: return
			if is_cell_in_any_clearance(i, j): return

	var my_clear_dir = get_clearance_direction(selected_module, module_rotation)
	if my_clear_dir != Vector2i.ZERO:
		var start_x = x + (r_size.x if my_clear_dir.x == 1 else (0 if my_clear_dir.x == -1 else 0))
		var start_y = y + (r_size.y if my_clear_dir.y == 1 else (0 if my_clear_dir.y == -1 else 0))
		if my_clear_dir.x == -1: start_x -= 1
		if my_clear_dir.y == -1: start_y -= 1
		var beam_width = r_size.x if my_clear_dir.y != 0 else r_size.y
		if not is_path_clear(start_x, start_y, beam_width, my_clear_dir): return 

	for i in range(x, x + r_size.x):
		for j in range(y, y + r_size.y):
			grid_data[i][j] = {"id": selected_module, "origin": Vector2i(x, y), "rotation": module_rotation}
	queue_redraw()

func remove_module(x, y):
	if grid_data[x][y] == null: return
	var origin = grid_data[x][y]["origin"]; var mod_id = grid_data[x][y]["id"]
	var r_size = get_rotated_size(module_db[mod_id]["size"], grid_data[x][y]["rotation"])
	for i in range(origin.x, origin.x + r_size.x):
		for j in range(origin.y, origin.y + r_size.y): grid_data[i][j] = null
	queue_redraw()

func _draw():
	if not is_building_mode: return
	draw_clearance_zones()

	for x in range(GRID_SIZE_X):
		for y in range(GRID_SIZE_Y):
			var data = grid_data[x][y]
			if data != null and data["origin"] == Vector2i(x, y):
				var m_id = data["id"]; var rot = data["rotation"]
				var r_size = get_rotated_size(module_db[m_id]["size"], rot)
				var rect = Rect2(x * CELL_SIZE, y * CELL_SIZE, r_size.x * CELL_SIZE, r_size.y * CELL_SIZE)
				draw_rect(rect, module_db[m_id]["color"], true)
				draw_rect(rect, Color.BLACK, false, 1.0)
				if module_db[m_id]["has_marker"]:
					draw_marker(rect, 2 if m_id == "cockpit" else rot)

	if hovered_cell != Vector2i(-1, -1):
		var r_size = get_rotated_size(module_db[selected_module]["size"], module_rotation)
		draw_rect(Rect2(hovered_cell.x * CELL_SIZE, hovered_cell.y * CELL_SIZE, r_size.x * CELL_SIZE, r_size.y * CELL_SIZE), Color(1, 1, 1, 0.2), true)

	var line_color = Color(0, 1, 0, 0.1)
	for i in range(GRID_SIZE_X + 1): draw_line(Vector2(i * CELL_SIZE, 0), Vector2(i * CELL_SIZE, GRID_SIZE_Y * CELL_SIZE), line_color)
	for i in range(GRID_SIZE_Y + 1): draw_line(Vector2(0, i * CELL_SIZE), Vector2(GRID_SIZE_X * CELL_SIZE, i * CELL_SIZE), line_color)

func draw_clearance_zones():
	for x in range(GRID_SIZE_X):
		for y in range(GRID_SIZE_Y):
			var data = grid_data[x][y]
			if data and data["origin"] == Vector2i(x, y):
				var dir = get_clearance_direction(data["id"], data["rotation"])
				if dir != Vector2i.ZERO:
					var m_size = get_rotated_size(module_db[data["id"]]["size"], data["rotation"])
					var z_color = Color(1, 0, 0, 0.05) if "engine" in data["id"] else Color(0, 1, 1, 0.05)
					var z_rect = Rect2()
					if dir == Vector2i(0, -1): z_rect = Rect2(x, 0, m_size.x, y)
					elif dir == Vector2i(0, 1): z_rect = Rect2(x, y + m_size.y, m_size.x, GRID_SIZE_Y - (y + m_size.y))
					elif dir == Vector2i(-1, 0): z_rect = Rect2(0, y, x, m_size.y)
					elif dir == Vector2i(1, 0): z_rect = Rect2(x + m_size.x, y, GRID_SIZE_X - (x + m_size.x), m_size.y)
					draw_rect(Rect2(z_rect.position * CELL_SIZE, z_rect.size * CELL_SIZE), z_color, true)

func draw_marker(rect, rot):
	var m_color = Color(0, 0, 0, 0.5); var th = 6; var m_rect = Rect2()
	if rot == 0: m_rect = Rect2(rect.position.x, rect.position.y + rect.size.y - th, rect.size.x, th)
	elif rot == 1: m_rect = Rect2(rect.position.x, rect.position.y, th, rect.size.y)
	elif rot == 2: m_rect = Rect2(rect.position.x, rect.position.y, rect.size.x, th)
	elif rot == 3: m_rect = Rect2(rect.position.x + rect.size.x - th, rect.position.y, th, rect.size.y)
	draw_rect(m_rect, m_color, true)

func create_vertical_ui():
	var canvas = get_node("CanvasLayer")
	for c in canvas.get_children():
		if c.name == "UI": c.queue_free()
		
	var ui = Control.new()
	ui.name = "UI"
	ui.set_anchors_preset(Control.PRESET_FULL_RECT)
	# ИСПРАВЛЕНИЕ: Говорим пустому контейнеру не глотать клики мыши
	ui.mouse_filter = Control.MOUSE_FILTER_IGNORE 
	canvas.add_child(ui)
	
	var panel = PanelContainer.new()
	panel.custom_minimum_size = Vector2(250, 0)
	panel.set_anchors_preset(Control.PRESET_LEFT_WIDE)
	# А вот панель должна блокировать клики под собой
	panel.mouse_filter = Control.MOUSE_FILTER_STOP 
	ui.add_child(panel)
	
	var margin = MarginContainer.new()
	margin.add_theme_constant_override("margin_top", 10)
	margin.add_theme_constant_override("margin_left", 10)
	margin.add_theme_constant_override("margin_right", 10)
	margin.add_theme_constant_override("margin_bottom", 10)
	panel.add_child(margin)
	
	var main_vbox = VBoxContainer.new()
	margin.add_child(main_vbox)
	
	var lbl_cat = Label.new(); lbl_cat.text = "КАТЕГОРИИ:"; main_vbox.add_child(lbl_cat)
	var cat_vbox = VBoxContainer.new(); main_vbox.add_child(cat_vbox)
	
	var categories = []
	for id in module_db:
		if not module_db[id]["cat"] in categories: categories.append(module_db[id]["cat"])
		
	for cat in categories:
		var btn = Button.new()
		btn.text = cat
		btn.pressed.connect(func(): 
			active_category = cat
			refresh_module_list()
		)
		cat_vbox.add_child(btn)
		
	var separator = HSeparator.new(); main_vbox.add_child(separator)
	
	var lbl_mod = Label.new(); lbl_mod.text = "МОДУЛИ:"; main_vbox.add_child(lbl_mod)
	ui_modules_container = VBoxContainer.new()
	main_vbox.add_child(ui_modules_container)
	
	refresh_module_list()
	
	var spacer = Control.new()
	spacer.size_flags_vertical = Control.SIZE_EXPAND_FILL
	main_vbox.add_child(spacer)
	
	var launch_btn = Button.new()
	launch_btn.text = "🚀 В ПОЛЕТ!"
	launch_btn.modulate = Color.GREEN
	launch_btn.custom_minimum_size = Vector2(0, 50)
	launch_btn.pressed.connect(launch_ship)
	main_vbox.add_child(launch_btn)

func refresh_module_list():
	for c in ui_modules_container.get_children(): c.queue_free()
	for id in module_db:
		if module_db[id]["cat"] == active_category:
			var btn = Button.new()
			btn.text = module_db[id]["name"] + " (" + str(module_db[id]["size"].x) + "x" + str(module_db[id]["size"].y) + ")"
			# ИСПРАВЛЕНИЕ: Используем bind() для передачи конкретного id, а не ссылки на переменную цикла
			btn.pressed.connect(_on_module_selected.bind(id))
			ui_modules_container.add_child(btn)

# Вспомогательная функция для исправления ошибки замыкания (closure bug)
func _on_module_selected(mod_id):
	selected_module = mod_id
	module_rotation = 0

func launch_ship():
	var min_x = 99999; var min_y = 99999; var max_x = -99999; var max_y = -99999
	var has_modules = false
	var cockpit_forward = Vector2(0, -1) 
	
	for x in range(GRID_SIZE_X):
		for y in range(GRID_SIZE_Y):
			var data = grid_data[x][y]
			if data and data["origin"] == Vector2i(x, y):
				has_modules = true
				var px = x * CELL_SIZE; var py = y * CELL_SIZE
				var m_size = get_rotated_size(module_db[data["id"]]["size"], data["rotation"])
				if px < min_x: min_x = px
				if py < min_y: min_y = py
				if (px + m_size.x * CELL_SIZE) > max_x: max_x = px + m_size.x * CELL_SIZE
				if (py + m_size.y * CELL_SIZE) > max_y: max_y = py + m_size.y * CELL_SIZE
				
				if data["id"] == "cockpit":
					cockpit_forward = get_clearance_direction("cockpit", data["rotation"])

	if not has_modules: return
	var center_offset = Vector2(min_x + max_x, min_y + max_y) / 2.0

	var physical_ship = RigidBody2D.new()
	physical_ship.set_script(load("res://scripts/player_ship.gd"))
	var compiled_modules = []
	
	for x in range(GRID_SIZE_X):
		for y in range(GRID_SIZE_Y):
			var data = grid_data[x][y]
			if data and data["origin"] == Vector2i(x, y):
				var m_id = data["id"]; var rot = data["rotation"]
				var r_size = get_rotated_size(module_db[m_id]["size"], rot)
				
				var collision = CollisionShape2D.new()
				var shape = RectangleShape2D.new()
				shape.size = Vector2(r_size.x, r_size.y) * CELL_SIZE
				collision.shape = shape
				collision.position = (Vector2(x, y) * CELL_SIZE + shape.size / 2.0) - center_offset
				physical_ship.add_child(collision)
				
				compiled_modules.append({
					"rect": Rect2(Vector2(x, y) * CELL_SIZE - center_offset, shape.size),
					"color": module_db[m_id]["color"],
					"has_marker": module_db[m_id]["has_marker"],
					"visual_rot": 2 if m_id == "cockpit" else rot,
					"is_engine": "engine" in m_id,
					"is_main_engine": module_db[m_id].get("is_main_engine", false),
					"clear_dir": get_clearance_direction(m_id, rot),
					"engine_length": r_size.y if get_clearance_direction(m_id, rot).y != 0 else r_size.x,
					"power": 0.0
				})
	
	physical_ship.modules_data = compiled_modules
	physical_ship.ship_forward_dir = cockpit_forward 
	
	is_building_mode = false 
	get_node("CanvasLayer").hide() 
	queue_redraw() 
	
	add_child(physical_ship)
	
	# Не забываем учесть наше глобальное смещение сетки при старте
	physical_ship.global_position = center_offset + self.position 
	
	var cam = get_node_or_null("Camera2D")
	if cam:
		cam.reparent(physical_ship)
		cam.position = Vector2.ZERO
