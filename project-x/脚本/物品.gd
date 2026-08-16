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
@export var search_complete_scale: float = 1.2
@export var search_complete_duration: float = 0.15

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
var consume_durability: float = 0.0

# ========== 新武器配件系统 ==========
var receiver_data: ItemData = null
var installed_parts: Dictionary = {}

var effective_width: int:
	get:
		var dims = _get_base_dimensions()
		return dims.y if is_rotated else dims.x

var effective_height: int:
	get:
		var dims = _get_base_dimensions()
		return dims.x if is_rotated else dims.y

var grid_pos: Vector2i = Vector2i(-1, -1)
var parent_grid: InventoryGrid = null
var _previous_grid: InventoryGrid = null
var _previous_pos: Vector2i = Vector2i(-1, -1)

var _search_indicator: TextureRect = null
var _search_timer: Timer = null
var _search_angle: float = 0.0
var _drag_offset: Vector2 = Vector2.ZERO

var _loaded_ammo_dict: Dictionary = {}
var _chambered_bullet_data: ItemData = null
var _original_weapon_texture: Texture2D = null

var chambered_round: int = 0

var _loading_ammo: bool = false
var _load_bullet: InventoryItem = null
var _total_rounds_to_load: int = 0
var _loaded_rounds: int = 0
var _load_timer: Timer = null
var _load_indicator: Control = null
var _arc_draw_control: Control = null
var _cancel_button: Button = null
var _is_being_loaded: bool = false
var _external_indicator: Control = null
var _external_arc: Control = null
var _external_total: int = 0
var _external_loaded: int = 0
var _loading_bullet_type: ItemData = null

var _unloading_ammo: bool = false
var _unload_timer: Timer = null
var _unload_indicator: Control = null
var _unload_arc: Control = null
var _unload_cancel_button: Button = null
var _unload_remaining_dict: Dictionary = {}
var _unload_total_count: int = 0
var _unload_current_count: int = 0

var _equipping_mag: bool = false
var _equip_timer: Timer = null
var _equip_progress: float = 0.0
var _equip_target_mag: InventoryItem = null
var _equip_indicator: Control = null
var _equip_arc: Control = null

var _unequipping_mag: bool = false
var _unequip_timer: Timer = null
var _unequip_progress: float = 0.0
var _unequip_indicator: Control = null
var _unequip_arc: Control = null

var _equipping_sight: bool = false
var _equip_sight_target: InventoryItem = null
var _equip_sight_progress: float = 0.0
var _equip_sight_timer: Timer = null
var _equip_sight_indicator: Control = null
var _equip_sight_arc: Control = null

var _is_equipped: bool = false
var _was_equipped: bool = false
var _progress_visible: bool = false
var _progress_value: float = 0.0
var _medical_progress_shown: bool = false
var _progress_layer: Control = null

static var _draggable_panels: Array = []
static var dragged_item: InventoryItem = null
var _pending_refresh_panel: bool = false

# ========== 异步安装/卸下进度条变量 ==========
var _install_part_progress: float = 0.0
var _install_part_timer: Timer = null
var _install_part_indicator: Control = null
var _install_part_arc: Control = null
var _install_part_target: InventoryItem = null
var _install_part_slot: String = ""

var _uninstall_part_progress: float = 0.0
var _uninstall_part_timer: Timer = null
var _uninstall_part_indicator: Control = null
var _uninstall_part_arc: Control = null
var _uninstall_part_target_slot: String = ""

# ========== 背包数据 ==========
var backpack_items_data: Array = []
var backpack_items_positions: Array = []
var backpack_items_searched: Array = []
var backpack_items_stack_counts: Array = []
var backpack_grid_columns: int = 5
var backpack_grid_rows: int = 4
var backpack_grid_size: int = 64

# ========== 辅助函数：判断是否为底座（枪机或头盔） ==========
func _is_host_type(data: ItemData) -> bool:
	return data.weapon_part_type == ItemData.WeaponPartType.RECEIVER or data.weapon_part_type == ItemData.WeaponPartType.HELMET

# ========== 基础函数 ==========
func _get_base_dimensions() -> Vector2i:
	var w = item_data.grid_width
	var h = item_data.grid_height
	if _is_host_type(item_data):
		for slot_name in installed_parts:
			var part = installed_parts[slot_name]
			if part is InventoryItem and part.item_data:
				w += part.item_data.grid_width_increase
				h += part.item_data.grid_height_increase
	return Vector2i(w, h)

func safe_queue_free():
	if parent_grid and is_instance_valid(parent_grid):
		parent_grid.remove_item(self)
	queue_free()

func _ready():
	anchor_left = 0.0; anchor_top = 0.0; anchor_right = 0.0; anchor_bottom = 0.0
	set_process(false); set_process_input(true)
	_apply_item_data()
	_update_size()
	update_search_visuals()
	_update_stack_label()

func _apply_item_data():
	if item_data:
		_original_weapon_texture = item_data.icon
		if _is_host_type(item_data):
			receiver_data = item_data
			installed_parts.clear()
			# 恢复配件数据
			if not item_data.installed_parts_data.is_empty():
				restore_installed_parts_from_data(item_data.installed_parts_data)
		else:
			receiver_data = null
		if 物品图标:
			if 物品品质: 物品品质.color = item_data.get_quality_color()
			if item_data.is_food_or_drink:
				consume_durability = item_data.consume_durability
			else:
				consume_durability = 0.0
			is_rotated = false
			物品图标.rotation = 0.0
			物品图标.pivot_offset = Vector2.ZERO
			chambered_round = 0
			_chambered_bullet_data = null
			if _is_host_type(item_data):
				_generate_weapon_texture()
			else:
				物品图标.texture = item_data.icon
		# 背包初始化：设置网格参数并恢复内部数据
		if item_data.is_backpack:
			backpack_grid_columns = max(1, item_data.backpack_grid_columns)
			backpack_grid_rows = max(1, item_data.backpack_grid_rows)
			backpack_grid_size = max(16, item_data.backpack_grid_size)
			# 如果内部数据为空且 ItemData 有序列化数据，则恢复
			if backpack_items_data.is_empty() and not item_data.backpack_contents.is_empty():
				backpack_items_data = item_data.backpack_contents.get("items_data", []).duplicate()
				backpack_items_positions = item_data.backpack_contents.get("items_positions", []).duplicate()
				backpack_items_searched = item_data.backpack_contents.get("items_searched", []).duplicate()
				backpack_items_stack_counts = item_data.backpack_contents.get("items_stack_counts", []).duplicate()
			# 如果已有数据，保留（可能来自实时保存）
	# 如果是弹匣，立即清理错误数据
	if item_data and item_data.weapon_part_type == ItemData.WeaponPartType.MAGAZINE:
		_cleanup_invalid_bullets()

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
	size = new_size
	物品图标.size = new_size
	物品图标.position = Vector2.ZERO
	物品图标.pivot_offset = new_size / 2.0
	if is_rotated:
		物品图标.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED if keep_aspect else TextureRect.STRETCH_SCALE
	elif keep_aspect:
		物品图标.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	else:
		物品图标.stretch_mode = TextureRect.STRETCH_SCALE
	if 物品品质:
		物品品质.size = Vector2(full_w, full_h)
		物品品质.position = Vector2(-margin, -margin)
	_update_stack_label()
	_update_name_label()
	if _progress_layer:
		_progress_layer.size = size
		_progress_layer.position = Vector2.ZERO
	if parent_grid:
		if grid_pos != Vector2i(-1, -1) and not parent_grid._can_place_at(self, grid_pos):
			var placed = false
			for x in range(parent_grid.columns):
				for y in range(parent_grid.rows):
					var pos = Vector2i(x, y)
					if parent_grid._can_place_at(self, pos):
						parent_grid._place_item(self, pos)
						placed = true
						break
				if placed: break
			if not placed:
				parent_grid.force_place_item(self, grid_pos)
		else:
			parent_grid._reposition_item(self)
		if parent_grid.has_method("update_item_occupancy"):
			parent_grid.update_item_occupancy(self)
	if receiver_data and 物品图标 and installed_parts.size() > 0:
		_generate_weapon_texture()
	queue_redraw()

# ========== 清理非法子弹数据 ==========
func _cleanup_invalid_bullets():
	var invalid_keys = []
	for key in _loaded_ammo_dict.keys():
		if not key is ItemData or key.weapon_part_type != ItemData.WeaponPartType.NONE:
			invalid_keys.append(key)
	for key in invalid_keys:
		print("[弹匣] 清理非法子弹数据: ", key.item_name if key is ItemData else key)
		_loaded_ammo_dict.erase(key)

	var total = 0
	for count in _loaded_ammo_dict.values():
		total += count
	item_data.current_ammo = total
	if item_data.current_ammo > item_data.magazine_capacity:
		item_data.current_ammo = item_data.magazine_capacity

# ========== 槽位管理 ==========
func get_all_slots() -> Array:
	if receiver_data:
		return receiver_data.receiver_slots
	return []

func get_available_slots() -> Array:
	var available = []
	for slot in get_all_slots():
		if _is_slot_active(slot) and not installed_parts.has(slot.slot_name):
			available.append(slot)
	return available

func _is_slot_active(slot: WeaponSlot) -> bool:
	if slot.parent_slot_name.is_empty():
		return true
	return installed_parts.has(slot.parent_slot_name)

func _find_slot_by_name(slot_name: String) -> WeaponSlot:
	for slot in get_all_slots():
		if slot.slot_name == slot_name:
			return slot
	return null

func get_equipped_part_of_type(part_type: int) -> InventoryItem:
	for slot_name in installed_parts:
		var part = installed_parts[slot_name]
		if part.item_data.weapon_part_type == part_type:
			return part
	return null

func get_equipped_magazine() -> InventoryItem:
	var mag = get_equipped_part_of_type(ItemData.WeaponPartType.MAGAZINE)
	if mag:
		mag._cleanup_invalid_bullets()
	return mag

func get_equipped_sight() -> InventoryItem:
	return get_equipped_part_of_type(ItemData.WeaponPartType.SIGHT)
# 将已安装的配件序列化为字典，用于保存/容器存储
func serialize_installed_parts() -> Dictionary:
	var parts_data = {}
	for slot_name in installed_parts:
		var part = installed_parts[slot_name]
		if not is_instance_valid(part):
			continue
		parts_data[slot_name] = {
			"item_data": part.item_data,
			"stack_count": part.stack_count,
			"loaded_ammo_dict": part._loaded_ammo_dict.duplicate() if part._loaded_ammo_dict else {},
			"current_ammo": part.item_data.current_ammo if part.item_data else 0,
			"is_equipped": part._is_equipped
		}
	return parts_data
# 从序列化数据恢复已安装的配件
func restore_installed_parts_from_data(data: Dictionary):
	installed_parts.clear()
	var item_scene = load("res://场景/所有继承场景的父场景/item.tscn")
	for slot_name in data.keys():
		var part_info = data[slot_name]
		var part_item = item_scene.instantiate()
		part_item.item_data = part_info["item_data"]
		part_item.stack_count = part_info.get("stack_count", 1)
		part_item._loaded_ammo_dict = part_info.get("loaded_ammo_dict", {}).duplicate()
		if part_item.item_data:
			part_item.item_data.current_ammo = part_info.get("current_ammo", part_item.item_data.current_ammo)
		part_item._is_equipped = true
		part_item.visible = false
		part_item.modulate.a = 0.0
		part_item.parent_grid = null
		part_item.grid_pos = Vector2i(-1, -1)
		installed_parts[slot_name] = part_item
	_update_size()
	_generate_weapon_texture()
	_update_stack_label()
# ========== 异步安装配件（带进度条） ==========
func start_install_part(part: InventoryItem, slot_name: String) -> bool:
	if _install_part_target or _uninstall_part_target_slot != "":
		return false
	if not receiver_data:
		return false
	var slot = _find_slot_by_name(slot_name)
	if not slot or slot.slot_type != part.item_data.weapon_part_type or not _is_slot_active(slot) or installed_parts.has(slot_name):
		return false
	if part.item_data.compatible_receivers.size() > 0 and not part.item_data.compatible_receivers.has(receiver_data.item_id):
		return false
	if not slot.required_slot_tag.is_empty() and part.item_data.slot_tag != slot.required_slot_tag:
		return false

	if part.item_data.weapon_part_type == ItemData.WeaponPartType.BARREL:
		var has_upper = false
		for s in installed_parts.keys():
			if s == "上机匣接口":
				has_upper = true
				break
		if not has_upper:
			print("需要先安装上机匣")
			return false

	if part.parent_grid:
		part.parent_grid.remove_item(part)
	if part.get_parent():
		part.get_parent().remove_child(part)
	part.visible = false
	part.modulate.a = 0.0

	_install_part_target = part
	_install_part_slot = slot_name
	_install_part_progress = 0.0
	_create_install_part_indicator()
	_install_part_timer = Timer.new()
	_install_part_timer.wait_time = 0.05
	_install_part_timer.one_shot = false
	_install_part_timer.timeout.connect(_on_install_part_tick)
	add_child(_install_part_timer)
	_install_part_timer.start()
	return true

func _on_install_part_tick():
	_install_part_progress += 0.05
	if _install_part_arc: _install_part_arc.queue_redraw()
	if _install_part_progress >= 1.0:
		_finish_install_part()

func _finish_install_part():
	if _install_part_timer:
		_install_part_timer.queue_free()
		_install_part_timer = null
	if _install_part_indicator:
		_install_part_indicator.queue_free()
		_install_part_indicator = null
		_install_part_arc = null
	var part = _install_part_target
	var slot_name = _install_part_slot
	_install_part_target = null
	_install_part_slot = ""
	_install_part_progress = 0.0
	if part and slot_name != "":
		_do_install_part(part, slot_name)

func _do_install_part(part: InventoryItem, slot_name: String):
	if part.parent_grid:
		part.parent_grid.remove_item(part)
	if part.get_parent():
		part.get_parent().remove_child(part)
	part.visible = false
	part.modulate.a = 0.0
	installed_parts[slot_name] = part
	part._is_equipped = true

	if part.item_data.weapon_part_type == ItemData.WeaponPartType.MAGAZINE:
		_loaded_ammo_dict = part._loaded_ammo_dict

	_update_size()
	_generate_weapon_texture()
	_update_stack_label()

func _create_install_part_indicator():
	if _install_part_indicator: return
	_install_part_indicator = Control.new()
	_install_part_indicator.size = size
	_install_part_indicator.position = Vector2.ZERO
	_install_part_indicator.mouse_filter = Control.MOUSE_FILTER_STOP
	_install_part_indicator.z_index = 10
	add_child(_install_part_indicator)
	_install_part_arc = Control.new()
	_install_part_arc.size = size
	_install_part_arc.position = Vector2.ZERO
	_install_part_arc.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_install_part_indicator.add_child(_install_part_arc)
	_install_part_arc.draw.connect(_draw_install_part_arc)

func _draw_install_part_arc():
	if not _install_part_arc or not _install_part_indicator: return
	var progress = _install_part_progress
	var center = _install_part_arc.size / 2.0
	var radius = min(_install_part_arc.size.x, _install_part_arc.size.y) * 0.35
	_install_part_arc.draw_arc(center, radius, -PI/2, -PI/2 + 2*PI*progress, 32, Color.BLUE, 5.0)
	_install_part_arc.draw_arc(center, radius, -PI/2 + 2*PI*progress, -PI/2 + 2*PI, 32, Color.DIM_GRAY, 5.0)

# ========== 异步卸下配件（带进度条） ==========
func start_uninstall_part(slot_name: String) -> bool:
	if not installed_parts.has(slot_name):
		return false
	if _uninstall_part_target_slot != "" or _install_part_target:
		return false
	_uninstall_part_target_slot = slot_name
	_uninstall_part_progress = 0.0
	_create_uninstall_part_indicator()
	_uninstall_part_timer = Timer.new()
	_uninstall_part_timer.wait_time = 0.05
	_uninstall_part_timer.one_shot = false
	_uninstall_part_timer.timeout.connect(_on_uninstall_part_tick)
	add_child(_uninstall_part_timer)
	_uninstall_part_timer.start()
	return true

func _on_uninstall_part_tick():
	_uninstall_part_progress += 0.05
	if _uninstall_part_arc: _uninstall_part_arc.queue_redraw()
	if _uninstall_part_progress >= 1.0:
		_finish_uninstall_part()

func _finish_uninstall_part():
	if _uninstall_part_timer:
		_uninstall_part_timer.queue_free()
		_uninstall_part_timer = null
	if _uninstall_part_indicator:
		_uninstall_part_indicator.queue_free()
		_uninstall_part_indicator = null
		_uninstall_part_arc = null
	var slot_name = _uninstall_part_target_slot
	_uninstall_part_target_slot = ""
	_uninstall_part_progress = 0.0
	if slot_name != "":
		_do_uninstall_part(slot_name)

func _do_uninstall_part(slot_name: String):
	if not installed_parts.has(slot_name):
		return
	var part = installed_parts[slot_name]
	for slot in get_all_slots():
		if slot.parent_slot_name == slot_name and installed_parts.has(slot.slot_name):
			_do_uninstall_part(slot.slot_name)

	if part.item_data.weapon_part_type == ItemData.WeaponPartType.MAGAZINE:
		_loaded_ammo_dict = {}

	installed_parts.erase(slot_name)
	part._is_equipped = false
	part.visible = true
	part.modulate.a = 1.0
	_update_size()
	_generate_weapon_texture()
	_update_stack_label()
	_place_back_anywhere(part)

func _create_uninstall_part_indicator():
	if _uninstall_part_indicator: return
	_uninstall_part_indicator = Control.new()
	_uninstall_part_indicator.size = size
	_uninstall_part_indicator.position = Vector2.ZERO
	_uninstall_part_indicator.mouse_filter = Control.MOUSE_FILTER_STOP
	_uninstall_part_indicator.z_index = 10
	add_child(_uninstall_part_indicator)
	_uninstall_part_arc = Control.new()
	_uninstall_part_arc.size = size
	_uninstall_part_arc.position = Vector2.ZERO
	_uninstall_part_arc.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_uninstall_part_indicator.add_child(_uninstall_part_arc)
	_uninstall_part_arc.draw.connect(_draw_uninstall_part_arc)

func _draw_uninstall_part_arc():
	if not _uninstall_part_arc or not _uninstall_part_indicator: return
	var progress = _uninstall_part_progress
	var center = _uninstall_part_arc.size / 2.0
	var radius = min(_uninstall_part_arc.size.x, _uninstall_part_arc.size.y) * 0.35
	_uninstall_part_arc.draw_arc(center, radius, -PI/2, -PI/2 + 2*PI*progress, 32, Color.RED, 5.0)
	_uninstall_part_arc.draw_arc(center, radius, -PI/2 + 2*PI*progress, -PI/2 + 2*PI, 32, Color.DIM_GRAY, 5.0)

# ========== 纹理合成（含灰色清理） ==========
func _generate_weapon_texture():
	if not receiver_data:
		return
	var base_tex = receiver_data.icon
	if not base_tex:
		return
	var base_img = base_tex.get_image()
	if base_img.is_compressed():
		base_img.decompress()

	var draw_items = []
	draw_items.append({"img": base_img, "pos": Vector2.ZERO})

	for slot_name in installed_parts:
		var part = installed_parts[slot_name]
		var slot = _find_slot_by_name(slot_name)
		if not slot:
			continue
		var part_tex = part.item_data.model_texture if part.item_data.model_texture else part.item_data.icon
		if not part_tex:
			continue
		var part_img = part_tex.get_image()
		if part_img.is_compressed():
			part_img.decompress()

		# 灰色清理（仅半透明中灰像素）
		for y in range(part_img.get_height()):
			for x in range(part_img.get_width()):
				var pixel = part_img.get_pixel(x, y)
				if pixel.a < 0.5:
					if abs(pixel.r - pixel.g) < 0.05 and abs(pixel.g - pixel.b) < 0.05:
						var luminance = 0.299 * pixel.r + 0.587 * pixel.g + 0.114 * pixel.b
						if luminance > 0.2 and luminance < 0.8:
							part_img.set_pixel(x, y, Color(pixel.r, pixel.g, pixel.b, 0.0))

		if part.item_data.model_size != Vector2.ZERO:
			part_img.resize(
				int(part.item_data.model_size.x),
				int(part.item_data.model_size.y),
				Image.INTERPOLATE_NEAREST
			)
		var part_size = part_img.get_size()
		var pos = slot.mount_offset - part_size / 2.0
		draw_items.append({"img": part_img, "pos": pos})

	var min_x = 0.0
	var min_y = 0.0
	var max_x = base_img.get_width()
	var max_y = base_img.get_height()
	for item in draw_items:
		var p = item["pos"]
		var img = item["img"]
		min_x = min(min_x, p.x)
		min_y = min(min_y, p.y)
		max_x = max(max_x, p.x + img.get_width())
		max_y = max(max_y, p.y + img.get_height())

	var total_w = int(max_x - min_x)
	var total_h = int(max_y - min_y)
	var offset = Vector2(-min_x, -min_y)

	var result = Image.create(total_w, total_h, false, Image.FORMAT_RGBA8)
	result.fill(Color(0, 0, 0, 0))

	var base_dest = Vector2.ZERO + offset
	result.blit_rect(base_img, Rect2i(0, 0, base_img.get_width(), base_img.get_height()), Vector2i(int(base_dest.x), int(base_dest.y)))

	for i in range(1, draw_items.size()):
		var img = draw_items[i]["img"]
		var dest = draw_items[i]["pos"] + offset
		result.blend_rect(img, Rect2i(0, 0, img.get_width(), img.get_height()), Vector2i(int(dest.x), int(dest.y)))

	var icon_node = get_node_or_null("物品图标") as TextureRect
	if icon_node:
		icon_node.texture = ImageTexture.create_from_image(result)

# ========== 堆叠与标签 ==========
func _update_stack_label():
	if not 数量: return
	if not _was_searched:
		数量.hide()
		_update_durability_color()
		return
	if item_data and item_data.weapon_part_type == ItemData.WeaponPartType.RECEIVER:
		var mag = get_equipped_magazine()
		var mag_ammo = mag.item_data.current_ammo if mag else 0
		var mag_max = mag.item_data.magazine_capacity if mag else 0
		var sight_name = ""
		var sight = get_equipped_sight()
		if sight:
			sight_name = " +" + sight.item_data.item_name
		数量.text = "%d | %d/%d%s" % [chambered_round, mag_ammo, mag_max, sight_name]
		数量.show()
	elif item_data and item_data.weapon_part_type == ItemData.WeaponPartType.MAGAZINE:
		数量.text = "%d/%d" % [item_data.current_ammo, item_data.magazine_capacity]
		数量.show()
	elif item_data and item_data.weapon_part_type == ItemData.WeaponPartType.HELMET:
		var total_durability = item_data.helmet_durability
		var visor = get_equipped_part_of_type(ItemData.WeaponPartType.VISOR)
		if visor:
			total_durability += visor.item_data.visor_durability
		数量.text = "耐:%.1f" % total_durability
		数量.show()
	elif item_data and item_data.weapon_part_type == ItemData.WeaponPartType.VISOR:
		数量.text = "耐:%.1f" % item_data.visor_durability
		数量.show()
	elif item_data and item_data.is_medical:
		数量.text = "耐:%.1f" % item_data.medical_durability
		数量.show()
	elif item_data and item_data.is_food_or_drink:
		数量.text = "剩余:%d" % consume_durability
		数量.show()
	elif stack_count > 1:
		数量.text = str(stack_count)
		数量.show()
	else:
		数量.hide()
	_update_durability_color()
	var cell_size = parent_grid.grid_size if parent_grid else 64
	var w = effective_width * cell_size
	var font_size = clamp(w / 4, 8, 12)
	数量.add_theme_font_size_override("font_size", int(font_size))

func _update_durability_color():
	if not 物品图标: return
	var should_be_red = false

	if item_data and item_data.weapon_part_type == ItemData.WeaponPartType.HELMET:
		var durability = item_data.helmet_durability
		var visor = get_equipped_part_of_type(ItemData.WeaponPartType.VISOR)
		if visor:
			durability += visor.item_data.visor_durability
		should_be_red = durability <= 0.0
	elif item_data and item_data.weapon_part_type == ItemData.WeaponPartType.VISOR:
		should_be_red = item_data.visor_durability <= 0.0
	elif item_data and item_data.weapon_part_type == ItemData.WeaponPartType.RECEIVER:
		var has_barrel = false
		var has_grip = false
		for part in installed_parts.values():
			if part.item_data.weapon_part_type == ItemData.WeaponPartType.BARREL:
				has_barrel = true
			elif part.item_data.weapon_part_type == ItemData.WeaponPartType.PISTOL_GRIP:
				has_grip = true
		should_be_red = not (has_barrel and has_grip)

	if should_be_red:
		物品图标.modulate = Color(1.0, 0.0, 0.0)
	else:
		物品图标.modulate = Color.WHITE

func get_texture_without_magazine() -> Texture2D:
	if not receiver_data:
		return null
	var mag_slot = ""
	var saved_mag = null
	for slot_name in installed_parts.keys():
		var part = installed_parts[slot_name]
		if part.item_data.weapon_part_type == ItemData.WeaponPartType.MAGAZINE:
			mag_slot = slot_name
			saved_mag = part
			break
	if mag_slot != "" and saved_mag:
		installed_parts.erase(mag_slot)
		_generate_weapon_texture()
		var tex = 物品图标.texture
		installed_parts[mag_slot] = saved_mag
		_generate_weapon_texture()
		return tex
	else:
		_generate_weapon_texture()
		return 物品图标.texture

func _update_name_label():
	if not 物品名字: return
	if not _was_searched or not item_data:
		物品名字.hide()
		return
	物品名字.text = item_data.item_name
	var cell_size = parent_grid.grid_size if parent_grid else 64
	var w = effective_width * cell_size
	var font_size = clamp(w / 4, 8, 12)
	物品名字.add_theme_font_size_override("font_size", int(font_size))
	物品名字.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	物品名字.custom_minimum_size = Vector2(w - margin * 2, 0)
	物品名字.show()

func can_stack_with(other: InventoryItem) -> bool:
	if not item_data or not other.item_data: return false
	if not is_instance_valid(other): return false
	if not item_data.can_stack or not other.item_data.can_stack: return false
	if item_data.weapon_part_type != ItemData.WeaponPartType.NONE or other.item_data.weapon_part_type != ItemData.WeaponPartType.NONE: return false
	return item_data.item_id == other.item_data.item_id and item_data.item_name == other.item_data.item_name and stack_count < item_data.max_stack and other.stack_count < other.item_data.max_stack

func try_merge(other: InventoryItem) -> int:
	if not can_stack_with(other): return other.stack_count
	var total = stack_count + other.stack_count
	if total <= item_data.max_stack:
		stack_count = total
		other.stack_count = 0
		other.item_data = self.item_data
		other.safe_queue_free()
		_update_stack_label()
		return 0
	else:
		stack_count = item_data.max_stack
		other.stack_count = total - item_data.max_stack
		_update_stack_label()
		return other.stack_count

# ========== 弹药辅助 ==========
func _ammo_dict_total() -> int:
	var total = 0
	for count in _loaded_ammo_dict.values(): total += count
	return total

func add_initial_bullet(bullet_data: ItemData, count: int):
	if item_data.weapon_part_type != ItemData.WeaponPartType.MAGAZINE:
		print("[弹匣] 当前物品不是弹匣，无法填充")
		return
	if bullet_data.weapon_part_type != ItemData.WeaponPartType.NONE:
		print("[弹匣] 非法子弹数据: ", bullet_data.item_name, " 类型: ", bullet_data.weapon_part_type)
		return
	print("[弹匣] 填充子弹: ", bullet_data.item_name, " x", count)
	_loaded_ammo_dict[bullet_data] = _loaded_ammo_dict.get(bullet_data, 0) + count
	item_data.current_ammo += count

func _get_first_bullet_from_mag() -> ItemData:
	if item_data and item_data.weapon_part_type == ItemData.WeaponPartType.MAGAZINE:
		if _loaded_ammo_dict.is_empty():
			return null
		return _loaded_ammo_dict.keys()[0]
	var mag = get_equipped_magazine()
	if mag:
		return mag._get_first_bullet_from_mag()
	return null

func _remove_one_bullet_from_mag(bullet_data: ItemData):
	if item_data and item_data.weapon_part_type == ItemData.WeaponPartType.MAGAZINE:
		if _loaded_ammo_dict.has(bullet_data):
			var count = _loaded_ammo_dict[bullet_data] - 1
			if count <= 0:
				_loaded_ammo_dict.erase(bullet_data)
			else:
				_loaded_ammo_dict[bullet_data] = count
			if item_data:
				item_data.current_ammo = _ammo_dict_total()
		return
	var mag = get_equipped_magazine()
	if mag:
		mag._remove_one_bullet_from_mag(bullet_data)

# ========== 子弹生成（卸弹或退膛时调用） ==========
func _spawn_bullet_with_merge(bullet_data: ItemData, amount: int):
	var tree = get_tree() if is_inside_tree() else null
	if not tree: return
	var remaining = amount
	var grids = tree.get_nodes_in_group("InventoryGrid")
	for grid in grids:
		if not (grid is InventoryGrid): continue
		for item in grid.items:
			if item is InventoryItem and item != self and item.item_data.item_id == bullet_data.item_id and item.item_data.item_name == bullet_data.item_name and item.stack_count < item.item_data.max_stack:
				var space = item.item_data.max_stack - item.stack_count
				var to_move = min(remaining, space)
				item.stack_count += to_move
				item._update_stack_label()
				remaining -= to_move
				if remaining <= 0:
					for g in grids: if g is InventoryGrid: g.queue_redraw()
					return
	while remaining > 0:
		var stack = min(remaining, bullet_data.max_stack)
		var scene = load("res://场景/所有继承场景的父场景/item.tscn")
		var bullet = scene.instantiate()
		bullet.item_data = bullet_data
		bullet.stack_count = stack
		bullet.mark_as_looted()
		var placed = false
		for grid in grids:
			if not (grid is InventoryGrid): continue
			for x in range(grid.columns):
				for y in range(grid.rows):
					if grid._can_place_at(bullet, Vector2i(x, y)):
						grid._place_item(bullet, Vector2i(x, y))
						placed = true
						break
				if placed: break
		if placed:
			remaining -= stack
		else:
			var player = tree.get_first_node_in_group("Player")
			if player:
				var loot = load("res://场景/所有继承场景的父场景/loot_item.tscn").instantiate()
				loot.item_data = bullet_data
				loot.stack_count = stack
				loot.global_position = player.global_position + Vector2(randf_range(-50, 50), randf_range(-50, 50))
				tree.current_scene.add_child(loot)
			bullet.queue_free()
			remaining -= stack
	for grid in grids: if grid is InventoryGrid: grid.queue_redraw()

# ========== 武器兼容方法 ==========
func equip_magazine(mag: InventoryItem) -> bool:
	if not receiver_data:
		if mag.parent_grid and is_instance_valid(mag.parent_grid):
			mag.parent_grid.remove_item(mag)
		mag.queue_free()
		return false
	var mag_slot = _find_slot_by_name("弹匣井")
	if not mag_slot:
		if mag.parent_grid and is_instance_valid(mag.parent_grid):
			mag.parent_grid.remove_item(mag)
		mag.queue_free()
		return false
	_do_install_part(mag, mag_slot.slot_name)
	return true

func unequip_magazine():
	var mag = get_equipped_magazine()
	if mag:
		var slot_name = null
		for slot in installed_parts:
			if installed_parts[slot] == mag:
				slot_name = slot
				break
		if slot_name:
			start_uninstall_part(slot_name)

func equip_sight(sight: InventoryItem):
	if receiver_data:
		var sight_slot = _find_slot_by_name("瞄具导轨")
		if sight_slot:
			start_install_part(sight, sight_slot.slot_name)
			return
	if sight.parent_grid: sight.parent_grid.remove_item(sight)
	sight.queue_free()

func unequip_sight():
	var sight = get_equipped_sight()
	if sight:
		var slot_name = null
		for slot in installed_parts:
			if installed_parts[slot] == sight:
				slot_name = slot
				break
		if slot_name:
			start_uninstall_part(slot_name)

# ========== 武器开火相关 ==========
func _weapon_chamber_round(bullet: InventoryItem) -> bool:
	if bullet.item_data.ammo_type == "": return false
	if bullet.item_data.ammo_type != item_data.ammo_type: return false
	if chambered_round > 0: return false
	if bullet.stack_count <= 0: return false
	if bullet.get_parent(): bullet.get_parent().remove_child(bullet)
	bullet.stack_count -= 1
	if bullet.stack_count <= 0:
		bullet.queue_free()
	else:
		bullet._update_stack_label()
		if not _place_back_anywhere(bullet): bullet.queue_free()
	chambered_round = 1
	_update_stack_label()
	return true

func unload_chamber():
	if chambered_round <= 0 or receiver_data == null: return
	chambered_round = 0
	if _chambered_bullet_data:
		_spawn_bullet_with_merge(_chambered_bullet_data, 1)
	_chambered_bullet_data = null
	_update_stack_label()

# ========== 弹匣压弹/卸弹 ==========
func start_loading_ammo(bullet: InventoryItem) -> bool:
	if _loading_ammo or _unloading_ammo:
		print("[压弹] 弹匣正在忙碌")
		return false
	if item_data.weapon_part_type != ItemData.WeaponPartType.MAGAZINE:
		print("[压弹] 目标不是弹匣")
		return false
	_cleanup_invalid_bullets()
	if bullet.item_data.weapon_part_type != ItemData.WeaponPartType.NONE:
		print("[压弹] 子弹类型错误: ", bullet.item_data.item_name, " 类型: ", bullet.item_data.weapon_part_type)
		return false
	if bullet.item_data.ammo_type != item_data.ammo_type:
		print("[压弹] 弹药类型不匹配，子弹: ", bullet.item_data.ammo_type, " 弹匣: ", item_data.ammo_type)
		return false
	var needed = item_data.magazine_capacity - item_data.current_ammo
	if needed <= 0:
		print("[压弹] 弹匣已满")
		return false
	_total_rounds_to_load = min(needed, bullet.stack_count)
	if _total_rounds_to_load <= 0:
		print("[压弹] 没有子弹可压")
		return false

	if bullet.get_parent() and bullet.get_parent().name == "DragLayer":
		bullet.get_parent().remove_child(bullet)
	bullet.visible = false

	_loading_ammo = true
	_load_bullet = bullet
	_loaded_rounds = 0
	_loading_bullet_type = bullet.item_data
	bullet._is_being_loaded = true

	print("[压弹] 开始压弹: ", bullet.item_data.item_name, " x", _total_rounds_to_load)

	if bullet.stack_count > _total_rounds_to_load:
		var extra = bullet.stack_count - _total_rounds_to_load
		bullet.stack_count = _total_rounds_to_load
		bullet._update_stack_label()
		var extra_bullet = _create_remainder_item(extra, bullet.item_data)
		if extra_bullet:
			if not _place_item_in_any_grid(extra_bullet): extra_bullet.queue_free()

	bullet._update_stack_label()
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
	_load_indicator.z_index = 10
	add_child(_load_indicator)
	_arc_draw_control = Control.new()
	_arc_draw_control.size = size
	_arc_draw_control.position = Vector2.ZERO
	_arc_draw_control.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_load_indicator.add_child(_arc_draw_control)
	_arc_draw_control.draw.connect(_draw_loading_arc)
	_cancel_button = Button.new()
	_cancel_button.text = "X"; _cancel_button.flat = true
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
	_arc_draw_control.draw_arc(center, radius, deg_to_rad(-90), deg_to_rad(-90 + 360 * progress), 32, Color.GREEN, 5.0)
	_arc_draw_control.draw_arc(center, radius, deg_to_rad(-90 + 360 * progress), deg_to_rad(270), 32, Color.DIM_GRAY, 5.0)

func _on_load_tick():
	_loaded_rounds += 1
	if _arc_draw_control: _arc_draw_control.queue_redraw()
	if is_instance_valid(_load_bullet):
		_load_bullet.stack_count -= 1
		_load_bullet._update_stack_label()
		if _load_bullet.stack_count <= 0:
			_load_bullet.safe_queue_free()
			_load_bullet = null
	if _loading_bullet_type:
		var cur = _loaded_ammo_dict.get(_loading_bullet_type, 0)
		_loaded_ammo_dict[_loading_bullet_type] = cur + 1
		print("[压弹] 已压入 1 发: ", _loading_bullet_type.item_name, "，当前弹匣弹药: ", item_data.current_ammo + 1)
	item_data.current_ammo += 1
	_update_stack_label()
	if _loaded_rounds >= _total_rounds_to_load:
		_finish_loading()

func _finish_loading():
	_loading_ammo = false
	if _load_timer: _load_timer.queue_free(); _load_timer = null
	if _load_indicator: _load_indicator.queue_free(); _load_indicator = null
	_arc_draw_control = null; _cancel_button = null
	if is_instance_valid(_load_bullet):
		_load_bullet._is_being_loaded = false
		if _load_bullet.stack_count > 0:
			_load_bullet.visible = true
			if not _place_back_anywhere(_load_bullet):
				_load_bullet.queue_free()
		else:
			_load_bullet.queue_free()
		_load_bullet = null
	_loading_bullet_type = null
	_update_stack_label()

func _cancel_loading():
	if not _loading_ammo: return
	_loading_ammo = false
	if _load_timer: _load_timer.queue_free(); _load_timer = null
	if _load_indicator: _load_indicator.queue_free(); _load_indicator = null
	_arc_draw_control = null; _cancel_button = null
	if _loading_bullet_type and _loaded_rounds > 0:
		var cur = _loaded_ammo_dict.get(_loading_bullet_type, 0) - _loaded_rounds
		if cur <= 0: _loaded_ammo_dict.erase(_loading_bullet_type)
		else: _loaded_ammo_dict[_loading_bullet_type] = cur
	item_data.current_ammo -= _loaded_rounds
	if is_instance_valid(_load_bullet):
		_load_bullet.stack_count = _total_rounds_to_load
		_load_bullet._update_stack_label()
		_load_bullet._is_being_loaded = false
		_load_bullet.visible = true
		if not _place_back_anywhere(_load_bullet):
			_load_bullet.queue_free()
		_load_bullet = null
	_loading_bullet_type = null
	_update_stack_label()

# ========== 卸出弹匣弹药 ==========
func unload_magazine_ammo():
	if item_data.weapon_part_type != ItemData.WeaponPartType.MAGAZINE: return
	if item_data.current_ammo <= 0: return
	if _loading_ammo or _unloading_ammo: return
	_unload_remaining_dict = _loaded_ammo_dict.duplicate()
	_unload_total_count = item_data.current_ammo
	_unload_current_count = 0
	_unloading_ammo = true
	_create_unload_indicator()
	_unload_timer = Timer.new()
	_unload_timer.wait_time = LOAD_TIME_PER_ROUND
	_unload_timer.one_shot = false
	_unload_timer.timeout.connect(_on_unload_tick)
	add_child(_unload_timer)
	_unload_timer.start()

func _create_unload_indicator():
	if _unload_indicator: return
	_unload_indicator = Control.new()
	_unload_indicator.size = size; _unload_indicator.position = Vector2.ZERO
	_unload_indicator.mouse_filter = Control.MOUSE_FILTER_STOP
	_unload_indicator.z_index = 10
	add_child(_unload_indicator)
	_unload_arc = Control.new()
	_unload_arc.size = size; _unload_arc.position = Vector2.ZERO
	_unload_arc.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_unload_indicator.add_child(_unload_arc)
	_unload_arc.draw.connect(_draw_unload_arc)
	_unload_cancel_button = Button.new()
	_unload_cancel_button.text = "X"; _unload_cancel_button.flat = true
	var btn_size = 40
	_unload_cancel_button.size = Vector2(btn_size, btn_size)
	_unload_cancel_button.position = (size - Vector2(btn_size, btn_size)) / 2.0
	_unload_cancel_button.add_theme_color_override("font_color", Color.RED)
	_unload_cancel_button.add_theme_font_size_override("font_size", 20)
	_unload_cancel_button.pressed.connect(_cancel_unloading)
	_unload_indicator.add_child(_unload_cancel_button)

func _draw_unload_arc():
	if not _unloading_ammo or not _unload_arc: return
	var progress = float(_unload_current_count) / float(_unload_total_count)
	var center = _unload_arc.size / 2.0
	var radius = min(_unload_arc.size.x, _unload_arc.size.y) * 0.35
	_unload_arc.draw_arc(center, radius, deg_to_rad(-90), deg_to_rad(-90 + 360 * progress), 32, Color.ORANGE, 5.0)
	_unload_arc.draw_arc(center, radius, deg_to_rad(-90 + 360 * progress), deg_to_rad(270), 32, Color.DIM_GRAY, 5.0)

func _on_unload_tick():
	if _unload_remaining_dict.is_empty(): _finish_unloading(); return
	var bullet_data: ItemData = _unload_remaining_dict.keys()[0]
	var count_left = _unload_remaining_dict[bullet_data]
	_spawn_bullet_with_merge(bullet_data, 1)
	count_left -= 1
	if count_left <= 0: _unload_remaining_dict.erase(bullet_data)
	else: _unload_remaining_dict[bullet_data] = count_left
	item_data.current_ammo -= 1
	var real_count = _loaded_ammo_dict.get(bullet_data, 0) - 1
	if real_count <= 0: _loaded_ammo_dict.erase(bullet_data)
	else: _loaded_ammo_dict[bullet_data] = real_count
	_unload_current_count += 1
	if _unload_arc: _unload_arc.queue_redraw()
	_update_stack_label()
	if _unload_remaining_dict.is_empty(): _finish_unloading()

func _finish_unloading():
	_unloading_ammo = false
	if _unload_timer: _unload_timer.queue_free(); _unload_timer = null
	if _unload_indicator: _unload_indicator.queue_free(); _unload_indicator = null
	_unload_arc = null; _unload_cancel_button = null
	_unload_remaining_dict.clear()
	_update_stack_label()

func _cancel_unloading():
	if not _unloading_ammo: return
	_unloading_ammo = false
	if _unload_timer: _unload_timer.queue_free(); _unload_timer = null
	if _unload_indicator: _unload_indicator.queue_free(); _unload_indicator = null
	_unload_arc = null; _unload_cancel_button = null
	_unload_remaining_dict.clear()
	_update_stack_label()

# ========== 进度显示 ==========
func show_progress(show: bool):
	_progress_visible = show
	if show: _progress_value = 0.0
	queue_redraw()

func update_progress(value: float):
	_progress_value = value
	queue_redraw()

func show_medical_progress(show: bool, initial_value: float = 0.0):
	_medical_progress_shown = show
	if show:
		if not _progress_layer:
			_create_progress_layer()
		_progress_value = initial_value
		_progress_layer.queue_redraw()
		_progress_layer.visible = true
	else:
		if _progress_layer:
			_progress_layer.visible = false

func update_medical_progress(value: float):
	if _medical_progress_shown:
		_progress_value = clamp(value, 0.0, 1.0)
		if _progress_layer:
			_progress_layer.queue_redraw()

func _create_progress_layer():
	_progress_layer = Control.new()
	_progress_layer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_progress_layer.z_index = 10
	add_child(_progress_layer)
	_progress_layer.draw.connect(_draw_progress)
	_progress_layer.size = size
	_progress_layer.position = Vector2.ZERO

func _draw_progress():
	if not _medical_progress_shown: return
	var center = size / 2
	var radius = min(size.x, size.y) * 0.35
	var from_angle = -PI / 2
	var to_angle = from_angle + 2 * PI * _progress_value
	_progress_layer.draw_arc(center, radius, from_angle, to_angle, 32, Color.GREEN, 5.0)
	_progress_layer.draw_arc(center, radius, to_angle, from_angle + 2 * PI, 32, Color.DIM_GRAY, 5.0)

func reduce_consume_durability(amount: float = 1.0):
	if not item_data.is_food_or_drink: return
	consume_durability -= amount
	if consume_durability <= 0.001:
		consume_durability = 0
		stack_count -= 1
		if stack_count <= 0:
			queue_free()
		else:
			consume_durability = item_data.consume_durability if item_data else 0.0
			_update_stack_label()
	else:
		_update_stack_label()

# ========== 外部进度指示器 ==========
func show_external_progress(total: int):
	_external_total = total; _external_loaded = 0
	if _external_indicator: _hide_external_indicator()
	_external_indicator = Control.new()
	_external_indicator.size = size; _external_indicator.position = Vector2.ZERO
	_external_indicator.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_external_indicator)
	_external_arc = Control.new()
	_external_arc.size = size; _external_arc.position = Vector2.ZERO
	_external_arc.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_external_indicator.add_child(_external_arc)
	_external_arc.draw.connect(_draw_external_arc)
	_external_arc.queue_redraw()

func update_external_progress(loaded: int):
	_external_loaded = loaded
	if _external_arc: _external_arc.queue_redraw()

func hide_external_progress():
	_hide_external_indicator()

func _hide_external_indicator():
	if _external_indicator:
		_external_indicator.queue_free()
		_external_indicator = null
		_external_arc = null
	_external_total = 0; _external_loaded = 0

func _draw_external_arc():
	if not _external_arc or _external_total <= 0: return
	var progress = float(_external_loaded) / float(_external_total)
	var center = _external_arc.size / 2.0
	var radius = min(_external_arc.size.x, _external_arc.size.y) * 0.35
	_external_arc.draw_arc(center, radius, deg_to_rad(-90), deg_to_rad(-90 + 360 * progress), 32, Color.GREEN, 5.0)
	_external_arc.draw_arc(center, radius, deg_to_rad(-90 + 360 * progress), deg_to_rad(270), 32, Color.DIM_GRAY, 5.0)

# ========== 搜索与视觉 ==========
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
	is_searching = false
	_was_searched = true
	if _search_indicator: _search_indicator.queue_free(); _search_indicator = null
	if _search_timer: _search_timer.queue_free(); _search_timer = null
	if not is_dragging: set_process(false)
	if 物品图标 and is_instance_valid(物品图标):
		var tween = create_tween()
		tween.set_trans(Tween.TRANS_BACK)
		tween.set_ease(Tween.EASE_OUT)
		tween.tween_property(物品图标, "scale", Vector2(search_complete_scale, search_complete_scale), search_complete_duration)
		tween.tween_property(物品图标, "scale", Vector2(1.0, 1.0), search_complete_duration)
	update_search_visuals()
	search_finished.emit()

func mark_as_looted():
	_was_searched = true; is_searching = false
	if _search_indicator: _search_indicator.queue_free(); _search_indicator = null
	if _search_timer: _search_timer.queue_free(); _search_timer = null
	set_process(false); update_search_visuals(); show()

func _create_circle_texture(s: int, c: Color) -> ImageTexture:
	var img = Image.create(s, s, false, Image.FORMAT_RGBA8)
	img.fill(Color(0,0,0,0))
	var center = s / 2.0; var radius = s / 2.0 - 2.0
	for x in range(s):
		for y in range(s):
			if Vector2(x - center, y - center).length() <= radius:
				img.set_pixel(x, y, c)
	return ImageTexture.create_from_image(img)

# ========== 交互：输入处理 ==========
func _input(event):
	if Engine.is_editor_hint(): return
	var mouse_pos = get_global_mouse_position()

	for drag_info in _draggable_panels:
		var panel = drag_info.panel
		var title_bar = drag_info.title_bar
		if not is_instance_valid(panel) or not is_instance_valid(title_bar):
			_draggable_panels.erase(drag_info)
			continue
		if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
			if event.pressed:
				var title_rect = Rect2(title_bar.global_position, title_bar.size)
				if title_rect.has_point(mouse_pos):
					drag_info.active = true
					drag_info.offset = panel.global_position - mouse_pos
			else:
				drag_info.active = false
		if event is InputEventMouseMotion and drag_info.get("active", false):
			panel.global_position = mouse_pos + drag_info.offset
			accept_event()

	if event is InputEventMouseMotion and dragged_item and is_instance_valid(dragged_item):
		if dragged_item.item_data.weapon_part_type != ItemData.WeaponPartType.NONE:
			for drag_info in _draggable_panels:
				var panel = drag_info.panel
				if not is_instance_valid(panel): continue
				var slot_containers = panel.get_meta("slot_icons", [])
				for container in slot_containers:
					if is_instance_valid(container) and container is Control:
						if container.get_global_rect().has_point(mouse_pos):
							container.self_modulate = Color.GREEN
						else:
							container.self_modulate = Color.WHITE

	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and not event.pressed:
		if dragged_item and is_instance_valid(dragged_item):
			var handled = false
			for drag_info in _draggable_panels:
				var panel = drag_info.panel
				if not is_instance_valid(panel): continue
				var canvas = panel.get_parent()
				if not canvas or not canvas is CanvasLayer: continue
				var weapon_item = canvas.get_meta("weapon_item", null)
				if not weapon_item or not is_instance_valid(weapon_item): continue
				var slot_containers = panel.get_meta("slot_icons", [])
				for container in slot_containers:
					if is_instance_valid(container) and container is Control:
						if container.get_global_rect().has_point(mouse_pos):
							var slot_name = container.get_meta("slot_name", "")
							if slot_name != "":
								if weapon_item.start_install_part(dragged_item, slot_name):
									handled = true
									break
				if handled: break

			for drag_info in _draggable_panels:
				var panel = drag_info.panel
				if is_instance_valid(panel):
					var slot_containers = panel.get_meta("slot_icons", [])
					for container in slot_containers:
						if is_instance_valid(container): container.self_modulate = Color.WHITE

			if handled:
				is_dragging = false
				set_process(false)
				dragged_item = null
				accept_event()
				return
			else:
				_stop_drag()

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
	if _is_equipped:
		if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_RIGHT and event.pressed:
			_show_context_menu()
			accept_event()
			return
		if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
			return
	if not _was_searched: return

	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		if event.double_click:
			if item_data and item_data.is_backpack:
				var ui = get_tree().get_first_node_in_group("InventoryUI")
				if ui and ui.has_method("show_backpack_item"):
					ui.show_backpack_item(self)
					accept_event()
					return
		if Input.is_key_pressed(KEY_CTRL):
			_quick_transfer()
		else:
			_start_drag()
		accept_event()
		return
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_RIGHT:
		if event.pressed and not is_dragging:
			_show_context_menu()
			accept_event()

# ========== 快速转移 ==========
func _quick_transfer():
	if not is_inside_tree(): return
	var tree = get_tree()
	if not tree: return
	var ui = tree.get_first_node_in_group("InventoryUI")
	if not ui: return
	var container_grid = ui.active_container_grid
	var original_grid = parent_grid
	var original_pos = grid_pos

	if parent_grid == container_grid:
		var player = tree.get_first_node_in_group("Player")
		if not player: return
		var player_grids = _get_player_grids_by_preference(player)
		for g in player_grids:
			if g and g != parent_grid:
				if _try_place_in_grid(g): return
	else:
		if container_grid:
			if _try_place_in_grid(container_grid): return

	if original_grid and original_pos != Vector2i(-1, -1):
		if original_grid._can_place_at(self, original_pos):
			original_grid._place_item(self, original_pos)
		else:
			original_grid.force_place_item(self, original_pos)
	elif original_grid:
		for x in range(original_grid.columns):
			for y in range(original_grid.rows):
				var pos = Vector2i(x, y)
				if original_grid._can_place_at(self, pos):
					original_grid._place_item(self, pos)
					break

func _try_place_in_grid(grid: InventoryGrid) -> bool:
	if _is_host_type(self.item_data):
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

	if self.item_data.weapon_part_type != ItemData.WeaponPartType.NONE:
		for target_item in grid.items:
			if target_item is InventoryItem and target_item != self and _is_host_type(target_item.item_data):
				var available_slots = target_item.get_available_slots()
				for slot in available_slots:
					if slot.slot_type == self.item_data.weapon_part_type:
						if target_item.start_install_part(self, slot.slot_name):
							return true
		for x in range(grid.columns):
			for y in range(grid.rows):
				var pos = Vector2i(x, y)
				if grid._can_place_at(self, pos):
					_move_to_grid(grid, pos)
					return true
		return false

	for target_item in grid.items:
		if target_item is InventoryItem and target_item != self:
			if _is_host_type(target_item.item_data):
				if self.item_data.weapon_part_type == ItemData.WeaponPartType.NONE and self.item_data.ammo_type != "":
					if target_item._weapon_chamber_round(self):
						return true
			elif target_item.item_data.weapon_part_type == ItemData.WeaponPartType.MAGAZINE:
				if self.item_data.weapon_part_type == ItemData.WeaponPartType.NONE:
					if not target_item._loading_ammo and not target_item._unloading_ammo:
						if target_item.start_loading_ammo(self):
							return true

	for item in grid.items:
		if item is InventoryItem and item != self and item.can_stack_with(self):
			var remaining = item.try_merge(self)
			if remaining > 0:
				var new_item = _create_remainder_item(remaining, self.item_data)
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
	if parent_grid: parent_grid.remove_item(self)
	new_grid._place_item(self, pos)

func _get_player_grids_by_preference(player: PlayerCharacter) -> Array:
	var ui = player.inventory_ui
	var pref = item_data.preferred_slot
	match pref:
		ItemData.SlotPreference.POCKET: return [ui.口袋网格, ui.胸挂网格, ui.背包网格]
		ItemData.SlotPreference.VEST: return [ui.胸挂网格, ui.口袋网格, ui.背包网格]
		ItemData.SlotPreference.BACKPACK: return [ui.背包网格, ui.胸挂网格, ui.口袋网格]
		_: return [ui.口袋网格, ui.胸挂网格, ui.背包网格]

# ========== 拖拽 ==========
func _start_drag():
	if _is_equipped: return
	if not _was_searched: return
	if _is_being_loaded or _loading_ammo or _unloading_ammo: return
	if not is_inside_tree(): return
	dragged_item = self
	is_dragging = true; set_process(true)
	_drag_offset = Vector2.ZERO
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
	if not is_inside_tree(): return
	dragged_item = null
	is_dragging = false

	# ★ 清除所有网格的拖拽预览状态，防止粉色高亮残留
	_clear_all_grid_preview()

	# 检测是否拖到了某个背包物品上（或背包装备槽）
	var mouse_pos = get_global_mouse_position()
	var backpack_target: InventoryItem = null

	# 检查所有网格中的背包物品
	for grid in get_tree().get_nodes_in_group("InventoryGrid"):
		if not (grid is InventoryGrid): continue
		for item in grid.items:
			if item is InventoryItem and item != self and item.item_data.is_backpack:
				if item.get_global_rect().has_point(mouse_pos):
					backpack_target = item
					break
		if backpack_target: break

	# 如果没找到，检查玩家背包装备槽
	if backpack_target == null:
		var player = get_tree().get_first_node_in_group("Player")
		if player and player.equipped_backpack_item and player.equipped_backpack_item != self:
			var ui = player.inventory_ui
			if ui and ui.背包装备槽:
				if ui.背包装备槽.get_global_rect().has_point(mouse_pos):
					backpack_target = player.equipped_backpack_item

	# 如果找到背包目标，尝试放入
	if backpack_target:
		if backpack_target.try_add_to_backpack(self):
			# 放入成功，无需继续下面的普通放置逻辑
			return
		# 放入失败，继续普通放置（可提示玩家空间不足）

	# 清理无效物品
	var grids = get_tree().get_nodes_in_group("InventoryGrid")
	for g in grids:
		if g is InventoryGrid: g._cleanup_invalid_items()
	var landed = false
	var player = get_tree().get_first_node_in_group("Player")
	var ui = get_tree().get_first_node_in_group("InventoryUI")

	# 武器拖到装备槽
	if ui and item_data.weapon_part_type == ItemData.WeaponPartType.RECEIVER:
		var slot_rect_primary = ui.主武器装备槽.get_global_rect() if ui.主武器装备槽 else null
		var slot_rect_secondary = ui.副武器装备槽.get_global_rect() if ui.副武器装备槽 else null
		var target_slot = ""
		if slot_rect_primary and slot_rect_primary.has_point(mouse_pos):
			target_slot = "primary"
		elif slot_rect_secondary and slot_rect_secondary.has_point(mouse_pos):
			target_slot = "secondary"
		if target_slot != "":
			if player and player.has_method("store_and_equip_weapon"):
				var equip_success = player.store_and_equip_weapon(self, target_slot)
				if equip_success:
					landed = true
					_was_equipped = false
					if get_parent():
						get_parent().remove_child(self)
					return

	# 头盔拖到头盔装备槽
	if ui and item_data.weapon_part_type == ItemData.WeaponPartType.HELMET and player:
		var helmet_rect = ui.头盔装备槽.get_global_rect() if ui.头盔装备槽 else null
		if helmet_rect and helmet_rect.has_point(mouse_pos):
			if player.has_method("equip_helmet"):
				var equip_success = player.equip_helmet(self)
				if equip_success:
					landed = true
					_was_equipped = false
					if get_parent():
						get_parent().remove_child(self)
					return

	# 背包拖到背包装备槽
	if ui and item_data.is_backpack and player:
		var backpack_rect = ui.背包装备槽.get_global_rect() if ui.背包装备槽 else null
		if backpack_rect and backpack_rect.has_point(mouse_pos):
			if player.has_method("equip_backpack"):
				var equip_success = player.equip_backpack(self)
				if equip_success:
					landed = true
					_was_equipped = false
					if get_parent():
						get_parent().remove_child(self)
					return

	# 普通网格拖拽
	for grid in grids:
		if not (grid is Control): continue
		if not grid.get_global_rect().has_point(mouse_pos): continue
		var target_pos = grid._get_grid_pos_at_mouse()
		var target_item = null
		if target_pos.x >= 0 and target_pos.y >= 0:
			target_item = grid.occupied[target_pos.x][target_pos.y]

		# 拖拽配件到主机
		if target_item is InventoryItem and target_item != self and _is_host_type(target_item.item_data):
			if self.item_data.weapon_part_type != ItemData.WeaponPartType.NONE:
				var available_slots = target_item.get_available_slots()
				for slot in available_slots:
					if slot.slot_type == self.item_data.weapon_part_type:
						if target_item.start_install_part(self, slot.slot_name):
							landed = true
							break
				if landed: break

		# 拖拽主机到空地
		if _is_host_type(self.item_data) and not landed:
			if target_item == null:
				if grid._can_place_at(self, target_pos):
					grid._place_item(self, target_pos)
					landed = true
				else:
					if item_data.can_rotate:
						is_rotated = not is_rotated
						_update_size()
						if grid._can_place_at(self, target_pos):
							grid._place_item(self, target_pos)
							landed = true
						else:
							is_rotated = not is_rotated
							_update_size()
			if landed: break

		# 子弹或压弹
		if target_item is InventoryItem and target_item != self:
			if _is_host_type(target_item.item_data):
				if self.item_data.weapon_part_type == ItemData.WeaponPartType.NONE and self.item_data.ammo_type != "":
					if target_item._weapon_chamber_round(self):
						if stack_count > 0: _place_item_anywhere()
						landed = true
						break
			elif target_item.item_data.weapon_part_type == ItemData.WeaponPartType.MAGAZINE:
				if self.item_data.weapon_part_type == ItemData.WeaponPartType.NONE:
					if not target_item._loading_ammo and not target_item._unloading_ammo:
						if target_item.start_loading_ammo(self):
							landed = true
							break

		# 堆叠
		if target_item is InventoryItem and target_item != self and target_item.can_stack_with(self):
			var remaining = target_item.try_merge(self)
			if remaining > 0:
				var new_item = _create_remainder_item(remaining, self.item_data)
				if new_item:
					if not _place_item_in_any_grid(new_item):
						new_item.queue_free()
			landed = true
			break

		# 普通放置
		if grid.try_place_item(self):
			landed = true
			break
		else:
			for x in range(grid.columns):
				for y in range(grid.rows):
					var pos = Vector2i(x, y)
					if grid._can_place_at(self, pos):
						grid._place_item(self, pos)
						landed = true
						break
				if landed: break
			if not landed and item_data and item_data.can_rotate:
				is_rotated = not is_rotated
				_update_size()
				for x in range(grid.columns):
					for y in range(grid.rows):
						var pos = Vector2i(x, y)
						if grid._can_place_at(self, pos):
							grid._place_item(self, pos)
							landed = true
							break
					if landed: break
				if not landed:
					is_rotated = not is_rotated
					_update_size()
			if landed: break

	# 曾是装备的武器且未放置
	if not landed and _was_equipped:
		if item_data.weapon_part_type == ItemData.WeaponPartType.RECEIVER and player:
			if not player.primary_weapon_item:
				if player.store_and_equip_weapon(self, "primary"):
					_was_equipped = false
					if get_parent(): get_parent().remove_child(self)
					return
			elif not player.secondary_weapon_item:
				if player.store_and_equip_weapon(self, "secondary"):
					_was_equipped = false
					if get_parent(): get_parent().remove_child(self)
					return
		elif item_data.weapon_part_type == ItemData.WeaponPartType.HELMET and player and not player.equipped_helmet_item:
			if player.equip_helmet(self):
				_was_equipped = false
				if get_parent(): get_parent().remove_child(self)
				return
		elif item_data.is_backpack and player and not player.equipped_backpack_item:
			if player.equip_backpack(self):
				_was_equipped = false
				if get_parent(): get_parent().remove_child(self)
				return

	# 无处可放，回退
	if not landed:
		if _previous_grid and _previous_pos != Vector2i(-1, -1):
			if _previous_grid._can_place_at(self, _previous_pos):
				_previous_grid._place_item(self, _previous_pos)
			else:
				_previous_grid.force_place_item(self, _previous_pos)
		else:
			_place_item_anywhere()

	# 底座且无父网格且未装备则丢弃
	if _is_host_type(self.item_data) and not parent_grid and not _was_equipped:
		_discard_item()
		queue_free()
		return

	if is_searching:
		update_search_visuals()
		if _search_indicator: _search_indicator.show()
	else:
		update_search_visuals()
	if not is_searching and not is_dragging:
		set_process(false)

func _create_remainder_item(count: int, data: ItemData) -> InventoryItem:
	var scene = load("res://场景/所有继承场景的父场景/item.tscn")
	var item = scene.instantiate()
	item.item_data = data; item.stack_count = count
	item.mark_as_looted(); item._update_stack_label()
	return item

func _place_item_in_any_grid(item: InventoryItem) -> bool:
	if not is_inside_tree(): return false
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
	if not is_inside_tree(): return
	var grids = get_tree().get_nodes_in_group("InventoryGrid")
	for grid in grids:
		if not (grid is Control): continue
		for x in range(grid.columns):
			for y in range(grid.rows):
				var pos = Vector2i(x, y)
				if grid._can_place_at(self, pos):
					grid._place_item(self, pos)
					return
	if _previous_grid: _previous_grid.force_place_item(self, _previous_pos)

func _process(delta):
	if is_dragging:
		global_position = get_global_mouse_position() - _drag_offset
	if is_searching and _search_indicator:
		_search_angle += delta * search_speed
		var center = size / 2.0
		var offset = Vector2(cos(_search_angle), sin(_search_angle)) * search_radius
		_search_indicator.position = center + offset - _search_indicator.size / 2.0

func _rotate():
	if not item_data.can_rotate: return
	is_rotated = not is_rotated
	物品图标.rotation = PI / 2.0 if is_rotated else 0.0
	_update_size()
	if parent_grid and grid_pos != Vector2i(-1, -1):
		if not parent_grid._can_place_at(self, grid_pos):
			is_rotated = not is_rotated
			物品图标.rotation = PI / 2.0 if is_rotated else 0.0
			_update_size()
		else:
			parent_grid.update_item_rotation(self)

func _exit_tree():
	if parent_grid and parent_grid.items.has(self):
		parent_grid.remove_item(self)

# ========== 右键菜单 ==========
func _show_context_menu():
	if _is_being_loaded or _loading_ammo or _unloading_ammo: return
	if not is_inside_tree(): return
	var tree = get_tree()
	if not tree: return
	var overlay = ColorRect.new()
	overlay.color = Color(0, 0, 0, 0.01)
	overlay.size = get_viewport().get_visible_rect().size
	overlay.position = Vector2.ZERO
	overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	overlay.gui_input.connect(_on_menu_close_click.bind(overlay))
	var menu = VBoxContainer.new()
	menu.name = "ItemContextMenu"
	menu.add_theme_constant_override("separation", 2)
	var btn_discard = _create_menu_button("丢弃", Callable(self, "_on_discard_pressed").bind(menu, overlay))
	var btn_inspect = _create_menu_button("查看", Callable(self, "_on_inspect_pressed").bind(menu, overlay))
	var btn_unload_ammo = _create_menu_button("卸下弹药", Callable(self, "_on_unload_magazine_ammo_pressed").bind(menu, overlay))
	var btn_unload_part = _create_menu_button("卸下配件", Callable(self, "_on_unload_part_pressed").bind(menu, overlay))
	var btn_use = _create_menu_button("使用", Callable(self, "_on_use_pressed").bind(menu, overlay))
	btn_use.visible = (item_data.is_medical and not _is_equipped) or (item_data.is_food_or_drink and not _is_equipped)
	var btn_equip_sight = _create_menu_button("装备瞄具", Callable(self, "_on_equip_sight_pressed").bind(menu, overlay))
	btn_equip_sight.visible = item_data.weapon_part_type == ItemData.WeaponPartType.SIGHT and not _is_equipped
	var btn_unequip_sight = _create_menu_button("卸下瞄具", Callable(self, "_on_unequip_sight_pressed").bind(menu, overlay))
	btn_unequip_sight.visible = receiver_data != null and get_equipped_sight() != null
	var player = tree.get_first_node_in_group("Player")
	var btn_equip = _create_menu_button("装备武器", Callable(self, "_on_equip_weapon_pressed").bind(menu, overlay))
	btn_equip.visible = item_data.weapon_part_type == ItemData.WeaponPartType.RECEIVER and not _is_equipped and player and not player.equipped_weapon_item
	menu.add_child(btn_equip)
	var btn_unequip = _create_menu_button("卸下武器", Callable(self, "_on_unequip_weapon_pressed").bind(menu, overlay))
	btn_unequip.visible = _is_equipped
	menu.add_child(btn_unequip)
	btn_discard.visible = true
	btn_inspect.visible = true
	btn_unload_ammo.visible = item_data.weapon_part_type == ItemData.WeaponPartType.MAGAZINE and item_data.current_ammo > 0 and not _unloading_ammo
	btn_unload_part.visible = receiver_data != null and installed_parts.size() > 0
	menu.add_child(btn_discard)
	menu.add_child(btn_inspect)
	menu.add_child(btn_equip_sight)
	menu.add_child(btn_unequip_sight)
	menu.add_child(btn_unload_ammo)
	menu.add_child(btn_unload_part)
	menu.add_child(btn_use)
	var canvas = tree.root.get_node_or_null("ContextMenuLayer")
	if not canvas:
		canvas = CanvasLayer.new(); canvas.name = "ContextMenuLayer"; canvas.layer = 200
		tree.root.add_child(canvas)
	canvas.add_child(overlay)
	canvas.add_child(menu)
	menu.global_position = get_global_mouse_position()
	menu.gui_input.connect(_on_menu_blank_clicked.bind(menu, overlay))

func _on_menu_close_click(event: InputEvent, overlay: Control):
	if event is InputEventMouseButton and event.pressed:
		var menu = null
		for child in overlay.get_parent().get_children():
			if child is VBoxContainer and child.name == "ItemContextMenu":
				menu = child
				break
		_close_context_menu(overlay, menu)

func _on_menu_blank_clicked(event: InputEvent, menu: Control, overlay: ColorRect):
	if event is InputEventMouseButton and event.pressed:
		if event.button_index == MOUSE_BUTTON_LEFT:
			_close_context_menu(overlay, menu)

func _create_menu_button(text: String, callback: Callable) -> Button:
	var btn = Button.new()
	btn.text = text
	btn.pressed.connect(callback)
	btn.custom_minimum_size = Vector2(120, 30)
	return btn

func _close_context_menu(overlay, menu):
	if is_instance_valid(overlay): overlay.queue_free()
	if is_instance_valid(menu): menu.queue_free()

func _on_discard_pressed(menu: Control, overlay: Control):
	_discard_item()
	_close_context_menu(overlay, menu)
	safe_queue_free()

func _discard_item():
	if not is_inside_tree(): return
	var tree = get_tree()
	if not tree: return
	var player = tree.get_first_node_in_group("Player")
	if not player: return
	var current_texture = 物品图标.texture
	var loot = load("res://场景/所有继承场景的父场景/loot_item.tscn").instantiate()
	loot.item_data = item_data
	loot.stack_count = stack_count

	# 保存武器/头盔配件数据
	if _is_host_type(item_data):
		loot.weapon_magazine_data = null
		loot.weapon_magazine_ammo_dict = {}
		loot.weapon_chambered_round = chambered_round
		if installed_parts.size() > 0:
			loot.installed_parts_data = serialize_installed_parts()
		else:
			loot.installed_parts_data = {}
		if _original_weapon_texture and current_texture != _original_weapon_texture:
			loot.override_texture = current_texture

	# 保存弹匣数据
	if item_data.weapon_part_type == ItemData.WeaponPartType.MAGAZINE:
		loot.magazine_ammo_dict = _loaded_ammo_dict.duplicate()
		loot.magazine_ammo_count = item_data.current_ammo

	# 保存背包内部数据
	if item_data.is_backpack:
		var backpack_data = {}
		if not backpack_items_data.is_empty():
			backpack_data = {
				"items_data": backpack_items_data.duplicate(),
				"items_positions": backpack_items_positions.duplicate(),
				"items_searched": backpack_items_searched.duplicate(),
				"items_stack_counts": backpack_items_stack_counts.duplicate()
			}
		elif not item_data.backpack_contents.is_empty():
			backpack_data = item_data.backpack_contents.duplicate()
		loot.backpack_data = backpack_data

	loot.scale = Vector2(item_data.discard_scale, item_data.discard_scale)
	loot.set_collision_radius(item_data.discard_collision_radius)
	loot.global_position = player.global_position + Vector2(randf_range(-10, 10), randf_range(-10, 10))
	tree.current_scene.add_child(loot)

# ========== 详情弹窗 ==========
func _create_inspect_panel(animated: bool = true) -> CanvasLayer:
	var canvas = CanvasLayer.new()
	canvas.layer = 300
	get_tree().root.add_child(canvas)

	var panel = Control.new()
	panel.pivot_offset = Vector2.ZERO
	panel.position = Vector2(
		get_viewport().size.x / 2 - 225 + randi_range(-80, 80),
		get_viewport().size.y / 2 - 275 + randi_range(-60, 60)
	)
	panel.custom_minimum_size = Vector2(450, 550)
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	canvas.add_child(panel)
	panel.set_meta("slot_icons", [])

	var quality_color = item_data.get_quality_color()
	var border = ColorRect.new()
	border.color = quality_color
	border.size = panel.custom_minimum_size + Vector2(4, 4)
	border.position = Vector2(-2, -2)
	border.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.add_child(border)

	var panel_bg = ColorRect.new()
	panel_bg.color = Color(0.1, 0.1, 0.1, 0.95)
	panel_bg.size = panel.custom_minimum_size
	panel_bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.add_child(panel_bg)

	var title_bar = ColorRect.new()
	title_bar.color = Color(0.2, 0.2, 0.2, 1)
	title_bar.size = Vector2(panel_bg.size.x - 30, 35)
	title_bar.position = Vector2.ZERO
	title_bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.add_child(title_bar)

	var title_label = Label.new()
	title_label.text = item_data.item_name + "   (拖动标题栏)"
	title_label.add_theme_color_override("font_color", Color.WHITE)
	title_label.position = Vector2(10, 5)
	title_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	title_bar.add_child(title_label)

	var close_btn = Button.new()
	close_btn.text = "✕"
	close_btn.position = Vector2(panel_bg.size.x - 40, 0)
	close_btn.custom_minimum_size = Vector2(30, 30)
	close_btn.pressed.connect(func(): _remove_inspect_panel(canvas))
	panel.add_child(close_btn)

	var scroll = ScrollContainer.new()
	scroll.size = panel_bg.size - Vector2(20, 20)
	scroll.position = Vector2(10, 40)
	scroll.mouse_filter = Control.MOUSE_FILTER_PASS
	panel.add_child(scroll)

	var vbox = VBoxContainer.new()
	scroll.add_child(vbox)

	var icon_rect = TextureRect.new()
	icon_rect.texture = 物品图标.texture if 物品图标 else item_data.icon
	icon_rect.custom_minimum_size = Vector2(100, 100)
	icon_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	vbox.add_child(icon_rect)

	var name_lbl = Label.new()
	name_lbl.text = item_data.item_name
	name_lbl.add_theme_font_size_override("font_size", 24)
	name_lbl.add_theme_color_override("font_color", Color.WHITE)
	vbox.add_child(name_lbl)

	var desc_lbl = Label.new()
	desc_lbl.text = item_data.description
	desc_lbl.add_theme_font_size_override("font_size", 16)
	desc_lbl.add_theme_color_override("font_color", Color(0.8, 0.8, 0.8))
	desc_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	desc_lbl.custom_minimum_size = Vector2(410, 0)
	desc_lbl.size_flags_horizontal = Control.SIZE_EXPAND
	vbox.add_child(desc_lbl)

	if _is_host_type(item_data):
		_show_weapon_detail(vbox, canvas, panel)
	elif item_data.is_medical or item_data.is_food_or_drink:
		_show_consumable_detail(vbox)

	if animated:
		panel.scale = Vector2(0.5, 0.5)
		var tween = create_tween()
		tween.set_ease(Tween.EASE_OUT)
		tween.tween_property(panel, "scale", Vector2(1, 1), 0.2)

	canvas.set_meta("weapon_item", self)

	var drag_info = {"panel": panel, "title_bar": title_bar, "active": false, "offset": Vector2.ZERO}
	_draggable_panels.append(drag_info)
	canvas.tree_exiting.connect(func(): _draggable_panels.erase(drag_info))

	var inventory_ui = get_tree().get_first_node_in_group("InventoryUI")
	if inventory_ui and not inventory_ui.visibility_changed.is_connected(canvas.queue_free):
		inventory_ui.visibility_changed.connect(canvas.queue_free, CONNECT_ONE_SHOT)

	return canvas

func _on_inspect_pressed(menu: Control, overlay: Control):
	_close_context_menu(overlay, menu)
	_create_inspect_panel(true)

func _open_inspect_panel_no_animation():
	_create_inspect_panel(false)

func _remove_inspect_panel(canvas: CanvasLayer):
	if is_instance_valid(canvas):
		canvas.queue_free()

func _show_weapon_detail(vbox: VBoxContainer, canvas: CanvasLayer, panel: Control = null):
	# 仅对武器显示射速等信息，头盔可省略或显示其他属性
	if item_data.weapon_part_type == ItemData.WeaponPartType.RECEIVER:
		var fire_lbl = Label.new()
		fire_lbl.text = "射速：%d RPM" % item_data.fire_rate_rpm
		fire_lbl.add_theme_color_override("font_color", Color(1, 0.9, 0.3))
		vbox.add_child(fire_lbl)

		var total_ergo = item_data.ergonomics
		var total_accuracy = float(item_data.weapon_precision)
		for part in installed_parts.values():
			if part.item_data.ergonomics_modifier != 0:
				total_ergo += part.item_data.ergonomics_modifier
			if part.item_data.accuracy_modifier != 0:
				total_accuracy += part.item_data.accuracy_modifier
		var ergo_lbl = Label.new()
		ergo_lbl.text = "人机功效：%.0f" % total_ergo
		ergo_lbl.add_theme_color_override("font_color", Color(0.6, 0.9, 1.0))
		vbox.add_child(ergo_lbl)
		var acc_lbl = Label.new()
		acc_lbl.text = "精度：%.0f" % total_accuracy
		acc_lbl.add_theme_color_override("font_color", Color(1.0, 0.8, 0.6))
		vbox.add_child(acc_lbl)

	var parts_title = Label.new()
	parts_title.text = "已安装配件："
	parts_title.add_theme_color_override("font_color", Color(0.8, 0.8, 1.0))
	vbox.add_child(parts_title)

	for slot_name in installed_parts.keys():
		var part = installed_parts[slot_name]
		var hbox = HBoxContainer.new()
		var slot_lbl = Label.new()
		slot_lbl.text = slot_name + "："
		slot_lbl.add_theme_color_override("font_color", Color.WHITE)
		hbox.add_child(slot_lbl)

		var part_icon = TextureRect.new()
		part_icon.texture = part.item_data.icon
		part_icon.custom_minimum_size = Vector2(40, 40)
		part_icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		part_icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		part_icon.tooltip_text = "左键卸下"
		part_icon.gui_input.connect(func(event):
			if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
				start_uninstall_part(slot_name)
				_remove_inspect_panel(canvas)
				_open_inspect_panel_no_animation()
		)
		hbox.add_child(part_icon)

		var part_name = Label.new()
		part_name.text = part.item_data.item_name
		hbox.add_child(part_name)

		vbox.add_child(hbox)

		if panel:
			var icons = panel.get_meta("slot_icons", [])
			icons.append(hbox)
			panel.set_meta("slot_icons", icons)

func _auto_install_from_backpack(slot_name: String, canvas: CanvasLayer):
	var player = get_tree().get_first_node_in_group("Player")
	if not player: return
	var grids = [player.inventory_ui.口袋网格, player.inventory_ui.胸挂网格, player.inventory_ui.背包网格]
	for grid in grids:
		for item in grid.items:
			if item is InventoryItem and item != self and item.item_data.weapon_part_type != ItemData.WeaponPartType.NONE:
				if start_install_part(item, slot_name):
					if is_instance_valid(canvas):
						canvas.queue_free()
					return
	print("背包中没有合适的配件")

func _show_consumable_detail(vbox: VBoxContainer):
	pass

# ========== 右键菜单回调 ==========
func _on_unload_magazine_ammo_pressed(menu: Control, overlay: Control):
	if item_data.weapon_part_type == ItemData.WeaponPartType.MAGAZINE:
		unload_magazine_ammo()
	_close_context_menu(overlay, menu)

func _on_unload_part_pressed(menu: Control, overlay: Control):
	if installed_parts.size() > 0:
		var slot_name = installed_parts.keys()[0]
		start_uninstall_part(slot_name)
	_close_context_menu(overlay, menu)

func _on_equip_sight_pressed(menu, overlay):
	print("请将瞄具拖拽到武器上安装")
	_close_context_menu(overlay, menu)

func _on_unequip_sight_pressed(menu, overlay):
	unequip_sight()
	_close_context_menu(overlay, menu)

func _on_equip_weapon_pressed(menu, overlay):
	var tree = get_tree() if is_inside_tree() else null
	if not tree: return
	var player = tree.get_first_node_in_group("Player")
	if player and item_data.weapon_part_type == ItemData.WeaponPartType.RECEIVER:
		if player.equip_weapon(self):
			print("[物品] 武器已装备到空闲槽位")
		else:
			print("[物品] 装备失败，武器槽已满")
	_close_context_menu(overlay, menu)

func _on_unequip_weapon_pressed(menu, overlay):
	var tree = get_tree() if is_inside_tree() else null
	if not tree: return
	var player = tree.get_first_node_in_group("Player")
	if player and _is_equipped: player.unequip_weapon()
	_close_context_menu(overlay, menu)

func _on_use_pressed(menu: Control, overlay: Control):
	var tree = get_tree() if is_inside_tree() else null
	if not tree: return
	var player = tree.get_first_node_in_group("Player")
	if player:
		if item_data.is_medical and player.has_method("use_medical_item"):
			player.use_medical_item(self)
		elif item_data.is_food_or_drink and player.has_method("use_food_or_drink_item"):
			player.use_food_or_drink_item(self)
	_close_context_menu(overlay, menu)

# ========== 其他辅助函数 ==========
func _place_back_anywhere(item: InventoryItem) -> bool:
	if not is_inside_tree(): return false
	if item.grid_pos != Vector2i(-1, -1) and item.parent_grid:
		if item.parent_grid._can_place_at(item, item.grid_pos):
			item.parent_grid._place_item(item, item.grid_pos)
			return true
	var grids = get_tree().get_nodes_in_group("InventoryGrid")
	for grid in grids:
		if not (grid is InventoryGrid): continue
		for x in range(grid.columns):
			for y in range(grid.rows):
				var pos = Vector2i(x, y)
				if grid._can_place_at(item, pos):
					grid._place_item(item, pos)
					return true
	return false

func _on_inventory_visibility_changed(canvas: CanvasLayer):
	if is_instance_valid(canvas):
		canvas.queue_free()

# ========== 背包数据保存/加载 ==========
func save_backpack_contents() -> Dictionary:
	return {
		"items_data": backpack_items_data.duplicate(),
		"items_positions": backpack_items_positions.duplicate(),
		"items_searched": backpack_items_searched.duplicate(),
		"items_stack_counts": backpack_items_stack_counts.duplicate(),
	}

func load_backpack_contents(data: Dictionary):
	backpack_items_data = data.get("items_data", []).duplicate()
	backpack_items_positions = data.get("items_positions", []).duplicate()
	backpack_items_searched = data.get("items_searched", []).duplicate()
	backpack_items_stack_counts = data.get("items_stack_counts", []).duplicate()

func clear_backpack_contents():
	backpack_items_data.clear()
	backpack_items_positions.clear()
	backpack_items_searched.clear()
	backpack_items_stack_counts.clear()

# ========== 新增：将物品放入背包内部 ==========
func try_add_to_backpack(other: InventoryItem) -> bool:
	if not item_data.is_backpack:
		return false
	if other == self:
		return false

	# 1. 先尝试堆叠到背包内已有的同类物品上
	if other.item_data.can_stack and other.stack_count > 0:
		for i in range(backpack_items_data.size()):
			var data = backpack_items_data[i]
			if data.item_id == other.item_data.item_id and data.item_name == other.item_data.item_name:
				var existing_stack = backpack_items_stack_counts[i]
				var max_stack = data.max_stack
				if existing_stack < max_stack:
					var space = max_stack - existing_stack
					var move_count = min(space, other.stack_count)
					backpack_items_stack_counts[i] += move_count
					other.stack_count -= move_count
					if other.stack_count <= 0:
						# 完全堆叠，销毁拖拽物品
						if other.parent_grid:
							other.parent_grid.remove_item(other)
						other.safe_queue_free()
						_clear_all_grid_preview()   # ★ 清除预览
						_update_backpack_visual()
						return true
					# 还有剩余，继续寻找其他堆叠目标或占位

	# 2. 寻找背包内部空位放置剩余物品
	if other.stack_count > 0:
		# 构建占用数组
		var occupied = []
		for x in range(backpack_grid_columns):
			occupied.append([])
			for y in range(backpack_grid_rows):
				occupied[x].append(false)
		for i in range(backpack_items_data.size()):
			var pos = backpack_items_positions[i]
			var w = backpack_items_data[i].grid_width
			var h = backpack_items_data[i].grid_height
			for cx in range(w):
				for cy in range(h):
					var px = pos.x + cx
					var py = pos.y + cy
					if px >= 0 and px < backpack_grid_columns and py >= 0 and py < backpack_grid_rows:
						occupied[px][py] = true

		var item_w = other.item_data.grid_width
		var item_h = other.item_data.grid_height
		var found_pos = Vector2i(-1, -1)
		for x in range(backpack_grid_columns - item_w + 1):
			for y in range(backpack_grid_rows - item_h + 1):
				var can_fit = true
				for cx in range(item_w):
					for cy in range(item_h):
						if occupied[x + cx][y + cy]:
							can_fit = false
							break
					if not can_fit: break
				if can_fit:
					found_pos = Vector2i(x, y)
					break
			if found_pos != Vector2i(-1, -1):
				break

		if found_pos != Vector2i(-1, -1):
			# 放置
			backpack_items_data.append(other.item_data)
			backpack_items_positions.append(found_pos)
			backpack_items_searched.append(other._was_searched)
			backpack_items_stack_counts.append(other.stack_count)
			# 从原网格移除 other
			if other.parent_grid:
				other.parent_grid.remove_item(other)
			other.queue_free()
			_clear_all_grid_preview()   # ★ 清除预览
			_update_backpack_visual()
			return true
		else:
			return false  # 没有空间
	return false

func _update_backpack_visual():
	# 更新背包物品的显示（可选），例如在图标上显示容量等
	_update_stack_label()
	if parent_grid:
		parent_grid.queue_redraw()
	# 如果此背包是玩家当前装备的背包，刷新背包网格
	var player = get_tree().get_first_node_in_group("Player")
	if player and player.equipped_backpack_item == self:
		if player.inventory_ui:
			player.inventory_ui._update_backpack_grid()
func _clear_all_grid_preview():
	var grids = get_tree().get_nodes_in_group("InventoryGrid")
	for grid in grids:
		if grid is InventoryGrid:
			grid.hovered_item = null
			grid.preview_pos = Vector2i(-1, -1)
			grid.queue_redraw()
