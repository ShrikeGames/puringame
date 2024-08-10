extends Node2D
class_name AIController

var game:PlayerController
var held_purin_level:int
var held_is_evil:bool
var next_purin_to_drop_level:int
var next_purin_is_evil:bool

var configurations:Dictionary
var debug:bool = false
var last_x_pos:float = 0
var last_purin_level_dropped:int = 0
var parent_1_name:String = ""
var parent_2_name:String = ""
var parents:String = ""
var weights:Array
func init(player_controller:PlayerController):
	self.game = player_controller
	self.held_purin_level = 0
	self.next_purin_to_drop_level = 0
	self.held_is_evil = false
	self.next_purin_is_evil = false
	self.debug = player_controller.debug
	if game.training:
		if game.rank < 10:
			self.configurations = game.get_configurations_with_mutation("configurations", game.ai_mutation_rate, {"0":{}}, false, game.rank)
		elif game.rank < 30:
			self.configurations = game.get_configurations_with_mutation("configurations", game.ai_mutation_rate, {"0":{}}, false, game.rank-10)
			var cross_breed_configuration = game.get_configurations_with_mutation("configurations", game.ai_mutation_rate, self.configurations, false, game.rank-9)
			self.configurations = cross_breed(self.configurations, cross_breed_configuration)
		else:
			self.configurations = game.get_configurations_with_mutation("configurations", game.ai_mutation_rate, {"0":{}}, true)
			var cross_breed_configuration = game.get_configurations_with_mutation("configurations", game.ai_mutation_rate, self.configurations, true)
			self.configurations = cross_breed(self.configurations, cross_breed_configuration)
		parents = "(%s+%s)"%[parent_1_name, parent_2_name]
	else:
		self.configurations = game.get_configurations_with_mutation("configurations", game.ai_mutation_rate, {"0":{}}, true)
	
	if debug:
		self.game.debug_label.text = "%s %s"%[parents, game.ai_mutation_rate]
	weights = self.configurations.get("weights", [0,0,0,0,0,0])
	

func cross_breed(config1:Dictionary, config2:Dictionary):
	if not config1:
		return config2
	if not config2:
		return config1
	var username_key:String = "username"
	if Global.language == "jp":
		username_key = "username_jp"
	parent_1_name = config1.get(username_key, "")
	parent_2_name = config2.get(username_key, "")
	
	var new_config = config1
	for i in range(0, len(config1["weights"])):
		# 50% chance for any weight to be taken from the other parent instead
		if randf() < 0.5:
			new_config["weights"][i] = config2["weights"][i]
			
	return new_config

func rate_purin(purin:Purin):
	var score_x:float = weights[0] * purin.position.x
	var score_y:float = weights[1] * purin.position.y
	var score_combines:float = weights[2] * purin.number_possible_combines()
	
	return score_x + score_y + score_combines
	
func priority_purin(purin1:Purin, purin2:Purin):
	var value1:float = rate_purin(purin1)
	var value2:float = rate_purin(purin2)
	if value1 > value2:
		return true
	return false

func update_noir_position():
	held_purin_level = game.purin_bag.get_current_purin()["level"]
	var field_purin:Array = game.purin_node.get_children()
	if not field_purin.is_empty():
		field_purin.sort_custom(priority_purin)
		var override_pos:bool = false
		for purin in field_purin:
			if purin.get_meta("level", 0) == held_purin_level:
				game.noir.position.x = game.valid_x_pos(purin.position.x)
				override_pos = true
				break
		if not override_pos:
			game.noir.position.x = game.valid_x_pos(field_purin[0].position.x - field_purin[0].get_meta("radius", 0))
	else:
		game.noir.position.x = game.valid_x_pos(randf_range(game.left_edge.position.x, game.right_edge.position.x))
	
	if debug:
		self.game.debug_label.text = "Attempt #%s %s %s %s"%[game.attempts+1, parents, game.ai_mutation_rate, configurations.get("weights", [])]
	
	
func process_ai(_delta):
	if game.gameover_screen.visible:
		return
	var cool_down_sec = game.drop_purin_cooldown_sec
	var emergency:bool = false
	
	var all_purin_stopped:bool = true
	#var current_purin_count:int = game.purin_node.get_child_count()
	
	for purin in game.purin_node.get_children():
		if purin.game_over_countdown.visible:
			cool_down_sec = 0.25
			emergency = true
		if (abs(purin.linear_velocity.x) >= 5 or abs(purin.linear_velocity.y) >= 5):# and current_purin_count > 5:
			all_purin_stopped = false
	
	var time_elapsed:bool = game.time_since_last_dropped_purin_sec >= cool_down_sec
	var double_time_elapsed:bool = game.time_since_last_dropped_purin_sec >= 2*cool_down_sec
	
	if (game.can_drop_early and game.time_since_last_dropped_purin_sec >= cool_down_sec*0.5 and all_purin_stopped) or (emergency and time_elapsed) or (time_elapsed and all_purin_stopped) or double_time_elapsed:
		# reposition the player
		update_noir_position()
		game.drop_purin()
		last_purin_level_dropped = held_purin_level
		game.can_drop_early = false
