extends CharacterBody2D
class_name PlayerCharacter

const WALK_SPEED = 150.0
const RUN_SPEED = 300.0
const RUN_STAMINA_COST = 20.0   # 每秒耐力消耗
const STAMINA_REGEN = 10.0      # 每秒回复量

# 调试：按数字键扣除的血量
@export var debug_damage: float = 10.0

# 部位最大血量（可导出）
@export var max_head_hp: float = 50.0
@export var max_body_hp: float = 100.0
@export var max_left_arm_hp: float = 35.0
@export var max_right_arm_hp: float = 35.0
@export var max_left_foot_hp: float = 40.0
@export var max_right_foot_hp: float = 40.0

# 当前部位血量
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
var can_sprint: bool = true   # 能否再次奔跑（耐力恢复后）

# 记录最后移动方向，用于待机时保持朝向
var last_dir: String = "down"

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

var interactables: Array = []
var current_index: int = -1

func _ready():
	add_to_group("Player")
	if inventory_ui: inventory_ui.hide()
	label.hide()
	Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
	_reset_hp()

func _physics_process(delta):
	if is_dead: return

	var direction = Input.get_vector("move_left", "move_right", "move_up", "move_down")
	
	# 奔跑逻辑（增加腿部血量检查）
	if Input.is_key_pressed(KEY_SHIFT) and direction != Vector2.ZERO and can_sprint and stamina > 0 and left_foot_hp > 0 and right_foot_hp > 0:
		is_running = true
		stamina = max(stamina - RUN_STAMINA_COST * delta, 0.0)
		if stamina == 0:
			can_sprint = false   # 耐力耗尽，锁死奔跑
			is_running = false
	else:
		is_running = false
		stamina = min(stamina + STAMINA_REGEN * delta, max_stamina)
		# 恢复到10%即可再次奔跑（但还需要腿部完好）
		if stamina >= max_stamina * 0.1:
			can_sprint = true

	var current_speed = RUN_SPEED if is_running else WALK_SPEED
	velocity = direction * current_speed
	move_and_slide()

	# 动画控制（八方向，无延迟，速度恒定）
	if direction != Vector2.ZERO:
		if abs(direction.x) > abs(direction.y):
			if direction.x > 0:
				last_dir = "right"
				animation_player.play("right_move")
			else:
				last_dir = "left"
				animation_player.play("left_move")
		else:
			if direction.y > 0:
				last_dir = "down"
				animation_player.play("down_move")
			else:
				last_dir = "up"
				animation_player.play("up_move")
		animation_player.speed_scale = 1.0
	else:
		match last_dir:
			"left": animation_player.play("left_idle")
			"right": animation_player.play("right_idle")
			"up": animation_player.play("up_idle")
			"down": animation_player.play("down_idle")
		animation_player.speed_scale = 1.0

	# 按下 V 键打印速度
	if Input.is_key_pressed(KEY_V):
		print("当前速度: %.1f" % velocity.length())

func _input(event):
	if is_dead: return

	if event is InputEventMouseButton and event.is_pressed():
		if event.button_index == MOUSE_BUTTON_WHEEL_UP: _switch_interactable(-1)
		elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN: _switch_interactable(1)

	if event is InputEventKey and event.keycode == KEY_F and event.pressed:
		if current_index >= 0 and current_index < interactables.size():
			var target = interactables[current_index]
			if target is ContainerLoot: inventory_ui.show_container(target)
			elif target is LootItem:
				var success = target.try_pickup(self)
				if not success: _show_message("背包已满")

	if event is InputEventKey and event.keycode == KEY_TAB and event.pressed:
		if inventory_ui: inventory_ui.toggle_visibility()

	if event.is_action_pressed("ui_cancel"):
		Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)

	if event is InputEventKey and event.pressed:
		match event.keycode:
			KEY_1: take_damage("head", debug_damage)
			KEY_2: take_damage("body", debug_damage)
			KEY_3: take_damage("left_arm", debug_damage)
			KEY_4: take_damage("right_arm", debug_damage)
			KEY_5: take_damage("left_foot", debug_damage)
			KEY_6: take_damage("right_foot", debug_damage)

# ---------- 状态获取 ----------
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
	if inventory_ui:
		for grid in [inventory_ui.口袋网格, inventory_ui.胸挂网格, inventory_ui.背包网格]:
			for item in grid.items:
				if item is InventoryItem and item.item_data:
					total_weight += item.item_data.weight
	return total_weight

func _reset_hp():
	head_hp = max_head_hp
	body_hp = max_body_hp
	left_arm_hp = max_left_arm_hp
	right_arm_hp = max_right_arm_hp
	left_foot_hp = max_left_foot_hp
	right_foot_hp = max_right_foot_hp
	is_dead = false

func take_damage(part: String, amount: float) -> bool:
	if is_dead: return false
	match part:
		"head": head_hp = max(head_hp - amount, 0.0)
		"body": body_hp = max(body_hp - amount, 0.0)
		"left_arm": left_arm_hp = max(left_arm_hp - amount, 0.0)
		"right_arm": right_arm_hp = max(right_arm_hp - amount, 0.0)
		"left_foot": left_foot_hp = max(left_foot_hp - amount, 0.0)
		"right_foot": right_foot_hp = max(right_foot_hp - amount, 0.0)
		_: return true

	var total_hp = get_total_hp()
	if total_hp <= 0 or head_hp <= 0:
		_die()
		return false
	return true

func heal(part: String, amount: float):
	if is_dead: return
	match part:
		"head": head_hp = min(head_hp + amount, max_head_hp)
		"body": body_hp = min(body_hp + amount, max_body_hp)
		"left_arm": left_arm_hp = min(left_arm_hp + amount, max_left_arm_hp)
		"right_arm": right_arm_hp = min(right_arm_hp + amount, max_right_arm_hp)
		"left_foot": left_foot_hp = min(left_foot_hp + amount, max_left_foot_hp)
		"right_foot": right_foot_hp = min(right_foot_hp + amount, max_right_foot_hp)

func _die():
	if is_dead: return
	is_dead = true
	print("玩家死亡！")

# ---------- 交互对象管理 ----------
func set_current_container(container: ContainerLoot): _add_interactable(container)
func clear_current_container(container: ContainerLoot):
	_remove_interactable(container)
	# 如果离开的容器正是当前打开的容器，立即隐藏容器界面
	if inventory_ui and inventory_ui._active_container == container:
		inventory_ui.hide_container()
func set_current_loot(loot: LootItem): _add_interactable(loot)
func clear_current_loot(loot: LootItem): _remove_interactable(loot)

func _add_interactable(obj):
	if not obj in interactables:
		interactables.append(obj); _sort_interactables(); _update_current_index(); _update_label()

func _remove_interactable(obj):
	var index = interactables.find(obj)
	if index != -1: interactables.remove_at(index); _update_current_index(); _update_label()

func _sort_interactables():
	interactables.sort_custom(_sort_by_priority)

func _sort_by_priority(a, b):
	if a is ContainerLoot and not b is ContainerLoot: return true
	if not a is ContainerLoot and b is ContainerLoot: return false
	return false

func _update_current_index():
	if interactables.is_empty(): current_index = -1
	elif current_index < 0 or current_index >= interactables.size(): current_index = 0

func _switch_interactable(direction: int):
	if interactables.size() <= 1: return
	current_index = (current_index + direction) % interactables.size()
	if current_index < 0: current_index = interactables.size() - 1
	_update_label()

func _update_label():
	if current_index >= 0 and current_index < interactables.size():
		var target = interactables[current_index]
		if target is ContainerLoot: label.text = "按 F 搜索容器"
		elif target is LootItem:
			var item_name = target.item_data.item_name if target.item_data else "物品"
			label.text = "按 F 拾取 " + item_name
		label.show()
	else: label.hide()

func _show_message(text: String): print(text)
