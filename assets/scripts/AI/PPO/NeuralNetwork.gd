extends Node

class_name NeuralNetwork

var input_size: int
var hidden_size: int
var output_size: int

var weights_input_hidden: Tensor
var weights_hidden_output: Tensor
var bias_hidden: Tensor
var bias_output: Tensor
var gradients: Dictionary

func _init(input_size: int, hidden_size: int, output_size: int):
	self.input_size = input_size
	self.hidden_size = hidden_size
	self.output_size = output_size
	
	# Value network should output a single value per state
	if output_size == 1:
		self.output_size = 1  # Keep it as 1 for value network
	
	initialize_parameters()
	initialize_gradients()

func initialize_parameters():
	# Xavier initialization
	var w1_std = sqrt(2.0 / input_size)
	var w2_std = sqrt(2.0 / hidden_size)
	
	# Initialize input->hidden weights
	var w1_data = PackedFloat32Array()
	for _i in range(input_size * hidden_size):
		w1_data.append(randfn(0, w1_std))
	weights_input_hidden = Tensor.new(w1_data, true)
	
	# Initialize hidden->output weights
	var w2_data = PackedFloat32Array()
	for _i in range(hidden_size * output_size):
		w2_data.append(randfn(0, w2_std))
	weights_hidden_output = Tensor.new(w2_data, true)
	
	# Initialize biases
	var b1_data = PackedFloat32Array()
	for _i in range(hidden_size):
		b1_data.append(0.0)
	bias_hidden = Tensor.new(b1_data, true)
	
	var b2_data = PackedFloat32Array()
	for _i in range(output_size):
		b2_data.append(0.0)
	bias_output = Tensor.new(b2_data, true)

func initialize_gradients():
	# Initialize gradients dictionary
	gradients = {
		"w1": weights_input_hidden,  # Use the actual tensors instead of creating new ones
		"w2": weights_hidden_output,
		"b1": bias_hidden,
		"b2": bias_output
	}
	
	# Ensure all tensors have gradients initialized
	weights_input_hidden.zero_gradients()
	weights_hidden_output.zero_gradients()
	bias_hidden.zero_gradients()
	bias_output.zero_gradients()

func backward(gradient: Tensor, cache: Dictionary) -> void:
	var batch_size = cache["input"].data.size() / input_size
	
	# Output layer gradients
	var d_output = gradient.data
	var hidden = cache["hidden"].data
	
	for i in range(output_size):
		for j in range(hidden_size):
			var weight_idx = j * output_size + i
			if weight_idx < weights_hidden_output.gradients.size():
				weights_hidden_output.gradients[weight_idx] += d_output[i] * hidden[j] / batch_size
		if i < bias_output.gradients.size():
			bias_output.gradients[i] += d_output[i] / batch_size

	# Add debug prints
	print("w1 gradients size: ", weights_input_hidden.gradients.size())
	print("w2 gradients size: ", weights_hidden_output.gradients.size())
	print("b1 gradients size: ", bias_hidden.gradients.size())
	print("b2 gradients size: ", bias_output.gradients.size())

func forward(input: Tensor) -> Dictionary:
	# Calculate batch size from input
	var batch_size = input.data.size() / input_size
	print("Forward pass batch_size: ", batch_size, " input_size: ", input_size)
	
	var cache = {"input": input}
	var hidden = PackedFloat32Array()
	var hidden_raw = PackedFloat32Array()
	
	# Input to hidden layer
	for b in range(batch_size):
		for i in range(hidden_size):
			var sum = 0.0
			for j in range(input_size):
				var input_idx = b * input_size + j
				var weight_idx = j * hidden_size + i
				sum += input.data[input_idx] * weights_input_hidden.data[weight_idx]
			sum += bias_hidden.data[i]
			hidden_raw.append(sum)
			hidden.append(tanh(sum))
	
	# Hidden to output layer
	var output_raw = PackedFloat32Array()
	var output = PackedFloat32Array()
	
	# Handle value network (output_size=1) differently than policy network
	if output_size == 1:  # Value network case
		for b in range(batch_size):
			var sum = 0.0
			for j in range(hidden_size):
				var hidden_idx = b * hidden_size + j
				var weight_idx = j
				sum += hidden[hidden_idx] * weights_hidden_output.data[weight_idx]
			sum += bias_output.data[0]
			output_raw.append(sum)
			output.append(sum)
	else:  # Policy network case
		for b in range(batch_size):
			var batch_output = PackedFloat32Array()
			for i in range(output_size):
				var sum = 0.0
				for j in range(hidden_size):
					var hidden_idx = b * hidden_size + j
					var weight_idx = j * output_size + i
					sum += hidden[hidden_idx] * weights_hidden_output.data[weight_idx]
				sum += bias_output.data[i]
				batch_output.append(sum)
			
			# Apply softmax only for policy network
			var softmax_result = softmax(batch_output)
			output_raw.append_array(batch_output)
			output.append_array(softmax_result)
	
	return {
		"input": input,
		"hidden_raw": Tensor.from_array(hidden_raw),
		"hidden": Tensor.from_array(hidden),
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
	for grad in gradients.values():
		for i in range(grad.data.size()):
			grad.data[i] = 0.0

func randfn(mean: float, std_dev: float) -> float:
	var u1 = randf()
	var u2 = randf()
	var z0 = sqrt(-2.0 * log(u1)) * cos(2.0 * PI * u2)
	return mean + z0 * std_dev

func get_parameters() -> Dictionary:
	return {
		"w1": weights_input_hidden,
		"w2": weights_hidden_output,
		"b1": bias_hidden,
		"b2": bias_output
	}
