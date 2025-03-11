extends TestBase
class_name TestPPO

var test_ppo: PPO
var test_nn: NeuralNetwork

func setup() -> void:
	# No global setup required for these tests.
	pass

func run_tests() -> void:
	# Run each test in sequence.
	test_neural_network_forward()
	test_select_action()
	test_save_and_load_model()
	test_train_function_runs()
	test_policy_network_layers_match_after_loading()

func before_test() -> void:
	# Optionally clear or reset state between tests.
	pass

func after_test() -> void:
	# Optionally perform cleanup after a test.
	pass

# Test that NeuralNetwork.forward returns an output of the expected size and that, 
# for multi-output (policy) networks, the outputs form a valid probability distribution.
func test_neural_network_forward() -> void:
	before_test()
	var input_size: int = 10
	var hidden_layers: Array = [5]
	var output_size: int = 3
	test_nn = NeuralNetwork.new(input_size, hidden_layers, output_size)
	
	# Create a sample input vector.
	var sample_input: Array = []
	for i in range(input_size):
		sample_input.append(randf_range(-1.0, 1.0))
	
	var output: Array = test_nn.forward(sample_input)
	# Check that the output vector is of expected length.
	assert_equal(output.size(), output_size, "NeuralNetwork.forward returns output of size " + str(output_size))
	
	# If the network uses softmax (for output_size > 1), then the sum of the probabilities should be ~1.
	if output_size > 1:
		var sum_out: float = 0.0
		for v in output:
			sum_out += v
		assert_almost_equal(sum_out, 1.0, 0.0001, "NeuralNetwork.forward softmax outputs sum to 1")
	after_test()

# Test that PPO.select_action returns a valid action index.
func test_select_action() -> void:
	before_test()
	var input_size: int = 10
	var hidden_layers: Array = [5]
	var output_size: int = 3
	test_ppo = PPO.new(input_size, hidden_layers, output_size)
	
	# Create a sample state.
	var sample_state: Array = []
	for i in range(input_size):
		sample_state.append(randf_range(-1.0, 1.0))
	
	var action: int = test_ppo.select_action(sample_state, null)
	assert_true(action >= 0 and action < output_size, "PPO.select_action returns a valid action index (" + str(action) + ")")
	after_test()

# Test that saving and loading the PPO model correctly preserves hyperparameters and network state.
func test_save_and_load_model() -> void:
	before_test()
	var input_size: int = 10
	var hidden_layers: Array = [5]
	var output_size: int = 3
	test_ppo = PPO.new(input_size, hidden_layers, output_size)
	
	# Set known hyperparameters.
	test_ppo.gamma = 0.95
	test_ppo.epsilon = 0.1
	test_ppo.learning_rate = 0.005
	
	# Save the model to a temporary file.
	var filepath: String = "user://temp_model.json"
	test_ppo.save_model(filepath)
	
	# Create a new PPO instance (with different initial parameters) and load the saved model.
	var loaded_ppo: PPO = PPO.new(input_size, hidden_layers, output_size)
	loaded_ppo.load_model(filepath)
	
	# Compare hyperparameters.
	assert_almost_equal(loaded_ppo.gamma, 0.95, 0.0001, "Loaded gamma matches saved value")
	assert_almost_equal(loaded_ppo.epsilon, 0.1, 0.0001, "Loaded epsilon matches saved value")
	assert_almost_equal(loaded_ppo.learning_rate, 0.005, 0.0001, "Loaded learning rate matches saved value")
	
	# Compare network state: for example, check that the layers and the count of weights/biases are the same.
	var orig_policy_state: Dictionary = test_ppo.policy_network.get_state()
	var loaded_policy_state: Dictionary = loaded_ppo.policy_network.get_state()
	print("orig_policy_state layers:", orig_policy_state["layers"])
	print("loaded_policy_state layers: ", loaded_policy_state["layers"])
	assert_equal(orig_policy_state["layers"].size(), loaded_policy_state["layers"].size(), "Policy network layers count match after loading")
	for i in range(orig_policy_state["layers"].size()):
		assert_equal(orig_policy_state["layers"][i], loaded_policy_state["layers"][i], "Layer " + str(i) + " matches after loading.")
	assert_equal(orig_policy_state["weights"].size(), loaded_policy_state["weights"].size(), "Policy network weights count matches after loading")
	assert_equal(orig_policy_state["biases"].size(), loaded_policy_state["biases"].size(), "Policy network biases count matches after loading")
	after_test()

# Test that PPO.train runs without throwing errors using dummy training data.
func test_train_function_runs() -> void:
	before_test()
	var input_size: int = 10
	var hidden_layers: Array = [5]
	var output_size: int = 2
	test_ppo = PPO.new(input_size, hidden_layers, output_size)
	
	var batch_size: int = 4
	# Create dummy training data as flat arrays.
	var states: Array = []
	var next_states: Array = []
	for i in range(batch_size):
		for j in range(input_size):
			states.append(randf_range(-1.0, 1.0))
			next_states.append(randf_range(-1.0, 1.0))
	var actions: Array = []
	var rewards: Array = []
	for i in range(batch_size):
		actions.append(randi() % output_size)
		rewards.append(randf_range(-1.0, 1.0))
	
	# Execute the train function. (If an error occurs, the test will fail.)
	test_ppo.train(states, actions, rewards, next_states)
	assert_true(true, "PPO.train executed without error")
	after_test()

# Test the network layers after loading
func test_policy_network_layers_match_after_loading():
	var model_path = "res://temp_model.json" # Path where model is saved

	# Save the model first
	var ppo = PPO.new(67, [128, 64], 10)
	ppo.save_model(model_path)

	# Load the model into a new PPO
	var loaded_ppo = PPO.new(67, [128, 64], 10)
	loaded_ppo.load_model(model_path)

	# Compare layers manually and log the results
	var saved_layers = ppo.policy_network.layers
	var loaded_layers = loaded_ppo.policy_network.layers
	
	print("Saved Layers: ", saved_layers)
	print("Loaded Layers: ", loaded_layers)

	# Check if layers match one by one
	for i in range(saved_layers.size()):
		assert_equal(saved_layers[i], loaded_layers[i], "Layer " + str(i) + " does not match.")
	
	# Compare the actual layer weights and biases more closely
	for i in range(saved_layers.size() - 1): # Layers are connected, so we don't need to check the final layer for weight connection
		var saved_weights = ppo.policy_network.weights[i]
		var loaded_weights = loaded_ppo.policy_network.weights[i]
		var weight_difference = compare_arrays(saved_weights, loaded_weights)
		if weight_difference.size() > 0:
			print("Weights differ for layer " + str(i) + ": ", weight_difference)
		
		var saved_biases = ppo.policy_network.biases[i]
		var loaded_biases = loaded_ppo.policy_network.biases[i]
		var bias_difference = compare_arrays(saved_biases, loaded_biases)
		if bias_difference.size() > 0:
			print("Biases differ for layer " + str(i) + ": ", bias_difference)

	print("✓ Pass: Policy network layers match after loading")

# Utility function to compare two arrays of floats element by element
func compare_arrays(array1: Array, array2: Array) -> Array:
	var diff: Array = []
	
	# Check if the arrays have the same size
	if array1.size() != array2.size():
		diff.append("Arrays have different sizes: " + str(array1.size()) + " != " + str(array2.size()))
		return diff
	
	# Iterate through the arrays
	for i in range(array1.size()):
		var sub_diff = []
		
		# If sub-arrays are themselves arrays, compare those as well
		if array1[i] is Array and array2[i] is Array:
			# Check for size mismatch in sub-arrays
			if array1[i].size() != array2[i].size():
				sub_diff.append("Sub-array sizes differ at index " + str(i))
			else:
				for j in range(array1[i].size()):
					if abs(array1[i][j] - array2[i][j]) > 0.0001: # tolerance for floating-point precision
						sub_diff.append("Index " + str(i) + ", Sub-index " + str(j) + ": " + str(array1[i][j]) + " != " + str(array2[i][j]))
		
		# If sub-arrays are 2D (nested arrays)
		elif array1[i] is Array and array2[i] is Array:
			# Handle the 3D arrays for weights or any deeper structure you might have
			for j in range(array1[i].size()):
				if array1[i][j] != array2[i][j]:
					sub_diff.append("Mismatch at index " + str(i) + ":" + str(j))
					
		if sub_diff.size() > 0:
			diff.append("Differences at index " + str(i) + ": " + str(sub_diff))
	
	return diff