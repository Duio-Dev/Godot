extends Node2D

@onready var 枪体节点: Sprite2D = $枪体
@onready var 动画播放器: AnimationPlayer = $AnimationPlayer
@onready var 抛壳: Marker2D = $抛壳
@onready var 枪口: Marker2D = $枪口

@export var 弹壳落地音效: AudioStream
@export var 射线长度: float = 1000.0
@export var 碰撞层: int = 1

var 武器物品: InventoryItem = null

var 是否正在换弹: bool = false
var 是否正在压弹: bool = false
var 是否正在检查弹药: bool = false
var 是否正在瞄准: bool = false
var 当前瞄准缩放: float = 1.0

var _下一次可开火: float = 0.0
var _膛内甲伤: float = 10.0
var _膛内肉伤: float = 10.0
var _原始缩放Y: float = 1.0
var _强制开火: bool = false
var _equip_timeout: float = 0.0
var _reload_locked: bool = false

# 旋转动画相关
var _is_rotating: bool = false
var _rotation_tween: Tween = null

var _shoot_player: AudioStreamPlayer = null

func _ready():
	_原始缩放Y = abs(scale.y)
	set_physics_process(true)
	set_process_input(true)
	add_to_group("Weapon")
	_shoot_player = AudioStreamPlayer.new()
	add_child(_shoot_player)

func 装备(物品: InventoryItem):
	武器物品 = 物品
	应用外观()
	_下一次可开火 = 0.0
	_强制开火 = false
	当前瞄准缩放 = 1.0
	if 物品.item_data.shoot_sound:
		_shoot_player.stream = 物品.item_data.shoot_sound
	else:
		_shoot_player.stream = null

func 卸下():
	武器物品 = null
	是否正在换弹 = false
	是否正在压弹 = false
	是否正在检查弹药 = false
	_强制开火 = false
	当前瞄准缩放 = 1.0
	_shoot_player.stop()
	rotation = 0.0
	visible = true

func _can_fire() -> bool:
	var player = get_tree().get_first_node_in_group("Player")
	if player and player.inventory_ui and player.inventory_ui.visible:
		return false
	return true

func _is_inventory_open() -> bool:
	var player = get_tree().get_first_node_in_group("Player")
	return player and player.inventory_ui and player.inventory_ui.visible

func _physics_process(delta):
	if not 武器物品: return

	var angle = wrapf(global_rotation, -PI, PI)
	scale.y = _原始缩放Y if angle > -PI/2 and angle < PI/2 else -_原始缩放Y

	var is_aim_pressed = Input.is_mouse_button_pressed(MOUSE_BUTTON_RIGHT)
	if is_aim_pressed and not 是否正在瞄准:
		当前瞄准缩放 = 1.0
	是否正在瞄准 = is_aim_pressed

	var target_zoom = 1.0
	var sight = 武器物品.get_equipped_sight()
	if sight:
		var zoom = sight.item_data.aim_zoom_level
		if zoom > 1.0:
			target_zoom = zoom if 是否正在瞄准 else 1.0

			var base_ergo = 武器物品.item_data.ergonomics
			var mod_ergo = 0.0
			var mag = 武器物品.get_equipped_magazine()
			if mag:
				mod_ergo += mag.item_data.ergonomics_modifier
			if sight:
				mod_ergo += sight.item_data.ergonomics_modifier
			var total_ergo = clamp(base_ergo + mod_ergo, 0.0, 200.0)

			var aim_duration = 0.3 + (1.0 - total_ergo / 100.0) * 1.7
			if aim_duration <= 0.0:
				aim_duration = 0.01
			if 当前瞄准缩放 != target_zoom:
				当前瞄准缩放 = move_toward(当前瞄准缩放, target_zoom,
					(target_zoom - 当前瞄准缩放) / aim_duration * delta)
		else:
			当前瞄准缩放 = 1.0
	else:
		当前瞄准缩放 = 1.0

	if not 是否正在压弹 and not 是否正在换弹 and not 是否正在检查弹药:
		var now = Time.get_ticks_msec() / 1000.0
		if _强制开火 or (Input.is_action_pressed("fire") and now >= _下一次可开火):
			尝试射击()
			_强制开火 = false

# 所有按键处理移至 _input，避免重复检测
func _input(event):
	if event is InputEventKey and event.pressed and not event.echo:
		if _is_inventory_open():
			return
		# Ctrl+R 退膛
		if event.keycode == KEY_R and event.ctrl_pressed:
			if not 是否正在压弹 and not 是否正在换弹 and not 是否正在检查弹药:
				退膛()
		# R 换弹
		elif event.keycode == KEY_R:
			if not 是否正在压弹 and not 是否正在换弹 and not 是否正在检查弹药:
				var success = 开始换弹()
				if not success:
					var player = get_tree().get_first_node_in_group("Player")
					if player and player.has_method("_show_message"):
						player._show_message("无法换弹（缺少弹匣或弹药）")
		# G 压弹
		elif event.keycode == KEY_G:
			if 武器物品 and not 是否正在换弹 and not 是否正在压弹:
				开始压弹()
		# E 检查弹药
		elif event.keycode == KEY_E:
			if 武器物品 and not 是否正在换弹 and not 是否正在检查弹药:
				检查弹药()

# ---------- 射击 ----------
func 尝试射击():
	if not _can_fire(): return
	if 是否正在压弹 or 是否正在换弹 or 是否正在检查弹药 or not 武器物品: return

	var now = Time.get_ticks_msec() / 1000.0
	if 武器物品.chambered_round > 0:
		# 膛室有子弹，直接发射
		_do_fire(now)
	else:
		# 膛室空，先上膛
		if _chamber_a_round():
			_do_fire(now)
		else:
			# 无法上膛（弹匣空或没有弹匣），播放空仓音效或延迟
			_下一次可开火 = now + 0.2
			_播放空挂音()

func _do_fire(now: float):
	# 发射膛室中的子弹
	var 甲伤 = _膛内甲伤
	var 肉伤 = _膛内肉伤

	# 清空膛室
	武器物品.chambered_round = 0
	武器物品._chambered_bullet_data = null
	_膛内甲伤 = 0.0
	_膛内肉伤 = 0.0

	print("[射击] 护甲伤害: ", 甲伤, " 肉体伤害: ", 肉伤)

	if _shoot_player.stream:
		_shoot_player.play()
	var rpm = 武器物品.item_data.fire_rate_rpm
	_下一次可开火 = now + (60.0 / float(rpm) if rpm > 0 else 0.15)
	_发射射线(甲伤, 肉伤)
	_枪体抖动()
	_抛壳()
	_震屏()
	call_deferred("_延迟生成烟雾")

	# 自动上膛（如果弹匣还有子弹）
	var mag = 武器物品.get_equipped_magazine()
	if mag and mag.item_data.current_ammo > 0:
		_chamber_a_round()

func _chamber_a_round() -> bool:
	if not 武器物品: return false

	var 弹匣 = 武器物品.get_equipped_magazine()
	if not 弹匣 or 弹匣.item_data.current_ammo <= 0:
		var 新弹匣 = _寻找最佳弹匣(武器物品.item_data.ammo_type)
		if 新弹匣 and 新弹匣 != 弹匣:
			# 手动安装新弹匣
			if _手动安装弹匣(武器物品, 新弹匣):
				弹匣 = 新弹匣
			else:
				return false

	if not 弹匣 or 弹匣.item_data.current_ammo <= 0:
		return false

	var 子弹数据 = 弹匣._get_first_bullet_from_mag()
	if 子弹数据 == null:
		print("[武器] 弹匣内没有有效子弹，无法上膛")
		return false

	if 子弹数据.ammo_type != 武器物品.item_data.ammo_type:
		print("[武器] 弹药类型不匹配，无法上膛")
		return false

	弹匣._remove_one_bullet_from_mag(子弹数据)

	武器物品.chambered_round = 1
	武器物品._chambered_bullet_data = 子弹数据
	_膛内甲伤 = 子弹数据.armor_damage
	_膛内肉伤 = 子弹数据.flesh_damage

	武器物品._update_stack_label()
	return true

func _播放空挂音(): pass

# ---------- 旋转动画辅助 ----------
func _play_rotation_animation(hold_duration: float) -> float:
	if _is_rotating:
		return 0.0
	_is_rotating = true
	if _rotation_tween and _rotation_tween.is_valid():
		_rotation_tween.kill()

	var total_time = 0.15 + hold_duration + 0.15
	_rotation_tween = create_tween()
	_rotation_tween.tween_property(self, "rotation", -PI / 2.0, 0.15).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	_rotation_tween.tween_callback(func():
		visible = false
	)
	_rotation_tween.tween_interval(hold_duration)
	_rotation_tween.tween_callback(func():
		visible = true
	)
	_rotation_tween.tween_property(self, "rotation", 0.0, 0.15).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	_rotation_tween.finished.connect(func():
		_is_rotating = false
		_rotation_tween = null
	)
	return total_time

# ---------- 换弹 ----------
func 开始换弹() -> bool:
	if 是否正在换弹 or 是否正在压弹:
		return false
	if not 武器物品:
		return false

	var mag = 武器物品.get_equipped_magazine()
	if not mag:
		# 没有弹匣时，尝试快速装备弹匣（异步执行，不等待）
		快速装备弹匣()
		return true

	# 膛室空但弹匣有子弹，自动上膛
	if 武器物品.chambered_round == 0 and mag.item_data.current_ammo > 0:
		if _chamber_a_round():
			print("[武器] 已自动上膛")
			return true
		# 上膛失败继续尝试换弹

	# 检查是否有备用弹匣
	var 备用弹匣 = _寻找最佳弹匣(武器物品.item_data.ammo_type)
	if 备用弹匣 == null:
		return false

	是否正在换弹 = true
	_reload_locked = true
	var 空仓 = (武器物品.chambered_round == 0 and mag.item_data.current_ammo <= 0)
	执行换弹(空仓)
	_reload_locked = false
	return true

func 执行换弹(空仓: bool):
	var 物品 = 武器物品
	var 弹药类型 = 物品.item_data.ammo_type
	var 换弹时间 = 物品.item_data.reload_time_full if 空仓 else 物品.item_data.reload_time_tactical

	var 满弹匣物品 = _寻找最佳弹匣(弹药类型)
	if not 满弹匣物品:
		是否正在换弹 = false
		return

	if 空仓:
		# 空仓换弹：丢弃旧弹匣（生成掉落物），然后安装新弹匣
		var 当前弹匣 = 物品.get_equipped_magazine()
		if 当前弹匣:
			var player = get_tree().get_first_node_in_group("Player")
			if player:
				var loot = load("res://场景/所有继承场景的父场景/loot_item.tscn").instantiate()
				loot.item_data = 当前弹匣.item_data
				loot.stack_count = 1
				loot.magazine_ammo_dict = 物品._loaded_ammo_dict.duplicate()
				loot.magazine_ammo_count = 当前弹匣.item_data.current_ammo
				loot.global_position = player.global_position + Vector2(randf_range(-50, 50), randf_range(-50, 50))
				get_tree().current_scene.add_child(loot)
			物品._loaded_ammo_dict.clear()
			物品.installed_parts.erase("弹匣井")
			物品._generate_weapon_texture()
			物品._update_size()
			物品._update_stack_label()
	else:
		# 战术换弹：交换弹匣
		_战术换弹(物品, 满弹匣物品)

	# 等待换弹动画
	var total_rotation_time = _play_rotation_animation(换弹时间)

	var 玩家节点 = get_tree().get_first_node_in_group("Player")
	if 玩家节点:
		玩家节点.label.text = "正在换弹"
		玩家节点.label.show()

	await get_tree().create_timer(total_rotation_time).timeout

	if 玩家节点 and is_instance_valid(玩家节点):
		玩家节点.label.hide()

	if not is_inside_tree() or not 武器物品:
		是否正在换弹 = false
		return

	if 空仓:
		if not _手动安装弹匣(物品, 满弹匣物品):
			是否正在换弹 = false
			return
		if not _chamber_a_round():
			_播放空挂音()
	else:
		# 战术换弹后，如果膛室空则尝试上膛
		if 物品.chambered_round == 0 and 物品.get_equipped_magazine() and 物品.get_equipped_magazine().item_data.current_ammo > 0:
			_chamber_a_round()

	应用外观()
	是否正在换弹 = false

func _战术换弹(武器物品节点: InventoryItem, 新弹匣: InventoryItem):
	# 先记录旧弹匣
	var 旧弹匣 = 武器物品节点.get_equipped_magazine()
	if not 旧弹匣:
		# 没有旧弹匣，直接安装
		_手动安装弹匣(武器物品节点, 新弹匣)
		return

	# 手动安装新弹匣（新弹匣会从背包移除）
	if not _手动安装弹匣(武器物品节点, 新弹匣):
		print("[换弹] 安装新弹匣失败")
		return

	# 将旧弹匣放回背包
	旧弹匣._is_equipped = false
	旧弹匣.visible = true
	if not _放回弹匣到背包(旧弹匣):
		# 背包满则掉落
		var player = get_tree().get_first_node_in_group("Player")
		if player:
			var loot = load("res://场景/所有继承场景的父场景/loot_item.tscn").instantiate()
			loot.item_data = 旧弹匣.item_data
			loot.stack_count = 1
			loot.magazine_ammo_dict = 旧弹匣._loaded_ammo_dict.duplicate()
			loot.magazine_ammo_count = 旧弹匣.item_data.current_ammo
			loot.global_position = player.global_position + Vector2(randf_range(-50, 50), randf_range(-50, 50))
			get_tree().current_scene.add_child(loot)
		旧弹匣.queue_free()

func _手动安装弹匣(武器物品节点: InventoryItem, 新弹匣: InventoryItem) -> bool:
	if not 武器物品节点 or not 新弹匣:
		return false
	# 从背包中移除新弹匣
	if 新弹匣.parent_grid:
		新弹匣.parent_grid.remove_item(新弹匣)
	if 新弹匣.get_parent():
		新弹匣.get_parent().remove_child(新弹匣)
	# 安装到弹匣井
	var slot = 武器物品节点._find_slot_by_name("弹匣井")
	if not slot:
		print("[换弹] 找不到弹匣井槽位")
		新弹匣.queue_free()
		return false
	武器物品节点.installed_parts[slot.slot_name] = 新弹匣
	新弹匣._is_equipped = true
	新弹匣.visible = false
	武器物品节点._loaded_ammo_dict = 新弹匣._loaded_ammo_dict.duplicate()
	武器物品节点._update_stack_label()
	武器物品节点._generate_weapon_texture()
	武器物品节点._update_size()
	return true

func _放回弹匣到背包(弹匣: InventoryItem) -> bool:
	# 优先放回原位
	if 弹匣.grid_pos != Vector2i(-1, -1) and 弹匣.parent_grid:
		if 弹匣.parent_grid._can_place_at(弹匣, 弹匣.grid_pos):
			弹匣.parent_grid._place_item(弹匣, 弹匣.grid_pos)
			return true
	# 否则放回任意空位
	return 武器物品._place_back_anywhere(弹匣)

func 快速装备弹匣() -> bool:
	if 是否正在换弹 or 是否正在压弹: return false
	if not 武器物品: return false

	var 新弹匣 = _寻找最佳弹匣(武器物品.item_data.ammo_type)
	if not 新弹匣: return false

	是否正在换弹 = true
	_reload_locked = true

	var total_rotation_time = _play_rotation_animation(0.8)

	await get_tree().create_timer(total_rotation_time).timeout

	if not is_inside_tree() or not 武器物品:
		是否正在换弹 = false
		return false

	if _手动安装弹匣(武器物品, 新弹匣):
		应用外观()
		武器物品._update_stack_label()
		武器物品._generate_weapon_texture()
		if 武器物品.get_equipped_magazine() and 武器物品.chambered_round == 0 and 武器物品.get_equipped_magazine().item_data.current_ammo > 0:
			_chamber_a_round()
			应用外观()
			武器物品._update_stack_label()
	是否正在换弹 = false
	_reload_locked = false
	return true

func _遍历所有网格() -> Array[InventoryGrid]:
	var player = get_tree().get_first_node_in_group("Player")
	if not player or not player.inventory_ui: return []
	var ui = player.inventory_ui
	return [ui.口袋网格, ui.胸挂网格, ui.背包网格]

func _寻找最佳弹匣(弹药类型: String) -> InventoryItem:
	var best = null
	var best_ammo = -1
	for grid in _遍历所有网格():
		for item in grid.items:
			if item is InventoryItem and item.item_data.weapon_part_type == ItemData.WeaponPartType.MAGAZINE:
				if item.item_data.ammo_type == 弹药类型 and item.item_data.current_ammo > 0:
					if item.item_data.current_ammo > best_ammo:
						best_ammo = item.item_data.current_ammo
						best = item
	return best

func 开始压弹():
	if 是否正在压弹 or 是否正在换弹: return
	if not 武器物品: return
	var 弹药类型 = 武器物品.item_data.ammo_type
	if 弹药类型 == "": return
	var 目标弹匣 = _寻找可压弹匣(弹药类型)
	if not 目标弹匣: return

	是否正在压弹 = true
	var 剩余空间 = 目标弹匣.item_data.magazine_capacity - 目标弹匣.item_data.current_ammo
	if 剩余空间 <= 0:
		是否正在压弹 = false
		return

	目标弹匣.show_external_progress(剩余空间)
	if 枪体节点: 枪体节点.visible = false

	var 已装弹数 = 0
	while 剩余空间 > 0 and 是否正在压弹:
		var 子弹物品 = _寻找背包子弹(弹药类型)
		if not 子弹物品: break
		var 可装 = min(剩余空间, 子弹物品.stack_count)
		for i in range(可装):
			if not 是否正在压弹: break
			子弹物品.stack_count -= 1
			if 子弹物品.stack_count <= 0:
				子弹物品.safe_queue_free()
			else:
				子弹物品._update_stack_label()
			目标弹匣.item_data.current_ammo += 1
			if 子弹物品.item_data:
				目标弹匣._loaded_ammo_dict[子弹物品.item_data] = 目标弹匣._loaded_ammo_dict.get(子弹物品.item_data, 0) + 1
			目标弹匣._update_stack_label()
			已装弹数 += 1
			目标弹匣.update_external_progress(已装弹数)
			await get_tree().create_timer(0.3).timeout
		剩余空间 = 目标弹匣.item_data.magazine_capacity - 目标弹匣.item_data.current_ammo

	目标弹匣.hide_external_progress()
	是否正在压弹 = false
	if 枪体节点: 枪体节点.visible = true

func _寻找可压弹匣(弹药类型: String) -> InventoryItem:
	for grid in _遍历所有网格():
		for item in grid.items:
			if item is InventoryItem and item.item_data.weapon_part_type == ItemData.WeaponPartType.MAGAZINE and item.item_data.ammo_type == 弹药类型 and item.item_data.current_ammo < item.item_data.magazine_capacity:
				return item
	return null

func _寻找背包子弹(弹药类型: String) -> InventoryItem:
	for grid in _遍历所有网格():
		for item in grid.items:
			if item is InventoryItem and not item.item_data.is_magazine and not item.item_data.is_weapon and item.item_data.ammo_type == 弹药类型 and item.stack_count > 0:
				return item
	return null

func 退膛():
	if 武器物品 and 武器物品.chambered_round > 0:
		武器物品.unload_chamber()

func 检查弹药():
	if not 武器物品: return
	var 弹匣 = 武器物品.get_equipped_magazine()
	if not 弹匣: return
	var 总弹药 = 武器物品.chambered_round + 弹匣.item_data.current_ammo
	var 最大弹药 = 弹匣.item_data.magazine_capacity + 1
	var 比例 = float(总弹药) / float(最大弹药)
	var 信息 = ""
	if 比例 >= 0.95:
		信息 = "弹匣已满"
	elif 比例 >= 0.75:
		信息 = "几乎全满"
	elif 比例 >= 0.5:
		信息 = "还剩一半"
	elif 比例 >= 0.25:
		信息 = "小于一半"
	else:
		信息 = "几乎空了"

	是否正在检查弹药 = true
	var 玩家 = get_tree().get_first_node_in_group("Player")
	if 玩家:
		玩家.label.text = 信息
		玩家.label.show()
	await get_tree().create_timer(1.0).timeout
	if 玩家 and is_instance_valid(玩家): 玩家.label.hide()
	是否正在检查弹药 = false

# ---------- 外观更新 ----------
func 应用外观():
	if 武器物品 and 枪体节点:
		枪体节点.texture = 武器物品.物品图标.texture
		枪体节点.rotation = 0.0
	var 玩家 = get_tree().get_first_node_in_group("Player")
	if 玩家 and 玩家.inventory_ui and 武器物品._is_equipped:
		玩家.inventory_ui.副武器装备槽.texture = 武器物品.物品图标.texture

# ---------- 特效函数 ----------
func 播放动画(名称: String):
	if 动画播放器 and 动画播放器.has_animation(名称):
		动画播放器.stop()
		动画播放器.play(名称)

func _枪体抖动():
	if not 枪体节点: return
	var orig = 枪体节点.position
	var offset = Vector2(randf_range(-4.0, 4.0), randf_range(-2.0, 2.0))
	var tween = create_tween()
	tween.tween_property(枪体节点, "position", orig + offset, 0.02)
	tween.tween_property(枪体节点, "position", orig, 0.06)

func _抛壳():
	if not 武器物品 or not 武器物品.item_data.shell_scene: return
	var 生成位置 = 抛壳.global_position if 抛壳 else global_position + Vector2(0, -10)
	var shell = 武器物品.item_data.shell_scene.instantiate()
	shell.global_position = 生成位置
	get_tree().current_scene.add_child(shell)
	var 抛出方向 = 1.0 if scale.y > 0 else -1.0
	var 落点 = Vector2(生成位置.x + 抛出方向 * randf_range(30, 60), 生成位置.y + randf_range(10, 25))
	var tween = create_tween()
	tween.tween_property(shell, "global_position", 落点, 0.45).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	create_tween().tween_property(shell, "rotation", shell.rotation + randf_range(-PI, PI), 0.45)

func _震屏():
	var 玩家 = get_tree().get_first_node_in_group("Player")
	if 玩家 and 玩家.has_method("_震屏"):
		玩家._震屏(0.05)

func _发射射线(甲伤: float, 肉伤: float):
	if not 枪口: return
	var start = 枪口.global_position
	var mouse_pos = get_global_mouse_position()
	var dir = (mouse_pos - start).normalized()

	var precision = 武器物品.item_data.weapon_precision
	var mag = 武器物品.get_equipped_magazine()
	if mag:
		precision += mag.item_data.accuracy_modifier
	var sight = 武器物品.get_equipped_sight()
	if sight:
		precision += sight.item_data.accuracy_modifier

	if 是否正在瞄准:
		precision += 30.0

	precision = clamp(precision, 0, 100)
	var spread = 30.0 * (1.0 - precision / 100.0)
	if spread > 0:
		dir = dir.rotated(deg_to_rad(randf_range(-spread / 2.0, spread / 2.0)))

	var end = start + dir * 射线长度

	var query = PhysicsRayQueryParameters2D.create(start, end, 0xFFFFFFFF, [self])
	var player = get_tree().get_first_node_in_group("Player")
	if player: query.exclude.append(player)

	var result = get_world_2d().direct_space_state.intersect_ray(query)
	var hit_point = end

	if result and result.has("collider"):
		var collider = result.collider
		hit_point = result.position
		var target = collider
		while target:
			if target.has_method("take_damage"):
				var part = "body"
				if target.has_method("get_hit_part"):
					part = target.get_hit_part(hit_point)
				target.take_damage(part, 肉伤)
				break
			target = target.get_parent()

	var trail = Line2D.new()
	trail.width = 3.0
	trail.default_color = Color(1.0, 0.8, 0.2)
	trail.add_point(start)
	trail.add_point(hit_point)
	get_tree().current_scene.add_child(trail)
	var trail_tween = create_tween()
	trail_tween.tween_property(trail, "modulate:a", 0.0, 0.08)
	trail_tween.tween_callback(trail.queue_free)

func _延迟生成烟雾():
	await get_tree().create_timer(0.1).timeout
	_生成烟雾()

func _生成烟雾():
	if not 枪口: return
	var smoke = GPUParticles2D.new()
	smoke.position = 枪口.global_position
	smoke.amount = 4
	smoke.lifetime = 0.5
	smoke.one_shot = true
	smoke.explosiveness = 1.0
	smoke.texture = _创建烟雾纹理()
	var mat = ParticleProcessMaterial.new()
	mat.direction = Vector3(0, -1, 0)
	mat.spread = 20.0
	mat.gravity = Vector3(0, -20, 0)
	mat.initial_velocity_min = 10.0
	mat.initial_velocity_max = 20.0
	mat.scale_min = 0.2
	mat.scale_max = 0.6
	mat.color = Color(0.7, 0.7, 0.7, 0.4)
	mat.color_ramp = _创建烟雾颜色渐变()
	smoke.process_material = mat
	get_tree().current_scene.add_child(smoke)
	smoke.emitting = true
	smoke.finished.connect(smoke.queue_free)

func _创建烟雾纹理() -> ImageTexture:
	var size = 32
	var img = Image.create(size, size, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))
	var center = Vector2(size / 2.0, size / 2.0)
	var radius = size / 2.0 - 2.0
	for x in range(size):
		for y in range(size):
			var dist = Vector2(x - center.x, y - center.y).length()
			if dist <= radius:
				var alpha = 1.0 - dist / radius
				img.set_pixel(x, y, Color(1, 1, 1, alpha))
	return ImageTexture.create_from_image(img)

func _创建烟雾颜色渐变() -> GradientTexture1D:
	var gradient = Gradient.new()
	gradient.set_color(0, Color(1, 1, 1, 0.6))
	gradient.set_color(1, Color(1, 1, 1, 0.0))
	var texture = GradientTexture1D.new()
	texture.gradient = gradient
	texture.width = 64
	return texture
