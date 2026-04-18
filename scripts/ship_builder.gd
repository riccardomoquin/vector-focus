extends Node2D

# --- НАСТРОЙКИ СЕТКИ ---
const GRID_SIZE_X = 20
const GRID_SIZE_Y = 20
const CELL_SIZE = 32 # <-- Наш размер клетки

var grid_data = []

func _ready():
	initialize_grid()
	# Команда queue_redraw() говорит движку: "В следующем кадре вызови функцию _draw()"
	# Без нее линии не появятся на экране.
	queue_redraw() 

func initialize_grid():
	for x in range(GRID_SIZE_X):
		var column = []
		for y in range(GRID_SIZE_Y):
			column.append(null)
		grid_data.append(column)
	print("Сетка корабля 20x20 успешно создана в памяти!")

# --- ВИЗУАЛИЗАЦИЯ ---
# Функция _draw() вызывается движком для отрисовки 2D элементов.
func _draw():
	# Цвет наших линий. Формат: Color(Red, Green, Blue, Alpha).
	# Значения от 0.0 до 1.0. (0.3, 0.3, 0.3) даст темно-серый цвет.
	var line_color = Color(0.3, 0.3, 0.3)
	var line_width = 1.0 # Толщина линии в пикселях
	
	# 1. Рисуем вертикальные линии
	# Мы идем от 0 до 20 включительно (+1), чтобы нарисовать правую замыкающую линию.
	for x in range(GRID_SIZE_X + 1):
		# Точка А (начало линии сверху)
		var start_point = Vector2(x * CELL_SIZE, 0)
		# Точка Б (конец линии снизу)
		var end_point = Vector2(x * CELL_SIZE, GRID_SIZE_Y * CELL_SIZE)
		# Рисуем саму линию
		draw_line(start_point, end_point, line_color, line_width)
		
	# 2. Рисуем горизонтальные линии
	for y in range(GRID_SIZE_Y + 1):
		# Точка А (начало линии слева)
		var start_point = Vector2(0, y * CELL_SIZE)
		# Точка Б (конец линии справа)
		var end_point = Vector2(GRID_SIZE_X * CELL_SIZE, y * CELL_SIZE)
		draw_line(start_point, end_point, line_color, line_width)
