extends VBoxContainer

var target_item: InventoryItem = null
var _overlay: ColorRect = null

var 丢弃: Button
var 查看: Button
var 卸下弹药: Button   # 弹匣卸出弹药
var 卸下弹匣: Button   # 武器卸下弹匣
var 使用: Button

func _ready():
	# 查找按钮（直接路径 + 递归查找双保险）
	丢弃 = get_node_or_null("丢弃") as Button
	查看 = get_node_or_null("查看") as Button
	卸下弹药 = get_node_or_null("卸下弹药") as Button
	卸下弹匣 = get_node_or_null("卸下弹匣") as Button
	使用 = get_node_or_null("使用") as Button

	if not 丢弃: 丢弃 = find_child("丢弃") as Button
	if not 查看: 查看 = find_child("查看") as Button
	if not 卸下弹药: 卸下弹药 = find_child("卸下弹药") as Button
	if not 卸下弹匣: 卸下弹匣 = find_child("卸下弹匣") as Button
	if not 使用: 使用 = find_child("使用") as Button

	# 连接按钮信号
	if 丢弃: 丢弃.pressed.connect(_on_discard)
	if 查看: 查看.pressed.connect(_on_inspect)
	if 卸下弹药: 卸下弹药.pressed.connect(_on_unload_magazine_ammo)
	if 卸下弹匣: 卸下弹匣.pressed.connect(_on_unload_weapon_magazine)
	if 使用: 使用.pressed.connect(_on_use)

	# 点击菜单空白区域也可关闭
	self.gui_input.connect(_on_menu_click)

func setup(item: InventoryItem):
	target_item = item
	if not is_instance_valid(item):
		queue_free()
		return

	# 创建全屏透明遮罩（用于点击菜单外部时关闭）
	_overlay = ColorRect.new()
	_overlay.color = Color(0, 0, 0, 0)          # 完全透明
	_overlay.size = get_viewport().get_visible_rect().size
	_overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	_overlay.gui_input.connect(_on_overlay_clicked)
	if get_parent():
		get_parent().add_child(_overlay)
		get_parent().move_child(_overlay, 0)    # 放在菜单下层

	# 显示常驻按钮
	if 丢弃: 丢弃.show()
	if 查看: 查看.show()
	if 使用: 使用.hide()

	# 条件按钮：弹匣且有子弹 → 显示“卸下弹药”
	if 卸下弹药:
		卸下弹药.visible = item.item_data.is_magazine and item.item_data.current_ammo > 0

	# 条件按钮：武器且已装备弹匣 → 显示“卸下弹匣”
	if 卸下弹匣:
		卸下弹匣.visible = item.item_data.is_weapon and item.equipped_magazine_data != null

# ---------- 关闭相关 ----------
func _on_overlay_clicked(event):
	if event is InputEventMouseButton and event.pressed:
		_close()

func _on_menu_click(event):
	if event is InputEventMouseButton and event.pressed:
		_close()

func _close():
	if _overlay:
		_overlay.queue_free()
		_overlay = null
	queue_free()

# ---------- 按钮回调 ----------
func _on_discard():
	if target_item:
		target_item.queue_free()
	_close()

func _on_inspect():
	# 待实现
	_close()

func _on_unload_magazine_ammo():
	if target_item and target_item.item_data.is_magazine:
		target_item.unload_magazine_ammo()
	_close()

func _on_unload_weapon_magazine():
	if target_item and target_item.item_data.is_weapon:
		target_item.unequip_magazine()
	_close()

func _on_use():
	_close()
