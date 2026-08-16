extends Sprite2D

@onready var 生命值: Label = $生命值
@onready var 护甲值: Label = $护甲值
@onready var area_2d: Area2D = $Area2D         # 护甲区域
@onready var area_2d_2: Area2D = $Area2D2     # 肉身区域

@export var armor: float = 50.0
@export var health: float = 100.0

func _ready():
	# 设置两个区域都可被射线检测
	area_2d.collision_layer = 1
	area_2d.monitorable = true
	area_2d_2.collision_layer = 1
	area_2d_2.monitorable = true
	更新UI()

func take_damage(amount: float):
	health -= amount
	更新UI()
	if health <= 0:
		queue_free()

func armor_damaged(amount: float):
	更新UI()

func 更新UI():
	if 生命值:
		生命值.text = "HP: %d" % health
	if 护甲值:
		护甲值.text = "Armor: %d" % armor
