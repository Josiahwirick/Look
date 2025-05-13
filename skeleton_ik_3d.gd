@tool
extends SkeletonIK3D

# To make IK nodes work, need to have the target tip be one more further than actual tip,
# and to add a script to start the IK otherwise it don't do nothing.

# Called when the node enters the scene tree for the first time.
#func _ready() -> void:
	#start()

func track() -> void:
	start()
