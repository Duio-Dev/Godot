@tool
extends Control
class_name InventoryItem

signal item_placed()
signal item_picked_up()
signal search_finished()

@export var item_data: ItemData : set = _set_item_data
@export var margin: float = 4.0
@export var search_icon: Texture2D = null
@export var search_radius: float = 5.0
@export var search_speed: float = 5.0
@export var keep_aspect: bool = true

const LOAD_TIME_PER_ROUND: float = 0.3

@onready var 物品图标: TextureRect = $物品图标
@onready var 物品品质: ColorRect = $物品品质
@onready var 数量: Label = $数量
@onready var 物品名字: Label = $物品名字

var is_dragging: bool = false
var is_rotated: bool = false
var is_searching: bool = false
var _was_searched: bool = false
var stack_count: int = 1

var effective_width: int:
	get: return item_data.grid_height if is_rotated else item_data.grid_width
var effective_height: int:
	get: return item_data.grid_width if is_rotated else item_data.grid_height

var grid_pos: Vector2i = Vector2i(-1, -1)
var parent_grid: InventoryGrid = null
var _previous_grid: InventoryGrid = null
var _previous_pos: Vector2i = Vector2i(-1, -1)

var _search_indicator: TextureRect = null
var _search_timer: Timer = null
var _search_angle: float = 0.0
var _drag_offset: Vector2 = Vector2.ZERO

# 压弹相关
var _loading_ammo: bool = false
var _load_bullet: InventoryItem = null
var _total_rounds_to_load: int = 0
var _loaded_rounds: int = 0
var _load_timer: Timer = null
var _load_indicator: Control = null
var _arc_draw_control: Control = null
var _cancel_button: Button = null
var _bullet_original_grid: InventoryGrid = null
var _bullet_original_pos: Vector2i = Vector2i(-1, -1)
var _bullet_rotated: bool = false

func _ready():
	anchor_left = 0.0; anchor_top = 0.0; anchor_right = 0.0; anchor_bottom = 0.0
	set_process(false); set_process_input(true)
	_apply_item_data()
	_update_size()
	update_search_visuals()
	_update_stack_label()

func _apply_item_data():
	if item_data and 物品图标:
		物品图标.texture = item_data.icon
		if 物品品质: 物品品质.color = item_data.get_quality_color()
	is_rotated = false
	物品图标.rotation = 0.0
	物品图标.pivot_offset = Vector2.ZERO

func _set_item_data(data: ItemData):
	item_data = data
	if is_inside_tree() and 物品图标:
		_apply_item_data()
		_update_size()
		update_search_visuals()

func _update_size():
	if not item_data or not 物品图标: return
	var cell_size = parent_grid.grid_size if parent_grid else 64
	var full_w = effective_width * cell_size
	var full_h = effective_height * cell_size
	var new_size = Vector2(full_w - margin * 2, full_h - margin * 2)
	size = new_size; 物品图标.size = new_size
	物品图标.position = Vector2.ZERO; 物品图标.pivot_offset = new_size / 2.0
	if keep_aspect: 物品图标.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	else: 物品图标.stretch_mode = TextureRect.STRETCH_SCALE
	if 物品品质:
		物品品质.size = Vector2(full_w, full_h)
		物品品质.position = Vector2(-margin, -margin)
	物品图标.rotation = PI / 2.0 if is_rotated else 0.0
	_update_stack_label()
	_update_name_label()

func _update_stack_label():
	if not 数量: return
	if not _was_searched:
		数量.hide()
		return
	if item_data and item_data.is_magazine:
		数量.text = "%d/%d" % [item_data.current_ammo, item_data.magazine_capacity]
		数量.show()
	elif stack_count > 1:
		数量.text = str(stack_count)
		数量.show()
	else:
		数量.hide()

func _update_name_label():
	if not 物品名字: return
	if not _was_searched or not item_data:
		物品名字.hide()
		return
	物品名字.text = item_data.item_name
	var cell_size = parent_grid.grid_size if parent_grid else 64
	var w = effective_width * cell_size
	var font_size = clamp(w / 4, 8, 16)
	物品名字.add_theme_font_size_override("font_size", int(font_size))
	物品名字.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	物品名字.custom_minimum_size = Vector2(w - margin * 2, 0)
	物品名字.show()

func can_stack_with(other: InventoryItem) -> bool:
	if not item_data or not other.item_data: return false
	if not is_instance_valid(other): return false
	if not item_data.can_stack or not other.item_data.can_stack: return false
	if item_data.is_magazine or other.item_data.is_magazine: return false
	return item_data.item_id == other.item_data.item_id and stack_count < item_data.max_stack and other.stack_count < other.item_data.max_stack

func try_merge(other: InventoryItem) -> int:
	if not can_stack_with(other): return other.stack_count
	var total = stack_count + other.stack_count
	var max_allowed = item_data.max_stack
	if total <= max_allowed:
		stack_count = total
		other.stack_count = 0
		other.queue_free()
		_update_stack_label()
		return 0
	else:
		stack_count = max_allowed
		other.stack_count = total - max_allowed
		_update_stack_label()
		return other.stack_count

# ---------- 压弹（先退回多余，再装填）----------
func start_loading_ammo(bullet: InventoryItem) -> bool:
	if _loading_ammo: return false
	if not item_data.is_magazine: return false
	if bullet.item_data.is_magazine: return false
	if not bullet.item_data or bullet.item_data.ammo_type != item_data.ammo_type: return false
	var needed = item_data.magazine_capacity - item_data.current_ammo
	if needed <= 0: return false
	_total_rounds_to_load = min(needed, bullet.stack_count)
	if _total_rounds_to_load <= 0: return false

	_loading_ammo = true
	_load_bullet = bullet
	_loaded_rounds = 0

	_bullet_original_grid = bullet.parent_grid if bullet.parent_grid else bullet._previous_grid
	_bullet_original_pos = bullet.grid_pos if bullet.parent_grid else bullet._previous_pos
	_bullet_rotated = bullet.is_rotated

	# 移除子弹占用
	if bullet.parent_grid:
		bullet.parent_grid.remove_item(bullet)
	elif bullet._previous_grid:
		bullet._previous_grid.remove_item(bullet)

	# 如果子弹数量多于装填量，退回多余部分（关键修复：传入子弹的 item_data）
	if bullet.stack_count > _total_rounds_to_load:
		var extra = bullet.stack_count - _total_rounds_to_load
		bullet.stack_count = _total_rounds_to_load
		bullet._update_stack_label()

		var extra_bullet = _create_remainder_item(extra, bullet.item_data)   # 传入正确的数据
		if extra_bullet:
			extra_bullet.is_rotated = _bullet_rotated
			extra_bullet._update_size()
			if _bullet_original_grid and _bullet_original_grid._can_place_at(extra_bullet, _bullet_original_pos):
				_bullet_original_grid._place_item(extra_bullet, _bullet_original_pos)
			elif not _place_item_in_any_grid(extra_bullet):
				extra_bullet.queue_free()

	# 将剩余子弹移入弹匣
	if bullet.get_parent():
		bullet.get_parent().remove_child(bullet)
	add_child(bullet)
	bullet.hide()

	_create_load_indicator()

	_load_timer = Timer.new()
	_load_timer.wait_time = LOAD_TIME_PER_ROUND
	_load_timer.one_shot = false
	_load_timer.timeout.connect(_on_load_tick)
	add_child(_load_timer)
	_load_timer.start()
	return true

func _create_load_indicator():
	if _load_indicator: return
	_load_indicator = Control.new()
	_load_indicator.size = size
	_load_indicator.position = Vector2.ZERO
	_load_indicator.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(_load_indicator)

	_arc_draw_control = Control.new()
	_arc_draw_control.size = size
	_arc_draw_control.position = Vector2.ZERO
	_arc_draw_control.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_load_indicator.add_child(_arc_draw_control)
	_arc_draw_control.draw.connect(_draw_loading_arc)

	_cancel_button = Button.new()
	_cancel_button.text = "X"
	_cancel_button.flat = true
	var btn_size = 40
	_cancel_button.size = Vector2(btn_size, btn_size)
	_cancel_button.position = (size - Vector2(btn_size, btn_size)) / 2.0
	_cancel_button.add_theme_color_override("font_color", Color.RED)
	_cancel_button.add_theme_font_size_override("font_size", 20)
	_cancel_button.pressed.connect(_cancel_loading)
	_load_indicator.add_child(_cancel_button)

func _draw_loading_arc():
	if not _loading_ammo or not _arc_draw_control: return
	var progress = float(_loaded_rounds) / float(_total_rounds_to_load)
	var center = _arc_draw_control.size / 2.0
	var radius = min(_arc_draw_control.size.x, _arc_draw_control.size.y) * 0.35
	var from_angle = -90
	var to_angle = -90 + 360 * progress
	_arc_draw_control.draw_arc(center, radius, deg_to_rad(from_angle), deg_to_rad(to_angle), 32, Color.GREEN, 5.0)
	_arc_draw_control.draw_arc(center, radius, deg_to_rad(to_angle), deg_to_rad(-90+360), 32, Color.DIM_GRAY, 5.0)

func _on_load_tick():
	_loaded_rounds += 1
	if _arc_draw_control:
		_arc_draw_control.queue_redraw()
	if _loaded_rounds >= _total_rounds_to_load:
		_finish_loading()

func _finish_loading():
	_loading_ammo = false
	if _load_timer:
		_load_timer.queue_free()
		_load_timer = null
	if _load_indicator:
		_load_indicator.queue_free()
		_load_indicator = null
	_arc_draw_control = null
	_cancel_button = null

	item_data.current_ammo += _loaded_rounds
	_load_bullet.stack_count -= _loaded_rounds
	if _load_bullet.stack_count <= 0:
		_load_bullet.queue_free()
	_load_bullet = null
	_update_stack_label()

func _cancel_loading():
	if not _loading_ammo: return
	_loading_ammo = false
	if _load_timer:
		_load_timer.queue_free()
		_load_timer = null
	if _load_indicator:
		_load_indicator.queue_free()
		_load_indicator = null
	_arc_draw_control = null
	_cancel_button = null

	_load_bullet.stack_count = _total_rounds_to_load
	_load_bullet.is_rotated = _bullet_rotated
	_load_bullet._update_size()
	if _bullet_original_grid and _bullet_original_grid._can_place_at(_load_bullet, _bullet_original_pos):
		_bullet_original_grid._place_item(_load_bullet, _bullet_original_pos)
	elif not _place_item_in_any_grid(_load_bullet):
		_load_bullet.queue_free()
	_load_bullet = null
	_update_stack_label()

# ---------- 搜索与视觉 ----------
func update_search_visuals():
	if not _was_searched:
		if 物品图标: 物品图标.hide()
		if 物品品质: 物品品质.hide()
		if 数量: 数量.hide()
		if 物品名字: 物品名字.hide()
	else:
		if 物品图标: 物品图标.show()
		if 物品品质: 物品品质.show()
		_update_stack_label()
		_update_name_label()
	if parent_grid: parent_grid.queue_redraw()

func start_search():
	if is_searching or _was_searched: return
	is_searching = true; set_process(true); update_search_visuals()

	_search_indicator = TextureRect.new()
	_search_indicator.texture = search_icon if search_icon else _create_circle_texture(32, Color.WHITE)
	_search_indicator.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_search_indicator.size = Vector2(32, 32)
	_search_indicator.position = size / 2 - _search_indicator.size / 2
	_search_indicator.pivot_offset = _search_indicator.size / 2.0
	add_child(_search_indicator); _search_angle = 0.0

	_search_timer = Timer.new()
	_search_timer.wait_time = item_data.get_search_duration() if item_data else 1.0
	_search_timer.one_shot = true
	_search_timer.timeout.connect(_on_search_complete)
	add_child(_search_timer); _search_timer.start()

func _on_search_complete():
	is_searching = false; _was_searched = true
	if _search_indicator: _search_indicator.queue_free(); _search_indicator = null
	if _search_timer: _search_timer.queue_free(); _search_timer = null
	if not is_dragging: set_process(false)
	update_search_visuals()
	search_finished.emit()

func mark_as_looted():
	_was_searched = true; is_searching = false
	if _search_indicator: _search_indicator.queue_free(); _search_indicator = null
	if _search_timer: _search_timer.queue_free(); _search_timer = null
	set_process(false); update_search_visuals(); show()

func _create_circle_texture(size: int, color: Color) -> ImageTexture:
	var img = Image.create(size, size, false, Image.FORMAT_RGBA8)
	img.fill(Color(0,0,0,0))
	var center = size / 2.0; var radius = size / 2.0 - 2.0
	for x in range(size):
		for y in range(size):
			if Vector2(x - center, y - center).length() <= radius:
				img.set_pixel(x, y, color)
	return ImageTexture.create_from_image(img)

# ---------- 交互 ----------
func _input(event):
	if Engine.is_editor_hint(): return
	if event is InputEventKey and event.keycode == KEY_R and event.pressed:
		if item_data.can_rotate and (is_dragging or grid_pos != Vector2i(-1, -1)):
			_rotate()
			accept_event()
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if not event.pressed and is_dragging:
			_stop_drag()
			accept_event()

func _gui_input(event):
	if Engine.is_editor_hint(): return
	if not _was_searched: return
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed:
			if Input.is_key_pressed(KEY_CTRL):
				_quick_transfer()
			else:
				_start_drag()

# ---------- 快速转移 ----------
func _quick_transfer():
	var ui = get_tree().get_first_node_in_group("InventoryUI")
	if not ui: return
	var container_grid = ui.active_container_grid

	if parent_grid == container_grid:
		var player = get_tree().get_first_node_in_group("Player")
		if not player: return
		var player_grids = _get_player_grids_by_preference(player)
		for g in player_grids:
			if g and g != parent_grid:
				if _try_place_in_grid(g): return
	else:
		if container_grid:
			_try_place_in_grid(container_grid)

func _try_place_in_grid(grid: InventoryGrid) -> bool:
	if not self.item_data.is_magazine:
		for target_item in grid.items:
			if target_item is InventoryItem and target_item != self and target_item.item_data.is_magazine:
				if not target_item._loading_ammo:
					if target_item.start_loading_ammo(self):
						return true

	for item in grid.items:
		if item is InventoryItem and item != self and item.can_stack_with(self):
			var remaining = item.try_merge(self)
			if remaining > 0:
				var new_item = _create_remainder_item(remaining, self.item_data)   # 传入自身数据
				if new_item:
					if not _place_item_in_any_grid(new_item):
						new_item.queue_free()
			return true

	for x in range(grid.columns):
		for y in range(grid.rows):
			var pos = Vector2i(x, y)
			if grid._can_place_at(self, pos):
				_move_to_grid(grid, pos)
				return true
	if item_data.can_rotate:
		is_rotated = not is_rotated
		_update_size()
		for x in range(grid.columns):
			for y in range(grid.rows):
				var pos = Vector2i(x, y)
				if grid._can_place_at(self, pos):
					_move_to_grid(grid, pos)
					return true
		is_rotated = not is_rotated
		_update_size()
	return false

func _move_to_grid(new_grid: InventoryGrid, pos: Vector2i):
	if parent_grid:
		parent_grid.remove_item(self)
	new_grid._place_item(self, pos)

func _get_player_grids_by_preference(player: PlayerCharacter) -> Array:
	var ui = player.inventory_ui
	var pref = item_data.preferred_slot
	match pref:
		ItemData.SlotPreference.POCKET:
			return [ui.口袋网格, ui.胸挂网格, ui.背包网格]
		ItemData.SlotPreference.VEST:
			return [ui.胸挂网格, ui.口袋网格, ui.背包网格]
		ItemData.SlotPreference.BACKPACK:
			return [ui.背包网格, ui.胸挂网格, ui.口袋网格]
		_:
			return [ui.口袋网格, ui.胸挂网格, ui.背包网格]

# ---------- 拖拽 ----------
func _start_drag():
	if not _was_searched: return
	if _loading_ammo: return
	is_dragging = true; set_process(true)
	_drag_offset = get_global_mouse_position() - global_position

	var grids = get_tree().get_nodes_in_group("InventoryGrid")
	for g in grids:
		if g is InventoryGrid:
			for x in range(g.columns):
				for y in range(g.rows):
					if g.occupied[x][y] == self: g.occupied[x][y] = null

	if parent_grid == null and get_parent() is InventoryGrid:
		var grid = get_parent() as InventoryGrid
		var col = floor(position.x / grid.grid_size)
		var row = floor(position.y / grid.grid_size)
		grid_pos = Vector2i(clamp(col, 0, grid.columns - 1), clamp(row, 0, grid.rows - 1))
		parent_grid = grid
		grid._set_occupied(grid_pos, effective_width, effective_height, null)
		if grid.items.has(self): grid.items.erase(self)
	_previous_grid = parent_grid; _previous_pos = grid_pos
	if parent_grid: parent_grid.remove_item(self)

	var top_layer = get_tree().root.get_node_or_null("DragLayer")
	if not top_layer:
		top_layer = CanvasLayer.new(); top_layer.name = "DragLayer"; top_layer.layer = 100
		get_tree().root.add_child(top_layer)
	if get_parent(): get_parent().remove_child(self)
	top_layer.add_child(self); z_index = 100

	_update_size()
	if 物品图标: 物品图标.show(); 物品图标.modulate = Color.WHITE
	if 物品品质: 物品品质.hide()
	if _search_indicator: _search_indicator.hide()
	show(); item_picked_up.emit()

func _stop_drag():
	is_dragging = false
	var grids = get_tree().get_nodes_in_group("InventoryGrid")
	var landed = false
	for grid in grids:
		if not (grid is Control): continue
		if grid.get_global_rect().has_point(get_global_mouse_position()):
			var target_pos = grid._get_grid_pos_at_mouse()
			var target_item = null
			if target_pos.x >= 0 and target_pos.y >= 0:
				target_item = grid.occupied[target_pos.x][target_pos.y]

			if target_item is InventoryItem and target_item != self and target_item.item_data.is_magazine:
				if not self.item_data.is_magazine:
					if not target_item._loading_ammo:
						if target_item.start_loading_ammo(self):
							landed = true
							break
				continue

			if target_item is InventoryItem and target_item != self and target_item.can_stack_with(self):
				var remaining = target_item.try_merge(self)
				if remaining > 0:
					var new_item = _create_remainder_item(remaining, self.item_data)   # 传入自身数据
					if new_item:
						if not _place_item_in_any_grid(new_item):
							new_item.queue_free()
				landed = true
				break

			if grid.try_place_item(self):
				landed = true
				break

	if not landed:
		if _previous_grid and _previous_pos != Vector2i(-1, -1):
			_previous_grid._force_place_item(self, _previous_pos)
		else:
			_place_item_anywhere()

	if is_searching:
		update_search_visuals()
		if _search_indicator: _search_indicator.show()
	else:
		update_search_visuals()
	if not is_searching and not is_dragging: set_process(false)

func _create_remainder_item(count: int, data: ItemData) -> InventoryItem:
	var scene = load("res://场景/所有继承场景的父场景/item.tscn")
	var item = scene.instantiate()
	item.item_data = data           # 使用传入的数据
	item.stack_count = count
	item.mark_as_looted()
	item._update_stack_label()
	return item

func _place_item_in_any_grid(item: InventoryItem) -> bool:
	var grids = get_tree().get_nodes_in_group("InventoryGrid")
	for grid in grids:
		if not (grid is Control): continue
		for x in range(grid.columns):
			for y in range(grid.rows):
				var pos = Vector2i(x, y)
				if grid._can_place_at(item, pos):
					grid._place_item(item, pos)
					return true
	return false

func _place_item_anywhere():
	var grids = get_tree().get_nodes_in_group("InventoryGrid")
	for grid in grids:
		if not (grid is Control): continue
		for x in range(grid.columns):
			for y in range(grid.rows):
				var pos = Vector2i(x, y)
				if grid._can_place_at(self, pos):
					grid._place_item(self, pos)
					return
	if _previous_grid: _previous_grid._place_item(self, _previous_pos)

func _process(delta):
	if is_dragging:
		global_position = get_global_mouse_position() - _drag_offset
	if is_searching and _search_indicator:
		_search_angle += delta * search_speed
		var center = size / 2.0
		var offset = Vector2(cos(_search_angle), sin(_search_angle)) * search_radius
		_search_indicator.position = center + offset - _search_indicator.size / 2.0

func _rotate():
	is_rotated = not is_rotated
	物品图标.rotation = PI / 2.0 if is_rotated else 0.0
	_update_size()
	if not is_dragging and parent_grid and grid_pos != Vector2i(-1, -1):
		parent_grid.update_item_rotation(self)

func _exit_tree():
	if parent_grid and parent_grid.items.has(self):
		parent_grid.remove_item(self)
