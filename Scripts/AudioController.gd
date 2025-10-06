extends Node

# Sound effects
const CLICK_004 = preload("res://Audio/Audio/click_004.ogg")

func play_effect(sound: String) -> void:
	var effect = AudioStreamPlayer.new()
	if sound == "click":
		effect.stream = CLICK_004
		add_child(effect)
		effect.play()
		await effect.finished
		effect.queue_free()
		print("Played click effect")
	
