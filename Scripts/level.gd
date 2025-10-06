extends Node3D

signal intruder_reported

# UI References
@onready var anomaly_alarm: Label = $Control/AnomalyAlarm
@onready var room_label: Label = $Control/RoomLabel
@onready var countdown: Label = $Control/Countdown
@onready var report_button: Button = $Control/ReportMargin/ReportButton
@onready var report_types: HBoxContainer = $Control/ReportMargin/ReportTypes

# Audio References
@onready var glitch_audio: AudioStreamPlayer2D = %GlitchAudio
@onready var reset_audio: AudioStreamPlayer2D = %ResetAudio

# Effects
@onready var glitch_effect: ColorRect = $Control/GlitchEffect
@onready var reset_effect: ColorRect = $Control/ResetEffect

# Timers
@onready var anomaly_spawner: Timer = $Control/AnomalySpawner

# Camera system
@export var cameras: Array[Camera3D] = []
@onready var current_camera: Camera3D

# Game state
@export var minute := 10
@export var seconds := 0
@export var game_over_thresh: int = 5
@export var diff_mult := 1

var activated: Array = []
var active_number: int = 0
var spawn_gap: float = 0
var spawn_threshold := 50.0
var reporting := false

# Anomaly type mapping for cleaner code
const ANOMALY_TYPES = {
	"missing": "missing",
	"extra": "extra", 
	"moved": "moved",
	"lights": "light",
	"camera": "camera_bug",
	"intruder": "intruder",
	"replaced": "replaced"
}

func _ready() -> void:
	cameras[0].current = true
	update_label()
	process_mode = PROCESS_MODE_DISABLED

func _process(delta: float) -> void:
	spawn_gap += delta
	
	if spawn_gap > spawn_threshold:
		spawn_anomaly()
	
	# Camera switching
	if Input.is_action_just_pressed("left"):
		switch_camera(-1)
	elif Input.is_action_just_pressed("right"):
		switch_camera(1)
	
	# Update current camera and room label
	update_current_camera()
	
	# Game over conditions
	if (minute <= 0 and seconds <= 0) or Input.is_action_just_pressed("ui_cancel"):
		game_over("Returning to menu")
		return
	
	# Anomaly alarm logic
	if active_number == game_over_thresh - 1 and not reporting:
		anomaly_alarm.visible = true
	elif active_number >= game_over_thresh and not reporting:
		game_over("Too many anomalies")
		return
	
	# Report button visibility
	report_types.visible = !report_button.visible

func update_current_camera() -> void:
	for cam in cameras:
		if cam.current:
			current_camera = cam
			room_label.text = cam.name
			break

func game_over(message: String) -> void:
	reset_effect.show()
	%Label.text = message
	await get_tree().create_timer(3).timeout
	get_tree().reload_current_scene()

func spawn_anomaly() -> void:
	var anomalies = get_tree().get_nodes_in_group("anomaly")
	var target = anomalies.pick_random()
	if not target.activated and not activated.has(target):
		target.activated = true
		activated.append(target)
		active_number += 1
		spawn_gap = 0.0

func switch_camera(direction: int) -> void:
	if cameras.is_empty():
		return
	
	var current_index = cameras.find(current_camera)
	current_index = (current_index + direction) % cameras.size()
	current_camera = cameras[current_index]
	current_camera.current = true
	AudioController.play_effect("click")

func update_label() -> void:
	countdown.text = "%d:%02d" % [minute, seconds]

func _on_timer_timeout() -> void:
	seconds -= 1
	if seconds < 0:
		if minute > 0:
			minute -= 1
			seconds = 59
		else:
			minute = 0
			seconds = 0
	update_label()

func _on_anomaly_spawner_timeout() -> void:
	var chance = randi() % 6 - diff_mult
	if chance == 1:
		spawn_anomaly()

func report_pending() -> void:
	report_button.visible = true
	report_button.disabled = true
	report_button.text = "Reporting..."
	reporting = true
	
	await get_tree().create_timer(4.05).timeout
	
	if reset_effect.visible:
		await get_tree().create_timer(1.95).timeout
	else:
		%Invalid.visible = true
		await get_tree().create_timer(2).timeout
		%Invalid.visible = false
	
	report_button.text = "Report"
	report_button.disabled = false

func report_anomaly(type: String) -> void:
	reporting = true
	var room_children = current_camera.get_parent().get_children()
	var fix_queue = filter_anomalies(room_children, type)
	
	if fix_queue.size() > 0:
		await trigger_reset_effect()
		process_fix_queue(fix_queue, type)
	
	reporting = false

func filter_anomalies(list: Array, type: String) -> Array:
	var fix_queue: Array = []
	var property_name = ANOMALY_TYPES.get(type, "")
	
	for anomaly in list:
		if anomaly in activated and anomaly.activated and not anomaly.fixed:
			if property_name and anomaly.get(property_name):
				if type == "intruder":
					emit_signal("intruder_reported")
				fix_queue.append(anomaly)
	
	return fix_queue

func trigger_reset_effect() -> void:
	await get_tree().create_timer(4).timeout
	reset_effect.visible = true
	reset_audio.play()
	await get_tree().create_timer(2).timeout
	reset_audio.stop()
	reset_effect.visible = false

func process_fix_queue(fix_queue: Array, type: String) -> void:
	for anomaly in fix_queue:
		match type:
			"replaced", "extra":
				anomaly.visible = false
			"missing":
				anomaly.visible = true
			"moved":
				anomaly.activated = false
				anomaly.animation_player.play("RESET")
		
		anomaly.fixed = true
		active_number -= 1

func _on_camera_bugged() -> void:
	glitch_effect.show()
	if not glitch_audio.playing:
		glitch_audio.play()

func _on_not_bugged() -> void:
	glitch_effect.hide()
	glitch_audio.stop()

# Difficulty setup helper
func setup_difficulty(multiplier: int, spawn_time: int, threshold_mult: float) -> void:
	diff_mult = multiplier
	anomaly_spawner.wait_time = spawn_time
	spawn_threshold *= threshold_mult
	%Menu.hide()
	%TutorialIntro.show()
	process_mode = Node.PROCESS_MODE_ALWAYS

func _on_easy_pressed() -> void:
	setup_difficulty(1, 20, 1.2)

func _on_medium_pressed() -> void:
	setup_difficulty(2, 20, 1.0)

func _on_hard_pressed() -> void:
	setup_difficulty(3, 15, 0.8)

func _on_quit_pressed() -> void:
	quit_game()

func quit_game() -> void:
	get_tree().quit()

func _on_report_button_pressed() -> void:
	AudioController.play_effect("click")
	report_button.visible = false

# Generic report handler to reduce redundancy
func _on_report_pressed(type: String) -> void:
	AudioController.play_effect("click")
	report_pending()
	report_anomaly(type)

# Connect these to the respective buttons
func _on_missing_object_pressed() -> void:
	_on_report_pressed("missing")

func _on_extra_object_pressed() -> void:
	_on_report_pressed("extra")

func _on_moved_object_pressed() -> void:
	_on_report_pressed("moved")

func _on_camera_bug_pressed() -> void:
	_on_report_pressed("camera")

func _on_lights_pressed() -> void:
	_on_report_pressed("lights")

func _on_intruder_pressed() -> void:
	_on_report_pressed("intruder")

func _on_replaced_object_pressed() -> void:
	_on_report_pressed("replaced")
