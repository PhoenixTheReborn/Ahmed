extends Label

@onready var player: CharacterBody3D = $".."

func _process(_delta: float) -> void:
	if player and "lives" in player:
		text = "Lives: " + str(player.lives)
