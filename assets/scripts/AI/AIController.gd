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
var left_corner:Vector2
var right_corner:Vector2
var mid_update:bool = false
var space_state
func init(player_controller:PlayerController):
	self.game = player_controller
	self.held_purin_level = 0
	self.next_purin_to_drop_level = 0
	self.held_is_evil = false
	self.next_purin_is_evil = false
	self.debug = player_controller.debug
	self.left_corner = Vector2(player_controller.left_edge.position.x, player_controller.bottom_edge.position.y)
	self.right_corner = Vector2(player_controller.right_edge.position.x, player_controller.bottom_edge.position.y)
	self.mid_update = false
	self.space_state = get_world_2d().direct_space_state
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

func can_reach_purin(purin:Purin):
	
	var start_pos:Vector2 = to_global(Vector2(purin.position.x, 0))
	var radius:float = purin.get_meta("radius", 10)
	# if left, or right can be reached them we're good
	for x_offset in range(-radius, radius, radius):
		var query = PhysicsRayQueryParameters2D.create(
			start_pos + Vector2(x_offset, 0), start_pos + Vector2(0, 900)
		)
		query.exclude = [self]
		query.collision_mask = 1
		var result = space_state.intersect_ray(query)
		# if it collides successfully with a Purin object that matches what we're looking for
		if result and is_instance_valid(result.collider) and is_instance_valid(result.collider) and is_instance_of(result.collider, Purin):
			if result.collider.get_rid() == purin.get_rid():
				purin.set_meta("offset_to_reach", x_offset)
				return true
	
	return false
	
func rate_purin(purin:Purin):
	# TODO compare to next purin in the bag and if it's better than block dropping here
	
	var purin_level_diff:int = held_purin_level - purin.get_meta("level")
	var total_score:float = 0
	if purin_level_diff == 0 and can_reach_purin(purin):
		total_score += weights[0] * 5
	var distance:float = -Vector2(pow(purin.get_meta("level"),2), left_corner.y).distance_to(purin.position)
	total_score += weights[1] * (distance/(right_corner.x - left_corner.x))
	var num_above_purin:float = weights[3] * purin.number_above_purin()
	if num_above_purin == 0:
		total_score += weights[2]
	if purin.game_over_countdown.visible:
		total_score += weights[3]
	var num_possible_combines:float = purin.number_possible_combines()
	total_score += weights[4] * num_possible_combines
	
	if purin_is_moving(purin):
		total_score *= 0.5
	total_score = snapped(total_score, 0.2)
	if debug:
		purin.debug_text.visible = true
		purin.debug_text.text = "[center]%s[/center]"%[total_score]
	return total_score
	
func priority_purin(purin1:Purin, purin2:Purin):
	if not is_instance_valid(purin1) or not is_instance_of(purin1, Purin):
		return false
	if not is_instance_valid(purin2) or not is_instance_of(purin2, Purin):
		return true
	
	var value1:float = rate_purin(purin1)
	var value2:float = rate_purin(purin2)
	if value1 > value2:
		return true
	return false

func update_noir_position():
	held_purin_level = game.purin_bag.get_current_purin()["level"]
	var field_purin:Array = game.purin_node.get_children()
	var best_score:float = 0
	if not field_purin.is_empty():
		field_purin.sort_custom(priority_purin)
		var offset_bias:float = field_purin[0].get_meta("offset_to_reach", 0)
		if offset_bias == 0:
			if field_purin[0].position.x < (game.right_edge.position.x - game.left_edge.position.x)*0.5:
				offset_bias = -field_purin[0].get_meta("radius", 0)*0.5
			else:
				offset_bias = field_purin[0].get_meta("radius", 0)*0.5
		best_score = rate_purin(field_purin[0])
		game.noir.position.x = game.valid_x_pos(field_purin[0].position.x + offset_bias)
		field_purin[0].set_meta("offset_to_reach", 0)
	else:
		game.noir.position.x = game.valid_x_pos(0)
	
	if debug:
		self.game.debug_label.text = "Attempt #%s %s %s %s %s"%[game.attempts+1, parents, game.ai_mutation_rate, configurations.get("weights", []), best_score]
	
func purin_is_moving(purin:Purin):
	if (abs(purin.linear_velocity.x) >= 5 or abs(purin.linear_velocity.y) >= 5):
		return true
	return false
	
func process_ai(_delta):
	if game.gameover_screen.visible:
		return
	var cool_down_sec = game.drop_purin_cooldown_sec
	var emergency:bool = false
	
	var all_purin_stopped:bool = true
	#var current_purin_count:int = game.purin_node.get_child_count()
	
	for purin in game.purin_node.get_children():
		if is_instance_valid(purin) and is_instance_of(purin, Purin):
			if purin.game_over_countdown.visible:
				cool_down_sec = 0.25
				emergency = true
			if purin_is_moving(purin):
				all_purin_stopped = false
	
	var time_elapsed:bool = game.time_since_last_dropped_purin_sec >= cool_down_sec
	var double_time_elapsed:bool = game.time_since_last_dropped_purin_sec >= 2*cool_down_sec
	
	if (game.can_drop_early and game.time_since_last_dropped_purin_sec >= cool_down_sec*0.5 and all_purin_stopped) or (emergency and time_elapsed) or (time_elapsed and all_purin_stopped) or double_time_elapsed:
		
		# reposition the player
		update_noir_position()
		game.drop_purin()
		last_purin_level_dropped = held_purin_level
		game.can_drop_early = false
		last_x_pos = game.noir.position.x
		mid_update = true
	elif game.time_since_last_dropped_purin_sec >= cool_down_sec*0.5 and mid_update:
		update_noir_position()
		mid_update = false
