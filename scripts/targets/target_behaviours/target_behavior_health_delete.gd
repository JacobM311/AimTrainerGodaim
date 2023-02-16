extends Node

class_name TargetBehaviorHealthDelete

@export var health: int= 5
@onready var target: Target = get_parent()
@onready var timer = $Timer2

func _ready(): 
	target.hit.connect(_hit)

func _hit(): 
	health -= 1
	print("hi")
	print(health)
	if health <= 0: 
		print("no health")
		target.queue_free()
