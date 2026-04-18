extends Node2D
class_name BaseModule

# СИГНАЛЫ (для уведомления интерфейса или корабля)
signal hp_changed(current, max)
signal functional_changed(is_ok)

# БАЗОВЫЕ ПАРАМЕТРЫ
@export_group("Common")
@export var module_id: String = "base_module"
@export var mass: float = 10.0
@export var max_hp: float = 100.0
var current_hp: float

# СОСТОЯНИЕ
var is_functional: bool = true

# ЭНЕРГЕТИКА
@export_group("Energy")
@export var energy_gen: float = 0.0          # Сколько вырабатывает (для Ядра)
@export var energy_cons_base: float = 0.0    # Постоянное потребление
@export var energy_cons_active: float = 0.0  # Потребление при работе (двигатель, пушка)
@export var buffer_max: float = 0.0          # Емкость встроенного аккумулятора
var buffer_current: float = 0.0

func _ready():
	current_hp = max_hp
	buffer_current = buffer_max

# Функция получения урона
func take_damage(amount: float):
	if current_hp <= 0: return
	
	current_hp -= amount
	hp_changed.emit(current_hp, max_hp)
	
	if current_hp <= 0:
		current_hp = 0
		set_functional(false)
	
	update_visual_state()

# Управление работоспособностью
func set_functional(state: bool):
	if is_functional == state: return
	is_functional = state
	functional_changed.emit(is_functional)

# Место для будущей логики изменения внешнего вида (трещины, дыры)
func update_visual_state():
	var health_percent = current_hp / max_hp
	if health_percent <= 0:
		# В будущем: скрыть спрайт, отключить коллайдер
		modulate.a = 0.2 # Пока просто делаем прозрачным
	elif health_percent < 0.5:
		modulate = Color(0.5, 0.5, 0.5) # "Поврежденный" вид
