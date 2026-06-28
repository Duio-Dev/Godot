extends Node
class_name DragManager

var is_dragging: bool = false
var dragging_item_data: ItemResource = null
var dragging_item_id: int = -1
var drag_start_cell: Vector2i = Vector2i(-1, -1)
var drag_start_container: ColorRect = null
var drag_start_rotated: bool = false

signal drag_started(item_data: ItemResource, source_container: ColorRect)
signal drag_ended(item_data: ItemResource, target_container: ColorRect, target_cell: Vector2i)
signal drag_cancelled(item_data: ItemResource)

func _ready() -> void:
	print("DragManager 已加载")

func start_drag(item_data: ItemResource, item_id: int, start_cell: Vector2i, source_container: ColorRect, rotated: bool = false) -> void:
	is_dragging = true
	dragging_item_data = item_data
	dragging_item_id = item_id
	drag_start_cell = start_cell
	drag_start_container = source_container
	drag_start_rotated = rotated
	drag_started.emit(item_data, source_container)
	print("全局拖拽开始: ", item_data.name)

func end_drag(target_container: ColorRect, target_cell: Vector2i) -> void:
	if not is_dragging:
		return
	
	print("全局拖拽放置到: ", target_container.name, " 格子: ", target_cell)
	drag_ended.emit(dragging_item_data, target_container, target_cell)
	clear_drag_state()

func cancel_drag() -> void:
	if not is_dragging:
		return
	
	print("全局拖拽取消")
	drag_cancelled.emit(dragging_item_data)
	clear_drag_state()

func clear_drag_state() -> void:
	is_dragging = false
	dragging_item_data = null
	dragging_item_id = -1
	drag_start_cell = Vector2i(-1, -1)
	drag_start_container = null
	drag_start_rotated = false
