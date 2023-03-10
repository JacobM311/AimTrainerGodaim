extends PathFollow3D

@export_range(0, 1) var speed = 0.2

var r = 1
# Called when the node enters the scene tree for the first time.
func _ready():
	pass # Replace with function body.


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta):

	
	if progress_ratio >= 1: 
		r = -1 
	if progress_ratio <= 0: 
		r = 1 
		
func _physics_process(delta):
	progress_ratio += delta * speed * r

func _on_timer_timeout():
	r = randi_range(1, 2)
	if r == 1:
		r = -1
	if r == 2:
		r = 1
