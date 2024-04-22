extends Node

var ADDRESS = "127.0.0.1" # = get_ip_text() #$Lobby/TextEdit.text #"127.0.0.1"
const PORT = 12077
const MAX_PLAYERS = 8

var temp_lineedit_ip = LineEdit.new()

var peer = ENetMultiplayerPeer.new()

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


func _process(delta):
	#print( multiplayer.get_instance_id() )
	pass
	# is below polling even needed?
	#if multiplayer.has_multiplayer_peer():
		##print("polling")
		#multiplayer.poll()
		##print(multiplayer.get_peers())

func _on_host_button_pressed():
	if username.text == "":
		$NoUsernameWarning.visible = true
		return
	print("_on_host_button_pressed")
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
	if username.text == "":
		$NoUsernameWarning.visible = true
		return
	print("_on_join_button_pressed")
	#ADDRESS = $Lobby/TextEdit.text
	print("LineEdit text: " + temp_lineedit_ip.get_text())
	temp_lineedit_ip.visible = false
	ADDRESS = temp_lineedit_ip.text
	peer.create_client(ADDRESS, PORT)
	#get_tree().set_multiplayer(multiplayer, self.get_path())
	multiplayer.multiplayer_peer = peer
	
	$Lobby.visible = false
	spawn_label("CLIENT")
	
	$Chat.visible = true

# to make spawning on clients side work we need both MultiSpawner Node with car scene and below signal spawning exact sam car scene
func _on_peer_connected(peer_id):
	# this wont be executed by server - only peers
	# we need to spawn car on server manually
	spawn_car(peer_id)
	print("Peer Connected, peer_id: {0}".format([peer_id]))
	
	# needs await a little because rpc is not executed - ??
	await get_tree().create_timer(1).timeout
	rpc("rpc_func")   # execute this remotely (from point of view of server because only on_host_join this signal is connected)
	print( "Multiplayer get peers: " + str(multiplayer.get_peers()) )

func _on_peer_disconnected(peer_id):
	print("Disconeccted peer: " + str(peer_id))
	despawn_car(peer_id)

func get_ip_text():
	#if $Lobby/LineEdit.get_text() != "":
	#	return "127.0.0.1"
	#else:
	return str($Lobby/TextEdit.text)


func spawn_car(id = 1):
	print("Spawned Car ID: {0}".format([id]))
	var car = load("res://vehicles/car_base.tscn")
	var autko = car.instantiate()
	autko.name = str(id)   # set particular instance name
	#autko.translate(Vector3(10, 0, 2))
	self.add_child(autko)


func despawn_car(id = 1):
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
func rpc_send_message(username, msg):
	msg_window.text += str(str(username) + ": " + msg + "\n")
	msg_window.scroll_vertical = 9999   # hack so that messages are auto scrolled to see only latest ones


func _on_close_button_pressed():
	$NoUsernameWarning.visible = false

