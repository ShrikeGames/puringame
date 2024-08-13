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
var prev_score:float
var actuals: Array

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
	if debug and game.training:
		self.game.debug_label.text = "Attempt #%s %s"%[game.attempts+1, temp_debug_text]
	
	if can_drop():
		#calc_level_distribution()
		self.space_state = get_world_2d().direct_space_state
		
		# look at results of last time we predicted and dropped
		if input and game.neural_training and game.source_network:
			if not predictions.is_empty() and predictions[0] is float:
				var best_nna_prediction:Array = game.best_nna.predict(input)
				actuals = best_nna_prediction
				if not actuals.is_empty() and actuals[0] is float:
					game.best_icon.position.x = actuals[0] * game.ml_scale_factor
					# train this model based on the best one
					game.source_network.train(input, actuals)
				
		# see where the old AI moved us to, treat that as good for now
		if game.neural_training and game.source_network:
			# get state of the game before anything is done
			input = game.get_state()
			# tell it to predict where we should drop next
			predictions = game.source_network.predict(input)
			
			if game.prediction_icon:
				game.prediction_icon.position.x = predictions[0] * game.ml_scale_factor
			# go to where the neural networks says to go
			if not predictions.is_empty() and not is_nan(predictions[0]):
				game.noir.position.x = game.valid_x_pos(predictions[0] * game.ml_scale_factor)
				temp_debug_text = "%s [Prediction] %s vs %s. Total Loss: %s."%[game.source_network.get_string_info(), predictions, actuals, game.source_network.total_loss]
			else:
				temp_debug_text = "invalid prediction? %s"%[predictions]
				
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
