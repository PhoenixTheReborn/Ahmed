extends RigidBody3D

@onready var mesh: MeshInstance3D = $MeshInstance3D

const INTERACTION_SHADER = preload("uid://dt6qfm685l3qk")
const HIGHLIGHT = preload("uid://culhol5h4jwd3")

var interaction_mat: ShaderMaterial
var highlight_mat: ShaderMaterial

var is_in_range: bool = false
var is_focused: bool = false
var tween: Tween

func _ready() -> void:

	if INTERACTION_SHADER:
		interaction_mat = INTERACTION_SHADER.duplicate()
		interaction_mat.set_shader_parameter("outline_width", 0.0)

	if HIGHLIGHT:
		highlight_mat = HIGHLIGHT.duplicate()
		highlight_mat.set_shader_parameter("outline_width", 0.0)

func set_in_range(in_range: bool) -> void:
	is_in_range = in_range
	update_shader()

func set_focused(focused: bool) -> void:
	is_focused = focused
	update_shader()

func update_shader() -> void:

	if tween and tween.is_running():
		tween.kill()

	var target_mat: ShaderMaterial = null
	var target_width: float = 0.0


	if is_focused:
		target_mat = highlight_mat
		target_width = 2.0  
	elif is_in_range:
		target_mat = interaction_mat
		target_width = 1.0


	if target_mat != null:
		mesh.material_overlay = target_mat
		
		tween = create_tween().set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
		tween.tween_property(target_mat, "shader_parameter/outline_width", target_width, 0.25)

	else:
		var active_mat = mesh.material_overlay as ShaderMaterial
		if active_mat:
			tween = create_tween().set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
			tween.tween_property(active_mat, "shader_parameter/outline_width", 0.0, 0.25)

			tween.tween_callback(func(): mesh.material_overlay = null)

func interact() -> void:
	print("Interacted with flashlight")
	queue_free()
