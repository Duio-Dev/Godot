extends CharacterBody2D

# ===== 移动参数 =====
@export var move_speed: float = 300.0
@export var acceleration: float = 10.0
@export var friction: float = 10.0
@export var dead_zone: float = 0.1

# ===== 动画参数 =====
@export var idle_animation_name: String = "idle"
@export var move_animation_name: String = "move"

# ===== 节点引用 =====
@onready var sprite_container: Node2D = $Player
@onready var animation_player: AnimationPlayer = $AnimationPlayer  # 根据实际路径调整

var input_direction: Vector2 = Vector2.ZERO
var current_facing: int = -1
var is_moving: bool = false





func _physics_process(delta: float) -> void:
	if Input.is_action_just_pressed("inventory"):
		# 切换 CanvasLayer 的可见性
		$CanvasLayer.visible = !$CanvasLayer.visible
	var raw_input = Input.get_vector("move_left", "move_right", "move_up", "move_down")
	input_direction = Vector2.ZERO
	if abs(raw_input.x) > dead_zone:
		input_direction.x = raw_input.x
	if abs(raw_input.y) > dead_zone:
		input_direction.y = raw_input.y
	
	if input_direction != Vector2.ZERO:
		velocity = velocity.lerp(input_direction * move_speed, acceleration * delta)
		is_moving = true
	else:
		velocity = velocity.lerp(Vector2.ZERO, friction * delta)
		is_moving = false
	
	update_facing_by_mouse()
	update_animation()
	
	move_and_slide()

func update_facing_by_mouse() -> void:
	var mouse_global_pos = get_global_mouse_position()
	var player_global_pos = global_position
	var direction_to_mouse = mouse_global_pos - player_global_pos
	
	if direction_to_mouse.x > 0 and current_facing != -1:
		sprite_container.scale.x = -1
		current_facing = -1
	elif direction_to_mouse.x < 0 and current_facing != 1:
		sprite_container.scale.x = 1
		current_facing = 1

# ✅ 通过 AnimationPlayer 播放动画
func update_animation() -> void:
	if animation_player == null:
		return
	
	var target_animation = move_animation_name if is_moving else idle_animation_name
	
	# 如果当前播放的动画不是目标动画，则切换
	if animation_player.current_animation != target_animation:
		animation_player.play(target_animation)
