@tool
extends Control
#调试脚本用于调试
@export var receiver_item: ItemData : set = _set_receiver

var preview_layer: CanvasLayer
var preview_texture_rect: TextureRect

func _ready():
	preview_layer = CanvasLayer.new()
	preview_layer.layer = 100
	add_child(preview_layer)
	_create_preview()
	_set_receiver(receiver_item)
	set_process(true)

func _set_receiver(data: ItemData):
	receiver_item = data
	if is_inside_tree() and preview_texture_rect:
		_update_preview()

func _process(delta):
	if Engine.is_editor_hint():
		_update_preview()

func _update_preview():
	if not preview_texture_rect: return
	var tex = _generate_preview(receiver_item)
	if tex:
		preview_texture_rect.texture = tex
		preview_texture_rect.size = tex.get_size()
		preview_texture_rect.position = Vector2.ZERO
	else:
		preview_texture_rect.texture = null

func _create_preview():
	var tex_rect = TextureRect.new()
	tex_rect.name = "Preview"
	tex_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	tex_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	tex_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	preview_layer.add_child(tex_rect)
	preview_texture_rect = tex_rect

func _generate_preview(data: ItemData) -> Texture2D:
	# 直接判断 weapon_part_type，避免调用自定义方法导致占位实例错误
	if not data:
		return null
	if data.weapon_part_type != ItemData.WeaponPartType.RECEIVER and data.weapon_part_type != ItemData.WeaponPartType.HELMET:
		return null
	if not data.icon:
		return null

	var base_img = data.icon.get_image()
	if base_img.is_compressed():
		base_img.decompress()

	var draw_items = []
	draw_items.append({"img": base_img, "pos": Vector2.ZERO})

	for slot in data.receiver_slots:
		var img: Image
		if slot.preview_texture:
			img = slot.preview_texture.get_image()
			if img.is_compressed(): img.decompress()
			if slot.preview_size != Vector2.ZERO:
				img.resize(int(slot.preview_size.x), int(slot.preview_size.y), Image.INTERPOLATE_NEAREST)
		else:
			var size = slot.preview_size if slot.preview_size != Vector2.ZERO else Vector2(20, 20)
			img = Image.create(int(size.x), int(size.y), false, Image.FORMAT_RGBA8)
			img.fill(Color(0,0,0,0))
			for x in range(int(size.x)):
				for y in range(int(size.y)):
					if x == 0 or y == 0 or x == int(size.x)-1 or y == int(size.y)-1:
						img.set_pixel(x, y, Color(0,1,0))
		var pos = slot.mount_offset - img.get_size() / 2.0
		draw_items.append({"img": img, "pos": pos})

	# 边界计算
	var min_x = 0.0
	var min_y = 0.0
	var max_x = base_img.get_width()
	var max_y = base_img.get_height()
	for item in draw_items:
		var p = item["pos"]
		var img = item["img"]
		min_x = min(min_x, p.x)
		min_y = min(min_y, p.y)
		max_x = max(max_x, p.x + img.get_width())
		max_y = max(max_y, p.y + img.get_height())

	var total_w = int(max_x - min_x)
	var total_h = int(max_y - min_y)
	var offset = Vector2(-min_x, -min_y)

	var result = Image.create(total_w, total_h, false, Image.FORMAT_RGBA8)
	result.fill(Color(0, 0, 0, 0))

	# 先绘制底图（直接覆盖）
	var base_dest = Vector2.ZERO + offset
	result.blit_rect(base_img, Rect2i(0, 0, base_img.get_width(), base_img.get_height()), Vector2i(int(base_dest.x), int(base_dest.y)))

	# 绘制其他预览配件（使用 blend_rect 避免透明覆盖）
	for i in range(1, draw_items.size()):
		var img = draw_items[i]["img"]
		var dest = draw_items[i]["pos"] + offset
		result.blend_rect(img, Rect2i(0, 0, img.get_width(), img.get_height()), Vector2i(int(dest.x), int(dest.y)))

	return ImageTexture.create_from_image(result)
