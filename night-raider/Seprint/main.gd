@tool
extends Control

# ===== 颜色定义 =====
const GODOT_BLUE = Color(0.2, 0.5, 0.85)
const WHITE = Color.WHITE
const GREY = Color(0.5, 0.5, 0.5)

# ===== 坐标数据 =====
var coords_head : Array = [
	[ 22.952, 83.271 ],  [ 28.385, 98.623 ],
	[ 53.168, 107.647 ], [ 72.998, 107.647 ],
	[ 99.546, 98.623 ],  [ 105.048, 83.271 ],
	[ 105.029, 55.237 ], [ 110.740, 47.082 ],
	[ 102.364, 36.104 ], [ 94.050, 40.940 ],
	[ 85.189, 34.445 ],  [ 85.963, 24.194 ],
	[ 73.507, 19.930 ],  [ 68.883, 28.936 ],
	[ 59.118, 28.936 ],  [ 54.494, 19.930 ],
	[ 42.039, 24.194 ],  [ 42.814, 34.445 ],
	[ 33.951, 40.940 ],  [ 25.637, 36.104 ],
	[ 17.262, 47.082 ],  [ 22.973, 55.237 ]
]

var coords_mouth = [
	[ 22.817, 81.100 ], [ 38.522, 82.740 ],
	[ 39.001, 90.887 ], [ 54.465, 92.204 ],
	[ 55.641, 84.260 ], [ 72.418, 84.177 ],
	[ 73.629, 92.158 ], [ 88.895, 90.923 ],
	[ 89.556, 82.673 ], [ 105.005, 81.100 ]
]

var head : PackedVector2Array
var mouth : PackedVector2Array

func float_array_to_Vector2Array(coords : Array) -> PackedVector2Array:
	var array : PackedVector2Array = []
	for coord in coords:
		array.append(Vector2(coord[0], coord[1]))
	return array

func _ready():
	head = float_array_to_Vector2Array(coords_head)
	mouth = float_array_to_Vector2Array(coords_mouth)

var default_font : Font = ThemeDB.fallback_font

var _mouth_width : float = 4.4
var _max_width : float = 7
var _time : float = 0

func _process(delta : float):
	_time += delta
	_mouth_width = abs(sin(_time) * _max_width)
	queue_redraw()

func _draw():
	# 头部
	draw_polygon(head, [ GODOT_BLUE ])
	
	# 嘴巴（动态宽度）
	draw_polyline(mouth, WHITE, _mouth_width)
	
	# 眼白
	draw_circle(Vector2(42.479, 65.4825), 9.3905, WHITE)
	draw_circle(Vector2(85.524, 65.4825), 9.3905, WHITE)
	
	# 瞳孔
	draw_circle(Vector2(43.423, 65.92), 6.246, GREY)
	draw_circle(Vector2(84.626, 66.008), 6.246, GREY)
	
	# 鼻子
	draw_line(Vector2(64.273, 60.564), Vector2(64.273, 74.349), WHITE, 5.8)
	
	# 文字
	draw_string(default_font, Vector2(20, 130), "GODOT",
				HORIZONTAL_ALIGNMENT_CENTER, 90, 22)


func _on_退出游戏_pressed() -> void:
	get_tree().quit()


func _on_市场_pressed() -> void:
	get_tree().change_scene_to_file("res://Scencs/UI/市场.tscn")


func _on_仓库_pressed() -> void:
	get_tree().change_scene_to_file("res://Scencs/UI/仓库.tscn")
