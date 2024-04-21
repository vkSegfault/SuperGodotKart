extends Node

var ADDRESS = "127.0.0.1" # = get_ip_text() #$Lobby/TextEdit.text #"127.0.0.1"
const PORT = 12077
const MAX_PLAYERS = 8

var temp_lineedit_ip = LineEdit.new()

var peer = ENetMultiplayerPeer.new()

func _ready():
	print("_ready")
	print("IP Address: " + str(IP.get_local_addresses().size()) )
	for ip in IP.get_local_addresses():
		print(ip)
		
	# temp
	temp_lineedit_ip.text = "127.0.0.1"
	temp_lineedit_ip.placeholder_text = "127.0.0.1"
	temp_lineedit_ip.expand_to_text_length = true
	temp_lineedit_ip.position.x = 600
	temp_lineedit_ip.position.y = 300
	self.add_child(temp_lineedit_ip)


func _process(delta):
	pass
	# is below polling even needed?
	#if multiplayer.has_multiplayer_peer():
		##print("polling")
		#multiplayer.poll()
		##print(multiplayer.get_peers())

func _on_host_button_pressed():
	print("_on_host_button_pressed")
	peer.create_server(PORT, MAX_PLAYERS)
	multiplayer.multiplayer_peer = peer
	
	# make signal connection, not run immediatelly, it will run when `peer_connected` signal is trigerred
	multiplayer.peer_connected.connect(_on_peer_connected)  # _on_peer_connected is going to spawn car for every other peer (not server)
	spawn_car()  # spawn car locally (on server)
	
	$Lobby.visible = false
	temp_lineedit_ip.visible = false
	spawn_label("SERVER")

func _on_join_button_pressed():
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
