extends Node3D

signal intruder_reported

@onready var anomaly_alarm: Label = $Control/AnomalyAlarm
@onready var glitch_audio: AudioStreamPlayer2D = %GlitchAudio
@onready var reset_audio: AudioStreamPlayer2D = %ResetAudio
@onready var anomaly_spawner: Timer = $Control/AnomalySpawner
@onready var room_label: Label = $Control/RoomLabel

## Camera references.
## Populate list of cameras. Room label is set to the name of the camera node.
@export var cameras: Array[Camera3D] = [] 
@onready var current_camera : Camera3D

## Reporting buttons
@onready var report_button: Button = $Control/ReportMargin/ReportButton
@onready var missing_object: Button = $Control/ReportMargin/HBoxContainer/MissingObject
@onready var extra_object: Button = $Control/ReportMargin/HBoxContainer/ExtraObject
@onready var moved_object: Button = $Control/ReportMargin/HBoxContainer/MovedObject
@onready var camera_bug: Button = $Control/ReportMargin/HBoxContainer/CameraBug
@onready var lights: Button = $Control/ReportMargin/HBoxContainer/Lights
@onready var intruder: Button = $Control/ReportMargin/HBoxContainer/Intruder
@onready var report_types: HBoxContainer = $Control/ReportMargin/ReportTypes

## Special anomalies
@onready var anomaly_floor: Node3D = $LevelFloor/AnomalyFloor
@onready var glitch_effect: ColorRect = $Control/GlitchEffect

## Reset anomaly effect
@onready var reset_effect: ColorRect = $Control/ResetEffect

## Countdown timer
@onready var countdown: Label = $Control/Countdown

@export var minute := 10
@export var seconds := 0
@export var game_over_thresh: int = 5
@export var diff_mult := 1

# List to hold used anomalies
var activated : Array = []

var active_number: int = 0
## Tracks time between spawned anomalies to ensure there's no more than a few failed
## spawns in a row
var spawn_gap: float = 0
var spawn_threshold := 50.0

## Reporting flag
var reporting := false

## Called when the node enters the scene tree for the first time.
func _ready() -> void:
	cameras[0].current = true
	update_label()
	self.process_mode = PROCESS_MODE_DISABLED

## Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	spawn_gap += 1.0 * delta
	if spawn_gap > spawn_threshold:
		spawn_anomaly()
	#print(spawn_gap)
	
	if Input.is_action_just_pressed("left"):
		switch_camera(-1)
	elif Input.is_action_just_pressed("right"):
		switch_camera(1)

	## Current camera check, used for validating reported anomaly type in
	## monitored room
	for cam in cameras:
		if cam.current == true:
			current_camera = cam
	
	## Room Label updater
	if current_camera:# in camera_labels:
		room_label.text = str(current_camera.name)
	
	
	if minute <= 0 and seconds <= 0 or Input.is_action_just_pressed("ui_cancel"):
		reset_effect.show()
		%Label.text = "Returning to menu"
		await get_tree().create_timer(3).timeout
		
		get_tree().reload_current_scene()
		
	

	## Logic for tracking active anomalies here, should increase the counter
	## through the spawning, and decrease from correct reports
	if active_number == game_over_thresh - 1:
		if not reporting:
			if active_number == game_over_thresh - 1:
				anomaly_alarm.visible = true
	if active_number == game_over_thresh:
		if not reporting:
			reset_effect.show()
			%Label.text = "Too many anomalies"
			await get_tree().create_timer(3).timeout
			quit_game()
	#print(active_number)

	## Report button visiblility logic
	if report_button.visible:
		report_types.visible = false
	elif !report_button.visible:
		report_types.visible = true

# Universal timer
func wait_time(time: int):
	get_tree().create_timer(time).timeout

## Currently this is set to not retry spawning an anomaly if the random target
## is already visible. In theory this should prevent being overwhelmed with anomalies
## too quickly, but might need to be adjusted if testers feel different.
func spawn_anomaly() -> void:
	var anomalies = get_tree().get_nodes_in_group("anomaly")
	var target = anomalies.pick_random()
	if target.activated == false and not activated.has(target):
		target.activated = true
		activated.append(target)
		active_number +=1
		spawn_gap = 0.0


func switch_camera(direction: int) -> void:
	if cameras.size() == 0:
		return
	var current_index = cameras.find(current_camera)

	current_index = (current_index + direction) % cameras.size()
	current_camera = cameras[current_index]
	current_camera.current = true
	AudioController.play_effect("click")


func cam_left() -> void:
	switch_camera(-1)


func cam_right() -> void:
	switch_camera(1)

# Countdown timer logic
func update_label() -> void:
	countdown.text = str(minute) + ":" + str(seconds)
	if seconds < 10:
		countdown.text = str(minute) + ":0" + str(seconds)


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


func quit_game() -> void:
	get_tree().quit()

## Probability to spawn anomaly on timer loop, could possibly
## look at adjusting chances for difficulty
func _on_anomaly_spawner_timeout() -> void:
	var chance = randi() % 6 - diff_mult
	if chance == 1:
		spawn_anomaly()
	#elif spawn_gap > 50.0:
		#spawn_anomaly()
	#print("Active anomalies: " +str(active_number))


## Report button functions
func report_pending() -> void:
	report_button.visible = true
	report_button.disabled = true
	report_button.text = "Reporting..."
	reporting = true
	await get_tree().create_timer(4.05).timeout
	if reset_effect.visible:
		await get_tree().create_timer(1.95).timeout
		report_button.text = "Report"
		report_button.disabled = false
	elif !reset_effect.visible:
		%Invalid.visible = true
		await get_tree().create_timer(2).timeout
		%Invalid.visible = false
		report_button.disabled = false
		report_button.text = "Report"


func report_anomaly(type: String) -> void:
	reporting = true
	var list = current_camera.get_parent().get_children() # Get nodes in the current room
	#print(list)
	var fix_queue: Array = filter_anomalies(list, type) # Filter anomalies to fix
	if fix_queue.size() > 0:
		await trigger_reset_effect()
		await process_fix_queue(fix_queue, type)
	reporting = false


func filter_anomalies(list: Array, type: String) -> Array:
	var fix_queue: Array = []
	for anomaly in list:
		if anomaly in activated and anomaly.activated and !anomaly.fixed:
			match type:
				"replaced":
					if anomaly.replaced:
						fix_queue.append(anomaly)
				"missing":
					if anomaly.missing:
						fix_queue.append(anomaly)
				"extra":
					if anomaly.extra:
						fix_queue.append(anomaly)
				"moved":
					if anomaly.moved:
						fix_queue.append(anomaly)
				"lights":
					if anomaly.light:
						fix_queue.append(anomaly)
				"camera":
					if anomaly.camera_bug:
						fix_queue.append(anomaly)
				"intruder":
					if anomaly.intruder:
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
		reporting = true
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
		reporting = false


func _on_camera_bugged() -> void:
	glitch_effect.show()
	if !glitch_audio.playing:
		glitch_audio.play()


func _on_not_bugged() -> void:
	glitch_effect.hide()
	glitch_audio.stop()

# Difficulty options
func _on_easy_pressed() -> void:
	diff_mult = 1
	anomaly_spawner.wait_time = 20
	spawn_threshold *= 1.2
	%Menu.hide()
	%TutorialIntro.show()
	process_mode = Node.PROCESS_MODE_ALWAYS


func _on_medium_pressed() -> void:
	anomaly_spawner.wait_time = 20
	diff_mult = 2
	spawn_threshold *= 1
	%Menu.hide()
	%TutorialIntro.show()
	process_mode = Node.PROCESS_MODE_ALWAYS


func _on_hard_pressed() -> void:
	diff_mult = 3
	spawn_threshold *= 0.8
	anomaly_spawner.wait_time = 15
	%Menu.hide()
	%TutorialIntro.show()
	process_mode = Node.PROCESS_MODE_ALWAYS


func _on_quit_pressed() -> void:
	get_tree().quit()


func _on_report_button_pressed() -> void:
	AudioController.play_effect("click")
	#print("Opened report menu")
	report_button.visible = false


func _on_missing_object_pressed() -> void:
	AudioController.play_effect("click")
	#print("Missing object reported")
	report_pending()
	report_anomaly("missing")


func _on_extra_object_pressed() -> void:
	AudioController.play_effect("click")
	#print("Extra object reported")
	report_pending()
	report_anomaly("extra")


func _on_moved_object_pressed() -> void:
	AudioController.play_effect("click")
	#print("Moved object reported")
	report_pending()
	report_anomaly("moved")


func _on_camera_bug_pressed() -> void:
	AudioController.play_effect("click")
	#print("Camera bug reported")
	report_pending()
	report_anomaly("camera")


func _on_lights_pressed() -> void:
	AudioController.play_effect("click")
	#print("Light anomaly reported")
	report_pending()
	report_anomaly("lights")


func _on_intruder_pressed() -> void:
	AudioController.play_effect("click")
	#print("Intruder reported")
	report_pending()
	report_anomaly("intruder")


func _on_replaced_object_pressed() -> void:
	AudioController.play_effect("click")
	#print("Replaced object reported")
	report_pending()
	report_anomaly("replaced")
