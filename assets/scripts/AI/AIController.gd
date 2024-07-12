extends Node
class_name AIController

var game:PlayerController
func init(player_controller:PlayerController):
	self.game = player_controller

func process_ai(_delta):
	pass
