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
var purin_distribution_by_level:Array[int] = [0,0,0,0,0,0,0,0,0,0]
var proportions:Array[float] = []
var highest_proportion_by_level:int = 0
var move_history:Array[Dictionary] = []
var temp_debug_text:String = ""


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
	
	self.temp_debug_text = ""
	if game.training:
		if game.neural_training:
			# we're training the real neural network id
			# only use the best old AI
			self.configurations = game.get_configurations_with_mutation("configurations", game.ai_mutation_rate, {"0":{}}, false, 0)
		else:
			if game.rank < 10:
				self.configurations = game.get_configurations_with_mutation("configurations", game.ai_mutation_rate, {"0":{}}, false, game.rank)
			else:
				self.configurations = game.get_configurations_with_mutation("configurations", game.ai_mutation_rate, {"0":{}}, false, game.rank%10)
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
	var parent_1_score:float = new_config.get("score", 100)
	var parent_2_score:float = new_config.get("score", 100)
	var mvp1:int = config1["mvp_weight"]
	var mvp2:int = config1["mvp_weight"]
	# if their score is less than the target score
	# decrease their highest weight to see if it was the problem
	if parent_1_score < game.target_score:
		config1["weights"][mvp1] = max(config1["weights"][mvp1]*0.5,0)
		
	if parent_2_score < game.target_score:
		config2["weights"][mvp2] = max(config1["weights"][mvp1]*0.5,0)
	
	for i in range(0, len(config1["weights"])):
		var total_score:float = parent_1_score + parent_2_score
		# % chance for any weight to be taken from the other parent instead
		# better parent gets a higher chance of keeping theirs in the child
		if randf() < parent_2_score/total_score:
			new_config["weights"][i] = config2["weights"][i]
		
			# did not meet the target score, punish its highest weight 
	return new_config


func rate_purin(purin:Purin, purin_level:int = held_purin_level, _next_purin_level:int = next_purin_to_drop_level):
	# 0 level matches
	# 1 reachable
	# 2 how many purin of the same level are close by
	# 3 in danger
	# 4 possible combines touching it
	# 5 target the purin with the highest proportion on the play area
	var score_0:float = 0
	var score_1:float = 0
	var score_2:float = 0
	var score_3:float = 0
	var score_4:float = 0
	var score_5:float = 0
	var score_moving:float = 1
	var purin_level_diff:int = purin_level - purin.get_meta("level")
	var total_score:float = 0
	var reachable:bool = purin.can_reach_purin(purin, game, space_state, purin_level)
	if purin_level_diff == 0:
		score_0 = weights[0] * Global.highest_possible_purin_level
	if reachable:
		score_1 = weights[1] * (Global.highest_possible_purin_level - abs(purin_level_diff))
		
	var search_distance = purin.get_meta("radius", 100) * 2
	var num_nearby_same_level:float = purin.number_matching_nearby(game.purin_node.get_children(), search_distance)
	score_2 = weights[2] * num_nearby_same_level
	
	if purin.game_over_countdown.visible:
		score_3 = weights[3]
	
	var num_possible_combines:float = purin.number_possible_combines()
	score_4 = weights[4] * num_possible_combines
	
	if purin.get_meta("level") == highest_proportion_by_level:
		score_5 = weights[5] * proportions[purin.get_meta("level")]
	
	if purin_is_moving(purin):
		score_moving = 0.5
		
	total_score = snapped((score_0 + score_1 + score_2 + score_3 + score_4 + score_5)* score_moving, 0.2)
	var result:Dictionary = {
		"score_moving": score_moving,
		"purin_level_diff": purin_level_diff,
		"purin_targets_level": purin.get_meta("level"),
		"purin_level": purin_level,
		"score_0": score_0,
		"score_1": score_1,
		"score_2": score_2,
		"score_3": score_3,
		"score_4": score_4,
		"score_5": score_5,
		"total_score": total_score
		
	}
	if debug:
		purin.debug_text.visible = true
		purin.debug_text.text = "[center]%s[/center]"%[total_score]
		#if total_score <= 0:
		#	temp_debug_text = str(result)
	return result
	
func priority_purin(purin1:Purin, purin2:Purin):
	if not is_instance_valid(purin1) or not is_instance_of(purin1, Purin):
		return false
	if not is_instance_valid(purin2) or not is_instance_of(purin2, Purin):
		return true
	
	var value1:float = rate_purin(purin1)["total_score"]
	var value2:float = rate_purin(purin2)["total_score"]
	if value1 > value2:
		return true
	return false
	
func rank_best(dict1:Dictionary, dict2:Dictionary):
	var level_diff1:float = dict1["level"] - held_purin_level
	var level_diff2:float = dict2["level"] - held_purin_level
	if level_diff1 == 0 and level_diff2 != 0:
		return true
	if level_diff2 == 0 and level_diff1 != 0:
		return false
	
	if dict1["score"] > dict2["score"]:
		return true
	return false
	
func get_best_for_level(level:int, max_length:int = 2):
	held_purin_level = level
	var field_purin:Array = game.purin_node.get_children()
	var results:Array[Dictionary] = []
	if not field_purin.is_empty():
		self.space_state = get_world_2d().direct_space_state
		field_purin.sort_custom(priority_purin)
		for i in range(0, min(max_length, len(field_purin))):
			var offset_bias:float = field_purin[i].get_meta("offset_to_reach", 0)
			var size:float = Global.purin_sizes[field_purin[0].get_meta("level", 0)]
			if offset_bias == 0 and held_purin_level != field_purin[0].get_meta("level", 0):
				if field_purin[0].position.x < (game.right_edge.position.x - game.left_edge.position.x)*0.5:
					offset_bias = -size*0.5
				else:
					offset_bias = size*0.5
			var scored_purin:Dictionary = rate_purin(field_purin[i], level)
			var score = scored_purin["total_score"]
			results.append({
				"x": field_purin[i].position.x + offset_bias,
				"score": score,
				"level": level,
				"details": scored_purin,
				"purin": field_purin[i]
			})
	return results
	
func calc_level_distribution():
	var field_purin:Array = game.purin_node.get_children()
	purin_distribution_by_level = [0, 0, 0, 0, 0, 0, 0, 0, 0, 0]
	for purin in field_purin:
		purin_distribution_by_level[purin.get_meta("level")] += 1
	
	var total_purin:int = 0
	for i in purin_distribution_by_level:
		total_purin += i
	proportions = []
	highest_proportion_by_level = 0
	if total_purin > 0:
		var level:int = 0
		for count in purin_distribution_by_level:
			var proportion = count / float(total_purin)
			proportions.append(proportion)
			if proportion > highest_proportion_by_level:
				highest_proportion_by_level = level
			level += 1
var selected_purin:Purin = null
var best_score:float = 0
func update_noir_position():
	calc_level_distribution()
	var best_for_level:Array[Dictionary] = get_best_for_level(game.purin_bag.get_current_purin()["level"], 2)
	var new_x_pos:float = 0
	
	if not best_for_level.is_empty():
		#print("current: %s"%[best_for_level])
		var next_level:int = game.purin_bag.bag[1]["level"]
		if next_level != game.purin_bag.get_current_purin()["level"]:
			var best_for_next_level:Array[Dictionary] = get_best_for_level(game.purin_bag.bag[1]["level"], 1)
			var current_best_score:float = best_for_level[0]["score"]
			var best_next_score:float = best_for_next_level[0]["score"]
			#print("next: %s"%[best_for_next_level])
			#print(abs(best_for_next_level[0]["x"]-best_for_level[0]["x"]))
			if abs(best_for_next_level[0]["x"]-best_for_level[0]["x"]) <= Global.purin_sizes[best_for_level[0]["level"]]*2:
				if  current_best_score >= best_next_score:
					# we want the same spot but my spot is better so I get it
					new_x_pos = game.valid_x_pos(best_for_level[0]["x"])
					best_score = current_best_score
					selected_purin = best_for_level[0]["purin"]
				elif len(best_for_level) > 1:
					# we want the same spot but my score is worse
					# use my 2nd best spot instead
					new_x_pos = game.valid_x_pos(best_for_level[1]["x"])
					best_score = best_for_level[1]["score"]
					selected_purin = best_for_level[1]["purin"]
				else:
					# we want the same spot but my score is worse
					# but I have no alternative so use default position
					new_x_pos = game.valid_x_pos(0)
					selected_purin = null
			else:
				# we don't want the same spot, no conflict, so use my best option
				new_x_pos = game.valid_x_pos(best_for_level[0]["x"])
				best_score = current_best_score
				selected_purin = best_for_level[0]["purin"]
		else:
			# there's no next purin so I get my best choice
			var current_best_score:float = best_for_level[0]["score"]
			new_x_pos = game.valid_x_pos(best_for_level[0]["x"])
			best_score = current_best_score
			selected_purin = best_for_level[0]["purin"]
	else:
		new_x_pos = game.valid_x_pos(0)
		selected_purin = null
	
	# if neuro training use its prediction instead
	if game.neural_training and game.source_network and predictions:
		actuals = [int(new_x_pos)/800.0]
		game.noir.position.x = game.valid_x_pos(int(predictions[0]*800))
	else:
		game.noir.position.x = game.valid_x_pos(new_x_pos)
	
	if debug and game.training:
		self.game.debug_label.text = "Attempt #%s %s %s %s %s %s %s"%[game.attempts+1, parents, game.ai_mutation_rate, configurations.get("weights", []), best_score, temp_debug_text, purin_distribution_by_level]
	held_purin_level = game.purin_bag.get_current_purin()["level"]

func process_ai(_delta):
	# do old AI
	execute_action(0)
	
	
	
func purin_is_moving(purin:Purin):
	if (abs(purin.linear_velocity.x) >= 5 or abs(purin.linear_velocity.y) >= 5):
		return true
	return false
var input:Array
var predictions:Array
var prev_score:float
var actuals: Array[float]
func execute_action(_action:int):
	if game.gameover_screen.visible:
		return
	var cool_down_sec = game.drop_purin_cooldown_sec
	var emergency:bool = false
	var all_purin_stopped:bool = true
	for purin in game.purin_node.get_children():
		if is_instance_valid(purin) and is_instance_of(purin, Purin):
			if purin.game_over_countdown.visible:
				cool_down_sec = 0.25
				emergency = true
			if purin_is_moving(purin):
				all_purin_stopped = false
			purin.remove_meta("offset_to_reach")
	var time_elapsed:bool = game.time_since_last_dropped_purin_sec >= cool_down_sec
	var double_time_elapsed:bool = game.time_since_last_dropped_purin_sec >= 2*cool_down_sec
	
		
	if (game.can_drop_early and game.time_since_last_dropped_purin_sec >= cool_down_sec*0.5 and all_purin_stopped) or (emergency and time_elapsed) or (time_elapsed and all_purin_stopped) or double_time_elapsed:
		# see where the old AI moved us to, treat that as good for now
		
		if game.neural_training and game.source_network:
			# get state of the game before anything is done
			input = game.get_state()
			# tell it to predict to see what it's already learned if anything
			predictions = game.source_network.predict(input)
			
			if game.prediction_icon:
				game.prediction_icon.position.x = predictions[0]*800
			
			#game.noir.position.x = predictions[0]
			# show us how close it was
			temp_debug_text = "[Prediction] %s vs %s. MSE: %s"%[predictions, actuals, game.mean_squared_error(actuals, predictions)]
			
			
		# reposition the player based on old AI logic
		update_noir_position()
		
		if input and game.neural_training and game.source_network:
			# train the neural network that the original input results in moving to here
			game.source_network.train(input, actuals)
			#temp_debug_text = "[Prediction] %s vs %s. MSE: %s"%[predictions, actuals, game.mean_squared_error(actuals, predictions)]
			
			
		game.drop_purin()
		held_purin_level = game.purin_bag.get_current_purin()["level"]
		last_purin_level_dropped = held_purin_level
		last_x_pos = game.noir.position.x
		
		move_history.append(
			{
				"x": game.noir.position.x,
				"level": held_purin_level,
				"score": game.score
			}
		)
