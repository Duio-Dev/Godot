extends CharacterBody2D
class_name PlayerCharacter

const WALK_SPEED = 80.0
const RUN_SPEED = 150.0
const RUN_STAMINA_COST = 20.0
const STAMINA_REGEN = 10.0

@onready var 医疗下: Marker2D = $医疗下
@onready var weapon: Marker2D = $Weapon下
@onready var 头盔显示节点: Sprite2D = $头盔显示节点
@onready var 面罩显示节点: Sprite2D = $"头盔显示节点/面罩显示节点"
@onready var 战术配件: Sprite2D = $头盔显示节点/战术配件
@onready var 背包显示节点: Sprite2D = $背包显示节点

@export var 武器角度偏移: float = -180
@export var debug_damage: float = 10.0

@export var max_head_hp: float = 50.0
@export var max_body_hp: float = 100.0
@export var max_left_arm_hp: float = 35.0
@export var max_right_arm_hp: float = 35.0
@export var max_left_foot_hp: float = 40.0
@export var max_right_foot_hp: float = 40.0

var head_hp: float = max_head_hp
var body_hp: float = max_body_hp
var left_arm_hp: float = max_left_arm_hp
var right_arm_hp: float = max_right_arm_hp
var left_foot_hp: float = max_left_foot_hp
var right_foot_hp: float = max_right_foot_hp

@export var max_hydration: float = 100.0
@export var max_satiety: float = 100.0
@export var max_stamina: float = 100.0
@export var max_weight: float = 30.0

var hydration: float = max_hydration
var satiety: float = max_satiety
var stamina: float = max_stamina
var hearing: float = 1.0

var is_dead: bool = false
var is_running: bool = false
var can_sprint: bool = true

@export var starvation_damage_per_second: float = 1.0

@onready var player_sprite_2d: Sprite2D = $PlayerSprite2D
@onready var animation_player: AnimationPlayer = $AnimationPlayer
@onready var inventory_ui: Control = $"CanvasLayer/背包界面"
@onready var label: Label = $Label
@onready var 头部: CollisionShape2D = $头部
@onready var 身体: CollisionShape2D = $身体
@onready var 左脚: CollisionShape2D = $左脚
@onready var 右脚: CollisionShape2D = $右脚
@onready var 左手: CollisionShape2D = $左手
@onready var 右手: CollisionShape2D = $右手
@onready var camera_2d: Camera2D = $Camera2D

var enable_damage_spread: bool = true
var interactables: Array = []
var current_index: int = -1

# ============================================================
# 武器系统
# ============================================================
var equipped_weapon_item: InventoryItem = null
var current_weapon_instance: Node2D = null
var _default_sprite: Texture2D

var primary_weapon_item: InventoryItem = null
var secondary_weapon_item: InventoryItem = null
var _current_weapon_slot: String = ""

var _item_holder: Control = null

var camera_aim_offset: Vector2 = Vector2.ZERO
var camera_aim_velocity: Vector2 = Vector2.ZERO
var shake_offset: Vector2 = Vector2.ZERO
var shake_tween: Tween = null

var _weapon_slot_dragging: bool = false
var _weapon_slot_drag_start: Vector2 = Vector2.ZERO
var _weapon_slot_drag_threshold: float = 5.0

var is_aiming: bool = false
var aim_zoom_level: float = 0.0
var zoom_transition_speed: float = 10.0
var base_zoom: Vector2 = Vector2(5, 5)

# ---------- 医疗系统 ----------
var is_medicating: bool = false
var _medical_item: InventoryItem = null
var _medical_data: ItemData = null
var _medical_target_part: String = ""
var _medical_total_heal: float = 0.0
var _medical_healed_so_far: float = 0.0
var _medical_is_limb_broken: bool = false
var _medical_max_penalty: float = 0.0
var _saved_weapon_visible: bool = true
var _saved_sprite: Texture2D = null
var _current_medical_effect: Node2D = null
var _last_treated_part: String = ""
var _same_part_count: int = 0
var _failed_parts: Array = []

# ---------- 饮食系统 ----------
var is_consuming: bool = false
var _consume_item: InventoryItem = null
var _consume_data: ItemData = null
var _saved_consume_weapon_visible: bool = true
var _saved_consume_sprite: Texture2D = null
var _current_consume_effect: Node2D = null
var _消耗计时器: Timer = null
var _starvation_timer: Timer = null

# ---------- 增益系统 ----------
var active_buffs: Array = []
var _base_max_stamina: float = 0.0
var _stamina_bonus: float = 0.0
var _damage_reduction: float = 0.0

# ---------- 辐射系统 ----------
var radiation: float = 0.0
const RADIATION_DECAY: float = 2.0
const BLEED_INTERVAL: float = 1.0
var _bleed_timer: float = 0.0
var _radiation_hp_penalty: float = 0.0
var _radiation_blocked: bool = false
var _heavy_damage_spread: bool = false
var _original_max_hp: Dictionary = {}

# ---------- 头盔/面罩系统 ----------
var equipped_helmet_item: InventoryItem = null
var has_thermal_vision: bool = false

# ---------- 背包系统 ----------
var equipped_backpack_item: InventoryItem = null

# ============================================================
func _ready():
	add_to_group("Player")
	if inventory_ui:
		inventory_ui.hide()
	label.hide()
	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
	_reset_hp()
	if player_sprite_2d:
		_default_sprite = player_sprite_2d.texture

	_消耗计时器 = Timer.new()
	_消耗计时器.wait_time = 5.0
	_消耗计时器.timeout.connect(_消耗饱食度和水分)
	add_child(_消耗计时器)
	_消耗计时器.start()

	头盔显示节点.visible = false
	面罩显示节点.visible = false

	# 动态创建背包显示节点（如果场景中没有）
	if not has_node("背包显示节点"):
		var backpack_sprite = Sprite2D.new()
		backpack_sprite.name = "背包显示节点"
		backpack_sprite.z_index = 1
		add_child(backpack_sprite)
		背包显示节点 = backpack_sprite
	if 背包显示节点:
		背包显示节点.visible = false

	_starvation_timer = Timer.new()
	_starvation_timer.wait_time = 1.0
	_starvation_timer.timeout.connect(_on_starvation_tick)
	add_child(_starvation_timer)
	_starvation_timer.start()

	_base_max_stamina = max_stamina

	_item_holder = Control.new()
	_item_holder.name = "WeaponItemHolder"
	_item_holder.visible = false
	_item_holder.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_item_holder)

	_original_max_hp = {
		"head": max_head_hp, "body": max_body_hp,
		"left_arm": max_left_arm_hp, "right_arm": max_right_arm_hp,
		"left_foot": max_left_foot_hp, "right_foot": max_right_foot_hp
	}

# ============================================================
func _physics_process(delta):
	if is_dead:
		return

	var direction = Input.get_vector("move_left", "move_right", "move_up", "move_down")

	# 根据鼠标位置左右翻转身体和头盔
	var mouse_pos = get_global_mouse_position()
	if player_sprite_2d:
		player_sprite_2d.flip_h = mouse_pos.x < global_position.x

	if 头盔显示节点:
		var base_scale_x = abs(头盔显示节点.scale.x)
		头盔显示节点.scale.x = base_scale_x if mouse_pos.x >= global_position.x else -base_scale_x
	# 面罩是头盔子节点，自动跟随，无需单独翻转

	# 背包显示节点：面朝右时背包在左侧（负X），纹理翻转；面朝左时背包在右侧（正X），纹理不翻转
	if 背包显示节点 and equipped_backpack_item:
		var facing_right = mouse_pos.x >= global_position.x
		var base_scale_x = abs(背包显示节点.scale.x)
		# 纹理翻转：面朝右时翻转（scale.x 为负），面朝左时不翻转（scale.x 为正）
		背包显示节点.scale.x = -base_scale_x if facing_right else base_scale_x
		# 位置镜像：使用 ItemData 中的偏移 x 分量，根据朝向取正负
		var offset_x = abs(equipped_backpack_item.item_data.backpack_display_offset.x)
		背包显示节点.position.x = -offset_x if facing_right else offset_x
		背包显示节点.position.y = equipped_backpack_item.item_data.backpack_display_offset.y

	var can_run = true
	if current_weapon_instance:
		if current_weapon_instance.has_method("开始压弹") and current_weapon_instance.是否正在压弹:
			can_run = false
		if current_weapon_instance.get("是否正在检查弹药") == true:
			can_run = false
		if current_weapon_instance.get("是否正在瞄准") == true:
			can_run = false

	var has_stimulant: bool = has_active_buff(ItemData.BuffType.STIMULANT)
	var stamina_cost_multiplier: float = 0.9 if has_stimulant else 1.0
	var stamina_regen_multiplier: float = 1.1 if has_stimulant else 1.0

	if Input.is_key_pressed(KEY_SHIFT) and direction != Vector2.ZERO and can_sprint and stamina > 0 and can_run and hydration > 0 and satiety > 0:
		var has_painkiller = has_active_buff(ItemData.BuffType.PAINKILLER)
		if not has_painkiller and (left_foot_hp <= 0 or right_foot_hp <= 0):
			is_running = false
		else:
			is_running = true
			stamina = max(stamina - RUN_STAMINA_COST * stamina_cost_multiplier * delta, 0.0)
			if stamina == 0:
				can_sprint = false
				is_running = false
	else:
		is_running = false
		stamina = min(stamina + STAMINA_REGEN * stamina_regen_multiplier * delta, max_stamina)
		if stamina >= max_stamina * 0.1:
			can_sprint = true
	if not can_run:
		is_running = false

	var current_speed = RUN_SPEED if is_running else WALK_SPEED
	velocity = direction * current_speed
	move_and_slide()

	# 动画：只有 idle 和 walk
	var target_anim = "walk" if direction != Vector2.ZERO else "idle"
	if animation_player.has_animation(target_anim):
		if animation_player.current_animation != target_anim:
			animation_player.play(target_anim)
	else:
		if animation_player.current_animation != "idle":
			animation_player.play("idle")

	if Input.is_key_pressed(KEY_V):
		print("当前速度: %.1f" % velocity.length())

# ============================================================
func _process(delta):
	# 武器父节点始终为 weapon
	if current_weapon_instance:
		var target_parent = weapon
		if current_weapon_instance.get_parent() != target_parent:
			var old_parent = current_weapon_instance.get_parent()
			if old_parent:
				old_parent.remove_child(current_weapon_instance)
			target_parent.add_child(current_weapon_instance)
			current_weapon_instance.position = Vector2.ZERO
			current_weapon_instance.rotation = 0.0
		target_parent.look_at(get_global_mouse_position())
		target_parent.rotation += deg_to_rad(武器角度偏移)
	else:
		camera_aim_offset = camera_aim_offset.lerp(Vector2.ZERO, delta * 18.0)
		camera_aim_velocity = Vector2.ZERO

	if current_weapon_instance:
		var mouse_pos = get_global_mouse_position()
		var target = (mouse_pos - global_position).normalized() * 35.0
		var stiffness = 30.0
		var damping = 12.0
		var force = (target - camera_aim_offset) * stiffness - camera_aim_velocity * damping
		camera_aim_velocity += force * delta
		camera_aim_offset += camera_aim_velocity * delta
	else:
		camera_aim_offset = camera_aim_offset.lerp(Vector2.ZERO, delta * 18.0)
		camera_aim_velocity = Vector2.ZERO

	if current_weapon_instance:
		is_aiming = current_weapon_instance.是否正在瞄准
		aim_zoom_level = current_weapon_instance.当前瞄准缩放
	else:
		is_aiming = false
		aim_zoom_level = 0.0

	if camera_2d:
		var zoom_factor = 1.0
		if is_aiming and aim_zoom_level > 0.0:
			zoom_factor = 1.0 + aim_zoom_level / 100.0
		var target_zoom = base_zoom / zoom_factor
		camera_2d.zoom = camera_2d.zoom.lerp(target_zoom, delta * zoom_transition_speed)
		camera_2d.position = camera_aim_offset + shake_offset

	# 医疗/饮食效果父节点始终为医疗下
	if _current_medical_effect:
		if _current_medical_effect.get_parent() != 医疗下:
			var old_parent = _current_medical_effect.get_parent()
			if old_parent:
				old_parent.remove_child(_current_medical_effect)
			医疗下.add_child(_current_medical_effect)
			_current_medical_effect.position = Vector2.ZERO
			_current_medical_effect.rotation = 0.0

	if _current_consume_effect:
		if _current_consume_effect.get_parent() != 医疗下:
			var old_parent = _current_consume_effect.get_parent()
			if old_parent:
				old_parent.remove_child(_current_consume_effect)
			医疗下.add_child(_current_consume_effect)
			_current_consume_effect.position = Vector2.ZERO
			_current_consume_effect.rotation = 0.0

	_update_buffs(delta)

	if not _radiation_blocked and not has_active_buff(ItemData.BuffType.RADIATION_REGRESSION):
		radiation = max(radiation - RADIATION_DECAY * delta, 0.0)

	if radiation >= 200:
		_radiation_blocked = true
	else:
		_radiation_blocked = false

	if radiation >= 50:
		_bleed_timer += delta
		while _bleed_timer >= BLEED_INTERVAL:
			_bleed_timer -= BLEED_INTERVAL
			_apply_radiation_bleed()

	if radiation >= 100 and _radiation_hp_penalty < 20:
		for buff in active_buffs.duplicate():
			if buff.type != ItemData.BuffType.RADIATION_SICKNESS and buff.type != ItemData.BuffType.RADIATION_DECAY and buff.type != ItemData.BuffType.RADIATION_REGRESSION:
				_apply_buff_effect(buff.type, buff.value, false)
				active_buffs.erase(buff)
		if not has_active_buff(ItemData.BuffType.DAMAGE_CONTROL):
			_heavy_damage_spread = true
			enable_damage_spread = true
		_apply_hp_penalty(20)
		if not has_active_buff(ItemData.BuffType.RADIATION_SICKNESS):
			apply_buff(ItemData.BuffType.RADIATION_SICKNESS, 0.0, 999999.0)

	if radiation >= 200:
		for buff in active_buffs.duplicate():
			if buff.type != ItemData.BuffType.RADIATION_REGRESSION:
				_apply_buff_effect(buff.type, buff.value, false)
				active_buffs.erase(buff)
		if not has_active_buff(ItemData.BuffType.DAMAGE_CONTROL):
			_heavy_damage_spread = true
			enable_damage_spread = true
		if _radiation_hp_penalty < 150:
			_apply_hp_penalty(150 - _radiation_hp_penalty)
		if not has_active_buff(ItemData.BuffType.RADIATION_DECAY):
			apply_buff(ItemData.BuffType.RADIATION_DECAY, 0.0, 999999.0)

	if radiation < 100 and has_active_buff(ItemData.BuffType.RADIATION_SICKNESS):
		for i in range(active_buffs.size() - 1, -1, -1):
			if active_buffs[i].type == ItemData.BuffType.RADIATION_SICKNESS:
				active_buffs.remove_at(i)

func _apply_radiation_bleed():
	var head_min = 0
	if radiation < 100:
		head_min = 1
	var parts = {
		"head": head_hp, "body": body_hp, "left_arm": left_arm_hp,
		"right_arm": right_arm_hp, "left_foot": left_foot_hp, "right_foot": right_foot_hp
	}
	for part in parts:
		var hp = parts[part]
		var damage = 1.0
		if part == "head":
			if hp - damage < head_min:
				damage = max(hp - head_min, 0.0)
		take_damage(part, damage)

func _apply_hp_penalty(amount: float):
	var actual = min(amount, 150 - _radiation_hp_penalty)
	if actual <= 0:
		return
	_radiation_hp_penalty += actual
	max_head_hp = max(0, _original_max_hp["head"] - _radiation_hp_penalty)
	max_body_hp = max(0, _original_max_hp["body"] - _radiation_hp_penalty)
	max_left_arm_hp = max(0, _original_max_hp["left_arm"] - _radiation_hp_penalty)
	max_right_arm_hp = max(0, _original_max_hp["right_arm"] - _radiation_hp_penalty)
	max_left_foot_hp = max(0, _original_max_hp["left_foot"] - _radiation_hp_penalty)
	max_right_foot_hp = max(0, _original_max_hp["right_foot"] - _radiation_hp_penalty)
	head_hp = min(head_hp, max_head_hp)
	body_hp = min(body_hp, max_body_hp)
	left_arm_hp = min(left_arm_hp, max_left_arm_hp)
	right_arm_hp = min(right_arm_hp, max_right_arm_hp)
	left_foot_hp = min(left_foot_hp, max_left_foot_hp)
	right_foot_hp = min(right_foot_hp, max_right_foot_hp)

# ============================================================
func _input(event):
	if is_dead:
		return

	if event is InputEventMouseButton and event.is_pressed():
		if event.button_index == MOUSE_BUTTON_WHEEL_UP:
			_switch_interactable(-1)
		elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			_switch_interactable(1)

	# F 键拾取/搜索
	if event is InputEventKey and event.keycode == KEY_F and event.pressed:
		if current_index >= 0 and current_index < interactables.size():
			var target = interactables[current_index]
			if target is ContainerLoot:
				inventory_ui.show_container(target)
			elif target is LootItem:
				var success = target.try_pickup(self)
				if not success:
					_show_message("背包已满")

	# H 键搜索掉落的背包
	if event is InputEventKey and event.keycode == KEY_H and event.pressed:
		if current_index >= 0 and current_index < interactables.size():
			var target = interactables[current_index]
			if target is LootItem and target.item_data and target.item_data.is_backpack:
				if inventory_ui and inventory_ui.has_method("show_backpack_loot"):
					inventory_ui.show_backpack_loot(target)
			else:
				print("当前目标不是掉落背包")

	if event is InputEventKey and event.keycode == KEY_TAB and event.pressed:
		if inventory_ui:
			inventory_ui.toggle_visibility()

	if event is InputEventKey and event.pressed:
		match event.keycode:
			KEY_1:
				if primary_weapon_item:
					equip_weapon_from_slot("primary")
			KEY_2:
				if secondary_weapon_item:
					equip_weapon_from_slot("secondary")

# ============================================================
# ---------- 武器核心函数 ----------
func store_and_equip_weapon(item: InventoryItem, slot: String) -> bool:
	if not item or item.item_data.weapon_part_type != ItemData.WeaponPartType.RECEIVER:
		return false

	# 检查必要配件：枪管和后握把
	var has_barrel = false
	var has_grip = false
	for part in item.installed_parts.values():
		if part.item_data.weapon_part_type == ItemData.WeaponPartType.BARREL:
			has_barrel = true
		elif part.item_data.weapon_part_type == ItemData.WeaponPartType.PISTOL_GRIP:
			has_grip = true
	if not has_barrel or not has_grip:
		print("武器缺少必要配件：枪管和后握把，无法装备")
		return false

	if slot != "primary" and slot != "secondary":
		return false

	var old_item = primary_weapon_item if slot == "primary" else secondary_weapon_item
	if old_item and old_item != item:
		if equipped_weapon_item == old_item:
			_unequip_current_weapon()
		if old_item.get_parent():
			old_item.get_parent().remove_child(old_item)
		_put_back_to_backpack(old_item)
		if slot == "primary":
			primary_weapon_item = null
		else:
			secondary_weapon_item = null

	if item.get_parent():
		item.get_parent().remove_child(item)
	item.visible = false
	item._is_equipped = false
	_item_holder.add_child(item)

	if slot == "primary":
		primary_weapon_item = item
	else:
		secondary_weapon_item = item

	if inventory_ui:
		inventory_ui._update_weapon_slots()

	return true

func equip_weapon_from_slot(slot: String):
	var target_item = primary_weapon_item if slot == "primary" else secondary_weapon_item
	if not target_item:
		return
	if equipped_weapon_item == target_item:
		return

	if equipped_weapon_item:
		_unequip_current_weapon()

	if target_item.get_parent():
		target_item.get_parent().remove_child(target_item)
	_equip_weapon(target_item, slot)

	if inventory_ui:
		inventory_ui._update_weapon_slots()

func _equip_weapon(item: InventoryItem, slot: String):
	if not item or not item.item_data.is_weapon:
		return

	equipped_weapon_item = item
	_current_weapon_slot = slot
	item._is_equipped = true

	current_weapon_instance = item.item_data.weapon_scene.instantiate()
	current_weapon_instance.add_child(item)
	item.visible = false

	var target_parent = weapon
	target_parent.add_child(current_weapon_instance)
	current_weapon_instance.position = Vector2.ZERO

	if current_weapon_instance.has_method("装备"):
		current_weapon_instance.装备(item)

	if 左手:
		左手.disabled = true
	if 右手:
		右手.disabled = true

	if item.item_data.weapon_sprite:
		player_sprite_2d.texture = item.item_data.weapon_sprite

	is_aiming = false
	aim_zoom_level = 0.0
	print("[武器] 已装备:", item.item_data.item_name, " 槽位:", slot)

func _unequip_current_weapon():
	if not equipped_weapon_item:
		return

	var item = equipped_weapon_item

	if current_weapon_instance and item.get_parent() == current_weapon_instance:
		current_weapon_instance.remove_child(item)

	equipped_weapon_item = null
	_current_weapon_slot = ""
	item._is_equipped = false

	if current_weapon_instance:
		current_weapon_instance.queue_free()
		current_weapon_instance = null

	if 左手:
		左手.disabled = false
	if 右手:
		右手.disabled = false
	if _default_sprite:
		player_sprite_2d.texture = _default_sprite
	is_aiming = false
	aim_zoom_level = 0.0

	item.visible = false
	_item_holder.add_child(item)

func unequip_weapon():
	if not equipped_weapon_item:
		return

	var old_slot = _current_weapon_slot
	var old_item = equipped_weapon_item

	_unequip_current_weapon()

	if old_item.get_parent():
		old_item.get_parent().remove_child(old_item)
	_put_back_to_backpack(old_item)

	if old_slot == "primary":
		primary_weapon_item = null
	elif old_slot == "secondary":
		secondary_weapon_item = null

	var other_slot = "secondary" if old_slot == "primary" else "primary"
	var other_item = primary_weapon_item if other_slot == "primary" else secondary_weapon_item
	if other_item:
		equip_weapon_from_slot(other_slot)
	else:
		if inventory_ui:
			inventory_ui._update_weapon_slots()

func equip_weapon(item: InventoryItem) -> bool:
	if not item or item.item_data.weapon_part_type != ItemData.WeaponPartType.RECEIVER:
		return false

	if not item.installed_parts.has("枪管接口"):
		print("[装备] 武器缺少枪管，无法装备")
		return false
	if not item.installed_parts.has("后握把接口"):
		print("[装备] 武器缺少后握把，无法装备")
		return false

	var target_slot = ""
	if not primary_weapon_item:
		target_slot = "primary"
	elif not secondary_weapon_item:
		target_slot = "secondary"
	else:
		print("[装备] 主副武器槽都已满，请先卸下其中一个")
		return false

	store_and_equip_weapon(item, target_slot)
	return true

# ---------- 头盔/面罩核心函数 ----------
func equip_helmet(item: InventoryItem) -> bool:
	if not item or item.item_data.weapon_part_type != ItemData.WeaponPartType.HELMET:
		return false
	if equipped_helmet_item:
		unequip_helmet()
	if item.get_parent():
		item.get_parent().remove_child(item)
	equipped_helmet_item = item
	item._is_equipped = true
	item.visible = false
	_item_holder.add_child(item)
	_update_helmet_display()
	_update_thermal_vision()
	if inventory_ui:
		inventory_ui._update_helmet_slot()
	return true

func unequip_helmet():
	if not equipped_helmet_item:
		return
	var item = equipped_helmet_item
	equipped_helmet_item = null
	item._is_equipped = false
	if item.get_parent():
		item.get_parent().remove_child(item)
	_update_helmet_display()
	_update_thermal_vision()
	_put_back_to_backpack(item)
	if inventory_ui:
		inventory_ui._update_helmet_slot()

func _update_helmet_display():
	if equipped_helmet_item:
		头盔显示节点.visible = true
		var helmet_tex = equipped_helmet_item.item_data.helmet_display_texture if equipped_helmet_item.item_data.helmet_display_texture else equipped_helmet_item.item_data.icon
		头盔显示节点.texture = helmet_tex
		var visor = equipped_helmet_item.get_equipped_part_of_type(ItemData.WeaponPartType.VISOR)
		if visor:
			面罩显示节点.visible = true
			var visor_tex = visor.item_data.visor_display_texture if visor.item_data.visor_display_texture else (visor.item_data.model_texture if visor.item_data.model_texture else visor.item_data.icon)
			面罩显示节点.texture = visor_tex
		else:
			面罩显示节点.visible = false
	else:
		头盔显示节点.visible = false
		面罩显示节点.visible = false

func _update_thermal_vision():
	has_thermal_vision = false
	if equipped_helmet_item:
		if equipped_helmet_item.item_data.has_thermal_imaging:
			has_thermal_vision = true
		else:
			var visor = equipped_helmet_item.get_equipped_part_of_type(ItemData.WeaponPartType.VISOR)
			if visor and visor.item_data.has_thermal_imaging:
				has_thermal_vision = true

func start_drag_helmet():
	if not equipped_helmet_item:
		return
	var item = equipped_helmet_item
	equipped_helmet_item = null
	item._is_equipped = false

	_update_helmet_display()
	_update_thermal_vision()

	if item.get_parent():
		item.get_parent().remove_child(item)

	item.anchor_left = 0.0
	item.anchor_top = 0.0
	item.anchor_right = 0.0
	item.anchor_bottom = 0.0
	item.margin = 4.0
	item.mouse_filter = Control.MOUSE_FILTER_STOP
	item.parent_grid = null
	item.grid_pos = Vector2i(-1, -1)
	item.visible = true
	item._update_size()

	var top_layer = get_tree().root.get_node_or_null("DragLayer")
	if not top_layer:
		top_layer = CanvasLayer.new()
		top_layer.name = "DragLayer"
		top_layer.layer = 100
		get_tree().root.add_child(top_layer)
	top_layer.add_child(item)
	item.global_position = get_global_mouse_position()

	if inventory_ui:
		inventory_ui._update_helmet_slot()

	await get_tree().process_frame
	if is_instance_valid(item):
		item._update_size()
		item._start_drag()

func _put_back_to_backpack(item: InventoryItem):
	if not item:
		return
	item._is_equipped = false
	if item.get_parent():
		item.get_parent().remove_child(item)
	item.anchor_left = 0.0
	item.anchor_top = 0.0
	item.anchor_right = 0.0
	item.anchor_bottom = 0.0
	item.offset_left = 0.0
	item.offset_top = 0.0
	item.offset_right = 0.0
	item.offset_bottom = 0.0
	item.margin = 4.0
	item.mouse_filter = Control.MOUSE_FILTER_STOP
	item.parent_grid = null
	item.grid_pos = Vector2i(-1, -1)
	item.visible = true
	item._update_size()
	item.update_search_visuals()
	if not _放回背包(item):
		item._discard_item()
		item.queue_free()

func start_drag_weapon():
	if not equipped_weapon_item:
		return
	var item = equipped_weapon_item
	var slot = _current_weapon_slot

	if slot == "primary":
		primary_weapon_item = null
	elif slot == "secondary":
		secondary_weapon_item = null

	equipped_weapon_item = null
	_current_weapon_slot = ""
	item._is_equipped = false

	if item.get_parent():
		item.get_parent().remove_child(item)

	if current_weapon_instance:
		if current_weapon_instance.has_method("卸下"):
			current_weapon_instance.卸下()
		current_weapon_instance.queue_free()
		current_weapon_instance = null

	if 左手:
		左手.disabled = false
	if 右手:
		右手.disabled = false
	if _default_sprite:
		player_sprite_2d.texture = _default_sprite
	if inventory_ui:
		inventory_ui._update_weapon_slots()
		inventory_ui.副武器装备槽.texture = null

	item.anchor_left = 0.0
	item.anchor_top = 0.0
	item.anchor_right = 0.0
	item.anchor_bottom = 0.0
	item.margin = 4.0
	item.mouse_filter = Control.MOUSE_FILTER_STOP
	item.parent_grid = null
	item.grid_pos = Vector2i(-1, -1)
	item.visible = true
	item._update_size()

	var top_layer = get_tree().root.get_node_or_null("DragLayer")
	if not top_layer:
		top_layer = CanvasLayer.new()
		top_layer.name = "DragLayer"
		top_layer.layer = 100
		get_tree().root.add_child(top_layer)
	top_layer.add_child(item)
	item.global_position = get_global_mouse_position()
	await get_tree().process_frame
	if is_instance_valid(item):
		item._update_size()
		item._start_drag()

func _放回背包(item: InventoryItem) -> bool:
	var grids = [inventory_ui.口袋网格, inventory_ui.胸挂网格, inventory_ui.背包网格]
	for g in grids:
		if g.has_method("_cleanup_invalid_items"):
			g._cleanup_invalid_items()

	if item.grid_pos != Vector2i(-1, -1) and item.parent_grid:
		if item.parent_grid._can_place_at(item, item.grid_pos):
			item.parent_grid._place_item(item, item.grid_pos)
			return true

	for grid in grids:
		for x in range(grid.columns):
			for y in range(grid.rows):
				var pos = Vector2i(x, y)
				if grid._can_place_at(item, pos):
					grid._place_item(item, pos)
					return true
	return false

func _on_weapon_slot_gui_input(event: InputEvent, slot: String = ""):
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_RIGHT and event.pressed:
		if equipped_weapon_item:
			var target_item = primary_weapon_item if slot == "primary" else secondary_weapon_item
			if equipped_weapon_item == target_item:
				unequip_weapon()
		else:
			unequip_slot_weapon(slot)
		return

	if not equipped_weapon_item:
		return
	var target_item = primary_weapon_item if slot == "primary" else secondary_weapon_item
	if equipped_weapon_item != target_item:
		return

	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_LEFT:
			if event.pressed:
				_weapon_slot_dragging = false
				_weapon_slot_drag_start = get_global_mouse_position()
			else:
				_weapon_slot_dragging = false

	if event is InputEventMouseMotion:
		if Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT) and equipped_weapon_item:
			var distance = get_global_mouse_position().distance_to(_weapon_slot_drag_start)
			if distance > _weapon_slot_drag_threshold and not _weapon_slot_dragging:
				_weapon_slot_dragging = true
				start_drag_weapon()

func unequip_slot_weapon(slot: String):
	var item = primary_weapon_item if slot == "primary" else secondary_weapon_item
	if not item:
		return
	if item.get_parent():
		item.get_parent().remove_child(item)
	_put_back_to_backpack(item)
	if slot == "primary":
		primary_weapon_item = null
	else:
		secondary_weapon_item = null
	if inventory_ui:
		inventory_ui._update_weapon_slots()

# ============================================================
# 背包系统新增函数
# ============================================================
func equip_backpack(item: InventoryItem) -> bool:
	if not item or not item.item_data.is_backpack:
		return false
	if equipped_backpack_item:
		unequip_backpack()
	if item.get_parent():
		item.get_parent().remove_child(item)
	equipped_backpack_item = item
	item._is_equipped = true
	item.visible = false
	_item_holder.add_child(item)
	_update_backpack_display()
	if inventory_ui:
		inventory_ui._update_backpack_grid()
		inventory_ui._update_backpack_slot()
	return true

func unequip_backpack():
	if equipped_backpack_item == null:
		return

	# 1. 保存背包内部数据到背包物品实例，并清空背包网格
	if inventory_ui:
		inventory_ui.prepare_backpack_unequip()

	# 2. 将背包物品本身放回玩家其他网格（胸挂或口袋优先）
	var backpack_item = equipped_backpack_item
	backpack_item._is_equipped = false
	backpack_item.visible = true
	backpack_item.modulate.a = 1.0

	# 3. 尝试放置到可用网格
	var placed = false
	if inventory_ui:
		var grids = [
			inventory_ui.胸挂网格,
			inventory_ui.口袋网格,
			inventory_ui.背包网格
		]
		for grid in grids:
			if grid == null or not grid.visible:
				continue
			for x in range(grid.columns):
				for y in range(grid.rows):
					var pos = Vector2i(x, y)
					if grid._can_place_at(backpack_item, pos):
						grid._place_item(backpack_item, pos)
						placed = true
						break
				if placed:
					break
			if placed:
				break

	# 4. 如果没地方放，则丢到地面
	if not placed:
		var loot = load("res://场景/所有继承场景的父场景/loot_item.tscn").instantiate()
		loot.item_data = backpack_item.item_data
		loot.stack_count = backpack_item.stack_count
		loot.backpack_data = {
			"items_data": backpack_item.backpack_items_data.duplicate(),
			"items_positions": backpack_item.backpack_items_positions.duplicate(),
			"items_searched": backpack_item.backpack_items_searched.duplicate(),
			"items_stack_counts": backpack_item.backpack_items_stack_counts.duplicate()
		}
		loot.global_position = global_position + Vector2(randf_range(-20, 20), randf_range(-20, 20))
		get_tree().current_scene.add_child(loot)
		backpack_item.queue_free()

	# 5. 无论放置成功还是丢弃，都清空引用
	equipped_backpack_item = null

	# 6. 更新显示和 UI
	_update_backpack_display()
	if inventory_ui:
		inventory_ui._update_backpack_slot()
		inventory_ui._update_backpack_grid()

func start_drag_backpack():
	if not equipped_backpack_item:
		return
	var item = equipped_backpack_item
	equipped_backpack_item = null
	item._is_equipped = false
	if item.get_parent():
		item.get_parent().remove_child(item)
	item.anchor_left = 0.0
	item.anchor_top = 0.0
	item.anchor_right = 0.0
	item.anchor_bottom = 0.0
	item.margin = 4.0
	item.mouse_filter = Control.MOUSE_FILTER_STOP
	item.parent_grid = null
	item.grid_pos = Vector2i(-1, -1)
	item.visible = true
	item._update_size()
	var top_layer = get_tree().root.get_node_or_null("DragLayer")
	if not top_layer:
		top_layer = CanvasLayer.new()
		top_layer.name = "DragLayer"
		top_layer.layer = 100
		get_tree().root.add_child(top_layer)
	top_layer.add_child(item)
	item.global_position = get_global_mouse_position()
	_update_backpack_display()
	if inventory_ui:
		inventory_ui._update_backpack_grid()
		inventory_ui._update_backpack_slot()
	await get_tree().process_frame
	if is_instance_valid(item):
		item._update_size()
		item._start_drag()

func _update_backpack_display():
	if equipped_backpack_item:
		if 背包显示节点:
			背包显示节点.visible = true
			var tex = equipped_backpack_item.item_data.backpack_display_texture if equipped_backpack_item.item_data.backpack_display_texture else equipped_backpack_item.item_data.icon
			背包显示节点.texture = tex
			# 设置位置为 ItemData 中定义的偏移
			背包显示节点.position = equipped_backpack_item.item_data.backpack_display_offset
	else:
		if 背包显示节点:
			背包显示节点.visible = false

# ============================================================
# 医疗系统
# ============================================================
func use_medical_item(item: InventoryItem) -> bool:
	if is_medicating:
		print("[医疗] 正在使用医疗物品，请等待完成")
		return false
	if not item.item_data.is_medical:
		print("[医疗] 物品不是医疗物品")
		return false

	var data = item.item_data
	if data.medical_durability <= 0.001:
		print("[医疗] 医疗物品耐久耗尽")
		return false

	_failed_parts.clear()
	_same_part_count = 0
	_last_treated_part = ""

	if data.is_surgery_kit:
		var found_broken = false
		var parts = ["head","body","left_arm","right_arm","left_foot","right_foot"]
		for p in parts:
			var hp = _get_hp_by_part(p)
			if hp <= 0.001:
				found_broken = true
				break
		if not found_broken:
			print("[手术包] 没有断肢需要修复")
			return false

	var heal_targets = [
		{"part": "head", "hp": head_hp, "max": max_head_hp},
		{"part": "body", "hp": body_hp, "max": max_body_hp},
		{"part": "left_arm", "hp": left_arm_hp, "max": max_left_arm_hp},
		{"part": "right_arm", "hp": right_arm_hp, "max": max_right_arm_hp},
		{"part": "left_foot", "hp": left_foot_hp, "max": max_left_foot_hp},
		{"part": "right_foot", "hp": right_foot_hp, "max": max_right_foot_hp}
	]

	var target_part = null
	var need_heal = 0.0
	var is_limb_broken = false
	var has_injury = false

	for t in heal_targets:
		if t.max - t.hp > 0.01:
			has_injury = true
			var is_broken = (t.hp <= 0.001)
			if data.is_surgery_kit and not is_broken:
				continue
			if not data.is_surgery_kit and is_broken and not data.can_heal_limb:
				continue
			target_part = t.part
			need_heal = t.max - t.hp
			is_limb_broken = is_broken
			break

	if target_part == null:
		if has_injury and not data.is_surgery_kit and not data.can_heal_limb:
			print("[医疗] 存在断肢部位，但该物品无法治疗断肢，请使用手术包或可治疗断肢的药物")
		else:
			print("[医疗] 没有合适的部位可以治疗（可能已满血）")
		return false

	var actual_heal = need_heal
	var max_penalty = 0.0
	if is_limb_broken and (data.can_heal_limb or data.is_surgery_kit):
		actual_heal = min(data.limb_heal_amount, need_heal)
		max_penalty = data.limb_heal_max_penalty

	is_medicating = true
	_medical_item = item
	_medical_data = data
	_medical_target_part = target_part
	_medical_total_heal = actual_heal
	_medical_healed_so_far = 0.0
	_medical_is_limb_broken = is_limb_broken
	_medical_max_penalty = max_penalty

	if data.use_hide_weapon and current_weapon_instance:
		_saved_weapon_visible = current_weapon_instance.visible
		current_weapon_instance.visible = false
	if data.use_sprite:
		_saved_sprite = player_sprite_2d.texture
		player_sprite_2d.texture = data.use_sprite

	_show_medical_effect()
	if _medical_item and is_instance_valid(_medical_item):
		_medical_item.show_medical_progress(true, 0.0)

	print("[治疗] 开始治疗 %s，治疗量=%.2f，当前血量=%.2f/%.2f" % [target_part, actual_heal, _get_hp_by_part(target_part), _get_max_hp_by_part(target_part)])

	await _perform_medical_treatment()

	if _medical_data and _medical_data.buff_type != ItemData.BuffType.NONE and _medical_data.buff_duration > 0:
		apply_buff(_medical_data.buff_type, _medical_data.buff_value, _medical_data.buff_duration)
	elif _medical_data and _medical_data.buff_type != ItemData.BuffType.NONE and _medical_data.buff_duration == 0:
		_apply_instant_buff(_medical_data.buff_type, _medical_data.buff_value)

	return true

func _perform_medical_treatment():
	var data = _medical_data
	if data.activation_time > 0:
		await get_tree().create_timer(data.activation_time).timeout
		if not is_medicating:
			_cleanup_medical()
			return

	var duration = data.treatment_duration
	if duration <= 0:
		duration = 0.1
	var elapsed = 0.0
	var step_time = 0.05
	var total_heal = _medical_total_heal
	var healed_so_far = 0.0

	var initial_hp = _get_hp_by_part(_medical_target_part)
	var max_hp = _get_max_hp_by_part(_medical_target_part)
	var need_heal = max_hp - initial_hp

	while elapsed < duration and is_medicating:
		await get_tree().create_timer(step_time).timeout
		if not is_medicating:
			_cleanup_medical()
			return
		elapsed += step_time
		var progress = min(elapsed / duration, 1.0)
		var target_heal = progress * total_heal
		var heal_this_step = target_heal - healed_so_far
		if heal_this_step > 0:
			_apply_heal_simple(heal_this_step)
			healed_so_far += heal_this_step
			var hp = _get_hp_by_part(_medical_target_part)
			print("[治疗] 进度 %.0f%%，当前血量=%.2f/%.2f" % [progress*100, hp, max_hp])
			if _medical_item and is_instance_valid(_medical_item):
				_medical_item.update_medical_progress(progress)

	if total_heal >= need_heal:
		match _medical_target_part:
			"head": head_hp = max_head_hp
			"body": body_hp = max_body_hp
			"left_arm": left_arm_hp = max_left_arm_hp
			"right_arm": right_arm_hp = max_right_arm_hp
			"left_foot": left_foot_hp = max_left_foot_hp
			"right_foot": right_foot_hp = max_right_foot_hp
	else:
		var remaining = total_heal - healed_so_far
		if remaining > 0.001:
			var current_hp = _get_hp_by_part(_medical_target_part)
			var space = max_hp - current_hp
			var apply = min(remaining, space)
			if apply > 0:
				_apply_heal_simple(apply)

	if _medical_is_limb_broken and (data.can_heal_limb or data.is_surgery_kit):
		_apply_limb_penalty()

	var total_cost: float = 0.0
	if data.is_surgery_kit:
		total_cost = 1.0
	else:
		total_cost = _medical_total_heal + (1 if _medical_is_limb_broken and data.can_heal_limb else 0)
	data.medical_durability -= total_cost
	if data.medical_durability < 0:
		data.medical_durability = 0

	if _medical_item and is_instance_valid(_medical_item):
		_medical_item._update_stack_label()

	if data.medical_durability <= 0.001:
		_medical_item.stack_count -= 1
		if _medical_item.stack_count <= 0:
			_medical_item.queue_free()
			_medical_item = null
		else:
			_medical_item._update_stack_label()

	var finished_item = _medical_item
	var finished_data = _medical_data

	var final_hp = _get_hp_by_part(_medical_target_part)
	var final_max = _get_max_hp_by_part(_medical_target_part)
	print("[治疗] 完成 %s，最终血量=%.2f/%.2f" % [_medical_target_part, final_hp, final_max])

	_cleanup_medical()

	if finished_item and is_instance_valid(finished_item) and finished_data.medical_durability > 0.001 and not finished_data.is_surgery_kit:
		var next_part = _find_next_injured_part()
		if next_part != "":
			if next_part == _last_treated_part:
				_same_part_count += 1
				if _same_part_count >= 3:
					if not _failed_parts.has(next_part):
						_failed_parts.append(next_part)
						print("[医疗] %s 连续治疗3次无效，加入失败列表" % next_part)
					_last_treated_part = ""
					_same_part_count = 0
					next_part = _find_next_injured_part()
					if next_part != "":
						_last_treated_part = next_part
						_same_part_count = 1
						use_medical_item(finished_item)
					else:
						print("[医疗] 所有可治疗部位均已尝试")
				else:
					use_medical_item(finished_item)
			else:
				_last_treated_part = next_part
				_same_part_count = 1
				use_medical_item(finished_item)
		else:
			_last_treated_part = ""
			_same_part_count = 0
			_failed_parts.clear()
	else:
		_last_treated_part = ""
		_same_part_count = 0
		_failed_parts.clear()

func _apply_heal_simple(amount: float):
	match _medical_target_part:
		"head": head_hp = min(head_hp + amount, max_head_hp)
		"body": body_hp = min(body_hp + amount, max_body_hp)
		"left_arm": left_arm_hp = min(left_arm_hp + amount, max_left_arm_hp)
		"right_arm": right_arm_hp = min(right_arm_hp + amount, max_right_arm_hp)
		"left_foot": left_foot_hp = min(left_foot_hp + amount, max_left_foot_hp)
		"right_foot": right_foot_hp = min(right_foot_hp + amount, max_right_foot_hp)

func _get_hp_by_part(part: String) -> float:
	match part:
		"head": return head_hp
		"body": return body_hp
		"left_arm": return left_arm_hp
		"right_arm": return right_arm_hp
		"left_foot": return left_foot_hp
		"right_foot": return right_foot_hp
	return 0.0

func _get_max_hp_by_part(part: String) -> float:
	match part:
		"head": return max_head_hp
		"body": return max_body_hp
		"left_arm": return max_left_arm_hp
		"right_arm": return max_right_arm_hp
		"left_foot": return max_left_foot_hp
		"right_foot": return max_right_foot_hp
	return 0.0

func _apply_limb_penalty():
	var p = _medical_max_penalty
	match _medical_target_part:
		"head":
			max_head_hp = max(0, max_head_hp - p)
			head_hp = min(head_hp, max_head_hp)
		"body":
			max_body_hp = max(0, max_body_hp - p)
			body_hp = min(body_hp, max_body_hp)
		"left_arm":
			max_left_arm_hp = max(0, max_left_arm_hp - p)
			left_arm_hp = min(left_arm_hp, max_left_arm_hp)
		"right_arm":
			max_right_arm_hp = max(0, max_right_arm_hp - p)
			right_arm_hp = min(right_arm_hp, max_right_arm_hp)
		"left_foot":
			max_left_foot_hp = max(0, max_left_foot_hp - p)
			left_foot_hp = min(left_foot_hp, max_left_foot_hp)
		"right_foot":
			max_right_foot_hp = max(0, max_right_foot_hp - p)
			right_foot_hp = min(right_foot_hp, max_right_foot_hp)

func _cleanup_medical():
	if _current_medical_effect:
		_current_medical_effect.queue_free()
		_current_medical_effect = null

	if _medical_item and is_instance_valid(_medical_item):
		_medical_item.show_medical_progress(false)

	if _medical_data and _medical_data.use_hide_weapon and current_weapon_instance:
		current_weapon_instance.visible = _saved_weapon_visible
	if _medical_data and _medical_data.use_sprite and _saved_sprite:
		player_sprite_2d.texture = _saved_sprite
		_saved_sprite = null

	is_medicating = false
	_medical_item = null
	_medical_data = null

func _show_medical_effect():
	if not _medical_data or not _medical_data.medical_scene:
		return
	var node = 医疗下
	var effect = _medical_data.medical_scene.instantiate()
	node.add_child(effect)
	_current_medical_effect = effect
	effect.position = Vector2.ZERO

	if effect.has_node("AnimationPlayer"):
		var ap = effect.get_node("AnimationPlayer") as AnimationPlayer
		if ap and ap.has_animation(_medical_data.medical_animation):
			ap.play(_medical_data.medical_animation)
	elif effect.has_method("play"):
		effect.call("play", _medical_data.medical_animation)

func _find_next_injured_part() -> String:
	var parts = [
		{"part": "head", "hp": head_hp, "max": max_head_hp},
		{"part": "body", "hp": body_hp, "max": max_body_hp},
		{"part": "left_arm", "hp": left_arm_hp, "max": max_left_arm_hp},
		{"part": "right_arm", "hp": right_arm_hp, "max": max_right_arm_hp},
		{"part": "left_foot", "hp": left_foot_hp, "max": max_left_foot_hp},
		{"part": "right_foot", "hp": right_foot_hp, "max": max_right_foot_hp}
	]
	for t in parts:
		if t.max - t.hp > 0.01 and not _failed_parts.has(t.part):
			return t.part
	return ""

# ============================================================
# 饮食系统
# ============================================================
func use_food_or_drink_item(item: InventoryItem) -> bool:
	if is_consuming:
		print("[饮食] 正在使用物品，请等待完成")
		return false
	if not item.item_data.is_food_or_drink:
		print("[饮食] 物品不是饮食类")
		return false

	var data = item.item_data
	if data.consume_durability <= 0:
		print("[饮食] 物品已耗尽")
		return false

	var has_buff = data.buff_type != ItemData.BuffType.NONE and data.buff_duration > 0

	var need_hydration = max(0.0, max_hydration - hydration)
	var need_satiety = max(0.0, max_satiety - satiety)
	var need_stamina = max(0.0, max_stamina - stamina)

	var actual_hydration = min(data.hydration_restore, need_hydration)
	var actual_satiety = min(data.satiety_restore, need_satiety)
	var actual_stamina = min(data.stamina_restore, need_stamina)

	if (actual_hydration <= 0 and actual_satiety <= 0 and actual_stamina <= 0) and not has_buff:
		print("[饮食] 没有属性需要恢复，且无增益效果")
		return false

	is_consuming = true
	_consume_item = item
	_consume_data = data

	if data.consume_hide_weapon and current_weapon_instance:
		_saved_consume_weapon_visible = current_weapon_instance.visible
		current_weapon_instance.visible = false
	if data.consume_sprite:
		_saved_consume_sprite = player_sprite_2d.texture
		player_sprite_2d.texture = data.consume_sprite

	_show_consume_effect()
	if _consume_item and is_instance_valid(_consume_item):
		_consume_item.show_medical_progress(true, 0.0)

	await _perform_consumption(actual_hydration, actual_satiety, actual_stamina, has_buff)

	if has_buff:
		apply_buff(data.buff_type, data.buff_value, data.buff_duration)

	return true

func _perform_consumption(hydration_restore: float, satiety_restore: float, stamina_restore: float, has_buff: bool = false):
	if not _consume_data:
		_cleanup_consume()
		return

	if _consume_data.food_activation_time > 0:
		await get_tree().create_timer(_consume_data.food_activation_time).timeout
		if not is_consuming:
			_cleanup_consume()
			return

	var duration = _consume_data.food_treatment_duration
	if duration <= 0:
		duration = 0.1
	var elapsed = 0.0
	var step_time = 0.05
	var total_heal = hydration_restore + satiety_restore + stamina_restore

	if total_heal == 0 and not has_buff:
		_cleanup_consume()
		return

	var healed_so_far = 0.0
	var item = _consume_item

	while elapsed < duration and is_consuming:
		await get_tree().create_timer(step_time).timeout
		if not is_consuming:
			_cleanup_consume()
			return
		elapsed += step_time
		var progress = min(elapsed / duration, 1.0)
		var target_heal = progress * total_heal
		var heal_this_step = target_heal - healed_so_far
		if heal_this_step != 0:
			var ratio_h = hydration_restore / total_heal
			var ratio_s = satiety_restore / total_heal
			var ratio_st = stamina_restore / total_heal
			hydration += heal_this_step * ratio_h
			satiety += heal_this_step * ratio_s
			stamina += heal_this_step * ratio_st
			healed_so_far += heal_this_step
			if item and is_instance_valid(item):
				item.update_medical_progress(progress)

		if hydration >= max_hydration and satiety >= max_satiety and stamina >= max_stamina:
			break

	hydration = clamp(hydration, 0.0, max_hydration)
	satiety = clamp(satiety, 0.0, max_satiety)
	stamina = clamp(stamina, 0.0, max_stamina)

	if item and is_instance_valid(item):
		item.reduce_consume_durability(1.0)

	_cleanup_consume()

func _show_consume_effect():
	if not _consume_data or not _consume_data.consume_scene:
		return
	var node = 医疗下
	var effect = _consume_data.consume_scene.instantiate()
	node.add_child(effect)
	_current_consume_effect = effect
	effect.position = Vector2.ZERO

	if effect.has_node("AnimationPlayer"):
		var ap = effect.get_node("AnimationPlayer") as AnimationPlayer
		if ap and ap.has_animation(_consume_data.consume_animation):
			ap.play(_consume_data.consume_animation)

func _cleanup_consume():
	if _current_consume_effect:
		_current_consume_effect.queue_free()
		_current_consume_effect = null
	if _consume_item and is_instance_valid(_consume_item):
		_consume_item.show_medical_progress(false)
	if _consume_data and _consume_data.consume_hide_weapon and current_weapon_instance:
		current_weapon_instance.visible = _saved_consume_weapon_visible
	if _consume_data and _consume_data.consume_sprite and _saved_consume_sprite:
		player_sprite_2d.texture = _saved_consume_sprite
		_saved_consume_sprite = null
	is_consuming = false
	_consume_item = null
	_consume_data = null

# ============================================================
# 增益系统
# ============================================================
func apply_buff(buff_type: int, value: float, duration: float):
	if duration <= 0:
		_apply_instant_buff(buff_type, value)
		return
	if value == 0 and not buff_type in [ItemData.BuffType.PAINKILLER, ItemData.BuffType.RADIATION_SICKNESS, ItemData.BuffType.RADIATION_DECAY, ItemData.BuffType.DAMAGE_CONTROL, ItemData.BuffType.RADIATION_REGRESSION]:
		print("[增益] 警告：增益数值为0，忽略")
		return

	for i in range(active_buffs.size() - 1, -1, -1):
		if active_buffs[i].type == buff_type:
			var old = active_buffs[i]
			_apply_buff_effect(old.type, old.value, false)
			active_buffs.remove_at(i)
			print("[增益] 移除旧增益: ", _buff_type_to_string(buff_type))

	var new_buff = {
		"type": buff_type,
		"value": value,
		"remaining": duration,
		"duration": duration
	}
	active_buffs.append(new_buff)
	_apply_buff_effect(buff_type, value, true)
	print("[增益] 应用增益: ", _buff_type_to_string(buff_type), " 数值:", value, " 持续:", duration, "s")

func _apply_buff_effect(buff_type: int, value: float, add: bool):
	match buff_type:
		ItemData.BuffType.PAINKILLER:
			if add:
				_damage_reduction += value
			else:
				_damage_reduction -= value
			_damage_reduction = clamp(_damage_reduction, 0.0, 1.0)
		ItemData.BuffType.STIMULANT:
			if add:
				_stamina_bonus += value
			else:
				_stamina_bonus -= value
			_stamina_bonus = max(0.0, _stamina_bonus)
			max_stamina = _base_max_stamina + _stamina_bonus
			if stamina > max_stamina:
				stamina = max_stamina
		ItemData.BuffType.DAMAGE_CONTROL:
			if add:
				_damage_reduction += value
				_heavy_damage_spread = false
			else:
				_damage_reduction -= value
			_damage_reduction = clamp(_damage_reduction, 0.0, 1.0)
		ItemData.BuffType.RADIATION_SICKNESS, ItemData.BuffType.RADIATION_DECAY, ItemData.BuffType.RADIATION_REGRESSION:
			pass

func _apply_instant_buff(buff_type: int, value: float):
	match buff_type:
		ItemData.BuffType.STIMULANT:
			stamina = min(stamina + value, max_stamina)
		ItemData.BuffType.PAINKILLER, ItemData.BuffType.DAMAGE_CONTROL:
			pass

func _buff_type_to_string(buff_type: int) -> String:
	match buff_type:
		ItemData.BuffType.PAINKILLER: return "止痛"
		ItemData.BuffType.STIMULANT: return "兴奋"
		ItemData.BuffType.RADIATION_SICKNESS: return "辐射损伤"
		ItemData.BuffType.RADIATION_DECAY: return "辐射衰败"
		ItemData.BuffType.RADIATION_REGRESSION: return "辐射消退"
		ItemData.BuffType.DAMAGE_CONTROL: return "损伤控制"
		_: return "未知"

func _update_buffs(delta):
	var to_remove = []
	for i in range(active_buffs.size()):
		var buff = active_buffs[i]
		buff.remaining -= delta
		if buff.remaining <= 0:
			to_remove.append(i)
		if buff.type == ItemData.BuffType.RADIATION_REGRESSION:
			radiation = max(radiation - 2.0 * delta, 0.0)
			if radiation <= 0:
				to_remove.append(i)

	for i in range(to_remove.size() - 1, -1, -1):
		var idx = to_remove[i]
		var buff = active_buffs[idx]
		_apply_buff_effect(buff.type, buff.value, false)
		active_buffs.remove_at(idx)
		if buff.type == ItemData.BuffType.RADIATION_REGRESSION and radiation <= 0:
			for j in range(active_buffs.size() - 1, -1, -1):
				if active_buffs[j].type == ItemData.BuffType.RADIATION_SICKNESS or active_buffs[j].type == ItemData.BuffType.RADIATION_DECAY:
					active_buffs.remove_at(j)

func has_active_buff(buff_type: int) -> bool:
	for buff in active_buffs:
		if buff.type == buff_type:
			return true
	return false

# ============================================================
# 其他系统
# ============================================================
func get_total_hp() -> float:
	return head_hp + body_hp + left_arm_hp + right_arm_hp + left_foot_hp + right_foot_hp

func get_max_total_hp() -> float:
	return max_head_hp + max_body_hp + max_left_arm_hp + max_right_arm_hp + max_left_foot_hp + max_right_foot_hp

func get_hp_percent(part: String) -> float:
	match part:
		"head": return head_hp / max_head_hp
		"body": return body_hp / max_body_hp
		"left_arm": return left_arm_hp / max_left_arm_hp
		"right_arm": return right_arm_hp / max_right_arm_hp
		"left_foot": return left_foot_hp / max_left_foot_hp
		"right_foot": return right_foot_hp / max_right_foot_hp
	return 0.0

func get_current_weight() -> float:
	var total_weight: float = 0.0

	# 1. 统计所有网格中的物品（口袋、胸挂、背包网格）
	if inventory_ui:
		for grid in [inventory_ui.口袋网格, inventory_ui.胸挂网格, inventory_ui.背包网格]:
			if grid == null:
				continue
			for item in grid.items:
				if item is InventoryItem and item.item_data:
					total_weight += _get_item_full_weight(item)

	# 2. 统计装备槽中的物品（主武器、副武器、头盔、背包）
	var equipped_items = [
		primary_weapon_item,
		secondary_weapon_item,
		equipped_helmet_item,
		equipped_backpack_item
	]
	for item in equipped_items:
		if item and is_instance_valid(item) and item.item_data:
			total_weight += _get_item_full_weight(item)

	return total_weight

func _reset_hp():
	head_hp = max_head_hp
	body_hp = max_body_hp
	left_arm_hp = max_left_arm_hp
	right_arm_hp = max_right_arm_hp
	left_foot_hp = max_left_foot_hp
	right_foot_hp = max_right_foot_hp
	is_dead = false

func take_damage(part: String, amount: float, _attacker: Node = null) -> bool:
	if is_dead:
		return false
	var actual_amount = amount * (1.0 - _damage_reduction)

	# 如果是头部，先处理头盔
	if part == "head" and equipped_helmet_item:
		var helmet_data = equipped_helmet_item.item_data
		var visor_item = equipped_helmet_item.get_equipped_part_of_type(ItemData.WeaponPartType.VISOR)
		var visor_data = visor_item.item_data if visor_item else null

		# 无视头盔判定
		var ignore_helmet = randf() < helmet_data.helmet_ignore_chance
		if not ignore_helmet:
			# 总耐久 = 头盔当前耐久 + 面罩当前耐久
			var helmet_current = helmet_data.helmet_durability
			var visor_current = visor_data.visor_durability if visor_data else 0.0
			var total_armor = helmet_current + visor_current

			if total_armor > 0:
				var absorbed = min(actual_amount, total_armor)
				actual_amount -= absorbed

				# 先扣面罩耐久
				if visor_data and visor_current > 0:
					var visor_abs = min(absorbed, visor_current)
					visor_data.visor_durability = max(visor_data.visor_durability - visor_abs, 0.0)
					absorbed -= visor_abs
					if visor_data.visor_durability <= 0:
						print("[头盔] 面罩耐久耗尽")

				# 再扣头盔耐久
				if absorbed > 0 and helmet_current > 0:
					var helmet_abs = min(absorbed, helmet_current)
					helmet_data.helmet_durability = max(helmet_data.helmet_durability - helmet_abs, 0.0)
					absorbed -= helmet_abs
					if helmet_data.helmet_durability <= 0:
						print("[头盔] 头盔耐久耗尽，失去保护")

				# 更新头盔物品标签
				if equipped_helmet_item:
					equipped_helmet_item._update_stack_label()

	# 如果没有剩余伤害，直接返回
	if actual_amount <= 0.001:
		return true

	# 原有部位伤害逻辑
	var current_part_hp = _get_hp_by_part(part)
	if current_part_hp < 0:
		return true

	var damage_to_this_part = min(actual_amount, current_part_hp)

	match part:
		"head": head_hp = max(head_hp - actual_amount, 0.0)
		"body": body_hp = max(body_hp - actual_amount, 0.0)
		"left_arm": left_arm_hp = max(left_arm_hp - actual_amount, 0.0)
		"right_arm": right_arm_hp = max(right_arm_hp - actual_amount, 0.0)
		"left_foot": left_foot_hp = max(left_foot_hp - actual_amount, 0.0)
		"right_foot": right_foot_hp = max(right_foot_hp - actual_amount, 0.0)
		_:
			return true

	# 溢出伤害扩散
	var overflow = actual_amount - damage_to_this_part
	if overflow > 0.001:
		var other_parts = []
		var all_parts = ["head", "body", "left_arm", "right_arm", "left_foot", "right_foot"]
		for p in all_parts:
			if p != part and _get_hp_by_part(p) > 0.001:
				other_parts.append(p)

		if other_parts.size() > 0:
			var damage_per_part = overflow / other_parts.size()
			for p in other_parts:
				match p:
					"head": head_hp = max(head_hp - damage_per_part, 0.0)
					"body": body_hp = max(body_hp - damage_per_part, 0.0)
					"left_arm": left_arm_hp = max(left_arm_hp - damage_per_part, 0.0)
					"right_arm": right_arm_hp = max(right_arm_hp - damage_per_part, 0.0)
					"left_foot": left_foot_hp = max(left_foot_hp - damage_per_part, 0.0)
					"right_foot": right_foot_hp = max(right_foot_hp - damage_per_part, 0.0)

	# 辐射重伤害扩散
	if _heavy_damage_spread and actual_amount > 0:
		var other_parts = ["head", "body", "left_arm", "right_arm", "left_foot", "right_foot"]
		other_parts.erase(part)
		if other_parts.size() > 0:
			var spread_part = other_parts[randi() % other_parts.size()]
			var spread_amount = actual_amount * 0.3
			match spread_part:
				"head": head_hp = max(head_hp - spread_amount, 0.0)
				"body": body_hp = max(body_hp - spread_amount, 0.0)
				"left_arm": left_arm_hp = max(left_arm_hp - spread_amount, 0.0)
				"right_arm": right_arm_hp = max(right_arm_hp - spread_amount, 0.0)
				"left_foot": left_foot_hp = max(left_foot_hp - spread_amount, 0.0)
				"right_foot": right_foot_hp = max(right_foot_hp - spread_amount, 0.0)

	if get_total_hp() <= 0 or head_hp <= 0:
		_die()
	return true

func heal(part: String, amount: float):
	if is_dead:
		return
	match part:
		"head": head_hp = min(head_hp + amount, max_head_hp)
		"body": body_hp = min(body_hp + amount, max_body_hp)
		"left_arm": left_arm_hp = min(left_arm_hp + amount, max_left_arm_hp)
		"right_arm": right_arm_hp = min(right_arm_hp + amount, max_right_arm_hp)
		"left_foot": left_foot_hp = min(left_foot_hp + amount, max_left_foot_hp)
		"right_foot": right_foot_hp = min(right_foot_hp + amount, max_right_foot_hp)

func _die():
	is_dead = true
	print("玩家死亡！")

func set_current_container(container: ContainerLoot):
	_add_interactable(container)

func clear_current_container(container: ContainerLoot):
	_remove_interactable(container)
	if inventory_ui and inventory_ui._active_container == container:
		inventory_ui.hide_container()

func set_current_loot(loot: LootItem):
	_add_interactable(loot)

func clear_current_loot(loot: LootItem):
	_remove_interactable(loot)

func _add_interactable(obj):
	if not obj in interactables:
		interactables.append(obj)
		_sort_interactables()
		_update_current_index()
		_update_label()

func _remove_interactable(obj):
	var index = interactables.find(obj)
	if index != -1:
		interactables.remove_at(index)
		_update_current_index()
		_update_label()

func _sort_interactables():
	interactables.sort_custom(_sort_by_priority)

func _sort_by_priority(a, b):
	if a is ContainerLoot and not b is ContainerLoot:
		return true
	return false

func _update_current_index():
	if interactables.is_empty():
		current_index = -1
	elif current_index < 0 or current_index >= interactables.size():
		current_index = 0

func _switch_interactable(direction: int):
	if interactables.size() <= 1:
		return
	current_index = (current_index + direction) % interactables.size()
	if current_index < 0:
		current_index = interactables.size() - 1
	_update_label()

func _update_label():
	if current_index >= 0 and current_index < interactables.size():
		var target = interactables[current_index]
		var text = ""
		if target is ContainerLoot:
			text = "按 F 搜索 " + target.container_name
		elif target is LootItem:
			var item_name = target.item_data.item_name if target.item_data else "物品"
			text = "按 F 拾取 " + item_name
		if interactables.size() > 1:
			text += " (滚轮切换)"
		label.text = text
		label.show()
	else:
		label.hide()

func _show_message(text: String):
	print(text)

func _震屏(duration: float = 0.05):
	if not camera_2d:
		return
	if shake_tween and shake_tween.is_valid():
		shake_tween.kill()
	shake_tween = create_tween()
	shake_tween.set_loops(1)
	for i in range(3):
		shake_tween.tween_callback(func():
			shake_offset = Vector2(randf_range(-1.5, 1.5), randf_range(-1.5, 1.5))
		)
		shake_tween.tween_interval(duration)
	shake_tween.tween_callback(func():
		shake_offset = Vector2.ZERO
	)
	# 计算背包内部所有物品的总重量（考虑堆叠数量）
func _get_backpack_total_weight(backpack_item: InventoryItem) -> float:
	var total: float = 0.0
	var data_list = backpack_item.backpack_items_data
	var stack_counts = backpack_item.backpack_items_stack_counts

	for i in range(data_list.size()):
		var data = data_list[i]
		if data == null:
			continue
		var count = 1
		if i < stack_counts.size():
			count = max(1, stack_counts[i])
		total += data.weight * count

	return total
# 计算单个物品及其配件、内部物品的总重量
func _get_item_full_weight(item: InventoryItem) -> float:
	if not item or not item.item_data:
		return 0.0

	var weight: float = item.item_data.weight

	# 加上已安装配件的重量（如武器配件、头盔面罩等）
	if item.installed_parts and item.installed_parts.size() > 0:
		for part in item.installed_parts.values():
			if part is InventoryItem and part.item_data:
				weight += part.item_data.weight

	# 如果是背包，加上背包内部所有物品的重量
	if item.item_data.is_backpack:
		weight += _get_backpack_total_weight(item)

	return weight
func get_hit_part(hit_point: Vector2) -> String:
	var parts = {
		"head": 头部,
		"body": 身体,
		"left_arm": 左手,
		"right_arm": 右手,
		"left_foot": 左脚,
		"right_foot": 右脚
	}
	var best_part = "body"
	var best_dist = INF
	for part_name in parts.keys():
		var shape_node = parts[part_name]
		if shape_node and shape_node is CollisionShape2D:
			var center = shape_node.global_position
			var dist = hit_point.distance_to(center)
			if shape_node.shape:
				var adjust = 0.0
				if shape_node.shape is CircleShape2D:
					adjust = shape_node.shape.radius * 0.5
				elif shape_node.shape is RectangleShape2D:
					var rect = shape_node.shape.get_rect()
					adjust = min(rect.size.x, rect.size.y) * 0.3
				elif shape_node.shape is CapsuleShape2D:
					adjust = shape_node.shape.radius * 0.5
				dist -= adjust
			if dist < best_dist:
				best_dist = dist
				best_part = part_name
	return best_part

func _消耗饱食度和水分():
	if is_dead:
		return
	hydration = max(hydration - 2.0, 0.0)
	satiety = max(satiety - 2.0, 0.0)

func _on_starvation_tick():
	if is_dead:
		return
	if hydration <= 0 or satiety <= 0:
		var damage = starvation_damage_per_second
		take_damage("head", damage)
		take_damage("body", damage)
		take_damage("left_arm", damage)
		take_damage("right_arm", damage)
		take_damage("left_foot", damage)
		take_damage("right_foot", damage)
