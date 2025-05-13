extends Label

var warn_1 = "Use the cameras to monitor the environment"
var warn_2 = "File a report if anything is not as it should be."
var end = ""

func scroll_text(input: String) -> void:
	visible_characters = 0
	text = input
	
	for i in text:
		visible_characters += 1
		await get_tree().create_timer(0.04).timeout

func _on_visibility_changed() -> void:
	scroll_text(warn_1)
	await get_tree().create_timer(5.5).timeout
	scroll_text(warn_2)
	await get_tree().create_timer(5.5).timeout
	text = end
