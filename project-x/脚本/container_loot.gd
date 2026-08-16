extends Area2D
class_name ContainerLoot

@export_group("容器属性")
@export var container_name: String = "容器"
@export var grid_size: int = 64
@export var grid_columns: int = 10
@export var grid_rows: int = 6

@export_group("容器物品数据")
@export var possible_items: Array = []          # ★ 改为普通 Array，避免类型赋值错误
@export var min_items: int = 2
@export var max_items: int = 5
@export var max_items_stack_counts: int = 60

@export_group("武器配件生成")
@export var possible_attachments: Array = []    # ★ 改为普通 Array
@export var min_attachments_per_weapon: int = 0
@export var max_attachments_per_weapon: int = 2

var items_data: Array = []                       # ★ 全部改为普通 Array
var items_positions: Array = []
var items_searched: Array = []
var items_stack_counts: Array = []
var items_attachments: Array = []

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

	# ★ 防止 possible_items 为空导致模零错误
	if possible_items.size() == 0:
		print("[容器] 警告：possible_items 为空，无法生成物品")
		return

	var count = randi_range(min_items, max_items)
	for i in range(count):
		var template = possible_items[randi() % possible_items.size()]
		var data = template.duplicate()
		# 弹匣弹药随机（这里固定为0，按需修改）
		if data.weapon_part_type == ItemData.WeaponPartType.MAGAZINE:
			data.current_ammo = randi_range(0, 0)
		items_data.append(data)
		items_positions.append(Vector2i(-1, -1))
		items_searched.append(false)
		# 堆叠数生成
		var stack = 1
		if data.max_stack > 1:
			var max_possible = min(max_items_stack_counts, data.max_stack)
			stack = randi_range(1, max_possible)
		items_stack_counts.append(stack)

		# 如果是武器，随机生成配件
		var attachments: Dictionary = {}
		if data.weapon_part_type == ItemData.WeaponPartType.RECEIVER and possible_attachments.size() > 0:
			attachments = _generate_random_attachments(data)
		items_attachments.append(attachments)

func _generate_random_attachments(weapon_data: ItemData) -> Dictionary:
	var result: Dictionary = {}
	var slots = weapon_data.receiver_slots
	if slots.is_empty():
		return result

	var max_possible = min(max_attachments_per_weapon, slots.size())
	if max_possible <= 0:
		return result
	var attachments_to_add = randi_range(min_attachments_per_weapon, max_possible)

	var available_slots = slots.duplicate()
	available_slots.shuffle()

	var installed_slot_names: Array[String] = []

	for slot in available_slots:
		if attachments_to_add <= 0:
			break

		if not slot.parent_slot_name.is_empty() and slot.parent_slot_name not in installed_slot_names:
			continue

		var compatible_parts: Array[ItemData] = []
		for part in possible_attachments:
			if part.weapon_part_type != slot.slot_type:
				continue
			if not part.compatible_receivers.is_empty() and not part.compatible_receivers.has(weapon_data.item_id):
				continue
			if not slot.required_slot_tag.is_empty() and part.slot_tag != slot.required_slot_tag:
				continue
			compatible_parts.append(part)

		if compatible_parts.is_empty():
			continue

		var chosen_part = compatible_parts[randi() % compatible_parts.size()]
		result[slot.slot_name] = chosen_part.duplicate()
		installed_slot_names.append(slot.slot_name)
		attachments_to_add -= 1

	return result

static func apply_attachments_to_item(item: InventoryItem, attachments: Dictionary) -> void:
	if not item or attachments.is_empty():
		return
	if item.item_data.weapon_part_type != ItemData.WeaponPartType.RECEIVER:
		return

	var item_scene = load("res://场景/所有继承场景的父场景/item.tscn")

	for slot_name in attachments.keys():
		var part_data: ItemData = attachments[slot_name]
		var part_item = item_scene.instantiate()
		part_item.item_data = part_data
		part_item.stack_count = 1
		part_item.mark_as_looted()
		part_item.visible = false
		part_item._is_equipped = true

		if part_data.weapon_part_type == ItemData.WeaponPartType.MAGAZINE:
			part_data.current_ammo = 0
			part_item._loaded_ammo_dict = {}

		item.installed_parts[slot_name] = part_item
		part_item.parent_grid = null

	item._update_size()
	item._generate_weapon_texture()
	item._update_stack_label()
