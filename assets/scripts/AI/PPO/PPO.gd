extends Object
class_name PPO

# Neural network for policy and value estimation.
var policy_network: NeuralNetwork
var value_network: NeuralNetwork
var gamma: float
var epsilon: float
var learning_rate: float

func _init(p_input_size: int, p_hidden_layers: Array, p_output_size: int, p_gamma: float = 0.99, p_epsilon: float = 0.2, p_learning_rate: float = 0.001) -> void:
	policy_network = NeuralNetwork.new(p_input_size, p_hidden_layers, p_output_size)
	value_network = NeuralNetwork.new(p_input_size, p_hidden_layers, 1)
	gamma = p_gamma
	epsilon = p_epsilon
	learning_rate = p_learning_rate

# Batch training using arrays of states, actions, rewards, and next states.
# Updated train function that reshapes flat state arrays into an array of samples.
func train(states: Array, actions: Array, rewards: Array, next_states: Array) -> void:
	# Retrieve input size from the network (first layer size).
	var input_size: int = policy_network.layers[0]
	var sample_states: Array = []
	var sample_next_states: Array = []
	
	# If the states are flat so reshape them.
	if states.size() % input_size != 0:
		push_error("States array size (" + str(states.size()) + ") is not a multiple of input size (" + str(input_size) + ").")
		return
	# Split the flat array into chunks of size 'input_size'.
	for i in range(0, states.size(), input_size):
		var sample: Array = []
		for j in range(input_size):
			sample.append(states[i + j])
		sample_states.append(sample)
	
	if next_states.size() % input_size != 0:
		push_error("Next states array size (" + str(next_states.size()) + ") is not a multiple of input size (" + str(input_size) + ").")
		return
	for i in range(0, next_states.size(), input_size):
		var sample: Array = []
		for j in range(input_size):
			sample.append(next_states[i + j])
		sample_next_states.append(sample)
	
	var advantages: Array = []
	var returns: Array = []
	
	# Loop over each experience (now sample_states.size() should match actions.size() and rewards.size()).
	for i in range(sample_states.size()):
		var value: float = value_network.forward(sample_states[i])[0]
		var next_value: float = value_network.forward(sample_next_states[i])[0]
		var advantage: float = rewards[i] + gamma * next_value - value
		advantages.append(advantage)
		returns.append(rewards[i] + gamma * next_value)
	
	policy_network.backward(sample_states, actions, advantages, learning_rate)
	value_network.backward(sample_states, [], returns, learning_rate)
	print_metrics(returns, advantages)

# Selects an action index based on the policy network's output probabilities for a given state.
func select_action(state: Array, debug_label: RichTextLabel) -> int:
	# Get probability distribution from policy network.
	#print("state:", state)
	var probs: Array = policy_network.forward(state)
	var cumulative: float = 0.0
	
	var r: float = randf() # Generates a random float in [0,1)
	#print("r: ", r)
	# Sample from the probability distribution.
	var best_action: int = -1
	for i in range(probs.size()):
		cumulative += probs[i]
		if r < cumulative:
			best_action = i
			#print("best action found: ", i)
			break
	if best_action < 0:
		# Fallback: return the last index if not selected earlier.
		best_action = probs.size() - 1
	if debug_label:
		#print("Probabilities -> Action: %s -> %s" % [probs, best_action])
		debug_label.text = "%s -> %s" % [probs, best_action]
	return best_action

func print_metrics(returns: Array, advantages: Array) -> void:
	var sum_return: float = 0.0
	for r in returns:
		sum_return += r
	var avg_return: float = sum_return / returns.size()
	
	var sum_adv: float = 0.0
	for a in advantages:
		sum_adv += a
	var avg_advantage: float = sum_adv / advantages.size()
	
	print("Avg Return: ", avg_return)
	print("Avg Advantage: ", avg_advantage)

# Saves the entire PPO model (hyperparameters and network states) to a JSON file.
func save_model(filepath: String) -> void:
	var model_data: Dictionary = {
		"gamma": gamma,
		"epsilon": epsilon,
		"learning_rate": learning_rate,
		"policy_network": policy_network.get_state(),
		"value_network": value_network.get_state()
	}
	var json_string: String = JSON.stringify(model_data)
	var file: FileAccess = FileAccess.open(filepath, FileAccess.WRITE)
	if file == null:
		push_error("Could not open file for writing: " + filepath)
		return
	file.store_string(json_string)
	file.close()

# Loads the PPO model from a JSON file, restoring hyperparameters and network states.
func load_model(filepath: String) -> void:
	var file: FileAccess = FileAccess.open(filepath, FileAccess.READ)
	if file == null:
		push_error("Could not open file for reading: " + filepath)
		return
	var json_string: String = file.get_as_text()
	file.close()
	
	# Create an instance of JSON and parse the JSON string.
	var json := JSON.new()
	var error_code: int = json.parse(json_string)
	if error_code != OK:
		push_error("Error parsing JSON: " + json.get_error_message())
		return
	
	var model_data: Dictionary = json.get_data()
	
	gamma = model_data.get("gamma", 0.99)
	epsilon = model_data.get("epsilon", 0.2)
	learning_rate = model_data.get("learning_rate", 0.001)
	
	# Restore network states (requires NeuralNetwork.gd to implement get_state and load_state)
	policy_network.load_state(model_data.get("policy_network", {}))
	value_network.load_state(model_data.get("value_network", {}))
