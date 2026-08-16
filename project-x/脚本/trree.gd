extends Node2D

@onready var tree_2: Sprite2D = $Tree2
@onready var area_2d: Area2D = $Area2D

var _initial_ignore: bool = true   # 防止加载时触发

func _ready():
	
	# 设置碰撞掩码（根据您的玩家碰撞层调整）
	area_2d.collision_layer = 0
	area_2d.collision_mask = 1      # 假设玩家在第1层

	# 连接信号
	area_2d.body_entered.connect(_on_body_entered)
	area_2d.body_exited.connect(_on_body_exited)

	# 延迟一帧启用检测，避免初始重叠误触
	call_deferred("_enable_detection")

func _enable_detection():
	_initial_ignore = false

func _on_body_entered(body):
	if _initial_ignore:
		return
	if body.name == "Player" or body.is_in_group("player"):
		tree_2.modulate.a = 0.5

func _on_body_exited(body):
	if _initial_ignore:
		return
	if body.name == "Player" or body.is_in_group("player"):
		tree_2.modulate.a = 1.0
