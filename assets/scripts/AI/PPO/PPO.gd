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

func select_action(state: PoolRealArray) -> int:
    var state_tensor = Tensor.from_array(state)
    var probs = policy_net.forward(state_tensor)
    var action = probs.sample()
    return action

func compute_advantages(rewards: PoolRealArray, values: PoolRealArray, next_values: PoolRealArray) -> PoolRealArray:
    var advantages = PoolRealArray()
    var gae = 0.0
    for i in range(rewards.size() - 1, -1, -1):
        delta = rewards[i] + gamma * next_values[i] - values[i]
        gae = delta + gamma * epsilon * gae
        advantages.append(gae)
    return advantages

func update_policy(states: PoolRealArray, actions: PoolIntArray, advantages: PoolRealArray):
    for _ in range(epochs):
        var old_probs = policy_net.forward(states)
        var new_probs = policy_net.forward(states)
        var ratio = new_probs / old_probs
        var surr1 = ratio * advantages
        var surr2 = clamp(ratio, 1 - epsilon, 1 + epsilon) * advantages
        var loss = -min(surr1, surr2).mean()
        policy_optimizer.zero_grad()
        loss.backward()
        policy_optimizer.step()

func update_value(states: PoolRealArray, returns: PoolRealArray):
    var values = value_net.forward(states)
    var loss = (returns - values).pow(2).mean()
    value_optimizer.zero_grad()
    loss.backward()
    value_optimizer.step()

func train(states: PoolRealArray, actions: PoolIntArray, rewards: PoolRealArray, next_states: PoolRealArray):
    var values = value_net.forward(states)
    var next_values = value_net.forward(next_states)
    var advantages = compute_advantages(rewards, values, next_values)
    update_policy(states, actions, advantages)
    update_value(states, rewards + gamma * next_values)