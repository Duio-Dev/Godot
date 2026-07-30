extends Area2D
class_name LootItem

@export var item_data: ItemData
@export var stack_count: int = 1

func _ready():
	if item_data and item_data.icon: $Sprite2D.texture = item_data.icon
	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)

func _on_body_entered(body):
	if body is PlayerCharacter: body.set_current_loot(self)

func _on_body_exited(body):
	if body is PlayerCharacter: body.clear_current_loot(self)

func try_pickup(player: PlayerCharacter) -> bool:
	var scene = preload("res://场景/所有继承场景的父场景/item.tscn")
	var item = scene.instantiate()
	item.item_data = item_data
	item.stack_count = stack_count
	item.mark_as_looted()

	var grids = _get_ordered_grids(player)
	# 先尝试堆叠
	for grid in grids:
		for existing in grid.items:
			if existing is InventoryItem and existing.can_stack_with(item):
				var remaining = existing.try_merge(item)
				if remaining == 0:
					queue_free()
					return true
				else:
					item.stack_count = remaining
					break
		if item.stack_count == 0:
			queue_free()
			return true

	# 再尝试放入空位（原方向及旋转）
	for grid in grids:
		for x in range(grid.columns):
			for y in range(grid.rows):
				var pos = Vector2i(x, y)
				if grid._can_place_at(item, pos):
					grid._place_item(item, pos)
					queue_free()
					return true
		if item_data.can_rotate:
			item.is_rotated = true
			item._update_size()
			for x in range(grid.columns):
				for y in range(grid.rows):
					var pos = Vector2i(x, y)
					if grid._can_place_at(item, pos):
						grid._place_item(item, pos)
						queue_free()
						return true
			item.is_rotated = false
			item._update_size()

	item.queue_free()
	return false

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
