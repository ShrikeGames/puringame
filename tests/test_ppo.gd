extends TestBase
class_name TestPPO

var ppo: PPO

func setup():
	# Initialize PPO with a small network
	var gamma: float = 0.999
	var epsilon: float = 1
	var learning_rate: float = 0.01
	var INPUT_NODES: int = 6 + (2 * 30) # 2*30 rays
	var BRAIN_HIDDEN_LAYERS: Array[int] = [128, 64]
	var OUTPUT_NODES: int = 5
	ppo = PPO.new(INPUT_NODES, BRAIN_HIDDEN_LAYERS, OUTPUT_NODES, gamma, epsilon, learning_rate)

func run_tests():
	await before_test()
	test_ppo_training()
	await after_test()

func read_json(path: String) -> Dictionary:
	if not FileAccess.file_exists(path):
		return {}
	var json_string = FileAccess.get_file_as_string(path)
	var json_dict = JSON.parse_string(json_string)
	
	return json_dict

func test_ppo_training():
	var states: Array = [
	]
	var actions: Array = []
	var rewards: Array = []
	var next_states: Array = [
	]
	print("Read experiences to use as test data")
	# load experience logs to use in unit test "user://experience_log.json"
	var experiences: Dictionary = read_json("user://experience_log.json")
	for _log in experiences["logs"]:
		states.append(_log["state"])
		actions.append(_log["action"])
		rewards.append(_log["reward"])
		next_states.append(_log["next_state"])
	print("Done loading test data")
	
	# Train the agent multiple times
	var initial_avg_return: float = 0.0
	var initial_avg_advantage: float = 0.0
	var initial_policy_loss: float = 0.0
	var initial_value_loss: float = 0.0

	for i in range(100): # Train for 10 steps
		ppo.train(states, actions, rewards, next_states)

		# Log metrics
		print("[Step %d] Avg Return: %f" % [i, ppo.metrics_avg_return])
		print("[Step %d] Avg Advantage: %f" % [i, ppo.metrics_avg_advantage])
		print("[Step %d] Policy Loss: %f" % [i, ppo.metrics_policy_loss])
		print("[Step %d] Value Loss: %f" % [i, ppo.metrics_value_loss])

		# Store initial metrics
		if i == 0:
			initial_avg_return = ppo.metrics_avg_return
			initial_avg_advantage = ppo.metrics_avg_advantage
			initial_policy_loss = ppo.metrics_policy_loss
			initial_value_loss = ppo.metrics_value_loss

	# Verify that metrics have improved
	assert_true(ppo.metrics_avg_return > initial_avg_return, "Avg Return should increase")
	assert_true(ppo.metrics_avg_advantage > initial_avg_advantage, "Avg Advantage should increase")
	assert_true(ppo.metrics_policy_loss < initial_policy_loss, "Policy Loss should decrease")
	assert_true(ppo.metrics_value_loss < initial_value_loss, "Value Loss should decrease")
