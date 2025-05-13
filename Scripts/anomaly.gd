extends Node3D

signal bugged
signal not_bugged
@onready var glitch_effect: ColorRect = %GlitchEffect
@onready var glitch_audio: AudioStreamPlayer2D = %GlitchAudio
@onready var reset_audio: AudioStreamPlayer2D = %ResetAudio

@onready var animation_player : AnimationPlayer = $AnimationPlayer # Need to fix this reference
@export var light_options : Light3D
# Export anomaly types
@export_category("Anomaly Types")
@export var activated := false
@export var missing := false
@export var moved := false
@export var extra := false
@export var replaced := false
# Replaced anomaly target export
@export var replace_target : Node3D
@export var light := false
@export var intruder := false
@export var camera_bug := false

# Light anomaly subtypes
@export_category("Light types")
@export var light_extra := false
@export var light_flicker := false
@export var light_missing := false

# Intruder Animation player
@export_category("Intruder Specifics")
@export var intruder_anim: AnimationPlayer
# Camera anomaly settings
@export_category("Camera anomaly specifics")
@export var cam : Camera3D

# Export audio player if required
@export_category("Audio Player")
@export var general_audio : AudioStreamPlayer3D

# Flag to indicate anomaly is done doing anomalous things
var fired := false
var fixed := false
var animation_done: bool = false

func _process(delta: float) -> void:
	#glitch_effect.hide()
	# Core anomaly logic
	if activated: # Enable anomaly behavior
		if !fired:
			if extra:
				show()
				fired = true
			elif missing:
				hide()
				fired = true
			elif moved:
				if animation_done == false:
					animation_player.play("MOVED")
					animation_done = true
					fired = true
			elif replaced:
				visible = true
				fired = true
				if replace_target:
					replace_target.visible = false
					fired = true
			elif intruder:
				show()
				if general_audio:
					if !general_audio.playing:
						general_audio.play()
				fired = true

	
	if not activated or fixed:
		if extra:
			visible = false
		elif missing:
			visible = true
		elif moved:
			pass
		elif replaced:
			visible = false
			if replace_target:
				replace_target.visible = true
		elif intruder:
			hide()
			if general_audio:
					if general_audio.playing:
						general_audio.stop()
		elif camera_bug:
			pass

	# Light anomaly specifics
	if activated and light and !fixed:
		if light_flicker:
			var power = randf_range(0.25, 1.25)
			light_options.light_energy = power
			if general_audio:
					if !general_audio.playing:
						general_audio.play()
		if light_missing:
			hide()
		if light_extra:
			show()
			if general_audio:
					if !general_audio.playing:
						general_audio.play()
	if activated and light and fixed:
		if light_flicker:
			light_options.light_energy = 1
			if general_audio:
					if general_audio.playing:
						general_audio.stop()
		if light_missing:
			show()
		if light_extra:
			hide()
			if general_audio:
					if general_audio.playing:
						general_audio.stop()
	
	# Camera bug logic
	if !fixed:
		if activated and camera_bug and cam.current:
			emit_signal("bugged")
			#glitch_audio.play()
		elif camera_bug and !activated and cam.current:
			emit_signal("not_bugged")
			#glitch_audio.stop()
	if fixed and camera_bug and cam.current:
		emit_signal("not_bugged")
		#glitch_audio.stop()

func _on_intruder_reported() -> void:
	if cam:
		if cam.current:
			intruder_anim.play("Animations/REPORTED")
			if fixed:
				queue_free()
