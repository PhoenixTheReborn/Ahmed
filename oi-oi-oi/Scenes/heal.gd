extends CSGBox3D

@export var heal_amount: int = 10

func interact() -> void:
	heal()

func heal() -> void:
	var player = get_tree().get_first_node_in_group("Player")
	if player and player.has_method("heal_hp"):
		player.heal_hp(heal_amount)
