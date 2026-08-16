extends Resource
class_name ItemData

# ========== 枚举定义 ==========
enum Quality { WHITE, GREEN, BLUE, PURPLE, GOLD, RED }
enum SlotPreference { DEFAULT, POCKET, VEST, BACKPACK }
enum FireMode { SEMI_AUTO, FULL_AUTO, BURST }
enum BuffType { NONE, PAINKILLER, STIMULANT, DAMAGE_CONTROL, RADIATION_SICKNESS, RADIATION_DECAY, RADIATION_REGRESSION }

# ========== 品质颜色映射 ==========
const QUALITY_COLORS = {
	Quality.WHITE:  Color(1.0, 1.0, 1.0, 0.5),
	Quality.GREEN:  Color(0.0, 1.0, 0.0, 0.5),
	Quality.BLUE:   Color(0.0, 0.0, 1.0, 0.5),
	Quality.PURPLE: Color(1.0, 0.0, 1.0, 0.5),
	Quality.GOLD:   Color(1.0, 0.84, 0.0, 0.5),
	Quality.RED:    Color(1.0, 0.0, 0.0, 0.5)
}
enum WeaponPartType {
	NONE,           ## 普通物品
	RECEIVER,       ## 枪机（核心）
	UPPER_RECEIVER, ## 上机匣
	STOCK,          ## 后托
	PISTOL_GRIP,    ## 后握把
	FOREGRIP,       ## 前握把
	BARREL,         ## 枪管
	MUZZLE,         ## 枪口
	SIGHT,          ## 瞄具
	MAGAZINE,       ## 弹匣
	HELMET,   ## 头盔底座
	VISOR     ## 面罩配件
}

## 用于容器序列化：存储背包内部数据（仅当 is_backpack 为 true 时有效）
@export var backpack_contents: Dictionary = {}
## 用于容器序列化：存储已安装配件数据（仅底座类型有效）
@export var installed_parts_data: Dictionary = {}
# ============================================================
#  1. 基础信息
# ============================================================
@export_group("基础信息")
## 物品唯一标识符（用于堆叠和识别）
@export var item_id: String = ""
## 物品显示名称
@export var item_name: String = "未知道具"
## 物品详细描述
@export_multiline var description: String = ""

# ============================================================
#  2. 外观
# ============================================================
@export_group("外观")
## 物品图标纹理
@export var icon: Texture2D

# ============================================================
#  3. 背包属性
# ============================================================
@export_group("背包属性")
## 占用背包格子的宽度
@export var grid_width: int = 1
## 占用背包格子的高度
@export var grid_height: int = 1
## 物品重量
@export var weight: float = 0.0
## 是否可以旋转放置
@export var can_rotate: bool = true


# ============================================================
#  4. 品质
# ============================================================
@export_group("外观/品质")
## 物品品质等级
@export var quality: Quality = Quality.WHITE

# ============================================================
#  5. 堆叠
# ============================================================
@export_group("基础信息/堆叠")
## 最大堆叠数量
@export var max_stack: int = 1
## 是否允许堆叠
@export var can_stack: bool = true

# ============================================================
#  6. 弹匣
# ============================================================
@export_group("配件/弹匣")
## 是否为弹匣
@export var is_magazine: bool = false
## 弹匣容量
@export var magazine_capacity: int = 30
## 当前弹药数量
@export var current_ammo: int = 0
## 弹药类型标识（用于匹配武器）
@export var ammo_type: String = ""

# ============================================================
#  7. 武器
# ============================================================
@export_group("装备/武器")
## 是否为武器
@export var is_weapon: bool = false
## 武器唯一标识符（用于匹配弹匣等配件）
@export var weapon_id: String = ""
## 武器精准度（0-100）
@export var weapon_precision: int = 100
## 抛出的弹壳场景
@export var shell_scene: PackedScene
## 射击音效
@export var shoot_sound: AudioStream
## 射速（发/分钟）
@export var fire_rate_rpm: int = 400
## 弹匣挂载点偏移（像素）
@export var magazine_mount_offset: Vector2 = Vector2.ZERO
## 弹匣显示尺寸
@export var magazine_display_size: Vector2 = Vector2(30, 60)

# ============================================================
#  人机功效
# ============================================================
@export_group("人机功效")
## 基础人机功效（0-100，影响开镜速度）
@export var ergonomics: float = 100.0
## 人机功效修正值（正数为提升，负数为降低）
@export var ergonomics_modifier: float = 0.0
## 精度修正值（正数为提升，负数为降低）
@export var accuracy_modifier: float = 0.0

# ============================================================
#  8. 开火模式
# ============================================================
@export_group("装备/武器/开火模式")
## 开火模式（半自动/全自动/点射）
@export var fire_mode: FireMode = FireMode.FULL_AUTO
## 点射模式下的单次连发数量
@export var burst_count: int = 3

# ============================================================
#  9. 拾取偏好
# ============================================================
@export_group("拾取偏好")
## 拾取时优先放入的背包区域
@export var preferred_slot: SlotPreference = SlotPreference.DEFAULT

# ============================================================
#  10. 装备（武器通用）
# ============================================================
@export_group("装备")
## 武器场景（用于实例化到玩家手中）
@export var weapon_scene: PackedScene
## 装备后显示的玩家精灵图（可选）
@export var weapon_sprite: Texture2D
## 装备所需时间（秒）
@export var equip_time: float = 1.0
## 卸下所需时间（秒）
@export var unequip_time: float = 1.0
## 空仓换弹时间（秒）
@export var reload_time_full: float = 2.5
## 战术换弹时间（秒）
@export var reload_time_tactical: float = 2.0
## 瞄具安装位置偏移
@export var sight_mount_position: Vector2 = Vector2.ZERO

@export_group("武器配件系统")
## 物品的武器配件类型（枪机或配件）

@export var weapon_part_type: WeaponPartType = WeaponPartType.NONE

## 配件可安装的枪机ID列表（空数组表示通用）
@export var compatible_receivers: Array[String] = []

## 配件标签（用于细槽位匹配，如 "AK弹匣"）
@export var slot_tag: String = ""

## 仅对枪机有效：该枪机拥有的所有安装槽位
@export var receiver_slots: Array[WeaponSlot] = []

## 配件在武器合成图中的绘制尺寸（像素），Vector2.ZERO 表示使用原始贴图尺寸
@export var model_size: Vector2 = Vector2.ZERO

## 配件模型图标（透明背景，用于合成）
@export var model_texture: Texture2D
# ============================================================
#  11. 瞄具
# ============================================================
@export_group("配件/瞄具")
## 是否为瞄具
@export var is_sight: bool = false
## 瞄具类型标识
@export var sight_type: String = ""
## 瞄具安装偏移
@export var sight_mount_offset: Vector2 = Vector2.ZERO
## 瞄具在武器上的显示尺寸
@export var sight_display_size: Vector2 = Vector2(20, 20)
## 瞄准放大倍率
@export var aim_zoom_level: float = 1.0

# ============================================================
#  12. 伤害
# ============================================================
@export_group("伤害")
## 护甲伤害
@export var armor_damage: float = 10.0
## 肉体伤害
@export var flesh_damage: float = 10.0

# ============================================================
#  13. 丢弃
# ============================================================
@export_group("丢弃")
## 丢弃后掉落物的缩放比例
@export var discard_scale: float = 1.0
## 丢弃后掉落物的碰撞半径
@export var discard_collision_radius: float = 20.0

# ============================================================
#  14. 医疗
# ============================================================
@export_group("医疗")
## 是否为医疗物品
@export var is_medical: bool = false
## 使用时的场景特效
@export var medical_scene: PackedScene
## 使用动画名称
@export var medical_animation: String = "default"
## 是否只能修复断肢（手术包）
@export var is_surgery_kit: bool = false
## 能否治疗断肢（普通医疗物品也可设置）
@export var can_heal_limb: bool = false
## 治疗断肢后造成的最大血量上限惩罚
@export var limb_heal_max_penalty: float = 20.0
## 断肢治疗量
@export var limb_heal_amount: float = 20.0
## 医疗物品耐久度
@export var medical_durability: float = 200.0
## 使用时是否隐藏武器
@export var use_hide_weapon: bool = true
## 使用前摇时间（秒）
@export var activation_time: float = 0.5
## 治疗过程时间（秒）
@export var treatment_duration: float = 2.0
## 使用时替代的玩家精灵图
@export var use_sprite: Texture2D = null
@export_group("头盔/面罩显示")
## 头盔在玩家身上的显示贴图（为空则用 icon）
@export var helmet_display_texture: Texture2D
## 面罩在玩家身上的显示贴图（为空则用 model_texture 或 icon）
@export var visor_display_texture: Texture2D
@export_group("头盔/面罩耐久")
## 头盔基础耐久
@export var helmet_durability: float = 100.0
## 面罩自身耐久（安装后加到总耐久）
@export var visor_durability: float = 50.0
## 敌人攻击头部时无视头盔的概率（0~1）
@export var helmet_ignore_chance: float = 0.1
@export_group("特殊功能")
## 是否拥有热成像能力（仅头盔或面罩有效）
@export var has_thermal_imaging: bool = false
@export_group("背包")
@export var is_backpack: bool = false
@export var backpack_grid_columns: int = 5
@export var backpack_grid_rows: int = 4
@export var backpack_grid_size: int = 64
@export var backpack_display_texture: Texture2D
@export var backpack_display_offset: Vector2 = Vector2.ZERO
# ============================================================
#  15. 饮食（食物/饮料）
# ============================================================
@export_group("饮食")
## 是否为饮食类物品
@export var is_food_or_drink: bool = false
## 使用时的场景特效
@export var consume_scene: PackedScene
## 使用动画名称
@export var consume_animation: String = "default"
## 使用时替代的玩家精灵图
@export var consume_sprite: Texture2D = null
## 恢复水分值
@export var hydration_restore: float = 0.0
## 恢复饱食度
@export var satiety_restore: float = 0.0
## 恢复耐力
@export var stamina_restore: float = 0.0
## 使用前摇时间（秒）
@export var food_activation_time: float = 0.5
## 消耗过程时间（秒）
@export var food_treatment_duration: float = 2.0
## 物品使用耐久（次数）
@export var consume_durability: float = 1.0
## 使用时是否隐藏武器
@export var consume_hide_weapon: bool = true

# ============================================================
#  16. 增益效果
# ============================================================
@export_group("增益效果")
## 增益效果类型
@export var buff_type: BuffType = BuffType.NONE
## 增益数值（如减伤比例、耐力增加等）
@export var buff_value: float = 0.0
## 增益持续时间（秒）
@export var buff_duration: float = 0.0

@export_group("配件/尺寸增量")
## 装备后增加占用的宽度（格）
@export var grid_width_increase: int = 0
## 装备后增加占用的高度（格）
@export var grid_height_increase: int = 0
# ============================================================
#  工具方法
# ============================================================
## 获取品质对应的颜色
func get_quality_color() -> Color:
	return QUALITY_COLORS.get(quality, Color.WHITE)

## 获取搜索所需时间（根据品质）
func get_search_duration() -> float:
	var durations = {
		Quality.WHITE: 0.2,
		Quality.GREEN: 0.4,
		Quality.BLUE: 0.8,
		Quality.PURPLE: 1.3,
		Quality.GOLD: 1.7,
		Quality.RED: 2.0
	}
	return durations.get(quality, 0.5)
#增加头盔装备后在玩家上显示的图标和面罩在玩家上显示的图标
