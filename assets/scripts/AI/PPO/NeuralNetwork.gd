extends Object
class_name NeuralNetwork

var layers: Array = [] # Array[int]
var weights: Array = [] # Array of 2D arrays (each is Array[Array[float]])
var biases: Array = [] # Array of vectors (each is Array[float]])
var batch_norm_params: Array = [] # For batch normalization

const ENTROPY_COEFF: float = 0.01
const EPSILON: float = 1e-7

func _init(input_size: int, hidden_layers: Array, output_size: int) -> void:
	layers.append(input_size)
	for layer_size in hidden_layers:
		layers.append(layer_size)
	layers.append(output_size)
	
	for i in range(layers.size() - 1):
		weights.append(rand_matrix(layers[i], layers[i + 1]))
		biases.append(rand_vector(layers[i + 1]))
		batch_norm_params.append({"mean": 0.0, "variance": 1.0})

# Forward pass with optional batch normalization
func forward(inputs: Array, training: bool = true) -> Array:
	var current_output: Array = inputs.duplicate()
	for i in range(weights.size()):
		current_output = Tensor.vector_add(Tensor.matrix_vector_mul(weights[i], current_output), biases[i])
		if training:
			current_output = Tensor.batch_norm(current_output, batch_norm_params[i])
		if i == weights.size() - 1:
			if layers[layers.size() - 1] > 1:
				current_output = Tensor.softmax(current_output)
			else:
				# only one output so use sigmoid instead
				current_output = Tensor.sigmoid(current_output)
				current_output = Tensor.clamp(current_output, EPSILON, 1.0 - EPSILON)
		else:
			current_output = Tensor.relu(current_output)
	return current_output

# Backward pass with clipped value loss
func backward(states: Array, actions: Array, targets: Array, learning_rate: float, epsilon: float = 0.1) -> float:
	var batch_size: int = states.size()
	var grad_weights: Array = []
	var grad_biases: Array = []
	for i in range(weights.size()):
		grad_weights.append(Tensor.zeros_matrix(weights[i].size(), weights[i][0].size()))
		grad_biases.append(Tensor.zeros_vector(biases[i].size()))
	
	var policy_loss: float = 0.0
	var value_loss: float = 0.0
	
	for sample_idx in range(batch_size):
		var x: Array = states[sample_idx]
		var activations: Array = []
		var pre_activations: Array = []
		activations.append(x)
		var a: Array = x.duplicate()
		
		# Forward pass
		for i in range(weights.size()):
			var z: Array = Tensor.vector_add(Tensor.matrix_vector_mul(weights[i], a), biases[i])
			pre_activations.append(z)
			if i == weights.size() - 1:
				if layers[layers.size() - 1] > 1:
					a = Tensor.softmax(z)
				else:
					a = z.duplicate()
			else:
				a = Tensor.relu(z)
			activations.append(a)
		
		# Compute delta
		var delta: Array = []
		if actions.size() > 0:
			var probs: Array = activations[activations.size() - 1]
			var action: int = int(actions[sample_idx])
			var advantage: float = targets[sample_idx]
			delta.resize(probs.size())
			for j in range(probs.size()):
				var indicator: float = 1.0 if j == action else 0.0
				delta[j] = (probs[j] - indicator) * advantage + ENTROPY_COEFF * (log(probs[j] + EPSILON) + 1.0)
			policy_loss += -log(probs[action] + EPSILON) * advantage
			# Debug: Print policy loss components
			#print("Probs: ", probs, " | Action: ", action, " | Advantage: ", advantage, " | Policy Loss: ", -log(probs[action] + EPSILON) * advantage)
		else:
			var prediction: float = activations[activations.size() - 1][0]
			var target: float = targets[sample_idx]
			var value_diff: float = prediction - target
			var clipped_value: float = clamp(value_diff, -epsilon, epsilon)
			delta.append(clipped_value)
			value_loss += 0.5 * pow(clipped_value, 2)
			#print("Prediction: ", prediction, " | Target: ", target, " | Value Diff: ", value_diff, " | Clipped Value: ", clipped_value, " | Value loss: ", 0.5 * pow(clipped_value, 2))
		
		# Backpropagate
		for layer_idx in range(weights.size() - 1, -1, -1):
			var a_prev: Array = activations[layer_idx]
			var delta_matrix: Array = Tensor.outer_product(a_prev, delta)
			grad_weights[layer_idx] = Tensor.matrix_add(grad_weights[layer_idx], delta_matrix)
			grad_biases[layer_idx] = Tensor.vector_add(grad_biases[layer_idx], delta)
			
			if layer_idx > 0:
				var wt_transposed: Array = Tensor.transpose(weights[layer_idx])
				var delta_prev: Array = Tensor.matrix_vector_mul(wt_transposed, delta)
				var relu_deriv: Array = Tensor.relu_derivative(pre_activations[layer_idx - 1])
				delta = Tensor.elementwise_multiply(delta_prev, relu_deriv)
	
	# Average gradients and update parameters
	for i in range(weights.size()):
		grad_weights[i] = Tensor.scalar_divide(grad_weights[i], float(batch_size))
		grad_biases[i] = Tensor.vector_divide(grad_biases[i], float(batch_size))
		weights[i] = Tensor.matrix_subtract(weights[i], Tensor.matrix_scalar_multiply(grad_weights[i], learning_rate))
		biases[i] = Tensor.vector_subtract(biases[i], Tensor.vector_scalar_multiply(grad_biases[i], learning_rate))
	
	if actions.size() > 0:
		return policy_loss / batch_size
	else:
		return value_loss / batch_size

# Save and load state (unchanged from your original implementation)
func get_state() -> Dictionary:
	var state: Dictionary = {
		"layers": layers,
		"weights": weights,
		"biases": biases
	}
	return state

func load_state(state: Dictionary) -> void:
	layers = state.get("layers", [])
	weights = state.get("weights", [])
	biases = state.get("biases", [])

# Returns a matrix (Array of Arrays) of size [rows x cols] with random values scaled using Xavier initialization.
func rand_matrix(rows: int, cols: int) -> Array:
	var matrix: Array = []
	# Compute scale factor for Xavier initialization.
	var scale: float = sqrt(2.0 / float(rows + cols))
	for i in range(rows):
		var row: Array = []
		for j in range(cols):
			row.append(randf_range(-1.0, 1.0) * scale)
		matrix.append(row)
	return matrix

# Returns a vector (Array) of the given size with random values scaled appropriately.
# Alternatively, you might set biases to zero.
func rand_vector(size: int) -> Array:
	var vector: Array = []
	# Option 1: Initialize biases with small random values.
	var scale: float = sqrt(2.0 / float(size))
	for i in range(size):
		vector.append(randf_range(-1.0, 1.0) * scale)
	# Option 2: Alternatively, you can set biases to zero:
	# for i in range(size):
	#	 vector.append(0.0)
	return vector
