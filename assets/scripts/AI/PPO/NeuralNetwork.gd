extends Object
class_name NeuralNetwork

# The network is defined by the list of layer sizes.
var layers: Array = [] # Array[int]
var weights: Array = [] # Array of 2D arrays (each is Array[Array[float]])
var biases: Array = [] # Array of vectors (each is Array[float])

# Coefficients used in the policy loss (entropy bonus) and a small constant for numerical stability.
const ENTROPY_COEFF: float = 0.01
const EPSILON: float = 1e-8

func _init(input_size: int, hidden_layers: Array, output_size: int) -> void:
	layers = []
	weights = []
	biases = []
	layers.append(input_size)
	for layer_size in hidden_layers:
		layers.append(layer_size)
	layers.append(output_size)
	
	for i in range(layers.size() - 1):
		weights.append(rand_matrix(layers[i], layers[i + 1]))
		biases.append(rand_vector(layers[i + 1]))

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

# Forward pass for one sample (inputs is an Array[float]).
func forward(inputs: Array) -> Array:
	var current_output: Array = inputs.duplicate()
	for i in range(weights.size()):
		# Multiply by weights and add biases.
		#print("weights[%s].size(): "%[i], weights[i].size())
		#print("biases[%s].size(): "%[i], biases[i].size())
		#print("current_output: ", current_output)
		current_output = Tensor.vector_add(Tensor.matrix_vector_mul(weights[i], current_output), biases[i])
		# For the final layer, use softmax if more than one output (policy); otherwise linear.
		if i == weights.size() - 1:
			if layers[layers.size() - 1] > 1:
				current_output = Tensor.softmax(current_output)
			# Else, value network: no activation (linear output)
		else:
			current_output = Tensor.relu(current_output)
	return current_output

# Backward pass performing gradient descent on a batch.
# If actions is nonempty, assume a policy network (using targets as advantages); if empty, assume a value network (using targets as returns).
func backward(states: Array, actions: Array, targets: Array, learning_rate: float) -> void:
	var batch_size: int = states.size()
	# Initialize gradient accumulators with the same dimensions as weights and biases.
	var grad_weights: Array = []
	var grad_biases: Array = []
	for i in range(weights.size()):
		grad_weights.append(Tensor.zeros_matrix(weights[i].size(), weights[i][0].size()))
		grad_biases.append(Tensor.zeros_vector(biases[i].size()))
	
	# Process each sample in the batch.
	for sample_idx in range(batch_size):
		var x: Array = states[sample_idx]
		# Store activations and pre-activations (z) for each layer.
		var activations: Array = []
		var pre_activations: Array = []
		activations.append(x)
		var a: Array = x.duplicate()
		# Forward pass (store each layer’s output).
		for i in range(weights.size()):
			var z: Array = Tensor.vector_add(Tensor.matrix_vector_mul(weights[i], a), biases[i])
			pre_activations.append(z)
			if i == weights.size() - 1:
				if layers[layers.size() - 1] > 1:
					a = Tensor.softmax(z)
				else:
					a = z.duplicate() # linear output for value network
			else:
				a = Tensor.relu(z)
			activations.append(a)
		
		# Compute delta (error) at the output layer.
		var delta: Array = []
		if actions.size() > 0:
			# Policy network: use cross-entropy loss with advantage and an entropy bonus.
			var probs: Array = activations[activations.size() - 1]
			var action: int = int(actions[sample_idx])
			var advantage: float = targets[sample_idx]
			delta.resize(probs.size())
			for j in range(probs.size()):
				var indicator: float = 0
				if j == action:
					indicator = 1.0
				# For the softmax output, the gradient becomes (p - one_hot)*advantage plus entropy regularization.
				delta[j] = (probs[j] - indicator) * advantage + ENTROPY_COEFF * (log(probs[j] + EPSILON) + 1.0)
		else:
			# Value network: using mean squared error loss.
			var prediction: float = activations[activations.size() - 1][0]
			var target: float = targets[sample_idx]
			delta.append(prediction - target)
		
		# Backpropagate the error.
		for layer_idx in range(weights.size() - 1, -1, -1):
			# Gradient for weights: outer product of activation from previous layer and delta.
			var a_prev: Array = activations[layer_idx]
			var delta_matrix: Array = Tensor.outer_product(a_prev, delta)
			grad_weights[layer_idx] = Tensor.matrix_add(grad_weights[layer_idx], delta_matrix)
			grad_biases[layer_idx] = Tensor.vector_add(grad_biases[layer_idx], delta)
			
			if layer_idx > 0:
				# Compute delta for the previous layer.
				var wt_transposed: Array = Tensor.transpose(weights[layer_idx])
				var delta_prev: Array = Tensor.matrix_vector_mul(wt_transposed, delta)
				# Multiply elementwise by the derivative of the ReLU activation.
				var relu_deriv: Array = Tensor.relu_derivative(pre_activations[layer_idx - 1])
				delta = Tensor.elementwise_multiply(delta_prev, relu_deriv)
	# End of batch loop
	
	# Average the gradients over the batch and update parameters.
	for i in range(weights.size()):
		grad_weights[i] = Tensor.scalar_divide(grad_weights[i], float(batch_size))
		grad_biases[i] = Tensor.vector_divide(grad_biases[i], float(batch_size))
		weights[i] = Tensor.matrix_subtract(weights[i], Tensor.matrix_scalar_multiply(grad_weights[i], learning_rate))
		biases[i] = Tensor.vector_subtract(biases[i], Tensor.vector_scalar_multiply(grad_biases[i], learning_rate))

# Returns the internal state of the network as a Dictionary.
func get_state() -> Dictionary:
	var state: Dictionary = {
		"layers": layers,
		"weights": weights,
		"biases": biases
	}
	return state

# Loads the internal state of the network from a Dictionary.
func load_state(state: Dictionary) -> void:
	layers = state.get("layers", [])
	weights = state.get("weights", [])
	biases = state.get("biases", [])
