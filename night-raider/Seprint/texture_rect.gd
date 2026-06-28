@tool
extends TextureRect

# 物品资源
@export_group("物品数据")
@export var itemResource : ItemResource

# 单格子像素尺寸 64
@export_group("格子标准")
@export var cell_size: float = 64.0

# 品质颜色配置
@export_group("品质颜色")
@export var white_color: Color = Color(0.8, 0.8, 0.8, 0.3)
@export var green_color: Color = Color(0.2, 0.8, 0.2, 0.3)
@export var blue_color: Color = Color(0.2, 0.4, 0.9, 0.3)
@export var purple_color: Color = Color(0.6, 0.2, 0.8, 0.3)
@export var gold_color: Color = Color(1.0, 0.8, 0.1, 0.3)

@onready var label: Label = $Label
@onready var rarity_bg: ColorRect = $RarityBG


# 缓存检测数值变化
var last_item_w: int = -1
var last_item_h: int = -1

func _ready() -> void:
	update_display()
	last_item_w = -1
	last_item_h = -1
	if label and itemResource:
		label.text = itemResource.name

func _validate_property(changed: Dictionary) -> void:
	var name = changed.get("name", "")
	if name in ["itemResource", "cell_size"]:
		last_item_w = -1
		update_display()

# 编辑器每帧监听资源内部height/weight改动，实时刷新
func _process(delta: float) -> void:
	if label and itemResource:
		label.text = itemResource.name
	if itemResource == null:
		return
	var cur_w = itemResource.weight
	var cur_h = itemResource.height
	if cur_w != last_item_w or cur_h != last_item_h:
		last_item_w = cur_w
		last_item_h = cur_h
		update_display()

func update_display() -> void:
	# 空资源清空
	if not itemResource or itemResource.texture == null:
		texture = null
		size = Vector2.ZERO
		scale = Vector2(1, 1)
		if rarity_bg:
			rarity_bg.visible = false
		return
	
	# 1. 预览框尺寸 = 占用格子 × 单格64
	var item_grid_w = float(itemResource.weight)
	var item_grid_h = float(itemResource.height)
	var box_width = item_grid_w * cell_size
	var box_height = item_grid_h * cell_size
	size = Vector2(box_width, box_height)
	
	# 设置背景大小
	if rarity_bg:
		rarity_bg.size = size
		rarity_bg.visible = true

	# 2. 赋值原图
	texture = itemResource.texture
	stretch_mode = STRETCH_KEEP_ASPECT_CENTERED
	scale = Vector2(1.0, 1.0)
	
	# 3. 更新品质颜色
	update_rarity_color()
	
	# 4. 更新标签
	if label:
		label.text = itemResource.name

# 根据品质等级更新背景颜色
func update_rarity_color() -> void:
	if rarity_bg == null:
		return
	
	if itemResource == null:
		rarity_bg.color = Color.TRANSPARENT
		return
	
	# 获取品质等级对应的颜色
	var color = get_rarity_color()
	rarity_bg.color = color

# 获取品质颜色
func get_rarity_color() -> Color:
	if itemResource == null:
		return Color.TRANSPARENT
	
	match itemResource.物品等级:
		0:  # 白
			return white_color
		1:  # 绿
			return green_color
		2:  # 蓝
			return blue_color
		3:  # 紫
			return purple_color
		4:  # 金
			return gold_color
		_:
			return Color.TRANSPARENT
