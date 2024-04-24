extends Node

var ADDRESS = "127.0.0.1" # = get_ip_text() #$Lobby/TextEdit.text #"127.0.0.1"
const PORT = 12077
const MAX_PLAYERS = 8

var temp_lineedit_ip = LineEdit.new()
@export var password: String

@onready var msg = $Chat/Message
@onready var msg_window = $Chat/MessageWindow
@onready var username = $Lobby/Username

func _ready():
	$Chat.visible = false
	
	print("_ready")
	print("IP Address: " + str(IP.get_local_addresses().size()) )
	for ip in IP.get_local_addresses():
		print(ip)
		
	# temp
	temp_lineedit_ip.text = "127.0.0.1"
	temp_lineedit_ip.placeholder_text = "127.0.0.1"
	temp_lineedit_ip.expand_to_text_length = true
	temp_lineedit_ip.position.x = 200
	temp_lineedit_ip.position.y = 260
	self.add_child(temp_lineedit_ip)

@warning_ignore("unused_parameter")
func _process(delta):
	#print( multiplayer.get_instance_id() )
	pass
	# is below polling even needed?
	#if multiplayer.has_multiplayer_peer():
		##print("polling")
		#multiplayer.poll()
		##print(multiplayer.get_peers())

func _on_host_button_pressed():
	print("_on_host_button_pressed")
	if username.text == "":
		$NoUsernameWarning.visible = true
		return
	print("Setting password to: " + $Lobby/Password.text)
	password = $Lobby/Password.text
	print( "Password is: " + password )
	print( "Peers before setting rpc password: " + str(multiplayer.get_peers()) )
	
	var peer = ENetMultiplayerPeer.new()
	peer.create_server(PORT, MAX_PLAYERS)
	multiplayer.multiplayer_peer = peer
	
	# make signal connection, not run immediatelly, it will run when `peer_connected` signal is trigerred
	multiplayer.peer_connected.connect(_on_peer_connected)  # _on_peer_connected is going to spawn car for every other peer (not server)
	multiplayer.peer_disconnected.connect(_on_peer_disconnected)
	spawn_car()  # spawn car locally (on server)
	
	$Lobby.visible = false
	temp_lineedit_ip.visible = false
	spawn_label("SERVER")
	
	$Chat.visible = true

func _on_join_button_pressed():
	print("_on_join_button_pressed")
	
	if username.text == "":
		$NoUsernameWarning.visible = true
		return
	
	# first connect peer to server so we can later ask server for password
	var peer = ENetMultiplayerPeer.new()
	peer.create_client(ADDRESS, PORT)
	multiplayer.multiplayer_peer = peer
	# peer connecion starts here but will finish at unknown point in future - it's ASYNC !
	
	# wait until peer is connected to sever (so Synchronizer node will sync password values across all peers)
	while peer.get_connection_status() != peer.CONNECTION_CONNECTED:
		print( "-- PEER NOT CONNECTED --" )
		await get_tree().create_timer(0.1).timeout
	
	if $Lobby/Password.text != password:
		print( "Provided password: " + $Lobby/Password.text + " Actual password: " + password )
		$NoPasswordWarning.visible = true
		#multiplayer.multiplayer_peer = null  # remove peer
		return
	# not all nodes inside car scene are initialized in time (and server tries to call spawner node when there is still none)
	print( "-- PASSWORD CORRECT --" )
	
	#spawn_car().rpc( multiplayer.get_unique_id() )
	rpc_id( 1, "spawn_car", multiplayer.get_unique_id() )  # run exactly on peer no. 1 which is server
	print( "Multiplayer get peers: " + str(multiplayer.get_peers()) )
	
	#ADDRESS = $Lobby/TextEdit.text
	print("LineEdit text: " + temp_lineedit_ip.get_text())
	temp_lineedit_ip.visible = false
	ADDRESS = temp_lineedit_ip.text
	
	$Lobby.visible = false
	spawn_label("CLIENT")
	
	$Chat.visible = true

# to make spawning on clients side work we need both MultiSpawner Node with car scene and below signal spawning exact sam car scene
func _on_peer_connected(peer_id):
	# while Engine passes here peer_id of every new peer, this function (actually every function connected to `peer_connected` signal) is fired only on server side
	# and it's proper way because we should spawn objects only on server and then and only then MultiplayerSpawner should replicate them
	print("_on_peer_connected")
	# somehow spawning remote nodes is safe when done inside _on_peer_connected but everywhere else it fails cause of not loaded nodes
	# like it ensures that all nodes of car scene are loaded before server attempts to replicate it via MultiplayerSpawner node
	#spawn_car(peer_id)
	print("Peer Connected, peer_id: {0}".format([peer_id]))
	print("Function executed on: " + str(multiplayer.get_unique_id()) )
	
	# needs await a little because rpc is not executed - ??
	await get_tree().create_timer(1).timeout
	rpc("rpc_func")   # execute this remotely (from point of view of server because only on_host_join this signal is connected)
	print( "Multiplayer get peers: " + str(multiplayer.get_peers()) )

func _on_peer_disconnected(peer_id):
	print("_on_peer_disconnected")
	print("Disconeccted peer: " + str(peer_id))
	despawn_car(peer_id)

func get_ip_text():
	#if $Lobby/LineEdit.get_text() != "":
	#	return "127.0.0.1"
	#else:
	return str($Lobby/TextEdit.text)

@rpc("any_peer")
func spawn_car(id = 1):
	if !multiplayer.is_server():
		return
	print(" --- Spawned Car ID: {0}".format([id]))
	var car = load("res://vehicles/car_base.tscn")
	var autko = car.instantiate()
	autko.name = str(id)   # set particular instance name
	#autko.translate(Vector3(10, 0, 2))
	self.add_child(autko)

func despawn_car(id = 1):
	print("Despawning car")
	if not self.has_node(str(id)):
		return
	self.get_node(str(id)).queue_free()

@rpc("any_peer", "call_local")
func rpc_func():
	print("Should be called remotely (any_peer) and on servcer (call_local)")
	var ui = LineEdit.new()
	ui.position.x = 200
	self.add_child(ui)

func spawn_label(text: String):
	var host_label = Label.new()
	host_label.text = text
	self.add_child(host_label)

func _on_send_button_pressed():
	# if there is nothing typed just skip sending message
	if msg.text == "":
		return
	rpc( "rpc_send_message", str( username.text + "(" + str(multiplayer.get_unique_id()) + ")"), msg.text )
	msg.text = ""

@rpc("any_peer", "call_local")
func rpc_send_message(username_param, msg_param):
	msg_window.text += str(str(username_param) + ": " + msg_param + "\n")
	msg_window.scroll_vertical = 9999   # hack so that messages are auto scrolled to see only latest ones

func _on_close_button_pressed():
	$NoUsernameWarning.visible = false

func _on_close_button_pressed_password():
	$NoPasswordWarning.visible = false
