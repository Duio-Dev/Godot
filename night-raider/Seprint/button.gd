extends Button

## 悬停时的缩放倍数（默认1.1倍）
@export var hover_scale: float = 1.1
## 动画持续时间（秒）
@export var anim_duration: float = 0.15

## 点击音效
@export var click_sound: AudioStream = null
## 悬停音效（可选）
@export var hover_sound: AudioStream = null

var _tween: Tween
var _audio_player: AudioStreamPlayer

func _ready() -> void:
	# 自动连接鼠标信号
	mouse_entered.connect(_on_mouse_entered)
	mouse_exited.connect(_on_mouse_exited)
	pressed.connect(_on_button_pressed)
	
	# 创建音频播放器
	_audio_player = AudioStreamPlayer.new()
	add_child(_audio_player)

func _on_mouse_entered() -> void:
	if _tween and _tween.is_valid():
		_tween.kill()
	_tween = create_tween()
	_tween.set_ease(Tween.EASE_OUT)
	_tween.set_trans(Tween.TRANS_BACK)
	_tween.tween_property(self, "scale", Vector2(hover_scale, hover_scale), anim_duration)
	
	# 播放悬停音效
	if hover_sound:
		_audio_player.stream = hover_sound
		_audio_player.play()

func _on_mouse_exited() -> void:
	if _tween and _tween.is_valid():
		_tween.kill()
	_tween = create_tween()
	_tween.set_ease(Tween.EASE_OUT)
	_tween.set_trans(Tween.TRANS_BACK)
	_tween.tween_property(self, "scale", Vector2.ONE, anim_duration)

func _on_button_pressed() -> void:
	# 播放点击音效
	if click_sound:
		_audio_player.stream = click_sound
		_audio_player.play()
	
	# 点击时稍微压一下再弹起的效果
	if _tween and _tween.is_valid():
		_tween.kill()
	_tween = create_tween()
	_tween.set_parallel(true)
	_tween.set_ease(Tween.EASE_OUT)
	_tween.set_trans(Tween.TRANS_BACK)
	
	# 快速缩小再恢复
	_tween.tween_property(self, "scale", Vector2(0.9, 0.9), 0.08)
	_tween.tween_property(self, "scale", Vector2.ONE, 0.12).set_delay(0.08)

# ==================== 外部控制函数 ====================
## 设置点击音效
func set_click_sound(sound: AudioStream) -> void:
	click_sound = sound

## 设置悬停音效
func set_hover_sound(sound: AudioStream) -> void:
	hover_sound = sound

## 播放自定义音效
func play_sound(sound: AudioStream) -> void:
	if sound:
		_audio_player.stream = sound
		_audio_player.play()

## 设置音量（0.0 - 1.0）
func set_volume(volume: float) -> void:
	_audio_player.volume_db = linear_to_db(volume)

## 停止所有音效
func stop_sound() -> void:
	_audio_player.stop()
