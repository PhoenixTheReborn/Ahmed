extends Label

@onready var player: CharacterBody3D = $".."


func _process(_delta: float) -> void:
	if player and "hp" in player:
		text = "HP: " + str(player.hp)
