extends Object
class_name PPO

# Neural network for policy and value estimation.
var policy_network: NeuralNetwork
var value_network: NeuralNetwork
var gamma: float
var epsilon: float
var learning_rate: float
var lambda: float = 0.95 # For GAE
var initial_learning_rate: float
var current_learning_rate: float
var metrics_avg_return: float = 0
var metrics_avg_advantage: float = 0
var metrics_policy_loss: float = 0
var metrics_value_loss: float = 0
var clip_range: float = 0.2
func _init(p_input_size: int, p_hidden_layers: Array, p_output_size: int, p_gamma: float = 0.90, p_epsilon: float = 0.2, p_learning_rate: float = 0.00001, p_lambda: float = 0.95, p_clip_range: float = 0.02) -> void:
	policy_network = NeuralNetwork.new(p_input_size, p_hidden_layers, p_output_size)
	value_network = NeuralNetwork.new(p_input_size, p_hidden_layers, 1)
	gamma = p_gamma
	epsilon = p_epsilon
	learning_rate = p_learning_rate
	initial_learning_rate = p_learning_rate
	current_learning_rate = p_learning_rate
	lambda = p_lambda
	clip_range = p_clip_range

# Batch training using arrays of states, actions, rewards, and next states.
func train(states: Array, actions: Array, rewards: Array, next_states: Array) -> void:
	var values: Array = []
	var next_values: Array = []
	var advantages: Array = []
	var returns: Array = []
	var normalized_rewards: Array = rewards # normalize_rewards(rewards)
	
	# Compute values and next values
	for i in range(states.size()):
		values.append(value_network.forward(states[i])[0])
		next_values.append(value_network.forward(next_states[i])[0])
	
	# Compute advantages using GAE
	advantages = compute_advantages(rewards, values, next_values, gamma, lambda)
	advantages = normalize_advantages(advantages)
	advantages = clip_advantages(advantages, clip_range)
	
	# Compute returns
	for i in range(normalized_rewards.size()):
		returns.append(normalized_rewards[i] + gamma * next_values[i])
	
	# Train policy and value networks
	var policy_loss: float = policy_network.backward(states, actions, advantages, current_learning_rate, epsilon)
	var value_loss: float = value_network.backward(states, [], returns, current_learning_rate, epsilon)
	# train the value network more
	for _d in range(4):
		value_loss = value_network.backward(states, [], returns, current_learning_rate, epsilon)
		
	# Print metrics
	print_metrics(returns, advantages, policy_loss, value_loss)

# Generalized Advantage Estimation (GAE)
func compute_advantages(rewards: Array, values: Array, next_values: Array, p_gamma: float, p_lambda: float) -> Array:
	var advantages: Array = []
	var gae: float = 0.0
	for i in range(rewards.size() - 1, -1, -1):
		var delta: float = rewards[i] + p_gamma * next_values[i] - values[i]
		gae = delta + p_gamma * p_lambda * gae
		advantages.insert(0, gae)
	return advantages

func normalize_rewards(rewards: Array) -> Array:
	var mean: float = Tensor.mean(rewards)
	var std: float = Tensor.std(rewards)
	if std == 0:
		std = 1 # Prevent divide by zero
	return Tensor.scalar_divide(Tensor.vector_subtract_single_value(rewards, mean), std)

func normalize_advantages(advantages: Array) -> Array:
	var mean: float = Tensor.mean(advantages)
	var std: float = Tensor.std(advantages)
	if std == 0:
		std = 1 # Prevent divide by zero
	return Tensor.scalar_divide(Tensor.vector_subtract_single_value(advantages, mean), std)

func clip_advantages(advantages: Array, p_clip_range: float = 2.0) -> Array:
	return Tensor.clamp(advantages, -p_clip_range, p_clip_range)

# Selects an action index based on the policy network's output probabilities for a given state.
func select_action(state: Array, temperature: float = 1.0) -> Array:
	# Get probability distribution from policy network.
	var probs: Array = policy_network.forward(state)
	if temperature != 1.0:
		probs = Tensor.scalar_divide(probs, temperature)
		probs = Tensor.softmax(probs)
	
	var cumulative: float = 0.0
	var best_prob: float = 0.0
	var r: float = randf() # Generates a random float in [0,1)
	var best_action: int = -1
	
	# Sample from the probability distribution.
	for i in range(probs.size()):
		cumulative += probs[i]
		if r < cumulative:
			best_action = i
			break
	if best_action < 0:
		# Fallback: pick the action with highest probability
		for i in range(probs.size()):
			if probs[i] >= best_prob:
				best_prob = probs[i]
				best_action = i
	return [best_action, probs]


# Print training metrics
func print_metrics(returns: Array, advantages: Array, policy_loss: float, value_loss: float) -> void:
	var sum_return: float = 0.0
	for r in returns:
		sum_return += r
	var avg_return: float = sum_return / returns.size()
	
	var sum_adv: float = 0.0
	for a in advantages:
		sum_adv += a
	var avg_advantage: float = sum_adv / advantages.size()
	
	metrics_avg_return = avg_return
	metrics_avg_advantage = avg_advantage
	metrics_policy_loss = policy_loss
	metrics_value_loss = value_loss
	print("[Metric] Avg Return: %s (Should increase until very high, GREEN)" % [metrics_avg_return])
	print("[Metric] Avg Advantage: %s (Should increase until slightly positive, WHITE)" % [metrics_avg_advantage])
	print("[Metric] Policy Loss: %s (Should decrease then stay low, RED)" % [metrics_policy_loss])
	print("[Metric] Value Loss: %s (Should decrease then stay low, DARK RED)" % [metrics_value_loss])

# Update learning rate with linear decay
func update_learning_rate(step: int, total_steps: int) -> void:
	current_learning_rate = initial_learning_rate * (1.0 - float(step) / float(total_steps))

# Save and load model (unchanged from your original implementation)
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

func load_model(filepath: String) -> void:
	var file: FileAccess = FileAccess.open(filepath, FileAccess.READ)
	if file == null:
		push_error("Could not open file for reading: " + filepath)
		return
	var json_string: String = file.get_as_text()
	file.close()
	
	var json := JSON.new()
	var error_code: int = json.parse(json_string)
	if error_code != OK:
		push_error("Error parsing JSON: " + json.get_error_message())
		return
	
	var model_data: Dictionary = json.get_data()
	gamma = model_data.get("gamma", 0.99)
	epsilon = model_data.get("epsilon", 0.2)
	learning_rate = model_data.get("learning_rate", 0.001)
	policy_network.load_state(model_data.get("policy_network", {}))
	value_network.load_state(model_data.get("value_network", {}))
