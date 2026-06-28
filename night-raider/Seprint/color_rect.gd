@tool
extends ColorRect
class_name bag

# 重量变化信号
signal weight_changed(total_weight: int)

# ===== 网格基础参数 =====
@export var grid_rows: int = 10:
	set(value):
		grid_rows = value
		update_container_size()
		queue_redraw()
@export var grid_cols: int = 10:
	set(value):
		grid_cols = value
		update_container_size()
		queue_redraw()
@export var cell_pixel_size: float = 64.0:
	set(value):
		cell_pixel_size = value
		update_container_size()
		queue_redraw()

# ===== 内边距 =====
@export var padding: float = 4.0:
	set(value):
		padding = value
		update_container_size()
		queue_redraw()

@export var line_color: Color = Color.WHITE
@export var line_width: float = 1.0
@export var hover_color: Color = Color.YELLOW
@export var drag_color: Color = Color(0.3, 0.8, 0.3, 0.3)
@export var valid_placement_color: Color = Color(0.0, 1.0, 0.0, 0.4)
@export var invalid_placement_color: Color = Color(1.0, 0.0, 0.0, 0.4)

# ===== 品质颜色 =====
@export var white_color: Color = Color(0.8, 0.8, 0.8, 0.25)
@export var green_color: Color = Color(0.2, 0.8, 0.2, 0.25)
@export var blue_color: Color = Color(0.2, 0.4, 0.9, 0.25)
@export var purple_color: Color = Color(0.6, 0.2, 0.8, 0.25)
@export var gold_color: Color = Color(1.0, 0.8, 0.1, 0.25)
@export var border_width: float = 2.0

@export var preset_item_list: Array[PackedScene] = []
@export var container_name: String = "背包"

# 运行时物品数据
var bag_items: Array = []

# 缓存变量
var cell_size: Vector2
var grid_total_size: Vector2
var grid_offset: Vector2
var hovered_cell: Vector2i = Vector2i(-1, -1)
var resource_signal_cache: Dictionary = {}

# 拖拽相关变量
var is_dragging_self: bool = false
var dragging_item_id: int = -1
var dragging_item_data: ItemResource = null
var dragging_item_rotated: bool = false
var drag_start_cell: Vector2i = Vector2i(-1, -1)
var drag_preview: Control = null
var placement_valid: bool = false
var item_id_counter: int = 0

# 全局拖拽状态
var is_global_dragging: bool = false
var global_drag_item: ItemResource = null
var global_drag_source: ColorRect = null

# ===== 获取 DragManager =====
func get_drag_manager():
	if Engine.has_singleton("DragManager"):
		return Engine.get_singleton("DragManager")
	
	var root = get_tree().root
	if root:
		var dm = root.get_node_or_null("DragManager")
		if dm:
			return dm
	
	for child in get_tree().root.get_children():
		if child is DragManager:
			return child
	
	return null

# ===== 自适应容器大小 =====
func update_container_size() -> void:
	var total_width = grid_cols * cell_pixel_size + padding * 2
	var total_height = grid_rows * cell_pixel_size + padding * 2
	custom_minimum_size = Vector2(total_width, total_height)
	size = Vector2(total_width, total_height)

# ===== 生命周期 =====
func _ready() -> void:
	mouse_filter = MOUSE_FILTER_PASS
	update_container_size()
	update_grid_size()
	refresh_auto_layout_items()
	bind_resource_signals()
	queue_redraw()
	
	add_to_group("inventory_containers")
	
	if not Engine.is_editor_hint():
		call_deferred("connect_drag_manager")

func _exit_tree() -> void:
	# 节点销毁时强制清理置顶预览，杜绝残影残留
	if drag_preview and is_instance_valid(drag_preview):
		drag_preview.queue_free()
		drag_preview = null

func connect_drag_manager() -> void:
	var drag_manager = get_drag_manager()
	if drag_manager:
		if drag_manager.drag_started.is_connected(_on_drag_started):
			drag_manager.drag_started.disconnect(_on_drag_started)
		if drag_manager.drag_ended.is_connected(_on_drag_ended):
			drag_manager.drag_ended.disconnect(_on_drag_ended)
		if drag_manager.drag_cancelled.is_connected(_on_drag_cancelled):
			drag_manager.drag_cancelled.disconnect(_on_drag_cancelled)
		
		drag_manager.drag_started.connect(_on_drag_started)
		drag_manager.drag_ended.connect(_on_drag_ended)
		drag_manager.drag_cancelled.connect(_on_drag_cancelled)
	else:
		get_tree().create_timer(0.1).timeout.connect(connect_drag_manager)

func _validate_property(changed: Dictionary) -> void:
	refresh_auto_layout_items()
	bind_resource_signals()
	update_grid_size()
	queue_redraw()

# ===== 物品资源管理 =====
func duplicate_item_resource(original: ItemResource) -> ItemResource:
	if original == null:
		return null
	
	var new_item = ItemResource.new()
	# 基础属性
	new_item.name = original.name
	new_item.weight = original.weight
	new_item.height = original.height
	new_item.texture = original.texture
	new_item.textureY = original.textureY
	new_item.物品等级 = original.物品等级
	new_item.物品重量 = original.物品重量
	
	# ========== 核心修复：补全物品类型属性 ==========
	new_item.is_枪 = original.is_枪
	new_item.is_药品 = original.is_药品
	new_item.is_刀具 = original.is_刀具
	new_item.is_其他 = original.is_其他
	
	# ========== 同步复制扩展属性，避免后续丢失 ==========
	# 枪械属性
	new_item.gun_伤害 = original.gun_伤害
	new_item.gun_弹匣容量 = original.gun_弹匣容量
	new_item.gun_射速 = original.gun_射速
	new_item.gun_有效射程 = original.gun_有效射程
	new_item.gun_弹药类型 = original.gun_弹药类型
	
	# 药品属性
	new_item.med_回复量 = original.med_回复量
	new_item.med_使用时间 = original.med_使用时间
	new_item.med_效果类型 = original.med_效果类型
	new_item.med_持续时间 = original.med_持续时间
	
	# 刀具属性
	new_item.knife_伤害 = original.knife_伤害
	new_item.knife_攻击速度 = original.knife_攻击速度
	new_item.knife_攻击范围 = original.knife_攻击范围
	new_item.knife_耐久度 = original.knife_耐久度
	
	return new_item
func refresh_auto_layout_items() -> void:
	bag_items.clear()
	item_id_counter = 0
	
	for scene in preset_item_list:
		if scene == null:
			continue
		
		var instance = scene.instantiate()
		var item_data: ItemResource = null
		
		if instance is TextureRect and instance.get("itemResource") != null:
			item_data = instance.itemResource
		
		if item_data == null and instance.has_meta("itemResource"):
			item_data = instance.get_meta("itemResource")
		
		instance.queue_free()
		
		if item_data == null or item_data.texture == null:
			continue
		
		var item_copy = duplicate_item_resource(item_data)
		
		var free_slot = find_first_empty_slot(item_copy, false)
		if free_slot == Vector2i(-1, -1):
			var rotated_item = create_rotated_item(item_copy)
			free_slot = find_first_empty_slot(rotated_item, true)
			if free_slot == Vector2i(-1, -1):
				continue
			else:
				item_copy = rotated_item
		
		add_item(item_copy, free_slot, false)
	
	_update_total_weight()

func create_rotated_item(original: ItemResource) -> ItemResource:
	var rotated = duplicate_item_resource(original)
	rotated.weight = original.height
	rotated.height = original.weight
	
	if original.textureY != null:
		rotated.texture = original.textureY
		rotated.textureY = original.texture
	
	return rotated

func rotate_item_data(item: ItemResource) -> void:
	if item == null:
		return
	
	var temp_w = item.weight
	item.weight = item.height
	item.height = temp_w
	
	if item.textureY != null:
		var temp_tex = item.texture
		item.texture = item.textureY
		item.textureY = temp_tex

# 统一物品添加函数
func add_item(item_res: ItemResource, pos: Vector2i, rotated: bool) -> int:
	var new_id = item_id_counter
	bag_items.append({
		"id": new_id,
		"pos": pos,
		"res": item_res,
		"rotated": rotated
	})
	item_id_counter += 1
	bind_resource_signals()
	_update_total_weight()
	return new_id

# ===== 重量统计 =====
func _update_total_weight() -> void:
	var total: int = 0
	for data in bag_items:
		var res = data.get("res")
		if res != null and "物品重量" in res:
			total += res.物品重量
	weight_changed.emit(total)

# ===== 网格功能 =====
func find_first_empty_slot(item: ItemResource, rotated: bool = false) -> Vector2i:
	for row in range(grid_rows):
		for col in range(grid_cols):
			var start = Vector2i(col, row)
			if check_out_of_bounds(start, item):
				continue
			var all_empty = true
			var occupy = get_occupy_cells(start, item)
			for cell in occupy:
				if is_cell_occupied(cell, rotated):
					all_empty = false
					break
			if all_empty:
				return start
	return Vector2i(-1, -1)

func bind_resource_signals() -> void:
	for res in resource_signal_cache.keys():
		if res != null and res.is_connected("changed", Callable(self, "queue_redraw")):
			res.changed.disconnect(queue_redraw)
	
	resource_signal_cache.clear()
	
	for data in bag_items:
		var res = data["res"]
		if res != null and not res.is_connected("changed", Callable(self, "queue_redraw")):
			res.changed.connect(queue_redraw)
			resource_signal_cache[res] = true

func update_grid_size() -> void:
	cell_size = Vector2(cell_pixel_size, cell_pixel_size)
	grid_total_size = Vector2(grid_cols, grid_rows) * cell_pixel_size
	grid_offset = Vector2(padding, padding)

# ===== 绘制 =====
func _draw() -> void:
	draw_grid_lines()
	draw_hover_cells()
	draw_all_bag_items()
	
	# 自身拖拽预览
	if is_dragging_self and hovered_cell != Vector2i(-1, -1) and dragging_item_data != null:
		draw_placement_preview(dragging_item_data)
	
	# 全局拖拽目标容器预览
	if not is_dragging_self and is_global_dragging:
		if hovered_cell != Vector2i(-1, -1) and global_drag_item != null:
			draw_placement_preview(global_drag_item)

func draw_placement_preview(item_data: ItemResource) -> void:
	if item_data == null:
		return
	
	var preview_cell = hovered_cell
	placement_valid = can_place_item(item_data, preview_cell)
	
	var preview_pixel_start = grid_offset + Vector2(preview_cell) * cell_pixel_size
	var preview_w = item_data.weight * cell_pixel_size
	var preview_h = item_data.height * cell_pixel_size
	
	if preview_cell.x < 0 || preview_cell.y < 0 || preview_cell.x + item_data.weight > grid_cols || preview_cell.y + item_data.height > grid_rows:
		var clip_rect = Rect2(
			max(preview_pixel_start.x, grid_offset.x),
			max(preview_pixel_start.y, grid_offset.y),
			min(preview_pixel_start.x + preview_w, grid_offset.x + grid_total_size.x) - max(preview_pixel_start.x, grid_offset.x),
			min(preview_pixel_start.y + preview_h, grid_offset.y + grid_total_size.y) - max(preview_pixel_start.y, grid_offset.y)
		)
		if clip_rect.size.x > 0 and clip_rect.size.y > 0:
			var color = valid_placement_color if placement_valid else invalid_placement_color
			draw_rect(clip_rect, color, true)
	else:
		var preview_rect = Rect2(preview_pixel_start, Vector2(preview_w, preview_h))
		var color = valid_placement_color if placement_valid else invalid_placement_color
		draw_rect(preview_rect, color, true)
	
	draw_occupancy_grid(item_data, preview_cell)

func draw_occupancy_grid(item_data: ItemResource, top_left: Vector2i) -> void:
	var occupy_cells = get_occupy_cells(top_left, item_data)
	for cell in occupy_cells:
		if cell.x >= 0 and cell.x < grid_cols and cell.y >= 0 and cell.y < grid_rows:
			var cell_pixel = grid_offset + Vector2(cell) * cell_pixel_size
			draw_rect(Rect2(cell_pixel, cell_size), Color.WHITE, false, 1.0)

func draw_all_bag_items() -> void:
	if bag_items.is_empty():
		return
	for data in bag_items:
		if is_dragging_self and data["id"] == dragging_item_id:
			continue
		draw_single_item(data["pos"], data["res"])

func draw_single_item(top_left: Vector2i, item: ItemResource) -> void:
	if item == null or item.texture == null:
		return
	
	var pixel_start = grid_offset + Vector2(top_left) * cell_pixel_size
	var item_w = item.weight * cell_pixel_size
	var item_h = item.height * cell_pixel_size
	var item_rect = Rect2(pixel_start, Vector2(item_w, item_h))
	
	var rarity_color = get_rarity_color(item)
	if rarity_color.a > 0:
		draw_rect(item_rect, rarity_color, true)
	
	draw_rect(item_rect, get_rarity_border_color(item), false, 2.0)
	
	var tex_size = item.texture.get_size()
	if tex_size.x > 0 and tex_size.y > 0:
		var fit_scale = min(item_w / tex_size.x, item_h / tex_size.y)
		var tex_draw_size = tex_size * fit_scale
		var draw_pos = pixel_start + Vector2((item_w - tex_draw_size.x) / 2.0, (item_h - tex_draw_size.y) / 2.0)
		draw_texture_rect(item.texture, Rect2(draw_pos, tex_draw_size), false)

func get_rarity_color(item: ItemResource) -> Color:
	if item == null:
		return Color.TRANSPARENT
	var level = item.物品等级 if "物品等级" in item else -1
	match level:
		0: return white_color
		1: return green_color
		2: return blue_color
		3: return purple_color
		4: return gold_color
		_: return Color.TRANSPARENT

func get_rarity_border_color(item: ItemResource) -> Color:
	if item == null:
		return Color.WHITE
	var level = item.物品等级 if "物品等级" in item else -1
	match level:
		0: return Color(0.7, 0.7, 0.7)
		1: return Color(0.2, 0.9, 0.2)
		2: return Color(0.2, 0.5, 1.0)
		3: return Color(0.7, 0.2, 0.9)
		4: return Color(1.0, 0.85, 0.1)
		_: return Color.WHITE

func draw_hover_cells() -> void:
	pass

func draw_grid_lines() -> void:
	for i in range(grid_cols + 1):
		var x = grid_offset.x + i * cell_pixel_size
		draw_line(Vector2(x, grid_offset.y), Vector2(x, grid_offset.y + grid_total_size.y), line_color, line_width)
	for i in range(grid_rows + 1):
		var y = grid_offset.y + i * cell_pixel_size
		draw_line(Vector2(grid_offset.x, y), Vector2(grid_offset.x + grid_total_size.x, y), line_color, line_width)

# ===== 输入处理 + 全局状态同步 =====
func _input(event: InputEvent) -> void:
	if event is InputEventMouseMotion:
		_sync_global_drag_state()
		update_hover()
		
		if is_dragging_self or is_global_dragging:
			queue_redraw()
		
		if is_dragging_self and drag_preview:
			drag_preview.global_position = get_global_mouse_position() - drag_preview.size / 2
	
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_LEFT:
			if event.pressed:
				start_drag()
			else:
				end_drag()
	
	if event is InputEventKey and event.pressed:
		if event.keycode == KEY_R:
			if is_dragging_self:
				rotate_dragging_item()
			elif hovered_cell != Vector2i(-1, -1):
				rotate_item_at_cell(hovered_cell)

# 主动同步全局拖拽状态（信号+查询双保险）
func _sync_global_drag_state() -> void:
	var dm = get_drag_manager()
	if dm == null:
		is_global_dragging = false
		global_drag_item = null
		global_drag_source = null
		return
	
	if dm.is_dragging:
		is_global_dragging = true
		global_drag_item = dm.dragging_item_data
		global_drag_source = dm.drag_start_container
	else:
		is_global_dragging = false
		global_drag_item = null
		global_drag_source = null

# ===== 拖拽功能 =====
func start_drag() -> void:
	if hovered_cell == Vector2i(-1, -1):
		return
	
	var drag_manager = get_drag_manager()
	if drag_manager and drag_manager.is_dragging:
		return
	
	var clicked_item = get_item_at_cell(hovered_cell)
	if clicked_item == null or clicked_item.is_empty():
		return
	
	if drag_manager == null:
		return
	
	dragging_item_id = clicked_item["id"]
	dragging_item_data = clicked_item["res"]
	dragging_item_rotated = clicked_item.get("rotated", false)
	drag_start_cell = clicked_item["pos"]
	is_dragging_self = true
	
	var index_to_remove = -1
	for i in range(bag_items.size()):
		if bag_items[i]["id"] == dragging_item_id:
			index_to_remove = i
			break
	
	if index_to_remove != -1:
		bag_items.remove_at(index_to_remove)
		_update_total_weight()
	else:
		is_dragging_self = false
		return
	
	drag_manager.start_drag(dragging_item_data, dragging_item_id, drag_start_cell, self, dragging_item_rotated)
	create_drag_preview(dragging_item_data)
	queue_redraw()

func end_drag() -> void:
	if not is_dragging_self:
		return
	
	# 销毁拖拽预览
	if drag_preview and is_instance_valid(drag_preview):
		drag_preview.queue_free()
		drag_preview = null
	
	if dragging_item_data == null:
		cancel_drag()
		return

	print("[背包] 松开鼠标，当前拖拽物品：", dragging_item_data.name)

	# ========== 优先判定：装备槽位 ==========
	var target_slot = get_slot_at_mouse()
	if target_slot != null:
		var place_ok = target_slot.equip_item(dragging_item_data)
		if place_ok:
			# 放置成功：物品从背包移除，结束拖拽
			var drag_manager = get_drag_manager()
			if drag_manager and drag_manager.is_dragging:
				drag_manager.cancel_drag()
			clear_drag_state()
			queue_redraw()
			print("[背包] ✅ 物品已放入槽位")
			return
		else:
			# 放置失败：弹回原位
			add_item(dragging_item_data, drag_start_cell, dragging_item_rotated)
			var drag_manager = get_drag_manager()
			if drag_manager and drag_manager.is_dragging:
				drag_manager.cancel_drag()
			clear_drag_state()
			queue_redraw()
			print("[背包] ❌ 槽位放置失败，物品弹回")
			return
	# ======================================

	var drag_manager = get_drag_manager()
	if drag_manager == null:
		cancel_drag()
		return
	
	var target_cell = hovered_cell
	
	# 放回当前容器
	if target_cell != Vector2i(-1, -1) and can_place_item(dragging_item_data, target_cell):
		add_item(dragging_item_data, target_cell, dragging_item_rotated)
		drag_manager.end_drag(self, target_cell)
		clear_drag_state()
		queue_redraw()
		return
	
	# 放到其他背包容器
	var target_container = get_container_at_mouse()
	if target_container and target_container != self:
		if target_container.can_place_item(dragging_item_data, target_container.hovered_cell):
			target_container.add_item(dragging_item_data, target_container.hovered_cell, dragging_item_rotated)
			drag_manager.end_drag(target_container, target_container.hovered_cell)
			clear_drag_state()
			queue_redraw()
			target_container.queue_redraw()
			return
	
	# 放回原位
	cancel_drag()

func cancel_drag() -> void:
	if not is_dragging_self:
		return
	
	var drag_manager = get_drag_manager()
	if drag_manager and drag_manager.is_dragging:
		drag_manager.cancel_drag()
	
	add_item(dragging_item_data, drag_start_cell, dragging_item_rotated)
	clear_drag_state()
	queue_redraw()

func get_container_at_mouse() -> ColorRect:
	var mouse_pos = get_global_mouse_position()
	for node in get_tree().get_nodes_in_group("inventory_containers"):
		if node is ColorRect and node != self and node.visible:
			if Rect2(node.global_position, node.size).has_point(mouse_pos):
				return node
	return null

# 拖拽预览：自定义绘制+全局置顶，放置后自动销毁
func create_drag_preview(item: ItemResource) -> void:
	if item == null or item.texture == null:
		return
	
	var preview_w = item.weight * cell_pixel_size
	var preview_h = item.height * cell_pixel_size
	var preview_size = Vector2(preview_w, preview_h)
	
	drag_preview = Control.new()
	drag_preview.mouse_filter = MOUSE_FILTER_IGNORE
	drag_preview.z_index = 999
	drag_preview.top_level = true
	drag_preview.custom_minimum_size = preview_size
	drag_preview.size = preview_size
	drag_preview.modulate = Color(1, 1, 1, 0.85)
	
	# 和背包内完全一致的绘制逻辑，视觉无缝衔接
	drag_preview.draw.connect(func():
		var item_rect = Rect2(Vector2.ZERO, preview_size)
		# 品质背景
		var rarity_color = get_rarity_color(item)
		if rarity_color.a > 0:
			drag_preview.draw_rect(item_rect, rarity_color, true)
		# 品质边框
		drag_preview.draw_rect(item_rect, get_rarity_border_color(item), false, 2.0)
		# 等比缩放纹理
		var tex_size = item.texture.get_size()
		if tex_size.x > 0 and tex_size.y > 0:
			var fit_scale = min(preview_w / tex_size.x, preview_h / tex_size.y)
			var tex_draw_size = tex_size * fit_scale
			var draw_pos = Vector2(
				(preview_w - tex_draw_size.x) / 2.0,
				(preview_h - tex_draw_size.y) / 2.0
			)
			drag_preview.draw_texture_rect(item.texture, Rect2(draw_pos, tex_draw_size), false)
	)
	
	get_tree().root.add_child(drag_preview)
	drag_preview.global_position = get_global_mouse_position() - preview_size / 2
	drag_preview.queue_redraw()

# ===== 悬停检测 =====
func update_hover() -> void:
	var mouse = get_local_mouse_position()
	var grid_mouse = mouse - grid_offset
	
	if grid_mouse.x < 0 || grid_mouse.y < 0 || grid_mouse.x > grid_total_size.x || grid_mouse.y > grid_total_size.y:
		if hovered_cell != Vector2i(-1, -1):
			hovered_cell = Vector2i(-1, -1)
		return
	
	var col = int(floor(grid_mouse.x / cell_pixel_size))
	var row = int(floor(grid_mouse.y / cell_pixel_size))
	
	if col < 0 || col >= grid_cols || row < 0 || row >= grid_rows:
		if hovered_cell != Vector2i(-1, -1):
			hovered_cell = Vector2i(-1, -1)
		return
	
	var new_hover = Vector2i(col, row)
	if hovered_cell != new_hover:
		hovered_cell = new_hover

# ===== 全局拖拽信号 =====
func _on_drag_started(item_data: ItemResource, source_container: ColorRect) -> void:
	is_global_dragging = true
	global_drag_item = item_data
	global_drag_source = source_container
	queue_redraw()

func _on_drag_ended(item_data: ItemResource, target_container: ColorRect, target_cell: Vector2i) -> void:
	is_global_dragging = false
	global_drag_item = null
	global_drag_source = null
	queue_redraw()

func _on_drag_cancelled(item_data: ItemResource) -> void:
	is_global_dragging = false
	global_drag_item = null
	global_drag_source = null
	queue_redraw()

# 统一状态清理：所有结束路径都销毁置顶预览
func clear_drag_state() -> void:
	if drag_preview and is_instance_valid(drag_preview):
		drag_preview.queue_free()
		drag_preview = null

	is_dragging_self = false
	dragging_item_id = -1
	dragging_item_data = null
	dragging_item_rotated = false
	drag_start_cell = Vector2i(-1, -1)
	placement_valid = false

# ===== 旋转功能 =====
func rotate_dragging_item() -> void:
	if dragging_item_data == null:
		return
	rotate_item_data(dragging_item_data)
	dragging_item_rotated = !dragging_item_rotated
	
	if drag_preview:
		drag_preview.queue_free()
		drag_preview = null
		create_drag_preview(dragging_item_data)
	queue_redraw()

func rotate_item_at_cell(cell: Vector2i) -> void:
	var item_data = get_item_at_cell(cell)
	if item_data == null or item_data.is_empty():
		return
	
	var item = item_data["res"]
	var current_pos = item_data["pos"]
	var item_id = item_data["id"]
	
	var old_weight = item.weight
	var old_height = item.height
	var old_texture = item.texture
	var old_textureY = item.textureY
	
	rotate_item_data(item)
	
	if can_place_item_at_position(item, current_pos, item_id):
		item_data["rotated"] = !item_data.get("rotated", false)
		queue_redraw()
	else:
		item.weight = old_weight
		item.height = old_height
		item.texture = old_texture
		item.textureY = old_textureY

# ===== 核心工具函数 =====
func get_item_at_cell(cell: Vector2i) -> Dictionary:
	for data in bag_items:
		var pos = data["pos"]
		var res = data["res"]
		var occupy = get_occupy_cells(pos, res)
		if cell in occupy:
			return data
	return {}

func can_place_item(item: ItemResource, top_left: Vector2i) -> bool:
	if check_out_of_bounds(top_left, item):
		return false
	
	var occupy = get_occupy_cells(top_left, item)
	for cell in occupy:
		if is_cell_occupied_excluding_dragging(cell):
			return false
	return true

func can_place_item_at_position(item: ItemResource, top_left: Vector2i, exclude_id: int) -> bool:
	if check_out_of_bounds(top_left, item):
		return false
	
	var occupy = get_occupy_cells(top_left, item)
	for cell in occupy:
		for data in bag_items:
			if data["id"] == exclude_id:
				continue
			var pos = data["pos"]
			var res = data["res"]
			var occupy_existing = get_occupy_cells(pos, res)
			if cell in occupy_existing:
				return false
	return true

func is_cell_occupied_excluding_dragging(target: Vector2i) -> bool:
	for data in bag_items:
		var pos = data["pos"]
		var res = data["res"]
		
		if is_dragging_self and data.get("id", -1) == dragging_item_id:
			continue
		
		var occupy = get_occupy_cells(pos, res)
		if target in occupy:
			return true
	return false

func is_cell_occupied(target: Vector2i, rotated: bool = false) -> bool:
	for data in bag_items:
		var pos = data["pos"]
		var res = data["res"]
		var occupy = get_occupy_cells(pos, res)
		if target in occupy:
			return true
	return false

func check_out_of_bounds(top_left: Vector2i, item: ItemResource) -> bool:
	var max_col = top_left.x + item.weight - 1
	var max_row = top_left.y + item.height - 1
	return max_col >= grid_cols or max_row >= grid_rows or top_left.x < 0 or top_left.y < 0

func get_occupy_cells(top_left: Vector2i, item: ItemResource) -> Array:
	var cells = []
	for r in range(item.height):
		for c in range(item.weight):
			cells.append(Vector2i(top_left.x + c, top_left.y + r))
	return cells

func clear_all_items() -> void:
	bag_items.clear()
	item_id_counter = 0
	bind_resource_signals()
	_update_total_weight()
	queue_redraw()

func _on_resized() -> void:
	update_grid_size()
	queue_redraw()
# 获取鼠标位置下的装备槽位（全局矩形精准检测）
func get_slot_at_mouse() -> EquipSlot:
	var mouse_pos = get_global_mouse_position()
	var slots = get_tree().get_nodes_in_group("item_equip_slots")
	print("[背包] 检测槽位，组内节点总数：", slots.size())
	
	for node in slots:
		if node is EquipSlot and node.visible:
			var rect = node.get_global_rect()
			if rect.has_point(mouse_pos):
				print("[背包] ✅ 命中槽位：", node.name, " 矩形：", rect)
				return node
	print("[背包] ❌ 未命中任何槽位")
	return null
