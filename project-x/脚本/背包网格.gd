@tool
extends ColorRect
class_name InventoryGrid

signal grid_changed()

@export var grid_size: int = 64 : set = _set_grid_size
@export var columns: int = 10 : set = _set_columns
@export var rows: int = 6 : set = _set_rows
@export var line_thickness: float = 1.0 : set = _set_line_thickness
@export var grid_color: Color = Color(0.3, 0.3, 0.3, 0.8)
@export var bg_color: Color = Color(0.1, 0.1, 0.1, 0.9)
@export var highlight_legal_color: Color = Color(0, 0.8, 0, 0.4)
@export var highlight_illegal_color: Color = Color(0.8, 0, 0, 0.4)

var occupied: Array = []
var items: Array[Control] = []
var hovered_item: Control = null
var preview_pos: Vector2i = Vector2i(-1, -1)
var preview_legal: bool = false

func _ready():
	add_to_group("InventoryGrid")
	_init_occupied()
	_update_own_size()

func _init_occupied():
	occupied.clear()
	for x in range(columns):
		occupied.append([])
		for y in range(rows):
			occupied[x].append(null)

func _set_grid_size(v): grid_size = v; _update_own_size(); _reposition_all_items(); queue_redraw()
func _set_columns(v): columns = v; _init_occupied(); _update_own_size(); queue_redraw()
func _set_rows(v): rows = v; _init_occupied(); _update_own_size(); queue_redraw()
func _set_line_thickness(v): line_thickness = v; queue_redraw()

func _update_own_size():
	size = Vector2(columns * grid_size, rows * grid_size)

func try_place_item(item: Control) -> bool:
	if not (item is InventoryItem): return false
	var pos = _get_grid_pos_at_mouse()
	if _can_place_at(item, pos): _place_item(item, pos); return true
	return false

func remove_item(item: Control):
	if not item in items: return
	for x in range(columns):
		for y in range(rows):
			if occupied[x][y] == item:
				occupied[x][y] = null
	items.erase(item)
	if is_instance_valid(item):
		item.parent_grid = null
		item.grid_pos = Vector2i(-1, -1)
	grid_changed.emit()

func _place_item(item: Control, pos: Vector2i):
	_cleanup_invalid_items()
	if item.parent_grid and item.parent_grid != self:
		item.parent_grid.remove_item(item)
	elif item.parent_grid == self and item.grid_pos != Vector2i(-1, -1):
		_set_occupied(item.grid_pos, item.effective_width, item.effective_height, null)

	_set_occupied(pos, item.effective_width, item.effective_height, item)
	if item.get_parent() != self:
		if item.get_parent(): item.get_parent().remove_child(item)
		add_child(item)
	item.grid_pos = pos; item.parent_grid = self
	if not item in items: items.append(item)
	_reposition_item(item)
	if item is InventoryItem: item.update_search_visuals()
	if item is InventoryItem: item._update_size()
	grid_changed.emit()

func _force_place_item(item: InventoryItem, pos: Vector2i):
	if occupied[pos.x][pos.y] and occupied[pos.x][pos.y] != item:
		var old = occupied[pos.x][pos.y]
		remove_item(old)
		old.queue_free()
	_set_occupied(pos, item.effective_width, item.effective_height, item)
	item.parent_grid = self
	item.grid_pos = pos
	if not item in items:
		items.append(item)
	_reposition_item(item)

func _reposition_item(item: Control):
	var margin = item.get("margin") if item.get("margin") != null else 0.0
	var total_w = item.effective_width * grid_size
	var total_h = item.effective_height * grid_size
	var new_size = Vector2(total_w - margin * 2, total_h - margin * 2)
	item.position = Vector2(item.grid_pos.x * grid_size + margin, item.grid_pos.y * grid_size + margin)
	item.size = new_size
	if item.has_node("物品图标"):
		var icon = item.get_node("物品图标")
		icon.size = new_size; icon.position = Vector2.ZERO
		if item is InventoryItem:
			icon.rotation = PI / 2.0 if item.is_rotated else 0.0

func _reposition_all_items():
	_cleanup_invalid_items()
	for item in items:
		if is_instance_valid(item): _reposition_item(item)

func _cleanup_invalid_items():
	var to_remove = []
	for item in items:
		if not is_instance_valid(item): to_remove.append(item)
	for item in to_remove: items.erase(item)
	for x in range(columns):
		for y in range(rows):
			if occupied[x][y] != null and not is_instance_valid(occupied[x][y]):
				occupied[x][y] = null

func _set_occupied(grid_pos: Vector2i, w: int, h: int, value):
	for x in range(w):
		for y in range(h):
			var cx = grid_pos.x + x; var cy = grid_pos.y + y
			if cx >= 0 and cx < columns and cy >= 0 and cy < rows:
				occupied[cx][cy] = value

func _can_place_at(item: Control, pos: Vector2i) -> bool:
	var w = item.effective_width; var h = item.effective_height
	if pos.x < 0 or pos.y < 0 or pos.x + w > columns or pos.y + h > rows:
		return false
	for x in range(w):
		for y in range(h):
			var cell = occupied[pos.x + x][pos.y + y]
			if cell != null and is_instance_valid(cell) and cell != item:
				return false
	return true

func _get_grid_pos_at_mouse() -> Vector2i:
	if columns <= 0 or rows <= 0:
		return Vector2i(-1, -1)
	var local = get_local_mouse_position()
	var x = int(local.x / grid_size)
	var y = int(local.y / grid_size)
	return Vector2i(clamp(x, 0, columns - 1), clamp(y, 0, rows - 1))

func _draw():
	_cleanup_invalid_items()
	
	for x in range(columns):
		for y in range(rows):
			var rect = Rect2(x * grid_size, y * grid_size, grid_size, grid_size)
			draw_rect(rect, bg_color, true)
			draw_rect(rect, grid_color, false, line_thickness)

	# 绘制未搜索物品的占位格子
	for item in items:
		if item is InventoryItem and not item._was_searched:
			var x = item.grid_pos.x
			var y = item.grid_pos.y
			var w = item.effective_width
			var h = item.effective_height
			
			var total_left = x * grid_size
			var total_top = y * grid_size
			var total_right = (x + w) * grid_size
			var total_bottom = (y + h) * grid_size
			draw_rect(Rect2(total_left, total_top, total_right - total_left, total_bottom - total_top), Color(0.25, 0.25, 0.25, 1.0), true)
			
			for cx in range(w):
				for cy in range(h):
					var cell_left = (x + cx) * grid_size
					var cell_top = (y + cy) * grid_size
					var cell_right = cell_left + grid_size
					var cell_bottom = cell_top + grid_size
					draw_rect(Rect2(cell_left, cell_top, grid_size, grid_size), Color.BLACK, false, 3.0)
			
			draw_rect(Rect2(total_left, total_top, total_right - total_left, total_bottom - total_top), Color.WHITE, false, 2.0)

	# 拖拽预览高亮
	if hovered_item:
		var w = hovered_item.effective_width
		var h = hovered_item.effective_height
		var pos = preview_pos
		if pos.x >= 0 and pos.y >= 0:
			var col = highlight_legal_color if preview_legal else highlight_illegal_color
			for x in range(w):
				for y in range(h):
					var r = Rect2((pos.x + x) * grid_size, (pos.y + y) * grid_size, grid_size, grid_size)
					draw_rect(r, col, true)
					draw_rect(r, Color.WHITE, false, 1.0)

func _process(delta):
	if Engine.is_editor_hint(): queue_redraw(); return
	var drag_layer = get_tree().root.get_node_or_null("DragLayer")
	if not drag_layer: return
	for child in drag_layer.get_children():
		if child is InventoryItem and child.is_dragging:
			var local_mouse = get_local_mouse_position()
			if Rect2(Vector2.ZERO, size).has_point(local_mouse):
				hovered_item = child; preview_pos = _get_grid_pos_at_mouse()
				preview_legal = _can_place_at(child, preview_pos)
				queue_redraw(); return
	if hovered_item: hovered_item = null; queue_redraw()

func full_consistency_check_and_fix():
	print("[网格修复] 开始修复 ", name)
	for x in range(columns):
		for y in range(rows):
			if occupied[x][y] != null and not is_instance_valid(occupied[x][y]):
				occupied[x][y] = null
	for x in range(columns):
		for y in range(rows):
			occupied[x][y] = null
	var to_remove = []
	for item in items:
		if not is_instance_valid(item):
			to_remove.append(item); continue
		if item.parent_grid != self:
			continue
		var pos = item.grid_pos
		if pos == Vector2i(-1, -1): continue
		var w = item.effective_width; var h = item.effective_height
		if pos.x >= 0 and pos.y >= 0 and pos.x + w <= columns and pos.y + h <= rows:
			_set_occupied(pos, w, h, item)
		else:
			var placed = false
			for nx in range(columns):
				for ny in range(rows):
					if _can_place_at(item, Vector2i(nx, ny)):
						item.grid_pos = Vector2i(nx, ny)
						_set_occupied(item.grid_pos, w, h, item)
						placed = true
						print("[网格修复] 物品 %s 被移到 (%d,%d)" % [item.item_data.item_name, nx, ny])
						break
				if placed: break
			if not placed:
				print("[网格修复] 严重错误：物品 %s 无法放置！" % item.item_data.item_name)
	for item in to_remove: items.erase(item)
	_reposition_all_items()
	queue_redraw()
	print("[网格修复] 完成 ", name)

func update_item_rotation(item: Control):
	if not item in items: return
	var old_pos = item.grid_pos
	var old_rotated = item.is_rotated
	
	_set_occupied(old_pos, item.effective_width, item.effective_height, null)
	
	item.is_rotated = not item.is_rotated
	item._update_size()
	
	if _can_place_at(item, old_pos):
		_set_occupied(old_pos, item.effective_width, item.effective_height, item)
	else:
		item.is_rotated = old_rotated
		item._update_size()
		_set_occupied(old_pos, item.effective_width, item.effective_height, item)
	
	_reposition_item(item)
	queue_redraw()
	grid_changed.emit()
# 根据物品当前尺寸和位置重新设置占用（通常用于尺寸变化后）
func update_item_occupancy(item: Control):
	if not item in items:
		return
	# 清除旧占用
	for x in range(columns):
		for y in range(rows):
			if occupied[x][y] == item:
				occupied[x][y] = null
	# 设置新占用
	if item.grid_pos != Vector2i(-1, -1):
		_set_occupied(item.grid_pos, item.effective_width, item.effective_height, item)
