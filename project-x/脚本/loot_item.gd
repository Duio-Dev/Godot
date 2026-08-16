extends Area2D
class_name LootItem

@export var item_data: ItemData
@export var stack_count: int = 1
@onready var sprite_2d: Sprite2D = $Sprite2D

var override_texture: Texture2D = null
var weapon_magazine_data: ItemData = null
var weapon_magazine_ammo_dict: Dictionary = {}
var weapon_chambered_round: int = 0

var magazine_ammo_dict: Dictionary = {}
var magazine_ammo_count: int = 0
var sight_data: ItemData = null

# ★ 保存已安装配件数据（包括头盔的面罩）
var installed_parts_data: Dictionary = {}

var backpack_data: Dictionary = {}
func _ready():
	if override_texture:
		sprite_2d.texture = override_texture
	elif item_data and item_data.icon:
		sprite_2d.texture = item_data.icon
	if item_data:
		scale = Vector2(item_data.discard_scale, item_data.discard_scale)
	if has_node("CollisionShape2D"):
		set_collision_radius(item_data.discard_collision_radius)
	else:
		set_collision_radius(item_data.discard_collision_radius)
	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)

func set_collision_radius(radius: float):
	var shape_node: CollisionShape2D = $CollisionShape2D if has_node("CollisionShape2D") else null
	if not shape_node:
		shape_node = CollisionShape2D.new()
		shape_node.name = "CollisionShape2D"
		add_child(shape_node)
	var circle = CircleShape2D.new()
	circle.radius = radius
	shape_node.shape = circle

func _on_body_entered(body):
	if body is PlayerCharacter:
		body.set_current_loot(self)

func _on_body_exited(body):
	if body is PlayerCharacter:
		body.clear_current_loot(self)

func try_pickup(player: PlayerCharacter) -> bool:
	var scene = preload("res://场景/所有继承场景的父场景/item.tscn")
	var item = scene.instantiate()
	item.item_data = item_data
	item.stack_count = stack_count
	item.mark_as_looted()

	# 放置到玩家背包网格
	var grids = _get_ordered_grids(player)
	var placed = false
	for grid in grids:
		for x in range(grid.columns):
			for y in range(grid.rows):
				if grid._can_place_at(item, Vector2i(x, y)):
					grid._place_item(item, Vector2i(x, y))
					placed = true
					break
		if placed:
			break
	if not placed:
		item.queue_free()
		return false

	# 恢复武器/头盔配件
	if (item_data.weapon_part_type == ItemData.WeaponPartType.RECEIVER or item_data.weapon_part_type == ItemData.WeaponPartType.HELMET) and installed_parts_data.size() > 0:
		item._apply_item_data()
		for slot_name in installed_parts_data:
			var part_data = installed_parts_data[slot_name]
			var part_item = scene.instantiate()
			part_item.item_data = part_data["item_data"]
			part_item.stack_count = part_data["stack_count"]
			part_item.mark_as_looted()
			part_item.visible = false
			part_item._is_equipped = true
			if "loaded_ammo_dict" in part_data:
				part_item._loaded_ammo_dict = part_data["loaded_ammo_dict"].duplicate()
			if "current_ammo" in part_data and part_item.item_data.weapon_part_type == ItemData.WeaponPartType.MAGAZINE:
				part_item.item_data.current_ammo = part_data["current_ammo"]
			item.installed_parts[slot_name] = part_item

		if weapon_magazine_data:
			item.equipped_magazine_data = weapon_magazine_data
			item._weapon_magazine_ammo_dict = weapon_magazine_ammo_dict.duplicate()
			item._loaded_ammo_dict = weapon_magazine_ammo_dict.duplicate()
			item.chambered_round = weapon_chambered_round
			if item.get_node_or_null("物品图标") and override_texture:
				item.get_node("物品图标").texture = override_texture

		item._update_size()
		item._update_stack_label()
		item._generate_weapon_texture()
	else:
		# 弹匣数据恢复
		if item_data.weapon_part_type == ItemData.WeaponPartType.MAGAZINE and not magazine_ammo_dict.is_empty():
			item._loaded_ammo_dict = magazine_ammo_dict.duplicate()
			item.item_data.current_ammo = magazine_ammo_count
			item._update_stack_label()

	# ★ 恢复背包内部数据（先清空再加载，避免残留）
	if item.item_data.is_backpack:
		item.clear_backpack_contents()
		if not backpack_data.is_empty():
			item.load_backpack_contents(backpack_data)

	queue_free()
	return true

func _get_ordered_grids(player: PlayerCharacter) -> Array:
	match item_data.preferred_slot:
		ItemData.SlotPreference.POCKET:
			return [player.inventory_ui.口袋网格, player.inventory_ui.胸挂网格, player.inventory_ui.背包网格]
		ItemData.SlotPreference.VEST:
			return [player.inventory_ui.胸挂网格, player.inventory_ui.口袋网格, player.inventory_ui.背包网格]
		ItemData.SlotPreference.BACKPACK:
			return [player.inventory_ui.背包网格, player.inventory_ui.胸挂网格, player.inventory_ui.口袋网格]
		_:
			return [player.inventory_ui.口袋网格, player.inventory_ui.胸挂网格, player.inventory_ui.背包网格]
