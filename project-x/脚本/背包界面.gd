extends Control

var active_container_grid: InventoryGrid = null

@export var player: PlayerCharacter

@onready var 口袋网格: InventoryGrid = $背包部分/VBoxContainer/口袋部分/口袋网格
@onready var 胸挂网格: InventoryGrid = $背包部分/VBoxContainer/胸挂部分/胸挂网格
@onready var 背包网格: InventoryGrid = $背包部分/VBoxContainer/背包部分/背包网格
@onready var 容器部分: VBoxContainer = $容器部分
@onready var 容器网格: InventoryGrid = $容器部分/Control/容器网格
@onready var 血量值: Label = $健康与装备部分/VBoxContainer/HBoxContainer/血量/血量值
@onready var 水分值: Label = $健康与装备部分/VBoxContainer/HBoxContainer/水分/水分值
@onready var 饱食值: Label = $健康与装备部分/VBoxContainer/HBoxContainer/饱食度/饱食值
@onready var 耐力: Label = $健康与装备部分/VBoxContainer/HBoxContainer/耐力/耐力
@onready var 负重值: Label = $健康与装备部分/VBoxContainer/HBoxContainer2/负重/负重值
@onready var 听力值: Label = $健康与装备部分/VBoxContainer/HBoxContainer2/听力/听力值
@onready var 头部血量显示: Label = $健康与装备部分/VBoxContainer/Control/头部/ColorRect/头部血量显示
@onready var 身体血量显示: Label = $健康与装备部分/VBoxContainer/Control/身体/ColorRect/身体血量显示
@onready var 左脚血量显示: Label = $健康与装备部分/VBoxContainer/Control/左脚/ColorRect/左脚血量显示
@onready var 右脚血量显示: Label = $健康与装备部分/VBoxContainer/Control/右脚/ColorRect/右脚血量显示
@onready var 右手血量显示: Label = $健康与装备部分/VBoxContainer/Control/右手/ColorRect/右手血量显示
@onready var 左手血量显示: Label = $健康与装备部分/VBoxContainer/Control/左手/ColorRect/左手血量显示

var _active_container: ContainerLoot = null
var _is_searching: bool = false

func _ready():
	add_to_group("InventoryUI")
	hide()
	容器部分.hide()
	set_process(true)

func _process(delta):
	if not visible or not player: return
	_update_stats()

func _update_stats():
	var total_hp = player.get_total_hp()
	var max_total_hp = player.get_max_total_hp()
	血量值.text = "%d / %d" % [total_hp, max_total_hp]
	水分值.text = "%d / %d" % [player.hydration, player.max_hydration]
	饱食值.text = "%d / %d" % [player.satiety, player.max_satiety]
	耐力.text = "%d / %d" % [player.stamina, player.max_stamina]
	var current_weight = player.get_current_weight()
	负重值.text = "%.1f / %.1f" % [current_weight, player.max_weight]
	听力值.text = "%d%%" % int(player.hearing * 100)
	头部血量显示.text = "%d / %d" % [player.head_hp, player.max_head_hp]
	身体血量显示.text = "%d / %d" % [player.body_hp, player.max_body_hp]
	左脚血量显示.text = "%d / %d" % [player.left_foot_hp, player.max_left_foot_hp]
	右脚血量显示.text = "%d / %d" % [player.right_foot_hp, player.max_right_foot_hp]
	右手血量显示.text = "%d / %d" % [player.right_arm_hp, player.max_right_arm_hp]
	左手血量显示.text = "%d / %d" % [player.left_arm_hp, player.max_left_arm_hp]

func toggle_visibility():
	visible = not visible
	if visible:
		_refresh_all_grids()
		Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
	elif not 容器部分.visible:
		Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)

func _refresh_all_grids():
	for grid in [口袋网格, 胸挂网格, 背包网格]:
		if grid: grid._reposition_all_items(); grid.queue_redraw()

func show_container(container: ContainerLoot):
	if _is_searching: return
	if _active_container: hide_container()
	_active_container = container; container.init_loot()
	容器部分.show(); 容器网格.show(); visible = true
	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
	active_container_grid = 容器网格

	var item_scene = preload("res://场景/所有继承场景的父场景/item.tscn")
	for item in 容器网格.items.duplicate():
		if is_instance_valid(item): 容器网格.remove_item(item); item.queue_free()

	var new_items: Array[InventoryItem] = []
	for i in range(container.items_data.size()):
		var data = container.items_data[i]
		var pos = container.items_positions[i]
		var searched = container.items_searched[i]
		var stack = 1
		if i < container.items_stack_counts.size():
			stack = container.items_stack_counts[i]

		var item = item_scene.instantiate(); item.item_data = data
		item.stack_count = stack
		item._update_stack_label()

		if pos.x < 0 or pos.y < 0:
			var found = false
			for x in range(容器网格.columns):
				for y in range(容器网格.rows):
					var test_pos = Vector2i(x, y)
					if 容器网格._can_place_at(item, test_pos):
						pos = test_pos; found = true; break
				if found: break
		if pos.x >= 0 and pos.y >= 0:
			容器网格._place_item(item, pos); container.items_positions[i] = pos
			if searched: item._was_searched = true; item.update_search_visuals()
			new_items.append(item)
		else:
			item.queue_free()

	_is_searching = true
	for item in new_items:
		if not item._was_searched and is_instance_valid(item):
			item.start_search()
			await item.search_finished
			if not visible: break
	_is_searching = false

func hide_container():
	_is_searching = false
	active_container_grid = null
	if not _active_container: return
	var new_datas: Array[ItemData] = []
	var new_positions: Array[Vector2i] = []
	var new_searched: Array[bool] = []
	var new_stack_counts: Array[int] = []
	for item in 容器网格.items.duplicate():
		if item is InventoryItem and is_instance_valid(item):
			new_datas.append(item.item_data)
			new_positions.append(item.grid_pos)
			new_searched.append(item._was_searched)
			new_stack_counts.append(item.stack_count)
			容器网格.remove_item(item)
			item.queue_free()
	_active_container.items_data = new_datas
	_active_container.items_positions = new_positions
	_active_container.items_searched = new_searched
	_active_container.items_stack_counts = new_stack_counts
	_active_container = null
	容器网格.hide(); 容器部分.hide()
	if not visible: Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
