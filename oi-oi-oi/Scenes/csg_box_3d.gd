extends CSGBox3D

@export var damage_amount: int = 5

func interact() -> void:
	print("Interacted with damage box")
	damage()

func damage() -> void:
	var player = get_tree().get_first_node_in_group("Player")
	if player and player.has_method("take_damage"):
		player.take_damage(damage_amount)
