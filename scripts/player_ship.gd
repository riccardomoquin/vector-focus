extends RigidBody2D

const ENGINE_POWER = 45000.0
const CELL_SIZE = 32

var modules_data = [] 
var ship_forward_dir = Vector2(0, -1) 
var safe_spin_speed: float = 5.0 
var use_main_for_rotation: bool = false 

var max_energy: float = 0.0
var current_energy: float = 0.0
var energy_generation: float = 0.0
var ui_energy_bar: ProgressBar

var stars_layers = [[], [], []]
var meteor_scene = preload("res://scenes/meteor.tscn")

func _ready():

	# ВОЗВРАЩАЕМ: Корабль создается кодом, поэтому Инспектора у него нет!
	gravity_scale = 0
	linear_damp = 0.0 
	angular_damp = 0.0 

	# --- ТЕМНЫЙ ФОН ---
	RenderingServer.set_default_clear_color(Color(0.02, 0.02, 0.05))
		# ... остальной код ...
	
	# --- ТЕМНЫЙ ФОН ---
	RenderingServer.set_default_clear_color(Color(0.02, 0.02, 0.05))

	# --- МАСШТАБНАЯ ГЕНЕРАЦИЯ ЗВЕЗД ---
	# Увеличили радиус до 10000 и количество звезд до 350 на слой
	for layer in range(3):
		for i in range(350):
			stars_layers[layer].append({
				"pos": Vector2(randf_range(-10000, 10000), randf_range(-10000, 10000)),
				"size": randf_range(1.0, 2.5) if layer == 0 else randf_range(0.5, 1.5),
				"alpha": randf_range(0.2, 0.7),
				"parallax": 0.1 + (layer * 0.2)
			})

	var total_mass = 0.0
	var com_sum = Vector2.ZERO
	
	for mod in modules_data:
		if mod.get("node_ref"):
			var node = mod["node_ref"]
			total_mass += node.mass
			com_sum += node.position * node.mass
			
			if "energy_gen" in node: energy_generation += node.energy_gen
			if "buffer_max" in node: max_energy += node.buffer_max
			
	if total_mass > 0:
		mass = total_mass
		center_of_mass_mode = RigidBody2D.CENTER_OF_MASS_MODE_CUSTOM
		center_of_mass = com_sum / total_mass
		
		var calculated_inertia = 0.0
		for mod in modules_data:
			if mod.get("node_ref"):
				var m = mod["node_ref"].mass
				var dist = mod["node_ref"].position.distance_to(center_of_mass)
				calculated_inertia += (m * 200.0) + (m * dist * dist)
		inertia = calculated_inertia
		safe_spin_speed = clamp(600.0 / mass, 0.6, 8.0)
		
	if meteor_scene:
		for i in range(15): 
			var meteor = meteor_scene.instantiate()
			var angle = randf_range(0, PI * 2)
			var dist = randf_range(500, 2500)
			meteor.global_position = global_position + Vector2(cos(angle), sin(angle)) * dist
			get_parent().call_deferred("add_child", meteor)

	current_energy = max_energy 
	create_hud() 

	var cam = get_node_or_null("Camera2D")
	if cam: cam.zoom = Vector2(0.5, 0.5)

func create_hud():
	var canvas = CanvasLayer.new()
	canvas.layer = 120
	add_child(canvas)
	
	var ui_root = Control.new()
	ui_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	ui_root.mouse_filter = Control.MOUSE_FILTER_IGNORE 
	canvas.add_child(ui_root)
	
	var bar_container = CenterContainer.new()
	bar_container.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	bar_container.custom_minimum_size.y = 80
	bar_container.mouse_filter = Control.MOUSE_FILTER_IGNORE 
	ui_root.add_child(bar_container)
	
	ui_energy_bar = ProgressBar.new()
	ui_energy_bar.custom_minimum_size = Vector2(500, 20)
	ui_energy_bar.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	ui_energy_bar.grow_horizontal = Control.GROW_DIRECTION_BOTH
	ui_energy_bar.position.y -= 50 
	ui_energy_bar.mouse_filter = Control.MOUSE_FILTER_IGNORE 
	
	ui_energy_bar.show_percentage = false
	ui_energy_bar.max_value = max_energy
	ui_energy_bar.value = current_energy
	
	var sb_fill = StyleBoxFlat.new()
	sb_fill.bg_color = Color(0.0, 1.0, 0.5, 0.9)
	ui_energy_bar.add_theme_stylebox_override("fill", sb_fill)
	
	bar_container.add_child(ui_energy_bar)

func _unhandled_input(event):
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_V:
			use_main_for_rotation = !use_main_for_rotation
	
	if event is InputEventMouseButton and event.pressed:
		var cam = get_viewport().get_camera_2d()
		if cam:
			if event.button_index == MOUSE_BUTTON_WHEEL_UP: cam.zoom *= 1.1 
			elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN: cam.zoom *= 0.9 
			cam.zoom = cam.zoom.clamp(Vector2(0.1, 0.1), Vector2(2.0, 2.0))

func _physics_process(delta):
	current_energy = clamp(current_energy + (energy_generation * delta), 0.0, max_energy)
	if ui_energy_bar: ui_energy_bar.value = current_energy

	var forward = Vector2(ship_forward_dir)
	var right = Vector2(-forward.y, forward.x)
	var is_braking = Input.is_physical_key_pressed(KEY_SPACE)
	var is_shooting = Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT)
	
	var target_angle = global_position.direction_to(get_global_mouse_position()).angle()
	var forward_angle = forward.angle()
	var angle_diff = wrapf(target_angle - (rotation + forward_angle), -PI, PI)
	
	var desired_angular_vel = 0.0
	if not is_braking:
		desired_angular_vel = clamp(angle_diff * 5.0, -safe_spin_speed, safe_spin_speed)
	
	var torque_needed = desired_angular_vel - angular_velocity
	var desired_torque_dir = sign(torque_needed)
	var needs_rotation = abs(torque_needed) > 0.05 
	
	var target_dir = Vector2.ZERO
	if is_braking:
		var local_vel = linear_velocity.rotated(-rotation)
		if local_vel.length() > 2.0: target_dir = -local_vel.normalized()
	else:
		if Input.is_physical_key_pressed(KEY_W): target_dir += forward
		if Input.is_physical_key_pressed(KEY_S): target_dir -= forward
		if Input.is_physical_key_pressed(KEY_D): target_dir += right
		if Input.is_physical_key_pressed(KEY_A): target_dir -= right
		if target_dir != Vector2.ZERO: target_dir = target_dir.normalized()
		
	for mod in modules_data:
		if not mod.get("node_ref"): continue
		var node = mod["node_ref"]
		
		if "module_id" in node and node.module_id == "weapon_laser":
			var cost = node.energy_cost_per_sec * delta
			if is_shooting and current_energy >= cost:
				current_energy -= cost
				node.set_firing(true)
			else:
				node.set_firing(false)

		if mod["is_engine"]:
			var t_power = 0.0
			var thrust_dir = -Vector2(mod["clear_dir"])
			var pos_from_com = node.position - center_of_mass
			
			if target_dir != Vector2.ZERO and thrust_dir.dot(target_dir) > 0.5:
				t_power = 1.0
				
			if needs_rotation and (not mod["is_main_engine"] or use_main_for_rotation):
				var torque = pos_from_com.cross(thrust_dir)
				if sign(torque) == desired_torque_dir and abs(torque) > 0.1:
					t_power = max(t_power, clamp(abs(torque_needed) / 2.0, 0.0, 1.0))
			
			var e_cons = node.energy_cons_active * t_power * delta
			if current_energy < e_cons: t_power = 0.0
			else: current_energy -= e_cons
			
			mod["power"] = lerp(mod.get("power", 0.0), t_power, node.dynamic_ramp * 12.0 * delta)
			
			if mod["power"] > 0.01:
				var f = (thrust_dir * ENGINE_POWER * node.thrust_multiplier * mod["power"]).rotated(rotation)
				apply_force(f, node.position.rotated(rotation))

	queue_redraw()

func _draw():
	var cam = get_viewport().get_camera_2d()
	var cam_zoom = cam.zoom.x if cam else 1.0
	
	draw_set_transform(Vector2.ZERO, -rotation, Vector2.ONE)
	for layer in range(3):
		for star in stars_layers[layer]:
			# Расширенная зона обертывания (10000)
			var px = wrapf(star["pos"].x - global_position.x * star["parallax"], -10000, 10000)
			var py = wrapf(star["pos"].y - global_position.y * star["parallax"], -10000, 10000)
			
			var apparent_size = max(star["size"], 1.5 / cam_zoom)
			draw_rect(Rect2(px, py, apparent_size, apparent_size), Color(1, 1, 1, star["alpha"]))
	draw_set_transform(Vector2.ZERO, 0, Vector2.ONE)

	# --- ВЫХЛОП ---
	for mod in modules_data:
		if mod["is_engine"] and mod.get("power", 0.0) > 0.01:
			var power = mod["power"]
			var len_px = mod["engine_length"] * CELL_SIZE * power
			var dir = mod["clear_dir"]
			var px = mod["rect"].position.x; var py = mod["rect"].position.y
			var sx = mod["rect"].size.x; var sy = mod["rect"].size.y
			
			var p1: Vector2; var p2: Vector2; var p3: Vector2; var p4: Vector2
			if dir == Vector2i(0, 1): p1 = Vector2(px, py + sy); p2 = Vector2(px + sx, py + sy); p3 = p2 + Vector2(0, len_px); p4 = p1 + Vector2(0, len_px)
			elif dir == Vector2i(0, -1): p1 = Vector2(px, py); p2 = Vector2(px + sx, py); p3 = p2 - Vector2(0, len_px); p4 = p1 - Vector2(0, len_px)
			elif dir == Vector2i(1, 0): p1 = Vector2(px + sx, py); p2 = Vector2(px + sx, py + sy); p3 = p2 + Vector2(len_px, 0); p4 = p1 + Vector2(len_px, 0)
			elif dir == Vector2i(-1, 0): p1 = Vector2(px, py); p2 = Vector2(px, py + sy); p3 = p2 - Vector2(len_px, 0); p4 = p1 - Vector2(len_px, 0)
			
			var base_c = Color(1.0, 0.4, 0.2) if mod["is_main_engine"] else Color(0.3, 0.7, 1.0)
			var pts = PackedVector2Array([p1, p2, p3, p4])
			var cols = PackedColorArray([Color(base_c.r, base_c.g, base_c.b, power), Color(base_c.r, base_c.g, base_c.b, power), Color(base_c.r, base_c.g, base_c.b, 0.0), Color(base_c.r, base_c.g, base_c.b, 0.0)])
			draw_primitive(pts, cols, PackedVector2Array())
