extends TextureRect
class_name EquipSlot

signal item_equipped(item_data: ItemResource)
signal item_unequipped(item_data: ItemResource)

# 基础配置
@export var default_texture: Texture = null
@export var border_width: float = 2.0
@export var cell_size: float = 64.0

# 类型过滤
@export var enable_type_filter: bool = false
enum ItemType {
	枪械,
	药品,
	刀具,
	其他
}
@export var accept_type: ItemType = ItemType.其他

# 运行数据
var current_item: ItemResource = null
var _is_global_dragging: bool = false
var _drag_item: ItemResource = null

# 自身拖拽状态
var _is_dragging_from_self: bool = false
var _drag_preview: Control = null

func _ready() -> void:
	mouse_filter = MOUSE_FILTER_PASS
	texture_filter = TEXTURE_FILTER_NEAREST
	if not is_in_group("item_equip_slots"):
		add_to_group("item_equip_slots")
	call_deferred("_connect_drag_manager")
	_refresh_display()

func _exit_tree() -> void:
	_clear_drag_preview()
	
	var dm = _get_drag_manager()
	if dm:
		if dm.drag_started.is_connected(_on_drag_started):
			dm.drag_started.disconnect(_on_drag_started)
		if dm.drag_ended.is_connected(_on_drag_ended):
			dm.drag_ended.disconnect(_on_drag_ended)
		if dm.drag_cancelled.is_connected(_on_drag_cancelled):
			dm.drag_cancelled.disconnect(_on_drag_cancelled)

# ========== GUI输入处理 ==========
func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseMotion:
		if _is_dragging_from_self && _drag_preview:
			_drag_preview.global_position = get_global_mouse_position() - _drag_preview.size / 2.0
			accept_event()
		return

	if event is InputEventMouseButton && event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed:
			var dm = _get_drag_manager()
			if dm != null && dm.is_dragging && !_is_dragging_from_self:
				return
			if current_item == null:
				return
			if !get_global_rect().grow(8.0).has_point(get_global_mouse_position()):
				return
			
			var item = unequip_item()
			_is_dragging_from_self = true
			if dm != null:
				dm.start_drag(item, -1, Vector2i(-1, -1), self, false)
			_create_drag_preview(item)
			accept_event()
			return

	if event is InputEventMouseButton && event.button_index == MOUSE_BUTTON_LEFT:
		if !event.pressed && _is_dragging_from_self:
			_handle_drag_end()
			accept_event()
			return

# ========== 核心修复：跨容器放置逻辑 ==========
func _handle_drag_end() -> void:
	var dm = _get_drag_manager()
	var item = dm.dragging_item_data if dm else null
	
	_clear_drag_preview()

	if item == null:
		_cancel_drag_restore()
		return

	# 优先级1：放到其他装备槽位
	var target_slot = _get_slot_at_mouse()
	if target_slot != null && target_slot != self:
		if target_slot.equip_item(item):
			if dm:
				dm.end_drag(target_slot, Vector2i(-1, -1))
			_is_dragging_from_self = false
			return

	# 优先级2：放到任意背包容器（鼠标指向的格子）
	var target_bag = _get_bag_at_mouse()
	if target_bag != null:
		# 实时计算鼠标在目标背包内的格子坐标
		var mouse_local = target_bag.get_local_mouse_position()
		var grid_mouse = mouse_local - target_bag.grid_offset
		var col = int(floor(grid_mouse.x / target_bag.cell_pixel_size))
		var row = int(floor(grid_mouse.y / target_bag.cell_pixel_size))
		var target_cell = Vector2i(col, row)
		
		# 精准放置到鼠标指向的格子
		if col >= 0 && col < target_bag.grid_cols && row >= 0 && row < target_bag.grid_rows:
			if target_bag.can_place_item(item, target_cell):
				target_bag.add_item(item, target_cell, false)
				if dm:
					dm.end_drag(target_bag, target_cell)
				_is_dragging_from_self = false
				return
		
		# 兜底：目标格子不可用则自动找第一个空位
		if target_bag.try_place_item_auto(item):
			if dm:
				dm.end_drag(target_bag, Vector2i(-1, -1))
			_is_dragging_from_self = false
			return

	# 都不满足：物品放回原槽位
	_cancel_drag_restore()

func _cancel_drag_restore() -> void:
	var dm = _get_drag_manager()
	var item = dm.dragging_item_data if dm else null
	
	if item != null:
		equip_item(item)
		if dm:
			dm.cancel_drag()
	
	_clear_drag_preview()
	_is_dragging_from_self = false

# ========== 拖拽预览 ==========
func _create_drag_preview(item: ItemResource) -> void:
	if item == null || item.texture == null:
		return
	
	var preview_w = item.weight * cell_size
	var preview_h = item.height * cell_size
	var preview_size = Vector2(preview_w, preview_h)
	
	_drag_preview = Control.new()
	_drag_preview.mouse_filter = MOUSE_FILTER_IGNORE
	_drag_preview.z_index = 999
	_drag_preview.top_level = true
	_drag_preview.custom_minimum_size = preview_size
	_drag_preview.size = preview_size
	_drag_preview.modulate = Color(1, 1, 1, 0.85)
	
	_drag_preview.draw.connect(func():
		var item_rect = Rect2(Vector2.ZERO, preview_size)
		var rarity_color = _get_rarity_color(item)
		if rarity_color.a > 0:
			_drag_preview.draw_rect(item_rect, rarity_color, true)
		_drag_preview.draw_rect(item_rect, _get_rarity_border_color(item), false, border_width)
		
		var tex_size = item.texture.get_size()
		if tex_size.x > 0 && tex_size.y > 0:
			var fit_scale = min(preview_w / tex_size.x, preview_h / tex_size.y)
			var tex_draw_size = tex_size * fit_scale
			var draw_pos = Vector2(
				(preview_w - tex_draw_size.x) / 2.0,
				(preview_h - tex_draw_size.y) / 2.0
			)
			_drag_preview.draw_texture_rect(item.texture, Rect2(draw_pos, tex_draw_size), false)
	)
	
	get_tree().root.add_child(_drag_preview)
	_drag_preview.global_position = get_global_mouse_position() - preview_size / 2.0
	_drag_preview.queue_redraw()

func _clear_drag_preview() -> void:
	if _drag_preview && is_instance_valid(_drag_preview):
		_drag_preview.queue_free()
		_drag_preview = null

# ========== 核心功能 ==========
func equip_item(item: ItemResource) -> bool:
	if item == null:
		return false
	if enable_type_filter && !check_type_match(item):
		return false
	
	current_item = item
	_refresh_display()
	item_equipped.emit(current_item)
	return true

func unequip_item() -> ItemResource:
	var old_item = current_item
	current_item = null
	_refresh_display()
	if old_item != null:
		item_unequipped.emit(old_item)
	return old_item

func check_type_match(item: ItemResource) -> bool:
	if item == null:
		return false
	if !enable_type_filter:
		return true
	
	match accept_type:
		ItemType.枪械:
			return item.is_枪
		ItemType.药品:
			return item.is_药品
		ItemType.刀具:
			return item.is_刀具
		ItemType.其他:
			return item.is_其他
		_:
			return false

# 全局拖拽悬停高亮
func _process(delta: float) -> void:
	if !enable_type_filter || !_is_global_dragging || _drag_item == null:
		modulate = Color.WHITE
		return
	
	var mouse_global = get_global_mouse_position()
	var is_hovered = get_global_rect().grow(4.0).has_point(mouse_global)
	
	var match = check_type_match(_drag_item)
	if is_hovered:
		modulate = Color(0.3, 1.0, 0.3, 1.0) if match else Color(1.0, 0.3, 0.3, 1.0)
	else:
		modulate = Color.WHITE

# ========== 工具函数 ==========
func _get_bag_at_mouse() -> bag:
	var mouse_pos = get_global_mouse_position()
	for node in get_tree().get_nodes_in_group("inventory_containers"):
		if node is bag && node.visible:
			if node.get_global_rect().has_point(mouse_pos):
				return node
	return null

func _get_slot_at_mouse() -> EquipSlot:
	var mouse_pos = get_global_mouse_position()
	var slots = get_tree().get_nodes_in_group("item_equip_slots")
	for node in slots:
		if node is EquipSlot && node != self && node.visible:
			if node.get_global_rect().grow(4.0).has_point(mouse_pos):
				return node
	return null

# ========== 品质颜色 ==========
func _get_rarity_color(item: ItemResource) -> Color:
	if item == null:
		return Color.TRANSPARENT
	var level = item.物品等级 if "物品等级" in item else -1
	match level:
		0: return Color(0.8, 0.8, 0.8, 0.25)
		1: return Color(0.2, 0.8, 0.2, 0.25)
		2: return Color(0.2, 0.4, 0.9, 0.25)
		3: return Color(0.6, 0.2, 0.8, 0.25)
		4: return Color(1.0, 0.8, 0.1, 0.25)
		_: return Color.TRANSPARENT

func _get_rarity_border_color(item: ItemResource) -> Color:
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

func _refresh_display() -> void:
	queue_redraw()

# ========== 拖拽管理器连接 ==========
func _connect_drag_manager() -> void:
	var dm = _get_drag_manager()
	if dm:
		if dm.drag_started.is_connected(_on_drag_started):
			dm.drag_started.disconnect(_on_drag_started)
		if dm.drag_ended.is_connected(_on_drag_ended):
			dm.drag_ended.disconnect(_on_drag_ended)
		if dm.drag_cancelled.is_connected(_on_drag_cancelled):
			dm.drag_cancelled.disconnect(_on_drag_cancelled)
		
		dm.drag_started.connect(_on_drag_started)
		dm.drag_ended.connect(_on_drag_ended)
		dm.drag_cancelled.connect(_on_drag_cancelled)
	else:
		get_tree().create_timer(0.1).timeout.connect(_connect_drag_manager)

func _get_drag_manager():
	if Engine.has_singleton("Dragmanager"):
		return Engine.get_singleton("Dragmanager")
	
	var root = get_tree().root
	for child in root.get_children():
		if child.name == "Dragmanager":
			return child
	return null

# ========== 全局拖拽信号回调 ==========
func _on_drag_started(item_data: ItemResource, source_container: Control) -> void:
	if source_container != self:
		_is_global_dragging = true
		_drag_item = item_data

func _on_drag_ended(item_data: ItemResource, target_container: Control, target_cell: Vector2i) -> void:
	_is_global_dragging = false
	_drag_item = null
	modulate = Color.WHITE
	_is_dragging_from_self = false

func _on_drag_cancelled(item_data: ItemResource) -> void:
	_is_global_dragging = false
	_drag_item = null
	modulate = Color.WHITE
	_is_dragging_from_self = false

# 自定义绘制
func _draw() -> void:
	var rect = Rect2(Vector2.ZERO, size)
	
	if _is_dragging_from_self:
		if default_texture != null:
			var tex_size = default_texture.get_size()
			if tex_size.x > 0 && tex_size.y > 0:
				var fit_scale = min(size.x / tex_size.x, size.y / tex_size.y)
				var draw_size = tex_size * fit_scale
				var draw_pos = (size - draw_size) / 2.0
				draw_texture_rect(default_texture, Rect2(draw_pos, draw_size), false)
		return
	
	if current_item == null:
		if default_texture != null:
			var tex_size = default_texture.get_size()
			if tex_size.x > 0 && tex_size.y > 0:
				var fit_scale = min(size.x / tex_size.x, size.y / tex_size.y)
				var draw_size = tex_size * fit_scale
				var draw_pos = (size - draw_size) / 2.0
				draw_texture_rect(default_texture, Rect2(draw_pos, draw_size), false)
		return
	
	var rarity_color = _get_rarity_color(current_item)
	if rarity_color.a > 0:
		draw_rect(rect, rarity_color, true)
	draw_rect(rect, _get_rarity_border_color(current_item), false, border_width)
	
	if current_item.texture != null:
		var tex_size = current_item.texture.get_size()
		if tex_size.x > 0 && tex_size.y > 0:
			var fit_scale = min(size.x / tex_size.x, size.y / tex_size.y)
			var draw_size = tex_size * fit_scale
			var draw_pos = (size - draw_size) / 2.0
			draw_texture_rect(current_item.texture, Rect2(draw_pos, draw_size), false)
