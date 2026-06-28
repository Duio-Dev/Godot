extends Control

@onready var 重量: Label = $背包/重量
@onready var 背包: bag = $"背包/ScrollContainer/VBoxContainer/背包1"

func _ready() -> void:
	# 监听背包重量变化信号
	if 背包 and 背包.has_signal("weight_changed"):
		背包.weight_changed.connect(_on_bag_weight_changed)
	# 初始化显示一次
	_on_bag_weight_changed(_calc_current_weight())

# 重量变化时自动更新文本
func _on_bag_weight_changed(total_weight: int) -> void:
	重量.text = "负重: %d" % total_weight

# 兜底手动计算当前重量
func _calc_current_weight() -> int:
	if not 背包:
		return 0
	var total: int = 0
	for item_data in 背包.bag_items:
		var res = item_data.get("res")
		if res != null and "物品重量" in res:
			total += res.物品重量
	return total
