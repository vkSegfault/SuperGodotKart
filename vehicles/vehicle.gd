extends Node3D

const STEER_SPEED = 1.5
const STEER_LIMIT = 0.4

static var NUM_OF_RUN = 0

@export var engine_force_value := 40.0

var _steer_target := 0.0

@onready var synchronizer = $MultiplayerSynchronizer
#@onready var camera = $CameraBase/Camera3D
@onready var camera = $Body/Camera3D

# remember that everytime we join(add) new peer it's executed per new instances and on all already running instances (because it needs to repliacte to other instances)
# when we have 2 running peers and joining as 3rd one: we will execute it 3 times (1 as authority and 2 as non-authority)
func _enter_tree():
	# synchronized set autothority should be done here but when it's done synchronizer is null (probably Node is not initialized yet)
	# authroity should be root of scene
	set_multiplayer_authority(str(name).to_int())
	print("[vehicle.gd] Entered tree - instance " + str(name) + " set to authority")

func _ready():
	# FUCKING IMPORTANT
	# makes every instance of this CAR an authority to itself - so it can ride on it's own
	# without it only server would be able to control all spawned cars
	# go up, because we set name of instance which here is `CarBase` root node, if we just call name it will be from current node that this script is atatched to
	print("Name of Car instance: " + str(name))  
	#synchronizer.set_multiplayer_authority(str(get_node("..").name).to_int())   # here using synchronizer node but we can use any node we want
	#get_node("..").set_multiplayer_authority(str(get_node("..").name).to_int())   # here setting authority for CarBase root node
	
	#var ms = MultiplayerSpawner.new()
	
	print("###################")
	print("Is multiplayer authority: " + str(is_multiplayer_authority()))
	print("Remote sender id: " + str(multiplayer.get_remote_sender_id()))
	# Set current camera only to this instance itsefl
	camera.current = is_multiplayer_authority()
	NUM_OF_RUN += 1
	print("_ready of vehicle executed " + str(NUM_OF_RUN) + " times" )
	print("unique id: " + str(multiplayer.get_unique_id())  )
	print("[vehicle.gd] " + str(name) + " is multiplayer authority on " + str(multiplayer.get_unique_id()) + ": " + str(is_multiplayer_authority()) )
	print("[vehicle.gd] " + "Camera " + str(name) + " is current on " + str(multiplayer.get_unique_id()) + ": " + str(camera.current) )
	print("###################")

func _physics_process(delta: float):
	#if synchronizer.is_multiplayer_authority():
	if is_multiplayer_authority():   # we can check if this node (or any parent node becausde inheritance) is authority
		var car_body: VehicleBody3D = $Body
		var fwd_mps := (car_body.linear_velocity * car_body.transform.basis).x

		_steer_target = Input.get_axis(&"turn_right", &"turn_left")
		_steer_target *= STEER_LIMIT

		if Input.is_action_pressed(&"accelerate"):
			# Increase engine force at low speeds to make the initial acceleration faster.
			var speed := car_body.linear_velocity.length()
			if speed < 5.0 and not is_zero_approx(speed):
				car_body.engine_force = clampf(engine_force_value * 5.0 / speed, 0.0, 100.0)
			else:
				car_body.engine_force = engine_force_value
		else:
			car_body.engine_force = 0.0

		if Input.is_action_pressed(&"reverse"):
			# Increase engine force at low speeds to make the initial acceleration faster.
			if fwd_mps >= -1.0:
				var speed := car_body.linear_velocity.length()
				if speed < 5.0 and not is_zero_approx(speed):
					car_body.engine_force = -clampf(engine_force_value * 5.0 / speed, 0.0, 100.0)
				else:
					car_body.engine_force = -engine_force_value
			else:
				car_body.brake = 1.0
		else:
			car_body.brake = 0.0

		car_body.steering = move_toward(car_body.steering, _steer_target, STEER_SPEED * delta)
	else:
		#print("It's not multiplayer authority!!!")
		pass


func _process(delta):
	if multiplayer.get_peers().size() > 0:
		print( str(multiplayer.get_unique_id()) + " has these peers connected: " + str(multiplayer.get_peers()) )


func _on_button_pressed():
	print( "Is camera current: " + str(camera.current) )
	camera.make_current()
	print( "Is camera current: " + str(camera.current) )
	#camera.rotate_x(30)


func _on_camera_3d_tree_exited():
	print( "Camera3D node has been deleted" )


func _on_camera_3d_tree_entered():
	print( "Camera3D node has entered tree" )
