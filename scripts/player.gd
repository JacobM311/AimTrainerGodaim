extends CharacterBody3D


enum e_movement_state { 
	none, 
	crouch, 
	ground_walk,
	ground_crouch,  
	air, 
	climb, 
	swim
}


@export var camera: Camera3D
@export var player_area: Area3D
@export var enable_movement = false
@export_range(0.01, 5.0) var mouse_sensitiviy = 0.5

var ui_locked = false

const CROUCH_HEIGHT = 0.7
const STANDING_HEIGHT = 1.8
const JUMP_VELOCITY = 10
const SPRINT_MULTIPLIER = 2.0
# Get the gravity from the project settings to be synced with RigidBody nodes.


var current_movement_state: e_movement_state
var speed = 1
var gravity = ProjectSettings.get_setting("physics/3d/default_gravity")
var friction = 0.2
var swimming = false
var climbing = false 

@onready var interaction_ray: RayCast3D = RayCast3D.new()
@onready var ground_ray: RayCast3D = RayCast3D.new()
@onready var head_ray: RayCast3D = RayCast3D.new()

@onready var start_friction = friction 
@onready var start_speed = speed

var coyote_time = 0.2
@onready var start_coyote_time = coyote_time

signal action

func _ready(): 
	Global.player = self
	
	_init_rays()

func _process(delta):
	
	var offset = -STANDING_HEIGHT - (ground_ray.get_collision_point().y - camera.global_position.y) + 0.1
	head_ray.target_position = Vector3(0, -offset , 0)
	head_ray.global_transform.basis = Basis.IDENTITY

	if get_slide_collision_count() > 0: 
		velocity += get_last_slide_collision().get_normal() * 2
	
	if Input.is_action_just_pressed("ads"): 
		$Camera3D/glock/GlockAnim.play("ads")
	elif Input.is_action_just_released("ads"):
		$Camera3D/glock/GlockAnim.play_backwards("ads")
		
	if Input.is_action_just_pressed("action") and !ui_locked: 
		# add an offset with the collision normal
		# helps when placing things such as lights 
		if interaction_ray.is_colliding():
			if interaction_ray.get_collider().has_method("hit"):
				interaction_ray.get_collider().hit()
			if interaction_ray.get_collider().get_parent().has_method("hit"):
				interaction_ray.get_collider().get_parent().hit()
		
		var place_offset = (interaction_ray.get_collision_normal() * delta)
		emit_signal("action", interaction_ray.get_collision_point() + place_offset )
	
	var max_angle = deg_to_rad(88)
	camera.rotation.x = clamp(camera.rotation.x, -max_angle, max_angle)

func _physics_process(delta):
	# Get the input direction and handle the movement/deceleration.
	# As good practice, you should replace UI actions with custom gameplay actions.
	var input_vec = Input.get_vector("left", "right", "up", "down")
	var direction = (transform.basis * Vector3(input_vec.x, 0, input_vec.y)).normalized()
	
	
	if !enable_movement: 
		return
	
	_crouch_move()
	
	match get_movement_state(): 
		e_movement_state["air"]: 
		
			apply_gravity()
			coyote_time -= delta
				
		e_movement_state["ground_walk"]: 
			_ground_move(direction)
			_ground_stick()
		e_movement_state["climb"]: 
			_wall_move(input_vec)
		e_movement_state["swim"]: 
			pass
	
	
	if Input.is_action_just_pressed("ui_accept") and is_grounded() or Input.is_action_just_pressed("ui_accept") and coyote_time > 0:
		velocity.y = 15
		velocity *= Vector3(1.5, 1, 1.5)
		coyote_time = 0
	
	move_and_slide()

func _ground_move(direction): 
	var delta = get_physics_process_delta_time()
	
	coyote_time = start_coyote_time
	
	if direction:
		velocity.x += direction.x * speed
		velocity.z += direction.z * speed
	
	Vector3.FORWARD.dot(Vector3.RIGHT)
	
	if rad_to_deg(get_ray_angle()) > 35: 
		direction = Vector3.ZERO
		apply_gravity()
	else: 
		apply_friction()
	
		
		if Input.is_action_pressed("sprint"): 
			speed = start_speed * SPRINT_MULTIPLIER
		else:
			speed = start_speed 

	velocity = velocity.slide(ground_ray.get_collision_normal())
	
func _wall_move(dir): 
	var floor_dot = camera.basis.z.dot(Vector3.DOWN)
	var wall_dot = -camera.global_transform.basis.z.dot(get_slide_collision(0).get_normal())
	var climb_direction = (transform.basis * Vector3(dir.x, get_axis() * floor_dot, dir.y)).normalized()
	
	velocity = climb_direction * speed * 2
	if get_jump_input() and wall_dot > 0: 
		velocity = (-camera.global_transform.basis.z * 10 ) + get_slide_collision(0).get_normal() * 2 + Vector3.UP * JUMP_VELOCITY
	else:
		velocity = velocity.slide(get_slide_collision(0).get_normal())

func _crouch_move(): 
	if Input.is_action_pressed("crouch") or is_crouch_blocked(): 
		
		ground_ray.target_position = ground_ray.target_position.lerp(
			Vector3(0, -CROUCH_HEIGHT, 0), 
			get_physics_process_delta_time() * 5
		)
		speed = start_speed * 0.5
	else: 
		ground_ray.target_position = ground_ray.target_position.lerp(
			Vector3(0, -STANDING_HEIGHT, 0), 
			get_physics_process_delta_time() * 5
		)
		friction = start_friction

func _ground_stick(): 

	global_position.y = ground_ray.get_collision_point().y + -ground_ray.target_position.y - 0.1

func is_grounded() -> bool: 
	return ground_ray.is_colliding()

func is_crouch_blocked(): 
	return head_ray.is_colliding()
 
func is_crouching() -> bool: 
	return is_grounded() and Input.is_action_pressed("crouch")

func get_movement_state() -> e_movement_state: 
	
	if is_grounded() and !can_climb(): 
		return e_movement_state["ground_walk"]
	elif !is_grounded() and !can_climb(): 
		return e_movement_state["air"]
	elif can_climb(): 
		return e_movement_state["climb"]
	elif can_swim(): 
		return e_movement_state["swim"]
	else: 
		return e_movement_state["none"]

func get_axis(): 
	return Input.get_axis("down", "up")

func get_ray_angle() -> float: 
	return ground_ray.get_collision_normal().angle_to(
		Vector3.UP
	)
	
func apply_friction(): 
	velocity += -1 * friction * velocity .length() * velocity.normalized()

func apply_gravity(): 
	var delta = get_physics_process_delta_time()
	velocity.y -= gravity * delta * 4

func _input(event):
	if event is InputEventMouseMotion: 
		if !ui_locked:
			rotate_object_local(Vector3.UP, -event.relative.x * (mouse_sensitiviy / 100))
			camera.rotate_object_local(Vector3.RIGHT, -event.relative.y * ( mouse_sensitiviy / 100))
			Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
		else: 
			Input.mouse_mode = Input.MOUSE_MODE_CONFINED
		
func _init_rays(): 
	add_child(ground_ray)
	camera.add_child(interaction_ray)
	camera.add_child(head_ray)
	
	interaction_ray.target_position = Vector3(0,0,-50)
	interaction_ray.collide_with_areas = true
	ground_ray.target_position = Vector3(0, -STANDING_HEIGHT, 0)

func can_climb() -> bool: 
	
	if get_slide_collision_count() > 0: 
		var col = get_slide_collision(0)
		var up_dot = get_slide_collision(0).get_normal().dot(Vector3.UP)
		print(up_dot)
		return col.get_collider().is_in_group("climbable") and up_dot <= 0
	
	return false 

func get_jump_input(): 
	return Input.is_action_just_pressed("jump")

func can_swim() -> bool: 
	return false 
