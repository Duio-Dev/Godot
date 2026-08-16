extends Control

@onready var color_rect: ColorRect = $ColorRect
@onready var scroll_container: ScrollContainer = $ColorRect/ScrollContainer
@onready var v_box_container: VBoxContainer = $ColorRect/ScrollContainer/VBoxContainer

var inventory_item: InventoryItem = null

func _ready():
	visible = false

func show_item(item: InventoryItem):
	inventory_item = item
	var data = item.item_data

	# 清空旧内容
	for child in v_box_container.get_children():
		child.queue_free()

	# 图标
	var icon_rect = TextureRect.new()
	icon_rect.texture = item.物品图标.texture if item.物品图标 else data.icon
	icon_rect.custom_minimum_size = Vector2(128, 128)
	icon_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	v_box_container.add_child(icon_rect)

	# 名称
	var name_label = Label.new()
	name_label.text = data.item_name
	name_label.add_theme_font_size_override("font_size", 24)
	v_box_container.add_child(name_label)

	# 描述
	var desc_label = Label.new()
	desc_label.text = data.description
	desc_label.add_theme_font_size_override("font_size", 16)
	desc_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	v_box_container.add_child(desc_label)

	# 武器额外信息
	if data.is_weapon:
		_show_weapon_info(item)
	# 医疗/饮食额外信息
	elif data.is_medical or data.is_food_or_drink:
		_show_consumable_info(data)

	visible = true

func _show_weapon_info(item: InventoryItem):
	var data = item.item_data

	# 射速
	var fire_rate_label = Label.new()
	fire_rate_label.text = "射速：%d RPM" % data.fire_rate_rpm
	v_box_container.add_child(fire_rate_label)

	# 配件槽（枪口、弹匣、瞄具、战术配件）
	var slots = {
		"枪口": null,
		"弹匣": item.equipped_magazine_data,
		"瞄具": item.equipped_sight_data,
		"战术配件": null
	}

	for slot_name in slots:
		var slot_container = HBoxContainer.new()
		var label = Label.new()
		label.text = slot_name + "："
		slot_container.add_child(label)

		var accessory_icon = TextureRect.new()
		accessory_icon.custom_minimum_size = Vector2(32, 32)
		accessory_icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE

		var data_ref = slots[slot_name]
		if data_ref:
			accessory_icon.texture = data_ref.icon
			accessory_icon.mouse_filter = Control.MOUSE_FILTER_STOP
			accessory_icon.gui_input.connect(_on_accessory_drag.bind(slot_name, item))
		else:
			accessory_icon.texture = null
		slot_container.add_child(accessory_icon)
		v_box_container.add_child(slot_container)

func _show_consumable_info(data: ItemData):
	# 医疗物品
	if data.is_medical:
		if data.medical_durability > 0:
			var dur_label = Label.new()
			dur_label.text = "耐久：%.1f" % data.medical_durability
			v_box_container.add_child(dur_label)
		if data.activation_time > 0:
			var act_label = Label.new()
			act_label.text = "启用时间：%.1f 秒" % data.activation_time
			v_box_container.add_child(act_label)
		# 效果
		var effect_label = Label.new()
		var effects = []
		if data.buff_type == ItemData.BuffType.PAINKILLER:
			effects.append("止痛")
			effects.append("损伤控制")
		elif data.buff_type == ItemData.BuffType.STIMULANT:
			effects.append("兴奋")
		if effects.is_empty():
			effects.append("无特殊效果")
		effect_label.text = "效果：" + "、".join(effects)
		v_box_container.add_child(effect_label)

	# 饮食物品
	if data.is_food_or_drink:
		if data.hydration_restore > 0:
			var hyd_label = Label.new()
			hyd_label.text = "水分恢复：%.0f" % data.hydration_restore
			v_box_container.add_child(hyd_label)
		if data.satiety_restore > 0:
			var sat_label = Label.new()
			sat_label.text = "饱食度恢复：%.0f" % data.satiety_restore
			v_box_container.add_child(sat_label)
		if data.stamina_restore > 0:
			var sta_label = Label.new()
			sta_label.text = "耐力恢复：%.0f" % data.stamina_restore
			v_box_container.add_child(sta_label)
		if data.food_activation_time > 0:
			var act_label = Label.new()
			act_label.text = "启用时间：%.1f 秒" % data.food_activation_time
			v_box_container.add_child(act_label)
		var effect_label = Label.new()
		var effects = []
		if data.buff_type == ItemData.BuffType.PAINKILLER:
			effects.append("止痛")
			effects.append("损伤控制")
		elif data.buff_type == ItemData.BuffType.STIMULANT:
			effects.append("兴奋")
		if effects.is_empty():
			effects.append("无特殊效果")
		effect_label.text = "效果：" + "、".join(effects)
		v_box_container.add_child(effect_label)

func _on_accessory_drag(event: InputEvent, slot: String, item: InventoryItem):
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		var new_item: InventoryItem = null
		match slot:
			"弹匣":
				if item.equipped_magazine_data:
					new_item = _create_magazine_item(item)
					item.unequip_magazine()
			"瞄具":
				if item.equipped_sight_data:
					new_item = _create_sight_item(item)
					item.unequip_sight()
		if new_item:
			_start_drag_new_item(new_item)

func _create_magazine_item(weapon: InventoryItem) -> InventoryItem:
	var scene = load("res://场景/所有继承场景的父场景/item.tscn")
	var mag = scene.instantiate()
	mag.item_data = weapon.equipped_magazine_data.duplicate()
	mag.item_data.current_ammo = weapon._ammo_dict_total()
	mag._loaded_ammo_dict = weapon._loaded_ammo_dict.duplicate()
	mag.mark_as_looted()
	mag._update_size()
	return mag

func _create_sight_item(weapon: InventoryItem) -> InventoryItem:
	var scene = load("res://场景/所有继承场景的父场景/item.tscn")
	var sight = scene.instantiate()
	sight.item_data = weapon.equipped_sight_data.duplicate()
	sight.mark_as_looted()
	sight._update_size()
	return sight

func _start_drag_new_item(item: InventoryItem):
	var drag_layer = get_tree().root.get_node_or_null("DragLayer")
	if not drag_layer:
		drag_layer = CanvasLayer.new()
		drag_layer.name = "DragLayer"
		drag_layer.layer = 100
		get_tree().root.add_child(drag_layer)
	drag_layer.add_child(item)
	item.global_position = get_global_mouse_position()
	item._update_size()
	item._start_drag()

func close_panel():
	visible = false
