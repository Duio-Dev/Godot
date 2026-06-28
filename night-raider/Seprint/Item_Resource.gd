extends Resource
class_name ItemResource

# ===== 基础属性 =====
@export var name: String = ""
@export var height: int = 1
@export var weight: int = 1
@export var texture: Texture
@export var textureY: Texture
@export var 物品重量: int = 1

# ===== 品质等级 =====
enum 等级 {
	白,
	绿,
	蓝,
	紫,
	金
}
@export var 物品等级: 等级 = 等级.白

# ===== 物品类型（互斥，只能选一个） =====
@export_group("物品类型", "is_")
@export var is_枪: bool = false:
	set(value):
		is_枪 = value
		if value:
			is_药品 = false
			is_刀具 = false
@export var is_药品: bool = false:
	set(value):
		is_药品 = value
		if value:
			is_枪 = false
			is_刀具 = false
@export var is_刀具: bool = false:
	set(value):
		is_刀具 = value
		if value:
			is_枪 = false
			is_药品 = false
@export var is_其他: bool = true:
	set(value):
		is_其他 = value
		if value:
			is_枪 = false
			is_药品 = false
			is_刀具 = false

# ===== 枪械属性（仅当 is_枪 为 true 时显示） =====
@export_group("枪械属性", "gun_")
@export var gun_伤害: int = 0
@export var gun_弹匣容量: int = 0
@export var gun_射速: float = 0.0
@export var gun_有效射程: int = 0
@export var gun_弹药类型: String = ""

# ===== 药品属性（仅当 is_药品 为 true 时显示） =====
@export_group("药品属性", "med_")
@export var med_回复量: int = 0
@export var med_使用时间: float = 0.0
@export var med_效果类型: String = ""  # 如：血量、体力、辐射等
@export var med_持续时间: float = 0.0

# ===== 刀具属性（仅当 is_刀具 为 true 时显示） =====
@export_group("刀具属性", "knife_")
@export var knife_伤害: int = 0
@export var knife_攻击速度: float = 0.0
@export var knife_攻击范围: int = 0
@export var knife_耐久度: int = 0

# ===== 获取物品类型名称 =====
func get_item_type_name() -> String:
	if is_枪:
		return "枪械"
	elif is_药品:
		return "药品"
	elif is_刀具:
		return "刀具"
	else:
		return "其他"

# ===== 获取物品类型图标（可选） =====
func get_item_type_color() -> Color:
	if is_枪:
		return Color(1.0, 0.3, 0.3)  # 红色
	elif is_药品:
		return Color(0.3, 1.0, 0.3)  # 绿色
	elif is_刀具:
		return Color(1.0, 0.8, 0.1)  # 金色
	else:
		return Color(0.5, 0.5, 0.5)  # 灰色

# ===== 获取物品类型图标（需要 Texture） =====
# @export var type_icon: Texture  # 可以添加类型图标

# ===== 判断是否为特定类型 =====
func is_weapon() -> bool:
	return is_枪 or is_刀具

func is_consumable() -> bool:
	return is_药品

func is_melee() -> bool:
	return is_刀具

func is_ranged() -> bool:
	return is_枪
