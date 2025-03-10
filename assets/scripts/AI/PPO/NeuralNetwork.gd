extends Node

class_name NeuralNetwork

var input_size: int
var hidden_sizes: Array[int]  # Now an array of hidden layer sizes
var output_size: int

var weights: Array[Tensor]  # Array of weight tensors for all layers
var biases: Array[Tensor]   # Array of bias tensors for all layers
var gradients: Dictionary

func _init(input_size: int, hidden_sizes: Array[int], output_size: int):
	self.input_size = input_size
	self.hidden_sizes = hidden_sizes
	self.output_size = output_size
	
	# Value network should output a single value per state
	if output_size == 1:
		self.output_size = 1  # Keep it as 1 for value network
	
	initialize_parameters()
	initialize_gradients()

func initialize_parameters():
	weights = []
	biases = []
	
	# Input to first hidden layer
	var prev_size = input_size
	for hidden_size in hidden_sizes:
		var w_std = sqrt(2.0 / prev_size)
		var w_data = PackedFloat32Array()
		for _i in range(prev_size * hidden_size):
			w_data.append(randfn(0, w_std))
		weights.append(Tensor.new(w_data, true))
		
		var b_data = PackedFloat32Array()
		for _i in range(hidden_size):
			b_data.append(0.0)
		biases.append(Tensor.new(b_data, true))
		
		prev_size = hidden_size
	
	# Last hidden layer to output
	var w_std = sqrt(2.0 / prev_size)
	var w_data = PackedFloat32Array()
	for _i in range(prev_size * output_size):
		w_data.append(randfn(0, w_std))
	weights.append(Tensor.new(w_data, true))
	
	var b_data = PackedFloat32Array()
	for _i in range(output_size):
		b_data.append(0.0)
	biases.append(Tensor.new(b_data, true))

func initialize_gradients():
	# Initialize gradients dictionary
	gradients = {
		"weights": weights,  # Use the actual tensors instead of creating new ones
		"biases": biases
	}
	
	# Ensure all tensors have gradients initialized
	for weight in weights:
		weight.zero_gradients()
	for bias in biases:
		bias.zero_gradients()

func backward(gradient: Tensor, cache: Dictionary) -> void:
	var batch_size = cache["input"].data.size() / input_size
	
	# Output layer gradients
	var d_output = gradient.data
	var hidden = cache["hidden"][-1]["activated"].data
	
	for i in range(output_size):
		for j in range(hidden.size()):
			var weight_idx = j * output_size + i
			if weight_idx < weights[-1].gradients.size():
				weights[-1].gradients[weight_idx] += d_output[i] * hidden[j] / batch_size
		if i < biases[-1].gradients.size():
			biases[-1].gradients[i] += d_output[i] / batch_size

	# Add debug prints
	print("weights gradients size: ", weights[-1].gradients.size())
	print("biases gradients size: ", biases[-1].gradients.size())

func forward(input: Tensor) -> Dictionary:
	# Calculate batch size from input
	var batch_size = input.data.size() / input_size
	var cache = {"input": input}
	var current = input
	var hidden_outputs = []
	
	# Debug input size
	#print("Input tensor size: ", input.data.size(), " input_size: ", input_size, " batch_size: ", batch_size)
	
	# Process through all hidden layers
	for i in range(weights.size() - 1):
		var hidden = PackedFloat32Array()
		var hidden_raw = PackedFloat32Array()
		
		# For each sample in batch
		for b in range(batch_size):
			# For each neuron in current hidden layer
			for j in range(hidden_sizes[i]):
				var sum = 0.0
				# For each input to this layer
				for k in range(input_size if i == 0 else hidden_sizes[i-1]):
					var input_idx = b * (input_size if i == 0 else hidden_sizes[i-1]) + k
					var weight_idx = k * hidden_sizes[i] + j
					if input_idx < current.data.size() and weight_idx < weights[i].data.size():
						sum += current.data[input_idx] * weights[i].data[weight_idx]
				sum += biases[i].data[j]
				hidden_raw.append(sum)
				hidden.append(tanh(sum))  # Use tanh activation for hidden layers
		
		current = Tensor.from_array(hidden)
		hidden_outputs.append({"raw": Tensor.from_array(hidden_raw), "activated": current})
		
		# Debug layer sizes
		#print("Layer ", i, " output size: ", hidden.size())
	
	# Output layer
	var output_raw = PackedFloat32Array()
	var output = PackedFloat32Array()
	
	# For each sample in batch
	for b in range(batch_size):
		# For each output neuron
		for i in range(output_size):
			var sum = 0.0
			# For each input from last hidden layer
			for j in range(hidden_sizes[-1]):
				var input_idx = b * hidden_sizes[-1] + j
				var weight_idx = j * output_size + i
				if input_idx < current.data.size() and weight_idx < weights[-1].data.size():
					sum += current.data[input_idx] * weights[-1].data[weight_idx]
			sum += biases[-1].data[i]
			output_raw.append(sum)
	
	# Apply softmax to output layer for policy network per batch
	if output_size > 1:
		var final_output = PackedFloat32Array()
		for b in range(batch_size):
			var batch_output = PackedFloat32Array()
			for i in range(output_size):
				batch_output.append(output_raw[b * output_size + i])
			var softmaxed = softmax(batch_output)
			final_output.append_array(softmaxed)
		output = final_output
	else:
		output = output_raw  # No activation for value network
	
	# Debug output size
	#print("Final output size: ", output.size())
	
	return {
		"input": input,
		"hidden": hidden_outputs,
		"output_raw": Tensor.from_array(output_raw),
		"output": Tensor.from_array(output)
	}

func softmax(x: PackedFloat32Array) -> PackedFloat32Array:
	var result = PackedFloat32Array()
	var max_val = -INF
	for val in x:
		if val > max_val:
			max_val = val

	var sum = 0.0
	for val in x:
		var exp_val = exp(val - max_val)
		result.append(exp_val)
		sum += exp_val
	
	for i in range(result.size()):
		result[i] /= sum
	
	return result

func get_gradients() -> Dictionary:
	return gradients

func zero_gradients() -> void:
	for grad in gradients.weights:
		for i in range(grad.data.size()):
			grad.data[i] = 0.0
	for grad in gradients.biases:
		for i in range(grad.data.size()):
			grad.data[i] = 0.0
			
func randfn(mean: float, std_dev: float) -> float:
	var u1 = randf()
	var u2 = randf()
	var z0 = sqrt(-2.0 * log(u1)) * cos(2.0 * PI * u2)
	return mean + z0 * std_dev

func get_parameters() -> Dictionary:
	return {
			"weights": weights,
			"biases": biases
	}
