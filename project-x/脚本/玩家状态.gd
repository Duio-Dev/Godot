extends Control

## 将玩家节点拖入此处（也可留空，脚本会自动通过组查找）
@export var player: PlayerCharacter

@onready var 耐力: ProgressBar = $耐力
@onready var 头部: TextureRect = $玩家健康/头部
@onready var 身体: TextureRect = $玩家健康/身体
@onready var 左手: TextureRect = $玩家健康/左手
@onready var 右手: TextureRect = $玩家健康/右手
@onready var 左腿: TextureRect = $玩家健康/左腿
@onready var 右腿: TextureRect = $玩家健康/右腿

func _ready() -> void:
	# 如果没有手动指定玩家，尝试自动查找
	if not player:
		player = get_tree().get_first_node_in_group("Player")
	if 耐力:
		耐力.max_value = player.max_stamina if player else 100.0

func _process(delta: float) -> void:
	if not player:
		return

	# 耐力条更新
	if 耐力:
		耐力.value = player.stamina
		耐力.max_value = player.max_stamina

	# 更新各部位颜色
	_update_part_color(头部, player.head_hp, player.max_head_hp)
	_update_part_color(身体, player.body_hp, player.max_body_hp)
	_update_part_color(左手, player.left_arm_hp, player.max_left_arm_hp)
	_update_part_color(右手, player.right_arm_hp, player.max_right_arm_hp)
	_update_part_color(左腿, player.left_foot_hp, player.max_left_foot_hp)
	_update_part_color(右腿, player.right_foot_hp, player.max_right_foot_hp)

## 根据血量百分比设置 TextureRect 的颜色
func _update_part_color(part: TextureRect, current_hp: float, max_hp: float) -> void:
	if not part:
		return
	if max_hp <= 0:
		part.modulate = Color.BLACK
		return

	var percent = clamp(current_hp / max_hp, 0.0, 1.0)

	if current_hp <= 0:
		part.modulate = Color.BLACK
	else:
		# 血量从满到 0 由绿变红，归零时上面已处理为黑，但此处仍用 lerp 保证平滑
		part.modulate = Color.GREEN.lerp(Color.RED, 1.0 - percent)
