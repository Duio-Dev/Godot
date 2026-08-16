# weapon_slot.gd
class_name WeaponSlot
extends Resource

@export var slot_name: String = ""
@export var slot_type: ItemData.WeaponPartType
@export var mount_offset: Vector2 = Vector2.ZERO
@export var mount_rotation: float = 0.0
@export var required_slot_tag: String = ""
@export var parent_slot_name: String = ""

# 预览专用
@export var preview_texture: Texture2D          # 预览时显示的贴图
@export var preview_size: Vector2 = Vector2(20, 20)  # 预览时绘制大小（若 preview_texture 为空则画绿色方框）
