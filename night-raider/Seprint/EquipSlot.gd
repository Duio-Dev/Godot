extends TextureRect
class_name EquipSlot

signal item_equipped(item_data: ItemResource)
signal item_unequipped(item_data: ItemResource)

# 基础配置
@export var default_texture: Texture = null
@export var border_width: float = 2.0

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

func _ready() -> void:
	mouse_filter = MOUSE_FILTER_PASS
	texture_filter = TEXTURE_FILTER_NEAREST
	if not is_in_group("item_equip_slots"):
		add_to_group("item_equip_slots")
	call_deferred("_connect_drag_manager")
	_refresh_display()
	print("[槽位-", name, "] 初始化完成 | 开启过滤:", enable_type_filter, " | 允许类型:", accept_type)

func _exit_tree() -> void:
	var dm = _get_drag_manager()
	if dm:
		if dm.drag_started.is_connected(_on_drag_started):
			dm.drag_started.disconnect(_on_drag_started)
		if dm.drag_ended.is_connected(_on_drag_ended):
			dm.drag_ended.disconnect(_on_drag_ended)
		if dm.drag_cancelled.is_connected(_on_drag_cancelled):
			dm.drag_cancelled.disconnect(_on_drag_cancelled)

# 自定义绘制
func _draw() -> void:
	var rect = Rect2(Vector2.ZERO, size)
	
	if current_item == null:
		if default_texture != null:
			var tex_size = default_texture.get_size()
			if tex_size.x > 0 && tex_size.y > 0:
				var fit_scale = min(size.x / tex_size.x, size.y / tex_size.y)
				var draw_size = tex_size * fit_scale
				var draw_pos = (size - draw_size) / 2.0
				draw_texture_rect(default_texture, Rect2(draw_pos, draw_size), false)
		return
	
	# 品质背景 + 边框 + 纹理
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

# 放入物品（带逐行调试打印）
func equip_item(item: ItemResource) -> bool:
	print("\n[槽位-", name, "] ====== 开始放置判定 ======")
	print("[槽位-", name, "] 传入物品:", item.name if item else "空")
	
	# 判定1：物品是否为空
	if item == null:
		print("[槽位-", name, "] ❌ 失败：物品为空")
		return false
	
	# 判定2：是否开启类型过滤
	print("[槽位-", name, "] 开启类型过滤:", enable_type_filter)
	if enable_type_filter:
		var match_result = check_type_match(item)
		print("[槽位-", name, "] 类型匹配结果:", match_result, " | 槽位允许:", accept_type, " | 物品is_枪:", item.is_枪, " is_药品:", item.is_药品, " is_刀具:", item.is_刀具, " is_其他:", item.is_其他)
		if not match_result:
			print("[槽位-", name, "] ❌ 失败：类型不匹配")
			return false
	
	# 放置成功
	current_item = item
	_refresh_display()
	item_equipped.emit(current_item)
	print("[槽位-", name, "] ✅ 放置成功")
	return true

# 取出物品
func unequip_item() -> ItemResource:
	var old_item = current_item
	current_item = null
	_refresh_display()
	if old_item != null:
		item_unequipped.emit(old_item)
	return old_item

# 类型匹配校验
func check_type_match(item: ItemResource) -> bool:
	if item == null:
		return false
	if not enable_type_filter:
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

# 悬停高亮
func _process(delta: float) -> void:
	if not enable_type_filter or not _is_global_dragging or _drag_item == null:
		modulate = Color.WHITE
		return
	
	var mouse_global = get_global_mouse_position()
	var is_hovered = get_global_rect().has_point(mouse_global)
	
	var match = check_type_match(_drag_item)
	if is_hovered:
		modulate = Color(0.3, 1.0, 0.3, 1.0) if match else Color(1.0, 0.3, 0.3, 1.0)
	else:
		modulate = Color.WHITE

# 品质颜色
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

# 拖拽管理器连接
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
	if Engine.has_singleton("DragManager"):
		return Engine.get_singleton("DragManager")
	
	var root = get_tree().root
	if root:
		var dm = root.get_node_or_null("DragManager")
		if dm:
			return dm
	
	for child in get_tree().root.get_children():
		if child.name == "DragManager":
			return child
	return null

# 拖拽信号回调
func _on_drag_started(item_data: ItemResource, source_container: ColorRect) -> void:
	_is_global_dragging = true
	_drag_item = item_data

func _on_drag_ended(item_data: ItemResource, target_container: ColorRect, target_cell: Vector2i) -> void:
	_is_global_dragging = false
	_drag_item = null
	modulate = Color.WHITE

func _on_drag_cancelled(item_data: ItemResource) -> void:
	_is_global_dragging = false
	_drag_item = null
	modulate = Color.WHITE
