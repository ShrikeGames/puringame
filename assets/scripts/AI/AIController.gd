extends Node2D
class_name AIController

var game:PlayerController
var held_purin_level:int
var next_purin_to_drop_level:int

var configurations:Dictionary
var debug:bool = false
var space_state
var purin_distribution_by_level:Array[int] = [0,0,0,0,0,0,0,0,0,0]
var proportions:Array[float] = []
var highest_proportion_by_level:int = 0
var move_history:Array[Dictionary] = []
var temp_debug_text:String = ""
var input:Array
var predictions:Array
var best_nna_prediction:Array
var prev_score:float
var epsilon:float = 0.25
var min_epsilon:float = 0.01
var decay_rate = 0.995
var selected_purin:Purin = null
var best_score:float = 0

func init(player_controller:PlayerController):
	self.game = player_controller
	self.held_purin_level = 0
	self.next_purin_to_drop_level = 0
	self.debug = player_controller.debug
	
	self.temp_debug_text = ""

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

func process_ai(_delta):
	if game.gameover_screen.visible:
		return
	
	calc_level_distribution()
	
	if can_drop():
		#calc_level_distribution()
		self.space_state = get_world_2d().direct_space_state
		
		if game.neural_training and game.source_network and Global.nna:
			if predictions:
				# was a previous prediction from last time we dropped
				var score_increased_amount:float = game.score - prev_score
				if score_increased_amount > 0:
					# train where you went on that input to get that score increase
					# train the best AI and yourself
					best_nna_prediction = [max(0,min(1, game.noir.position.x / game.ml_scale_factor))]
					Global.nna.train(input, best_nna_prediction)
					game.source_network.train(input, best_nna_prediction)
				# show what we picked
				if game.prediction_icon:
					game.prediction_icon.position.x = predictions[0] * game.ml_scale_factor
				if game.best_icon:
					game.best_icon.position.x = best_nna_prediction[0] * game.ml_scale_factor
				temp_debug_text = "#%s %s e:%s\nTarget FS: %s Total Loss: %s\n[Prediction] %s vs %s\n"%[game.attempts+1, game.source_network.get_string_info(), snapped(epsilon, 0.001), snapped(game.source_network.target_fitness, 0.001), snapped(game.source_network.target_fitness, 0.01), predictions, best_nna_prediction]
				self.game.debug_label.text = "%s"%[temp_debug_text]
			# new drop
			# get state of the game
			input = game.get_state()
			# see what the best AI would do in this state
			best_nna_prediction = Global.nna.predict(input)
			
			# random chance to do a random move to see what happens instead
			if randf() < epsilon:
				predictions = [randf()]
			else:
				# predict using our nn where we should drop
				predictions = game.source_network.predict(input)
			
			# reduce epsilon chance
			epsilon = max(min_epsilon, epsilon * decay_rate)
			
			# move us to where we predict
			game.noir.position.x = game.valid_x_pos(predictions[0] * game.ml_scale_factor)	
			# update score
			game.source_network.total_score = game.score
			# update fitness
			var new_tf:float = 0
			for i in range(0, len(proportions)-1):
				new_tf += game.score_by_level(i+1) * proportions[i]
			game.source_network.target_fitness = new_tf
			
		# drop the purin wherever was selected
		game.drop_purin()
		
		held_purin_level = game.purin_bag.get_current_purin()["level"]
		
		move_history.append(
			{
				"x": game.noir.position.x,
				"level": held_purin_level,
				"score": game.score,
				#"input": input
			}
		)
		
		prev_score = game.score
	
	
func purin_is_moving(purin:Purin):
	if (abs(purin.linear_velocity.x) >= 5 or abs(purin.linear_velocity.y) >= 5):
		return true
	return false

func can_drop():
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
	
	return (game.can_drop_early and game.time_since_last_dropped_purin_sec >= cool_down_sec*0.5 and all_purin_stopped) or (emergency and time_elapsed) or (time_elapsed and all_purin_stopped) or double_time_elapsed
