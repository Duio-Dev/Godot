extends Area2D
class_name ContainerLoot

@export var possible_items: Array[ItemData] = []
@export var min_items: int = 2
@export var max_items: int = 5

var items_data: Array[ItemData] = []
var items_positions: Array[Vector2i] = []
var items_searched: Array[bool] = []
var items_stack_counts: Array[int] = []    # 堆叠数量数组

var _is_initialized: bool = false

func _ready():
	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)

func _on_body_entered(body):
	if body is PlayerCharacter:
		body.set_current_container(self)

func _on_body_exited(body):
	if body is PlayerCharacter:
		body.clear_current_container(self)

func init_loot():
	if _is_initialized:
		return
	_is_initialized = true
	var count = randi_range(min_items, max_items)
	for i in range(count):
		var template = possible_items[randi() % possible_items.size()]
		var data = template.duplicate()   # 避免修改原资源
		# 弹匣弹药随机
		if data.is_magazine:
			data.current_ammo = randi_range(0, 0)
		items_data.append(data)
		items_positions.append(Vector2i(-1, -1))
		items_searched.append(false)
		if data.max_stack > 1:
			items_stack_counts.append(randi_range(1, 20))
		else:
			items_stack_counts.append(1)
