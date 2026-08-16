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
@onready var 容器名称: Label = $容器部分/Control/ColorRect/容器名称
@onready var 副武器装备槽: TextureRect = $健康与装备部分/VBoxContainer/Control2/武器装备槽/副武器/副武器2/副武器装备槽
@onready var 主武器装备槽: TextureRect = $"健康与装备部分/VBoxContainer/Control2/武器装备槽/主武器/主武器2/主武器装备槽"
@onready var 玩家预览: TextureRect = $健康与装备部分/VBoxContainer/Control2/玩家预览
@onready var 辐射值: Label = $健康与装备部分/VBoxContainer/HBoxContainer2/辐射/ColorRect/TextureRect/辐射值
@onready var 头部标题: Label = $健康与装备部分/VBoxContainer/Control/头部/ColorRect/头部标题
@onready var 身体标题: Label = $健康与装备部分/VBoxContainer/Control/身体/ColorRect/身体标题
@onready var 左脚标题: Label = $健康与装备部分/VBoxContainer/Control/左脚/ColorRect/左脚标题
@onready var 右脚标题: Label = $健康与装备部分/VBoxContainer/Control/右脚/ColorRect/右脚标题
@onready var 右手标题: Label = $健康与装备部分/VBoxContainer/Control/右手/ColorRect/右手标题
@onready var 左手标题: Label = $健康与装备部分/VBoxContainer/Control/左手/ColorRect/左手标题
@onready var 状态显示: Label = $健康与装备部分/VBoxContainer/状态显示
@onready var 头盔装备槽: TextureRect = $健康与装备部分/VBoxContainer/Control2/GridContainer/ColorRect/ColorRect/头盔装备槽
@onready var 背包装备槽: TextureRect = $背包部分/VBoxContainer/背包部分/ColorRect2/ColorRect3/背包装备槽  # 路径请按实际场景调整
var _active_container_source_inventory_item: InventoryItem = null
var _helmet_slot_dragging: bool = false
var _helmet_slot_drag_start: Vector2 = Vector2.ZERO
var _helmet_slot_drag_threshold: float = 5.0

var _backpack_slot_dragging: bool = false
var _backpack_slot_drag_start: Vector2 = Vector2.ZERO
var _backpack_slot_drag_threshold: float = 5.0

var _active_container: ContainerLoot = null
var _is_searching: bool = false

var _equip_progress_arc: Control = null
var _equip_progress_value: float = 0.0

var _original_head_title: String = "头部"
var _original_body_title: String = "身体"
var _original_left_arm_title: String = "左手"
var _original_right_arm_title: String = "右手"
var _original_left_foot_title: String = "左脚"
var _original_right_foot_title: String = "右脚"
var _original_status_text: String = ""

var _preview_viewport: SubViewport
var _preview_camera: Camera2D
var _preview_container: SubViewportContainer

# ---------- 背包套包代理容器变量 ----------
var _active_container_is_backpack_proxy: bool = false
var _active_container_source_loot: LootItem = null
var _active_container_source_backpack_item: InventoryItem = null
var _loaded_backpack_item: InventoryItem = null
var _active_container_source_item_data: ItemData = null   # 用于代理容器关闭时写回源 ItemData
func _ready():
	add_to_group("InventoryUI")
	hide()
	容器部分.hide()
	set_process(true)

	var menu_layer = CanvasLayer.new()
	menu_layer.name = "ContextMenuLayer"
	menu_layer.layer = 200
	get_tree().root.add_child(menu_layer)

	if 主武器装备槽: 主武器装备槽.gui_input.connect(_on_main_weapon_slot_gui_input)
	if 副武器装备槽: 副武器装备槽.gui_input.connect(_on_secondary_weapon_slot_gui_input)
	if 头盔装备槽: 头盔装备槽.gui_input.connect(_on_helmet_slot_gui_input)
	if 背包装备槽: 背包装备槽.gui_input.connect(_on_backpack_slot_gui_input)
	背包网格.grid_changed.connect(_on_backpack_grid_changed)
	_update_weapon_slots()
	_setup_player_preview()
	_init_body_part_titles()

	# 初始隐藏背包网格，待装备背包后显示
	if 背包网格:
		背包网格.visible = false

func _init_body_part_titles():
	if 头部标题: _original_head_title = 头部标题.text
	if 身体标题: _original_body_title = 身体标题.text
	if 左手标题: _original_left_arm_title = 左手标题.text
	if 右手标题: _original_right_arm_title = 右手标题.text
	if 左脚标题: _original_left_foot_title = 左脚标题.text
	if 右脚标题: _original_right_foot_title = 右脚标题.text
	if 状态显示: _original_status_text = 状态显示.text

func _setup_player_preview():
	if not player or not 玩家预览: return
	玩家预览.texture = null
	玩家预览.hide()

	var preview_size = 玩家预览.size
	if preview_size.x <= 0 or preview_size.y <= 0: preview_size = Vector2(200, 200)

	_preview_container = SubViewportContainer.new()
	_preview_container.name = "PlayerPreviewContainer"
	_preview_container.anchor_left = 玩家预览.anchor_left
	_preview_container.anchor_top = 玩家预览.anchor_top
	_preview_container.anchor_right = 玩家预览.anchor_right
	_preview_container.anchor_bottom = 玩家预览.anchor_bottom
	_preview_container.offset_left = 玩家预览.offset_left
	_preview_container.offset_top = 玩家预览.offset_top
	_preview_container.offset_right = 玩家预览.offset_right
	_preview_container.offset_bottom = 玩家预览.offset_bottom
	_preview_container.stretch = true

	_preview_viewport = SubViewport.new()
	_preview_viewport.name = "PlayerPreviewViewport"
	_preview_viewport.transparent_bg = true
	_preview_viewport.size = preview_size
	_preview_viewport.world_2d = player.get_world_2d()
	_preview_viewport.canvas_cull_mask = 1
	player.visibility_layer = 1

	_preview_camera = Camera2D.new()
	_preview_camera.name = "PreviewCamera"
	_preview_camera.zoom = Vector2(1.5, 1.5)
	_preview_viewport.add_child(_preview_camera)

	_preview_container.add_child(_preview_viewport)
	玩家预览.get_parent().add_child(_preview_container)

func _process(delta):
	if not visible or not player: return
	_update_stats()
	_update_weapon_slots()
	_update_helmet_slot()
	_update_backpack_grid()
	_update_backpack_slot()
	_update_player_preview()
	_update_radiation_display()
	_update_body_part_titles()
	_update_status_display()

func _update_radiation_display():
	if 辐射值: 辐射值.text = "%.1f" % player.radiation

func _update_body_part_titles():
	if 头部标题: 头部标题.text = _original_head_title
	if 身体标题: 身体标题.text = _original_body_title
	if 左手标题: 左手标题.text = _original_left_arm_title
	if 右手标题: 右手标题.text = _original_right_arm_title
	if 左脚标题: 左脚标题.text = _original_left_foot_title
	if 右脚标题: 右脚标题.text = _original_right_foot_title

func _update_status_display():
	if not 状态显示: return
	var status_names = []
	for buff in player.active_buffs:
		var name = player._buff_type_to_string(buff.type)
		if name != "未知":
			status_names.append(name)
	var suffix = ""
	if status_names.size() > 0:
		suffix = "+" + "+".join(status_names)
	状态显示.text = _original_status_text + suffix

func _update_player_preview():
	if not _preview_camera or not player: return
	_preview_camera.global_position = player.global_position

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

func _update_weapon_slots():
	if player and player.primary_weapon_item:
		主武器装备槽.texture = player.primary_weapon_item.物品图标.texture
	else:
		主武器装备槽.texture = null
	if player and player.secondary_weapon_item:
		副武器装备槽.texture = player.secondary_weapon_item.物品图标.texture
	else:
		副武器装备槽.texture = null

func _update_helmet_slot():
	if player and player.equipped_helmet_item:
		头盔装备槽.texture = player.equipped_helmet_item.物品图标.texture
	else:
		头盔装备槽.texture = null

func _update_backpack_slot():
	if player and player.equipped_backpack_item:
		背包装备槽.texture = player.equipped_backpack_item.物品图标.texture
	else:
		背包装备槽.texture = null

func _update_backpack_grid():
	var backpack = player.equipped_backpack_item
	if backpack == null:
		if _loaded_backpack_item != null:
			_save_grid_to_backpack(_loaded_backpack_item)
			_loaded_backpack_item = null
		if 背包网格.visible:
			背包网格.visible = false
			for item in 背包网格.items.duplicate():
				背包网格.remove_item(item)
				item.queue_free()
			背包网格.columns = 1
			背包网格.rows = 1
			背包网格._init_occupied()
		return

	var size_changed = (
		背包网格.columns != backpack.backpack_grid_columns or
		背包网格.rows != backpack.backpack_grid_rows or
		背包网格.grid_size != backpack.backpack_grid_size
	)

	if _loaded_backpack_item != backpack or size_changed:
		if _loaded_backpack_item != null and _loaded_backpack_item != backpack:
			_save_grid_to_backpack(_loaded_backpack_item)

		for item in 背包网格.items.duplicate():
			背包网格.remove_item(item)
			item.queue_free()

		背包网格.columns = backpack.backpack_grid_columns
		背包网格.rows = backpack.backpack_grid_rows
		背包网格.grid_size = backpack.backpack_grid_size   # ← 使用背包自定义格子大小
		背包网格._init_occupied()
		背包网格._update_own_size()

		_load_backpack_to_grid(backpack)
		_loaded_backpack_item = backpack
		背包网格.visible = true
		背包网格.queue_redraw()

func toggle_visibility():
	visible = not visible
	if visible:
		for grid in [口袋网格, 胸挂网格, 背包网格]:
			if grid and grid.has_method("full_consistency_check_and_fix"):
				grid.full_consistency_check_and_fix()
		_refresh_all_grids()
		Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
	else:
		# 关闭 UI 前，如果当前有打开的容器（普通容器或背包套包），先保存并关闭
		if _active_container:
			hide_container()
		Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
		_clear_context_menus()

func _refresh_all_grids():
	for grid in [口袋网格, 胸挂网格, 背包网格, 容器网格]:
		if grid:
			grid._reposition_all_items()
			grid.queue_redraw()

# ---------- 容器显示（支持普通容器和背包套包） ----------
func show_container(container: ContainerLoot):
	if _is_searching: return
	if _active_container: hide_container()
	_active_container = container

	# 如果是背包代理容器，不要调用 init_loot()，因为数据已手动填充
	if not _active_container_is_backpack_proxy:
		container.init_loot()

	容器名称.text = container.container_name
	容器名称.add_theme_color_override("font_color", Color.BLACK)
	容器网格.grid_size = container.grid_size
	容器网格.columns = container.grid_columns
	容器网格.rows = container.grid_rows
	容器网格._init_occupied()
	容器网格._update_own_size()
	容器网格.queue_redraw()
	容器部分.show()
	容器网格.show()
	visible = true
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
		var stack = container.items_stack_counts[i]
		var item = item_scene.instantiate()
		item.item_data = data
		item.stack_count = stack

		# 恢复背包内部数据
		if data.is_backpack and not data.backpack_contents.is_empty():
			item.backpack_items_data = data.backpack_contents.get("items_data", []).duplicate()
			item.backpack_items_positions = data.backpack_contents.get("items_positions", []).duplicate()
			item.backpack_items_searched = data.backpack_contents.get("items_searched", []).duplicate()
			item.backpack_items_stack_counts = data.backpack_contents.get("items_stack_counts", []).duplicate()

		# 恢复配件数据（头盔/武器）
		if (data.weapon_part_type == ItemData.WeaponPartType.RECEIVER or data.weapon_part_type == ItemData.WeaponPartType.HELMET) and not data.installed_parts_data.is_empty():
			item.restore_installed_parts_from_data(data.installed_parts_data)

		if pos.x < 0 or pos.y < 0:
			var found = false
			for x in range(容器网格.columns):
				for y in range(容器网格.rows):
					var test_pos = Vector2i(x, y)
					if 容器网格._can_place_at(item, test_pos):
						pos = test_pos
						found = true
						break
				if found: break
		if pos.x >= 0 and pos.y >= 0:
			容器网格._place_item(item, pos)
			container.items_positions[i] = pos
			if searched:
				item._was_searched = true
				item.update_search_visuals()
			new_items.append(item)
		else:
			item.queue_free()

	# 为弹匣填充正确弹药（如果容器中有弹药）
	for item in new_items:
		if item.item_data.weapon_part_type == ItemData.WeaponPartType.MAGAZINE and item.item_data.current_ammo > 0:
			var candidates: Array[ItemData] = []
			for candidate in container.possible_items:
				if candidate.weapon_part_type == ItemData.WeaponPartType.NONE and candidate.ammo_type == item.item_data.ammo_type:
					candidates.append(candidate)
			if candidates.size() > 0:
				var bullet_data = candidates[randi() % candidates.size()]
				item.add_initial_bullet(bullet_data, item.item_data.current_ammo)
			else:
				item.item_data.current_ammo = 0
				item._loaded_ammo_dict.clear()
				item._update_stack_label()

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
	var new_stacks: Array[int] = []
	for item in 容器网格.items.duplicate():
		if item is InventoryItem and is_instance_valid(item):
			# 保存背包内部数据到 ItemData
			if item.item_data.is_backpack:
				item.item_data.backpack_contents = {
					"items_data": item.backpack_items_data.duplicate(),
					"items_positions": item.backpack_items_positions.duplicate(),
					"items_searched": item.backpack_items_searched.duplicate(),
					"items_stack_counts": item.backpack_items_stack_counts.duplicate()
				}
			# 保存配件数据到 ItemData
			if item.item_data.weapon_part_type == ItemData.WeaponPartType.RECEIVER or item.item_data.weapon_part_type == ItemData.WeaponPartType.HELMET:
				if item.installed_parts.size() > 0:
					item.item_data.installed_parts_data = item.serialize_installed_parts()
				else:
					item.item_data.installed_parts_data = {}

			new_datas.append(item.item_data)
			new_positions.append(item.grid_pos)
			new_searched.append(item._was_searched)
			new_stacks.append(item.stack_count)
			容器网格.remove_item(item)
			item.queue_free()

	# 写回数据
	if _active_container_is_backpack_proxy:
		# 1. 更新源 InventoryItem（如果仍然存在）
		if _active_container_source_inventory_item and is_instance_valid(_active_container_source_inventory_item):
			_active_container_source_inventory_item.backpack_items_data = new_datas.duplicate()
			_active_container_source_inventory_item.backpack_items_positions = new_positions.duplicate()
			_active_container_source_inventory_item.backpack_items_searched = new_searched.duplicate()
			_active_container_source_inventory_item.backpack_items_stack_counts = new_stacks.duplicate()
		# 2. 更新源 ItemData
		if _active_container_source_item_data:
			_active_container_source_item_data.backpack_contents = {
				"items_data": new_datas,
				"items_positions": new_positions,
				"items_searched": new_searched,
				"items_stack_counts": new_stacks
			}
		elif _active_container_source_loot:
			_active_container_source_loot.backpack_data = {
				"items_data": new_datas,
				"items_positions": new_positions,
				"items_searched": new_searched,
				"items_stack_counts": new_stacks
			}
		elif _active_container_source_backpack_item:
			_active_container_source_backpack_item.backpack_items_data = new_datas
			_active_container_source_backpack_item.backpack_items_positions = new_positions
			_active_container_source_backpack_item.backpack_items_searched = new_searched
			_active_container_source_backpack_item.backpack_items_stack_counts = new_stacks

		# 清理代理状态
		_active_container_is_backpack_proxy = false
		_active_container_source_loot = null
		_active_container_source_backpack_item = null
		_active_container_source_item_data = null
		_active_container_source_inventory_item = null
	else:
		_active_container.items_data = new_datas
		_active_container.items_positions = new_positions
		_active_container.items_searched = new_searched
		_active_container.items_stack_counts = new_stacks

	_active_container = null
	容器网格.hide()
	容器部分.hide()
	if not visible:
		Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
	_clear_context_menus()

# ---------- 背包套包专用函数 ----------
func show_backpack_loot(loot_item: LootItem):
	if not loot_item or not loot_item.item_data or not loot_item.item_data.is_backpack:
		return
	if _active_container:
		hide_container()

	var container = ContainerLoot.new()
	container.container_name = loot_item.item_data.item_name
	container.grid_columns = loot_item.item_data.backpack_grid_columns
	container.grid_rows = loot_item.item_data.backpack_grid_rows
	container.grid_size = 64
	container.possible_items = []  # 避免生成随机物品
	container.items_data = loot_item.backpack_data.get("items_data", []).duplicate()
	container.items_positions = loot_item.backpack_data.get("items_positions", []).duplicate()
	container.items_searched = loot_item.backpack_data.get("items_searched", []).duplicate()
	container.items_stack_counts = loot_item.backpack_data.get("items_stack_counts", []).duplicate()

	_active_container_is_backpack_proxy = true
	_active_container_source_loot = loot_item
	_active_container_source_backpack_item = null
	show_container(container)

func show_backpack_item(item: InventoryItem):
	if not item or not item.item_data.is_backpack:
		return

	# 在 hide_container 前保存所有需要的数据，防止 item 被释放
	var backpack_data_dict = {
		"items_data": item.backpack_items_data.duplicate(),
		"items_positions": item.backpack_items_positions.duplicate(),
		"items_searched": item.backpack_items_searched.duplicate(),
		"items_stack_counts": item.backpack_items_stack_counts.duplicate()
	}
	var backpack_item_name = item.item_data.item_name
	var backpack_grid_columns = item.backpack_grid_columns
	var backpack_grid_rows = item.backpack_grid_rows
	var backpack_grid_size = item.backpack_grid_size
	var source_item_data = item.item_data   # 保存 ItemData 引用
	var source_inventory_item = item        # 保存 InventoryItem 引用（可能仍然存在）

	# 关闭当前容器（会保存并销毁当前容器中的物品，包括这个背包物品）
	if _active_container:
		hide_container()

	# 创建临时容器，使用保存的数据
	var container = ContainerLoot.new()
	container.container_name = backpack_item_name
	container.grid_columns = backpack_grid_columns
	container.grid_rows = backpack_grid_rows
	container.grid_size = backpack_grid_size
	container.possible_items = []   # 避免生成随机物品
	container.items_data = backpack_data_dict["items_data"]
	container.items_positions = backpack_data_dict["items_positions"]
	container.items_searched = backpack_data_dict["items_searched"]
	container.items_stack_counts = backpack_data_dict["items_stack_counts"]

	# 设置代理标志，以便 hide_container 时写回源对象
	_active_container_is_backpack_proxy = true
	_active_container_source_loot = null
	_active_container_source_backpack_item = null
	_active_container_source_item_data = source_item_data
	_active_container_source_inventory_item = source_inventory_item   # ★ 保存源 InventoryItem

	show_container(container)

# ---------- 槽位输入处理 ----------
func _on_helmet_slot_gui_input(event: InputEvent):
	# 如果有任何物品正在拖拽（包括武器、头盔、背包等），直接忽略，防止误卸下
	if InventoryItem.dragged_item != null:
		return
	if not player: return
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_RIGHT and event.pressed:
		if player.equipped_helmet_item:
			player.unequip_helmet()
		return
	if not player.equipped_helmet_item: return
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed:
			_helmet_slot_dragging = false
			_helmet_slot_drag_start = get_global_mouse_position()
		else:
			_helmet_slot_dragging = false
	if event is InputEventMouseMotion:
		if Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT) and player.equipped_helmet_item:
			var distance = get_global_mouse_position().distance_to(_helmet_slot_drag_start)
			if distance > _helmet_slot_drag_threshold and not _helmet_slot_dragging:
				_helmet_slot_dragging = true
				player.start_drag_helmet()

func _on_backpack_slot_gui_input(event: InputEvent):
	# 同上：有物品拖拽时直接返回
	if InventoryItem.dragged_item != null:
		return
	if not player: return
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_RIGHT and event.pressed:
		if player.equipped_backpack_item:
			player.unequip_backpack()
		return
	if not player.equipped_backpack_item: return
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed:
			_backpack_slot_dragging = false
			_backpack_slot_drag_start = get_global_mouse_position()
		else:
			_backpack_slot_dragging = false
	if event is InputEventMouseMotion:
		if Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT) and player.equipped_backpack_item:
			var distance = get_global_mouse_position().distance_to(_backpack_slot_drag_start)
			if distance > _backpack_slot_drag_threshold and not _backpack_slot_dragging:
				_backpack_slot_dragging = true
				player.start_drag_backpack()

func _on_main_weapon_slot_gui_input(event: InputEvent):
	if player: player._on_weapon_slot_gui_input(event, "primary")

func _on_secondary_weapon_slot_gui_input(event: InputEvent):
	if player: player._on_weapon_slot_gui_input(event, "secondary")

# ---------- 其他原有函数保持不变 ----------
func _clear_context_menus():
	var tree = get_tree()
	if not tree: return
	var canvas = tree.root.get_node_or_null("ContextMenuLayer")
	if canvas:
		for child in canvas.get_children(): child.queue_free()

func show_equip_progress(show: bool):
	if show:
		if not _equip_progress_arc:
			_equip_progress_arc = Control.new()
			_equip_progress_arc.size = 副武器装备槽.size
			_equip_progress_arc.mouse_filter = Control.MOUSE_FILTER_IGNORE
			副武器装备槽.add_child(_equip_progress_arc)
			_equip_progress_arc.draw.connect(_draw_equip_progress)
		_equip_progress_arc.visible = true
		_equip_progress_value = 0.0
		_equip_progress_arc.queue_redraw()
	else:
		if _equip_progress_arc:
			_equip_progress_arc.queue_free()
			_equip_progress_arc = null

func set_equip_progress(value: float):
	_equip_progress_value = value
	if _equip_progress_arc: _equip_progress_arc.queue_redraw()

func _draw_equip_progress():
	var progress = _equip_progress_value
	var center = _equip_progress_arc.size / 2
	var radius = min(_equip_progress_arc.size.x, _equip_progress_arc.size.y) * 0.35
	_equip_progress_arc.draw_arc(center, radius, -PI/2, -PI/2 + 2*PI*progress, 32, Color.BLUE, 5)
	_equip_progress_arc.draw_arc(center, radius, -PI/2 + 2*PI*progress, -PI/2 + 2*PI, 32, Color.DIM_GRAY, 5)
func _save_grid_to_backpack(backpack_item: InventoryItem):
	var item_datas = []
	var positions = []
	var searched = []
	var stacks = []
	for item in 背包网格.items:
		if is_instance_valid(item) and item is InventoryItem:
			item_datas.append(item.item_data)
			positions.append(item.grid_pos)
			searched.append(item._was_searched)
			stacks.append(item.stack_count)
	backpack_item.backpack_items_data = item_datas
	backpack_item.backpack_items_positions = positions
	backpack_item.backpack_items_searched = searched
	backpack_item.backpack_items_stack_counts = stacks

func _load_backpack_to_grid(backpack_item: InventoryItem):
	var item_scene = preload("res://场景/所有继承场景的父场景/item.tscn")
	for i in range(backpack_item.backpack_items_data.size()):
		var data = backpack_item.backpack_items_data[i]
		var pos = backpack_item.backpack_items_positions[i]
		var searched = backpack_item.backpack_items_searched[i]
		var stack = backpack_item.backpack_items_stack_counts[i]
		var item = item_scene.instantiate()
		item.item_data = data
		item.stack_count = stack
		item._was_searched = searched
		item.update_search_visuals()
		if pos.x >= 0 and pos.y >= 0 and 背包网格._can_place_at(item, pos):
			背包网格._place_item(item, pos)
		else:
			var placed = false
			for x in range(背包网格.columns):
				for y in range(背包网格.rows):
					var test_pos = Vector2i(x, y)
					if 背包网格._can_place_at(item, test_pos):
						背包网格._place_item(item, test_pos)
						placed = true
						break
				if placed:
					break
			if not placed:
				item.queue_free()
func _on_backpack_grid_changed():
	if _loaded_backpack_item != null:
		_save_grid_to_backpack(_loaded_backpack_item)
func prepare_backpack_unequip():
	if _loaded_backpack_item != null:
		_save_grid_to_backpack(_loaded_backpack_item)
		for item in 背包网格.items.duplicate():
			背包网格.remove_item(item)
			item.queue_free()
		_loaded_backpack_item = null
		背包网格.visible = false
