extends Node

class_name PPO

# Neural network parameters
var input_size: int
var hidden_size: int
var output_size: int

# PPO parameters
var learning_rate: float = 0.0003
var gamma: float = 0.99
var epsilon: float = 0.2
var epochs: int = 10

# Neural network
var policy_net: NeuralNetwork
var value_net: NeuralNetwork

# Optimizers
var policy_optimizer: Optimizer
var value_optimizer: Optimizer

func _init(input_size: int, hidden_size: int, output_size: int):
	self.input_size = input_size
	self.hidden_size = hidden_size
	self.output_size = output_size

	policy_net = NeuralNetwork.new(input_size, hidden_size, output_size)
	value_net = NeuralNetwork.new(input_size, hidden_size, 1)

	policy_optimizer = AdamOptimizer.new(policy_net.parameters(), learning_rate)
	value_optimizer = AdamOptimizer.new(value_net.parameters(), learning_rate)

func select_action(state: PackedFloat32Array) -> int:
	var probs = policy_net.forward(state)
	var action = sample_action(probs)
	return action

func sample_action(probs: PackedFloat32Array) -> int:
	var cumulative_sum = 0.0
	var random_value = randf()
	for i in range(probs.size()):
		cumulative_sum += probs[i]
		if random_value < cumulative_sum:
			return i
	return probs.size() - 1

func compute_advantages(rewards: PackedFloat32Array, values: PackedFloat32Array, next_values: PackedFloat32Array) -> PackedFloat32Array:
	var advantages = PackedFloat32Array()
	var gae = 0.0
	for i in range(rewards.size() - 1, -1, -1):
		var delta = rewards[i] + gamma * next_values[i] - values[i]
		gae = delta + gamma * epsilon * gae
		advantages.append(gae)
	return advantages

func update_policy(states: PackedFloat32Array, actions: PackedFloat32Array, advantages: PackedFloat32Array):
	for _d in range(epochs):
		var old_probs = policy_net.forward(states)
		var new_probs = policy_net.forward(states)
		var ratio = new_probs / old_probs
		var surr1 = ratio * advantages
		var surr2 = clamp(ratio, 1 - epsilon, 1 + epsilon) * advantages
		var loss = -min(surr1, surr2).mean()
		policy_optimizer.zero_grad()
		loss.backward()
		policy_optimizer.step()

func update_value(states: PackedFloat32Array, returns: PackedFloat32Array):
	var values = value_net.forward(states)
	var loss = (returns - values).pow(2).mean()
	value_optimizer.zero_grad()
	loss.backward()
	value_optimizer.step()

func train(states: PackedFloat32Array, actions: PackedFloat32Array, rewards: PackedFloat32Array, next_states: PackedFloat32Array):
	var values = value_net.forward(states)
	var next_values = value_net.forward(next_states)
	var advantages = compute_advantages(rewards, values, next_values)
	update_policy(states, actions, advantages)
	update_value(states, rewards + gamma * next_values)

func save_model(path: String) -> void:
	var data = {
		"input_size": input_size,
		"hidden_size": hidden_size,
		"output_size": output_size,
		"policy_net": policy_net.to_dict(),
		"value_net": value_net.to_dict()
	}
	var file = FileAccess.open(path, FileAccess.WRITE)
	if file:
		file.store_string(JSON.stringify(data))
		file.close()

func load_model(path: String) -> void:
	var file = FileAccess.open(path, FileAccess.READ)
	if file:
		var data = JSON.parse_string(file.get_as_text())
		file.close()
		input_size = data["input_size"]
		hidden_size = data["hidden_size"]
		output_size = data["output_size"]
		policy_net.from_dict(data["policy_net"])
		value_net.from_dict(data["value_net"])
