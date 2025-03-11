extends TestBase

class_name TestLearning

var ppo_agent: PPO
var num_episodes: int = 100
var reward_threshold: float = 10.0 # Threshold for average reward after training

func setup():
	# Define the input size, hidden layers, and output size
	var input_size = 3
	var hidden_layers = [8]
	var output_size = 3

	ppo_agent = PPO.new(input_size, hidden_layers, output_size, 0.99, 0.2, 0.001)

func run_tests():
	# Run the learning test
	test_learning()

func test_learning():
	print("Testing learning over episodes...")

	var previous_avg_return = - float("inf")
	var rewards: Array = []

	for episode in range(num_episodes):
		# Run an episode
		var episode_reward = run_episode()
		rewards.append(episode_reward)

		# Calculate the average return manually
		var avg_return = calculate_average(rewards)

		# Print progress (optional)
		if episode % 10 == 0:
			print("Episode %d: Avg Return = %.3f" % [episode, avg_return])

		# Check if the average return has improved compared to the previous episode
		if avg_return > previous_avg_return:
			previous_avg_return = avg_return
		else:
			fail("The average return did not improve in episode %d!" % episode)

		# Optionally, assert that the average return is above a certain threshold after the final episode
		if episode == num_episodes - 1:
			assert_true(avg_return >= reward_threshold, "Learning did not reach the expected return threshold.")
		else:
			pass

	print("Learning test passed.")

func run_episode() -> float:
	# Simulate running an episode with a simple reward structure
	var total_reward = 0.0
	var state = get_initial_state()
	var done = false

	while not done:
		# Select action based on the state (no real environment, just a dummy action)
		var action = ppo_agent.select_action(state, null)

		# Get reward and next state (dummy environment)
		var result = environment_step(action, state)
		var next_state = result["next_state"]
		var reward = result["reward"]
		done = result["done"]
		print(state, " -> ", next_state, " via ", action, " reward was ", reward)
		# Update PPO agent (simulated)
		ppo_agent.train(state, [action], [reward], next_state)

		# Accumulate rewards
		total_reward += reward

		state = next_state

	return total_reward

func get_initial_state() -> Array:
	# Return a simple initial state
	return [1, 0, 0] # Simple 3D state vector (replace as needed)

func environment_step(action: int, state: Array) -> Dictionary:
	# Simulate a simple environment step with an easily predicatable reward structure and next state
	var reward = 0
	# if action == index of the largest value in state reward = 1 else -1
	var best_action = state.find(state.max())
	if action == best_action:
		reward = 1
	else:
		reward = -1
	
	var done = false # For simplicity, this environment never ends
	if randf() < 0.1:
		done = true
	# always say the next best action is one ahead of the last one
	var next_state = [0, 0, 0]
	var next_best = best_action + 1
	if next_best > 2:
		next_best = 0
	next_state[next_best] = 1
	
	return {"next_state": next_state, "reward": reward, "done": done}

# Function to calculate the average manually
func calculate_average(arr: Array) -> float:
	var total = 0.0
	for value in arr:
		total += value
	return total / arr.size()
