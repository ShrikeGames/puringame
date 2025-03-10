extends Node

class_name NeuralNetwork

var input_size: int
var hidden_size: int
var output_size: int

var weights_input_hidden: PackedFloat32Array
var weights_hidden_output: PackedFloat32Array
var bias_hidden: PackedFloat32Array
var bias_output: PackedFloat32Array

func _init(input_size: int, hidden_size: int, output_size: int):
	self.input_size = input_size
	self.hidden_size = hidden_size
	self.output_size = output_size

	weights_input_hidden = PackedFloat32Array()
	weights_hidden_output = PackedFloat32Array()
	bias_hidden = PackedFloat32Array()
	bias_output = PackedFloat32Array()

	# Initialize weights and biases with random values
	for i in range(input_size * hidden_size):
		weights_input_hidden.append(randf() * 2 - 1)
	for i in range(hidden_size * output_size):
		weights_hidden_output.append(randf() * 2 - 1)
	for i in range(hidden_size):
		bias_hidden.append(randf() * 2 - 1)
	for i in range(output_size):
		bias_output.append(randf() * 2 - 1)

func forward(input: PackedFloat32Array) -> PackedFloat32Array:
	var hidden = PackedFloat32Array()
	for i in range(hidden_size):
		var sum = 0.0
		for j in range(input_size):
			sum += input[j] * weights_input_hidden[i * input_size + j]
		sum += bias_hidden[i]
		hidden.append(tanh(sum))

	var output = PackedFloat32Array()
	for i in range(output_size):
		var sum = 0.0
		for j in range(hidden_size):
			sum += hidden[j] * weights_hidden_output[i * hidden_size + j]
		sum += bias_output[i]
		output.append(sum)

	return output

func sample_action(probs: PackedFloat32Array) -> int:
	var cumulative_sum = 0.0
	var random_value = randf()
	for i in range(probs.size()):
		cumulative_sum += probs[i]
		if random_value < cumulative_sum:
			return i
	return probs.size() - 1

func parameters() -> Array:
	return [weights_input_hidden, weights_hidden_output, bias_hidden, bias_output]

func to_dict() -> Dictionary:
	return {
		"input_size": input_size,
		"hidden_size": hidden_size,
		"output_size": output_size,
		"weights_input_hidden": weights_input_hidden,
		"weights_hidden_output": weights_hidden_output,
		"bias_hidden": bias_hidden,
		"bias_output": bias_output
	}

func from_dict(data: Dictionary) -> void:
	input_size = data["input_size"]
	hidden_size = data["hidden_size"]
	output_size = data["output_size"]
	weights_input_hidden = data["weights_input_hidden"]
	weights_hidden_output = data["weights_hidden_output"]
	bias_hidden = data["bias_hidden"]
	bias_output = data["bias_output"]
