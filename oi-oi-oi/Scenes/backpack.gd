extends Node3D

func _on_static_body_3d_mouse_entered() -> void:
	get_tree().quit()
