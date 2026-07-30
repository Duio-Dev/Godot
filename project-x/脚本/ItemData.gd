extends Resource
class_name ItemData

enum Quality { WHITE, GREEN, BLUE, PURPLE, GOLD, RED }
enum SlotPreference { DEFAULT, POCKET, VEST, BACKPACK }

const QUALITY_COLORS = {
	Quality.WHITE:  Color(1.0, 1.0, 1.0, 0.5),
	Quality.GREEN:  Color(0.0, 1.0, 0.0, 0.5),
	Quality.BLUE:   Color(0.0, 0.0, 1.0, 0.5),
	Quality.PURPLE: Color(1.0, 0.0, 1.0, 0.5),
	Quality.GOLD:   Color(1.0, 0.84, 0.0, 0.5),
	Quality.RED:    Color(1.0, 0.0, 0.0, 0.5)
}

# ========== 基础信息 ==========
@export_group("基础信息")
@export var item_id: String = ""
@export var item_name: String = "未知道具"
@export_multiline var description: String = ""

# ========== 外观 ==========
@export_group("外观")
@export var icon: Texture2D

# ========== 背包属性 ==========
@export_group("背包属性")
@export var grid_width: int = 1
@export var grid_height: int = 1
@export var weight: float = 0.0
@export var can_rotate: bool = true

# ========== 品质 ==========
@export_group("品质")
@export var quality: Quality = Quality.WHITE

# ========== 堆叠 ==========
@export_group("堆叠")
@export var max_stack: int = 1        # 最大堆叠数量，1表示不可堆叠
@export var can_stack: bool = true    # 是否允许堆叠

# ========== 弹匣 ==========
@export_group("弹匣")
@export var is_magazine: bool = false
@export var magazine_capacity: int = 30
@export var current_ammo: int = 0     # 当前弹药数
@export var ammo_type: String = ""    # 弹药类型，弹匣与子弹匹配

# ========== 拾取偏好 ==========
@export_group("拾取偏好")
@export var preferred_slot: SlotPreference = SlotPreference.DEFAULT

func get_quality_color() -> Color:
	return QUALITY_COLORS.get(quality, Color.WHITE)

func get_search_duration() -> float:
	var durations = {
		Quality.WHITE: 0.1, Quality.GREEN: 0.4, Quality.BLUE: 0.8,
		Quality.PURPLE: 1.3, Quality.GOLD: 1.7, Quality.RED: 2.0
	}
	return durations.get(quality, 0.5)
