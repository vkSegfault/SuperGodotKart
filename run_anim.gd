extends Node3D

@onready var anim_player = $AnimationPlayer

func _ready():
	anim_player.get_animation("run").loop_mode = Animation.LOOP_LINEAR


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta):
	anim_player.play("run")
