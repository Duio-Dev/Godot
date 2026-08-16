extends CharacterBody2D

# ========== 外国名字列表（用于掉落容器命名） ==========
const FOREIGN_NAMES = [
	"安德烈", "尼古拉", "弗拉基米尔", "谢尔盖", "德米特里", "伊万", "阿列克谢", "米哈伊尔",
	"亚历山大", "叶戈尔", "马克西姆", "丹尼尔", "阿尔乔姆", "维克托", "斯坦尼斯拉夫", "瓦西里",
	"格里戈里", "列昂尼德", "奥列格", "尤里", "鲍里斯", "基里尔", "罗曼", "谢尔盖",
	"弗拉基米尔", "阿纳托利", "维克托", "伊戈尔", "爱德华", "鲁斯兰", "季莫费",
	"卡尔", "弗里茨", "海因里希", "赫尔曼", "路德维希", "奥托", "保罗", "威廉",
	"阿道夫", "阿尔弗雷德", "伯恩哈德", "康拉德", "埃里希", "弗里德里希", "格哈德", "京特",
	"汉斯", "赫尔伯特", "库尔特", "莱因哈特", "鲁道夫", "齐格弗里德", "沃纳", "沃尔夫冈",
	"路易", "皮埃尔", "保罗", "亨利", "维克多", "安德烈", "米歇尔", "菲利普",
	"阿尔贝", "夏尔", "埃德蒙", "古斯塔夫", "朱尔", "莱昂", "莫里斯", "奥古斯特",
	"加布里埃尔", "让", "约瑟夫", "罗贝尔", "安托万", "巴蒂斯特", "克莱芒", "多米尼克",
	"埃米尔", "费尔南", "乔治", "纪尧姆", "亨利", "让-巴蒂斯特", "路易-菲利普", "马塞尔",
	"诺埃尔", "帕特里斯", "雷米", "塞巴斯蒂安", "泰奥多尔", "于贝尔", "瓦伦丁", "泽维尔",
	"马克", "约翰", "威廉", "詹姆斯", "查尔斯", "乔治", "弗兰克", "约瑟夫",
	"托马斯", "亨利", "罗伯特", "爱德华", "阿尔弗雷德", "欧内斯特", "雷蒙德", "沃尔特"
]

# ========== 外国姓氏列表 ==========
const FOREIGN_SURNAMES = [
	"伊万诺夫", "彼得罗夫", "斯米尔诺夫", "库兹涅佐夫", "索科洛夫", "波波夫", "列别杰夫", "科兹洛夫",
	"诺维科夫", "莫罗佐夫", "沃尔科夫", "阿列克谢耶夫", "格里戈里耶夫", "德米特里耶夫", "叶戈罗夫", "安德烈耶夫",
	"马特维耶夫", "扎伊采夫", "斯捷潘诺夫", "卡扎科夫", "维诺格拉多夫", "叶利谢耶夫", "费奥多罗夫", "尼基京",
	"穆勒", "施密特", "施耐德", "费舍尔", "韦伯", "迈耶", "瓦格纳", "贝克",
	"舒尔茨", "霍夫曼", "舍费尔", "科赫", "鲍尔", "里希特", "克莱因", "沃尔夫",
	"施罗德", "诺依曼", "施瓦茨", "齐默尔曼", "布劳恩", "克鲁格", "哈特曼", "朗格",
	"杜邦", "马丁", "贝尔纳", "托马斯", "佩蒂特", "罗伯特", "理查", "杜兰德",
	"鲁瓦", "莫罗", "罗曼", "勒费弗尔", "梅尼耶", "布兰", "布鲁诺", "罗杰",
	"雷诺", "米歇尔", "勒布朗", "莫雷", "安托万", "巴蒂斯特", "克莱芒", "埃米尔",
	"史密斯", "约翰逊", "威廉姆斯", "布朗", "琼斯", "加西亚", "米勒", "戴维斯",
	"马丁内斯", "罗德里格斯", "埃尔南德斯", "洛佩兹", "冈萨雷斯", "威尔逊", "安德森", "托马斯",
	"泰勒", "摩尔", "杰克逊", "马丁", "李", "佩雷斯", "汤普森", "怀特"
]

# ========== 调试开关 ==========
@export var debug_log: bool = true

# ========== 部位节点引用 ==========
@onready var 头部碰撞: CollisionShape2D = $头部
@onready var 身体碰撞: CollisionShape2D = $身体
@onready var 左手碰撞: CollisionShape2D = $左手
@onready var 右手碰撞: CollisionShape2D = $右手
@onready var 左脚碰撞: CollisionShape2D = $左脚
@onready var 右脚碰撞: CollisionShape2D = $右脚
@onready var 视野范围: Area2D = $"M4A1/视野范围"
@onready var 听力范围: Area2D = $听力范围
@onready var animation_player: AnimationPlayer = $AnimationPlayer

@onready var 身体精灵: Sprite2D = $Sprite2D

# ========== 直接引用场景中的武器 ==========
@onready var 武器节点: Node2D = $M4A1
@onready var 枪口位置: Marker2D = $M4A1/枪口
@onready var 武器动画: AnimationPlayer = $M4A1/AnimationPlayer2
@onready var 抛壳位置: Marker2D = $M4A1/抛壳

# ========== 独立音效播放器 ==========
var 开火音效播放器: AudioStreamPlayer2D = null
var 弹壳落地音效播放器: AudioStreamPlayer2D = null

# ========== 导出变量 ==========
@export var 子弹数据: ItemData
@export var 射速_RPM: float = 400.0
@export var 射程: float = 800.0
@export var 射击精度: float = 50.0
@export var 开火音效: AudioStream
@export var 弹壳落地音效: AudioStream
@export var 弹壳场景: PackedScene

# ========== 伤害自定义 ==========
@export_group("伤害自定义")
@export var 基础伤害: float = 10.0
@export var 伤害浮动范围: float = 0.2
@export var 是否启用暴击: bool = true
@export var 暴击率: float = 0.15
@export var 暴击伤害倍率: float = 2.0
@export var 护甲穿透率: float = 0.0

@export_group("部位伤害倍率")
@export var 头部伤害倍率: float = 2.5
@export var 身体伤害倍率: float = 1.0
@export var 手臂伤害倍率: float = 0.8
@export var 腿部伤害倍率: float = 0.7

# ========== 移动与AI ==========
@export var 移动速度: float = 100.0
@export var 追击距离: float = 600.0
@export var 停止距离: float = 300.0
@export var 最小距离: float = 60.0

# ========== 随机巡逻 ==========
@export_group("随机巡逻")
@export var 巡逻速度: float = 30.0
@export var 转向间隔: float = 2.0
@export var 转向角度范围: float = 180.0
@export var 是否随机移动: bool = true
@export var 是否原地转向: bool = false

var 巡逻计时: float = 0.0
var 当前巡逻方向: Vector2 = Vector2.RIGHT
var 目标巡逻方向: Vector2 = Vector2.RIGHT

# ========== 武器角度修正 ==========
@export var 武器角度偏移: float = PI

# ========== 部位属性 ==========
@export_group("部位血量")
@export var 头部最大血量: float = 50.0
@export var 身体最大血量: float = 100.0
@export var 左手最大血量: float = 30.0
@export var 右手最大血量: float = 30.0
@export var 左脚最大血量: float = 40.0
@export var 右脚最大血量: float = 40.0

@export_group("部位护甲")
@export var 头部护甲: float = 20.0
@export var 身体护甲: float = 30.0

var 部位数据: Dictionary = {}
var 是否死亡: bool = false

# ========== 死亡掉落 ==========
@export var 掉落容器模板: PackedScene
@export var 战利品列表: Array[ItemData] = []

# ========== 内部状态 ==========
var 玩家: CharacterBody2D = null
var 当前状态: String = "idle"
var 是否正在射击: bool = false
var _射击计时: float = 0.0
var _朝向: String = "down"
var _受击反击强制开火: bool = false
var _has_aggro: bool = false   # 新增：仇恨状态标记

# ============================================================
func _ready():
	add_to_group("Enemy")
	初始化部位数据()
	连接视野信号()
	_创建音效播放器()
	播放动画("down_idle")
	_生成随机巡逻方向()
	if debug_log:
		print("[敌人] 初始化完成，射程=", 射程, " 射速=", 射速_RPM, " RPM")

func _创建音效播放器():
	开火音效播放器 = AudioStreamPlayer2D.new()
	add_child(开火音效播放器)
	开火音效播放器.name = "开火音效播放器"
	弹壳落地音效播放器 = AudioStreamPlayer2D.new()
	add_child(弹壳落地音效播放器)
	弹壳落地音效播放器.name = "弹壳落地音效播放器"

func 连接视野信号():
	if 视野范围:
		视野范围.body_entered.connect(_on_视野范围_body_entered)
		视野范围.body_exited.connect(_on_视野范围_body_exited)

func _collect_all_children(node: Node, list: Array):
	for child in node.get_children():
		list.append(child)
		_collect_all_children(child, list)

func _has_line_of_sight(target: Node2D) -> bool:
	var start = global_position
	var end = target.global_position
	var query = PhysicsRayQueryParameters2D.create(start, end)
	query.collide_with_areas = false
	query.collide_with_bodies = true
	query.exclude = [self]
	for enemy in get_tree().get_nodes_in_group("Enemy"):
		if enemy != self:
			query.exclude.append(enemy)
	var result = get_world_2d().direct_space_state.intersect_ray(query)
	if result.is_empty():
		return true
	var collider = result.collider
	if collider == target or collider.is_in_group("Player"):
		return true
	return false

func _on_视野范围_body_entered(body):
	if body.is_in_group("Player"):
		if _has_line_of_sight(body):
			玩家 = body
			当前状态 = "chase"

func _on_视野范围_body_exited(body):
	# 如果处于仇恨状态，不因离开视野而丢失目标
	if body == 玩家 and not _has_aggro:
		玩家 = null
		当前状态 = "idle"
		是否正在射击 = false

# ============================================================
func _physics_process(delta):
	if 是否死亡:
		return
	if _受击反击强制开火:
		_受击反击强制开火 = false
		if 玩家:
			var 距离 = global_position.distance_to(玩家.global_position)
			if 距离 <= 射程 and _has_line_of_sight(玩家):
				当前状态 = "shoot"
				是否正在射击 = true
				_射击计时 = 0.0
				射击(0.0)
	更新AI(delta)
	if 玩家 and not _has_line_of_sight(玩家):
		是否正在射击 = false
		当前状态 = "chase"
	移动(delta)
	if 是否正在射击:
		射击(delta)
	更新朝向与动画()
	更新巡逻(delta)

func 更新AI(delta):
	if not 玩家:
		当前状态 = "idle"
		是否正在射击 = false
		_has_aggro = false   # 无目标时清除仇恨
		return
	var 距离 = global_position.distance_to(玩家.global_position)
	# 如果是仇恨状态，不因距离过远而放弃；否则按常规追击距离判断
	if not _has_aggro and 距离 > 追击距离:
		玩家 = null
		当前状态 = "idle"
		是否正在射击 = false
		return
	var can_shoot = (距离 <= 射程) and _has_line_of_sight(玩家)
	if can_shoot:
		当前状态 = "shoot"
		是否正在射击 = true
	else:
		当前状态 = "chase"
		是否正在射击 = false

func 更新巡逻(delta):
	if 当前状态 != "idle" or 是否死亡:
		return
	巡逻计时 += delta
	if 巡逻计时 >= 转向间隔:
		巡逻计时 = 0.0
		_生成随机巡逻方向()
	if 当前巡逻方向 != 目标巡逻方向:
		var 当前角度 = 当前巡逻方向.angle()
		var 目标角度 = 目标巡逻方向.angle()
		var 差值 = 目标角度 - 当前角度
		while 差值 > PI:
			差值 -= 2 * PI
		while 差值 < -PI:
			差值 += 2 * PI
		var 旋转速度 = 5.0 * delta
		if abs(差值) < 旋转速度:
			当前巡逻方向 = 目标巡逻方向
		else:
			当前巡逻方向 = 当前巡逻方向.rotated(sign(差值) * 旋转速度)

func _生成随机巡逻方向():
	var 随机角度 = randf_range(-转向角度范围, 转向角度范围)
	var 弧度 = deg_to_rad(随机角度)
	if 是否原地转向:
		目标巡逻方向 = Vector2.RIGHT.rotated(弧度)
	else:
		目标巡逻方向 = Vector2.RIGHT.rotated(randf_range(0, 2 * PI))
	转向间隔 = randf_range(1.0, 3.0)

func 移动(delta):
	if 当前状态 == "chase" or 当前状态 == "shoot":
		if not 玩家:
			velocity = Vector2.ZERO
			move_and_slide()
			return
		var 距离 = global_position.distance_to(玩家.global_position)
		if 距离 < 最小距离:
			velocity = Vector2.ZERO
			move_and_slide()
			return
		var 方向 = (玩家.global_position - global_position).normalized()
		var 目标速度 = 方向 * 移动速度
		if 当前状态 == "shoot":
			目标速度 *= 0.5
		velocity = velocity.lerp(目标速度, 0.2)
		move_and_slide()
		return
	if 当前状态 == "idle" and 是否随机移动 and not 是否死亡:
		var 目标速度 = 当前巡逻方向 * 巡逻速度
		velocity = velocity.lerp(目标速度, 0.1)
		move_and_slide()
	else:
		velocity = Vector2.ZERO
		move_and_slide()

func 射击(delta):
	if not 玩家 or 是否死亡:
		return
	if not 枪口位置:
		return
	var 有效射速 = max(射速_RPM, 1.0)
	var 射击间隔 = 60.0 / 有效射速
	_射击计时 += delta
	if _射击计时 >= 射击间隔:
		_射击计时 -= 射击间隔
		_执行射击()

func 计算伤害(部位名称: String) -> float:
	var 最终伤害 = 基础伤害
	var 浮动值 = randf_range(-伤害浮动范围, 伤害浮动范围)
	最终伤害 *= (1.0 + 浮动值)
	var 部位倍率 = 1.0
	match 部位名称:
		"head": 部位倍率 = 头部伤害倍率
		"body": 部位倍率 = 身体伤害倍率
		"left_arm", "right_arm": 部位倍率 = 手臂伤害倍率
		"left_foot", "right_foot": 部位倍率 = 腿部伤害倍率
	最终伤害 *= 部位倍率
	if 是否启用暴击 and randf() < 暴击率:
		最终伤害 *= 暴击伤害倍率
	最终伤害 = max(最终伤害, 1.0)
	return 最终伤害

func _执行射击():
	if not 枪口位置:
		return
	var 起点 = 枪口位置.global_position
	var 方向 = (玩家.global_position - 起点).normalized()
	var 散 = 30.0 * (1.0 - 射击精度 / 100.0)
	if 散 > 0:
		方向 = 方向.rotated(deg_to_rad(randf_range(-散/2, 散/2)))
	var 终点 = 起点 + 方向 * 射程
	var 排除 = [self]
	var query = PhysicsRayQueryParameters2D.create(起点, 终点, 1, 排除)
	var result = get_world_2d().direct_space_state.intersect_ray(query)
	var 命中部位名称 = "body"
	var 实际命中点 = 终点
	if result and result.has("collider"):
		var collider = result.collider
		var 命中点 = result.position
		实际命中点 = 命中点
		var target = collider
		var is_player = false
		while target:
			if target.is_in_group("Player"):
				is_player = true
				break
			target = target.get_parent()
		if is_player and target and target.has_method("take_damage"):
			if target.has_method("get") and target.get("is_dead") == true:
				玩家 = null
				当前状态 = "idle"
				是否正在射击 = false
				_has_aggro = false
				return
			if collider == target:
				if target.has_method("get_hit_part"):
					命中部位名称 = target.get_hit_part(命中点)
				else:
					var 部位列表 = ["head", "body", "left_arm", "right_arm", "left_foot", "right_foot"]
					命中部位名称 = 部位列表[randi() % 部位列表.size()]
			else:
				var name_map = {
					"头部": "head", "头": "head",
					"身体": "body", "躯干": "body",
					"左手": "left_arm", "左臂": "left_arm",
					"右手": "right_arm", "右臂": "right_arm",
					"左脚": "left_foot", "左腿": "left_foot",
					"右脚": "right_foot", "右腿": "right_foot",
					"Head": "head", "Body": "body",
					"LeftArm": "left_arm", "RightArm": "right_arm",
					"LeftFoot": "left_foot", "RightFoot": "right_foot"
				}
				命中部位名称 = name_map.get(collider.name, "body")
			var 伤害 = 计算伤害(命中部位名称)
			target.take_damage(命中部位名称, 伤害, self)
	var 音效流 = 子弹数据.shoot_sound if 子弹数据 and 子弹数据.shoot_sound else 开火音效
	if 开火音效播放器 and 音效流:
		开火音效播放器.stream = 音效流
		开火音效播放器.play()
	_创建子弹拖尾(起点, 实际命中点)
	if 弹壳场景 and 抛壳位置:
		var 弹壳 = 弹壳场景.instantiate()
		弹壳.global_position = 抛壳位置.global_position
		get_tree().current_scene.add_child(弹壳)
		var 方向偏移 = Vector2(randf_range(-30, -60), randf_range(-20, 20))
		var 目标点 = 弹壳.global_position + 方向偏移
		var tween = get_tree().create_tween()
		tween.tween_property(弹壳, "global_position", 目标点, 0.3)
		tween.tween_callback(func():
			if 弹壳落地音效播放器 and 弹壳落地音效:
				弹壳落地音效播放器.stream = 弹壳落地音效
				弹壳落地音效播放器.play()
			await get_tree().create_timer(0.5).timeout
			if is_instance_valid(弹壳):
				弹壳.queue_free()
		)
	if 武器动画 and 武器动画.has_animation("开火"):
		武器动画.play("开火")
	播放动画("shoot")

func _创建子弹拖尾(起点: Vector2, 终点: Vector2):
	var trail = Line2D.new()
	trail.width = 2.0
	trail.default_color = Color(1.0, 0.8, 0.2)
	trail.add_point(起点)
	trail.add_point(终点)
	get_tree().current_scene.add_child(trail)
	var tween = get_tree().create_tween()
	tween.tween_property(trail, "modulate:a", 0.0, 0.1)
	tween.tween_callback(trail.queue_free)

func 更新朝向与动画():
	var 方向向量: Vector2
	if 玩家:
		方向向量 = (玩家.global_position - global_position).normalized()
	else:
		if 当前巡逻方向.length() < 0.1:
			方向向量 = Vector2.DOWN
		else:
			方向向量 = 当前巡逻方向.normalized()
	if abs(方向向量.x) > abs(方向向量.y):
		_朝向 = "right" if 方向向量.x > 0 else "left"
	else:
		_朝向 = "down" if 方向向量.y > 0 else "up"
	if 武器节点:
		var 武器角度 = 方向向量.angle() + 武器角度偏移
		武器节点.rotation = 武器角度
		var 原始缩放_x = abs(武器节点.scale.x)
		var 原始缩放_y = abs(武器节点.scale.y)
		if 方向向量.x > 0:
			武器节点.scale.x = 原始缩放_x
		else:
			武器节点.scale.x = -原始缩放_x
		武器节点.scale.y = 原始缩放_y
	if 视野范围:
		var 视野局部角度 = 方向向量.angle() - 武器节点.rotation
		视野范围.rotation = 视野局部角度
	if 身体精灵:
		if 方向向量.x > 0:
			身体精灵.scale.x = abs(身体精灵.scale.x)
		else:
			身体精灵.scale.x = -abs(身体精灵.scale.x)
	if velocity.length() > 10:
		播放动画(_朝向 + "_move")
	else:
		播放动画(_朝向 + "_idle")

func 播放动画(动画名: String):
	if animation_player and animation_player.has_animation(动画名):
		if animation_player.current_animation != 动画名:
			animation_player.play(动画名)

# ============================================================
func take_damage(部位名称: String, 伤害量: float, attacker: Node = null) -> void:
	if 是否死亡:
		return
	if not 部位数据.has(部位名称):
		return
	# 如果没有传递攻击者，尝试从玩家组获取
	if attacker == null:
		var players = get_tree().get_nodes_in_group("Player")
		if players.size() > 0:
			attacker = players[0]
	if attacker and attacker.is_in_group("Player"):
		玩家 = attacker
		_has_aggro = true
		当前状态 = "chase"
		是否正在射击 = false
		_受击反击强制开火 = true
		if debug_log:
			print("[敌人] 受到攻击，锁定玩家并进入仇恨状态")
	var data = 部位数据[部位名称]
	var 护甲值 = data.护甲
	var 实际伤害 = 伤害量
	if 护甲值 > 0:
		var 吸收 = min(护甲值, 伤害量)
		护甲值 -= 吸收
		实际伤害 -= 吸收
		data.护甲 = 护甲值
	if 实际伤害 > 0:
		data.当前血量 = max(data.当前血量 - 实际伤害, 0.0)
	if data.当前血量 <= 0 and data.节点:
		data.节点.disabled = true
	if 部位数据["head"].当前血量 <= 0 or 部位数据["body"].当前血量 <= 0:
		_死亡()
	else:
		var 总血量 = 0.0
		for key in 部位数据.keys():
			总血量 += 部位数据[key].当前血量
		if 总血量 <= 0:
			_死亡()

func 初始化部位数据():
	部位数据 = {
		"head": {"节点": 头部碰撞, "当前血量": 头部最大血量, "最大血量": 头部最大血量, "护甲": 头部护甲, "名称": "头部"},
		"body": {"节点": 身体碰撞, "当前血量": 身体最大血量, "最大血量": 身体最大血量, "护甲": 身体护甲, "名称": "身体"},
		"left_arm": {"节点": 左手碰撞, "当前血量": 左手最大血量, "最大血量": 左手最大血量, "护甲": 0.0, "名称": "左手"},
		"right_arm": {"节点": 右手碰撞, "当前血量": 右手最大血量, "最大血量": 右手最大血量, "护甲": 0.0, "名称": "右手"},
		"left_foot": {"节点": 左脚碰撞, "当前血量": 左脚最大血量, "最大血量": 左脚最大血量, "护甲": 0.0, "名称": "左脚"},
		"right_foot": {"节点": 右脚碰撞, "当前血量": 右脚最大血量, "最大血量": 右脚最大血量, "护甲": 0.0, "名称": "右脚"}
	}

func _死亡():
	if 是否死亡:
		return
	是否死亡 = true
	set_physics_process(false)
	if animation_player and animation_player.has_animation("死亡"):
		animation_player.play("死亡")
		await animation_player.animation_finished
	_生成掉落容器()
	queue_free()

func _生成掉落容器():
	var 容器: ContainerLoot
	if 掉落容器模板:
		容器 = 掉落容器模板.instantiate()
	else:
		容器 = load("res://场景/所有继承场景的父场景/container_loot.tscn").instantiate()

	# 随机名称
	var 名 = FOREIGN_NAMES[randi() % FOREIGN_NAMES.size()]
	var 姓 = FOREIGN_SURNAMES[randi() % FOREIGN_SURNAMES.size()]
	容器.container_name = 名 + "·" + 姓

	# 掉落物品
	容器.possible_items = 战利品列表
	容器.init_loot()

	# 位置与显示
	容器.global_position = global_position
	容器.visible = true
	容器.z_index = 10

	get_tree().current_scene.add_child(容器)

func get_part_hp_percent(部位名称: String) -> float:
	if not 部位数据.has(部位名称):
		return 0.0
	return 部位数据[部位名称].当前血量 / 部位数据[部位名称].最大血量
