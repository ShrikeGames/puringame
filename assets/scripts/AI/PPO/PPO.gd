extends Node

class_name PPO

var input_size: int
var hidden_size: int
var output_size: int

var learning_rate: float = 0.0003
var gamma: float = 0.99
var epsilon: float = 0.2
var epochs: int = 10
var clip_range: float = 0.2
var value_coef: float = 0.5
var entropy_coef: float = 0.01

var policy_net: NeuralNetwork
var value_net: NeuralNetwork
var policy_optimizer: AdamOptimizer
var value_optimizer: AdamOptimizer

func _init(input_size: int, hidden_size: int, output_size: int):
	self.input_size = input_size
	self.hidden_size = hidden_size
	self.output_size = output_size

	policy_net = NeuralNetwork.new(input_size, hidden_size, output_size)
	value_net = NeuralNetwork.new(input_size, hidden_size, 1)

	policy_optimizer = AdamOptimizer.new(policy_net.get_parameters(), learning_rate)
	value_optimizer = AdamOptimizer.new(value_net.get_parameters(), learning_rate)

func select_action(state: PackedFloat32Array) -> int:
	var state_tensor = Tensor.from_array(state)
	var output = policy_net.forward(state_tensor)
	var probs = output["output"]
	return probs.sample()

func update_policy(states: Tensor, actions: Tensor, old_probs: Tensor, advantages: Tensor):
	var batch_size = advantages.size()
	print("Update policy batch_size: ", batch_size)
	
	for _epoch in range(epochs):
		# Add debug prints before forward pass
		print("\nEpoch ", _epoch)
		policy_net.weights_input_hidden.debug_grad_flow("w1 before forward")
		policy_net.weights_hidden_output.debug_grad_flow("w2 before forward")
		
		var output = policy_net.forward(states)
		var new_probs = output["output"]
		
		# Extract only the probabilities for the actions that were taken
		var selected_new_probs = Tensor.new(PackedFloat32Array())
		var selected_old_probs = Tensor.new(PackedFloat32Array())
		
		for i in range(batch_size):
			var action_idx = i * output_size + int(actions.data[i])
			selected_new_probs.data.append(new_probs.data[action_idx])
			selected_old_probs.data.append(old_probs.data[action_idx])
		
		var ratio = selected_new_probs.__div(selected_old_probs)
		var surr1 = ratio.__mul(advantages)
		var surr2 = ratio.clamp(1.0 - clip_range, 1.0 + clip_range).__mul(advantages)
		
		# Calculate means first
		var surr1_tensor = surr1.mean()
		var surr2_tensor = surr2.mean()
		
		# Get scalar values
		var surr1_value = surr1_tensor.data[0]
		var surr2_value = surr2_tensor.data[0]
		
		# Create policy loss tensor with negative value
		var min_value = min(surr1_value, surr2_value)
		var neg_min_value = PackedFloat32Array([-min_value])
		var policy_loss = Tensor.from_array(neg_min_value)
		
		# Calculate entropy loss using full probability distributions
		var log_probs = new_probs.__log()
		var probs_times_logprobs = new_probs.__mul(log_probs)
		var entropy_tensor = probs_times_logprobs.mean()
		var entropy_value = -entropy_tensor.data[0]
		
		# Combine losses
		var combined_loss = PackedFloat32Array([policy_loss.data[0] - entropy_coef * entropy_value])
		var total_loss = Tensor.from_array(combined_loss)
		
		policy_net.zero_gradients()
		print("\nBefore backward:")
		policy_net.weights_input_hidden.print_gradients("w1")
		policy_net.weights_hidden_output.print_gradients("w2")
		
		total_loss.backward()
		
		print("\nAfter backward:")
		policy_net.weights_input_hidden.print_gradients("w1")
		policy_net.weights_hidden_output.print_gradients("w2")
		
		policy_optimizer.step()

func update_value(states: Tensor, returns: Tensor):
	print("States size: ", states.size())
	print("Returns size: ", returns.size())
	
	for _epoch in range(epochs):
		var output = value_net.forward(states)
		var values = output["output"]
		
		# Ensure values tensor has same size as returns
		var values_expanded = Tensor.new(PackedFloat32Array())
		for i in range(returns.size()):
			values_expanded.data.append(values.data[i % values.size()])
		
		var value_loss = (returns.__sub(values_expanded)).pow(2).mean()
		
		value_net.zero_gradients()
		value_loss.backward()
		value_optimizer.step()

func compute_gae(rewards: Tensor, values: Tensor, next_values: Tensor, dones: Tensor) -> Dictionary:
	# Add debug prints to check sizes
	print("Rewards size: ", rewards.size())
	print("Values size: ", values.size())
	print("Next values size: ", next_values.size())
	print("Dones size: ", dones.size())
	
	# Ensure we have at least one element
	if rewards.size() == 0 or values.size() == 0 or next_values.size() == 0 or dones.size() == 0:
		push_error("Empty tensor in compute_gae")
		return {
			"advantages": Tensor.from_array(PackedFloat32Array([0.0])),
			"returns": Tensor.from_array(PackedFloat32Array([0.0]))
		}
	
	var advantages = PackedFloat32Array()
	var returns = PackedFloat32Array()
	var gae = 0.0
	
	# Handle single sample case
	if rewards.size() == 1:
		var non_terminal = 1.0 - dones.data[0]
		var delta = rewards.data[0] + gamma * next_values.data[0] * non_terminal - values.data[0]
		advantages.append(delta)
		returns.append(delta + values.data[0])
	else:
		# Handle batch case
		for i in range(rewards.size() - 1, -1, -1):
			var non_terminal = 1.0 - dones.data[i]
			var delta = rewards.data[i] + gamma * next_values.data[i] * non_terminal - values.data[i]
			gae = delta + gamma * epsilon * non_terminal * gae
			advantages.insert(0, gae)
			returns.insert(0, gae + values.data[i])
	
	return {
		"advantages": Tensor.from_array(advantages),
		"returns": Tensor.from_array(returns)
	}

func save_model(path: String) -> void:
	var data = {
		"input_size": input_size,
		"hidden_size": hidden_size,
		"output_size": output_size,
		"policy_net": {
			"weights_input_hidden": Array(policy_net.weights_input_hidden.data),
			"weights_hidden_output": Array(policy_net.weights_hidden_output.data),
			"bias_hidden": Array(policy_net.bias_hidden.data),
			"bias_output": Array(policy_net.bias_output.data)
		},
		"value_net": {
			"weights_input_hidden": Array(value_net.weights_input_hidden.data),
			"weights_hidden_output": Array(value_net.weights_hidden_output.data),
			"bias_hidden": Array(value_net.bias_hidden.data),
			"bias_output": Array(value_net.bias_output.data)
		}
	}
	
	var json_string = JSON.stringify(data)
	var file = FileAccess.open(path, FileAccess.WRITE)
	file.store_string(json_string)
	file.close()

func load_model(path: String) -> void:
	if not FileAccess.file_exists(path):
		push_error("Model file not found: " + path)
		return
	
	var file = FileAccess.open(path, FileAccess.READ)
	var json_string = file.get_as_text()
	file.close()
	
	var json = JSON.new()
	var error = json.parse(json_string)
	if error != OK:
		push_error("JSON Parse Error: " + json.get_error_message())
		return
		
	var data = json.get_data()
	
	# Verify model architecture matches
	if data.input_size != input_size or data.hidden_size != hidden_size or data.output_size != output_size:
		push_error("Model architecture mismatch")
		return
	
	# Load policy network weights
	policy_net.weights_input_hidden.data = PackedFloat32Array(data.policy_net.weights_input_hidden)
	policy_net.weights_hidden_output.data = PackedFloat32Array(data.policy_net.weights_hidden_output)
	policy_net.bias_hidden.data = PackedFloat32Array(data.policy_net.bias_hidden)
	policy_net.bias_output.data = PackedFloat32Array(data.policy_net.bias_output)  # Fixed this line
	
	# Load value network weights
	value_net.weights_input_hidden.data = PackedFloat32Array(data.value_net.weights_input_hidden)
	value_net.weights_hidden_output.data = PackedFloat32Array(data.value_net.weights_hidden_output)
	value_net.bias_hidden.data = PackedFloat32Array(data.value_net.bias_hidden)
	value_net.bias_output.data = PackedFloat32Array(data.value_net.bias_output)

func train(states: Tensor, actions: Tensor, rewards: Tensor, next_states: Tensor, dones: Tensor):
	var batch_size = rewards.size()
	print("Training batch size: ", batch_size)
	
	# Forward pass through value network with full batch
	var value_output = value_net.forward(states)
	var next_value_output = value_net.forward(next_states)
	
	# Value network outputs one value per state
	var values = value_output["output"]
	var next_values = next_value_output["output"]
	
	# Ensure correct sizes
	var values_resized = Tensor.new(PackedFloat32Array())
	var next_values_resized = Tensor.new(PackedFloat32Array())
	
	# Take one value per state
	for i in range(batch_size):
		values_resized.data.append(values.data[i])
		next_values_resized.data.append(next_values.data[i])
	
	# Calculate GAE and returns
	var gae_info = compute_gae(rewards, values_resized, next_values_resized, dones)
	var advantages = gae_info["advantages"]
	var returns = gae_info["returns"]
	
	# Forward pass through policy network
	var output = policy_net.forward(states)
	var old_probs = output["output"]
	
	update_policy(states, actions, old_probs, advantages)
	update_value(states, returns)
