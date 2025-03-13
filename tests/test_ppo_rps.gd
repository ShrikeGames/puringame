extends TestBase
class_name TestPPORPS

var ppo: PPO
func setup():
	# Initialize PPO with a small network
	# advantages
	var gamma: float = 0.99 # also affects rewards
	var lambda: float = 0.95
	var clip_range: float = 0.1

	# value
	var epsilon: float = 0.01
	# Average gradients and update parameters
	var learning_rate: float = 0.0001
	
	var INPUT_NODES: int = 10
	var BRAIN_HIDDEN_LAYERS: Array[int] = [64, 32, 3]
	var OUTPUT_NODES: int = 3
	var ENTROPY_COEFF: float = 0.01
	print("gamma: %f, epsilon: %f, learning_rate: %f, lambda: %f, clip_range: %f, ENTROPY_COEFF: %f" % [gamma, epsilon, learning_rate, lambda, clip_range, ENTROPY_COEFF])
	ppo = PPO.new(INPUT_NODES, BRAIN_HIDDEN_LAYERS, OUTPUT_NODES, gamma, epsilon, learning_rate, lambda, clip_range)
	print(ppo.enable_normalize_advantages)
	ppo.enable_normalize_advantages = true
	ppo.enable_clip_advantages = true
	ppo.enable_normalized_rewards = true
	ppo.extra_value_loss_training = 4

	ppo.value_network.ENTROPY_COEFF = ENTROPY_COEFF
	ppo.policy_network.ENTROPY_COEFF = ENTROPY_COEFF
	

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
	var states: Array = []
	var actions: Array = []
	var rewards: Array = []
	var next_states: Array = []
	var dones: Array = []
	print("Read experiences to use as test data")
	# load experience logs to use in unit test "user://experience_log.json"
	var experiences: Dictionary = read_json("user://experience_log_rps.json")
	var i: int = 0
	# Train the agent multiple times, between each episode marked by done
	var initial_avg_return: float = 0.0
	var initial_avg_advantage: float = 0.0
	var initial_policy_loss: float = 0.0
	var initial_value_loss: float = 0.0
	print(experiences)
	for _log in experiences["logs"]:
		states.append(_log["state"])
		actions.append(_log["action"])
		rewards.append(_log["reward"])
		next_states.append(_log["next_state"])
		dones.append(_log["done"])
		if _log["done"]:
			print("End of episode found. Start step: %s" % [i])
			for _epoch in range(10):
				print("Epoch ", _epoch)
				ppo.train(states, actions, rewards, next_states, dones)
			# Store initial metrics
			if i == 0:
				initial_avg_return = ppo.metrics_avg_return
				initial_avg_advantage = ppo.metrics_avg_advantage
				initial_policy_loss = ppo.metrics_policy_loss
				initial_value_loss = ppo.metrics_value_loss
			# Log metrics
			print("[Step %d] Avg Return diff (vs initial): %f" % [i, ppo.metrics_avg_return - initial_avg_return])
			print("[Step %d] Avg Advantage diff (vs initial): %f" % [i, ppo.metrics_avg_advantage - initial_avg_advantage])
			print("[Step %d] Policy Loss diff (vs initial): %f" % [i, ppo.metrics_policy_loss - initial_policy_loss])
			print("[Step %d] Value Loss diff (vs initial): %f" % [i, ppo.metrics_value_loss - initial_value_loss])
			states = []
			actions = []
			rewards = []
			next_states = []
			dones = []
			i += 1

	# Verify that metrics have improved
	assert_true(ppo.metrics_avg_return > initial_avg_return, "Avg Return should increase")
	assert_true(ppo.metrics_avg_advantage > initial_avg_advantage, "Avg Advantage should increase")
	assert_true(ppo.metrics_policy_loss < initial_policy_loss, "Policy Loss should decrease")
	assert_true(ppo.metrics_value_loss < initial_value_loss, "Value Loss should decrease")

	ppo.save_model("user://ppo_model.json")
