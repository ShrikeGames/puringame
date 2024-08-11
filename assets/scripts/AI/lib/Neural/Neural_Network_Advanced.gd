class_name NeuralNetworkAdvanced
# source: https://github.com/ryash072007/Godot-AI-Kit
# Date: 2024-08-11
var network: Array

var ACTIVATIONS: Dictionary = {
	"SIGMOID": {
		"function": Callable(Activation, "sigmoid"),
		"derivative": Callable(Activation, "dsigmoid"),
		"name": "sigmoid"
	},
	"RELU": {
		"function": Callable(Activation, "relu"),
		"derivative": Callable(Activation, "drelu"),
		"name": "relu"
	},
	"TANH": {
		"function": Callable(Activation, "tanh_"),
		"derivative": Callable(Activation, "dtanh"),
		"name": "tanh_"
	},
	"ARCTAN": {
		"function": Callable(Activation, "arcTan"),
		"derivative": Callable(Activation, "darcTan"),
		"name": "arcTan"
	},
	"PRELU": {
		"function": Callable(Activation, "prelu"),
		"derivative": Callable(Activation, "dprelu"),
		"name": "prelu"
	},
	"ELU": {
		"function": Callable(Activation, "elu"),
		"derivative": Callable(Activation, "delu"),
		"name": "elu"
	},
	"SOFTPLUS": {
		"function": Callable(Activation, "softplus"),
		"derivative": Callable(Activation, "dsoftplus"),
		"name": "softplus"
	},
	"LINEAR": {
		"function": Callable(Activation, "linear"),
		"derivative": Callable(Activation, "dlinear"),
		"name": "linear"
	}
}


var learning_rate: float = 0.5

var layer_structure: Array[int] = []
var layers: Array[Dictionary] = []
func add_layer(nodes: int, activation: Dictionary = ACTIVATIONS.SIGMOID, input_weights:Array=[], input_bias:Array=[], col_size = 1):
	
	
	var weights:Matrix
	var bias:Matrix
	
	if input_weights.is_empty():
		#print("Create new random weights")
		if layer_structure.size() != 0:
			weights = Matrix.rand(Matrix.new(nodes, layer_structure[-1]))
		else:
			weights = Matrix.new(nodes, nodes)
	else:
		#print("Load weights from array")
		weights = Matrix.from_array2(input_weights, col_size)
		
	
	if input_bias.is_empty():
		bias = Matrix.rand(Matrix.new(nodes, 1))
	else:
		bias = Matrix.from_array(input_bias)
	
	var layer_data: Dictionary = {
		"weights": weights,
		"bias": bias,
		"activation": activation,
		"activation_name": activation["name"],
		"size": nodes,
		"rows": weights.rows,
		"cols": weights.cols
	}
	layers.append(layer_data)
	if layer_structure.size() != 0:
		network.push_back(layer_data)
	
	layer_structure.append(nodes)


func predict(input_array: Array) -> Array:
	var inputs: Matrix = Matrix.from_array(input_array)
	for layer in network:
		var product: Matrix = Matrix.dot_product(layer.weights, inputs)
		var sum: Matrix = Matrix.add(product, layer.bias)
		var map: Matrix = Matrix.map(sum, layer.activation.function)
		inputs = map
	return Matrix.to_array(inputs)
#
func train(input_array: Array, target_array: Array):
	var inputs: Matrix = Matrix.from_array(input_array)
	var targets: Matrix = Matrix.from_array(target_array)

	var layer_inputs: Matrix = inputs
	var outputs: Array[Matrix] = []
	var unactivated_outputs: Array[Matrix] = []
	for layer in network:
		var product: Matrix = Matrix.dot_product(layer.weights, layer_inputs)
		var sum: Matrix = Matrix.add(product, layer.bias)
		var map: Matrix = Matrix.map(sum, layer.activation.function)
		layer_inputs = map
		outputs.append(map)
		unactivated_outputs.append(sum)
	
	var expected_output: Matrix = targets
	
	var next_layer_errors: Matrix
	
	for layer_index in range(network.size() - 1, -1, -1):
		var layer: Dictionary = network[layer_index]
		var layer_outputs: Matrix = outputs[layer_index]
		#var layer_unactivated_output: Matrix = Matrix.transpose(unactivated_outputs[layer_index])

		if layer_index == network.size() - 1:
			var output_errors: Matrix = Matrix.subtract(expected_output, layer_outputs)
			next_layer_errors = output_errors
			
			var gradients: Matrix = Matrix.map(layer_outputs, layer.activation.derivative)
			gradients = Matrix.multiply(gradients, output_errors)
			gradients = Matrix.scalar(gradients, learning_rate)
			
			var weight_delta: Matrix
			if layer_index == 0:
				weight_delta = Matrix.dot_product(gradients, Matrix.transpose(inputs))
			else:
				weight_delta = Matrix.dot_product(gradients, Matrix.transpose(outputs[layer_index - 1]))
				
			network[layer_index].weights = Matrix.add(layer.weights, weight_delta)
			network[layer_index].bias = Matrix.add(layer.bias, gradients)
		else:
			var weights_hidden_output_t = Matrix.transpose(network[layer_index + 1].weights)
			var hidden_errors = Matrix.dot_product(weights_hidden_output_t, next_layer_errors)
			next_layer_errors = hidden_errors
			var hidden_gradient = Matrix.map(layer_outputs, layer.activation.derivative)
			hidden_gradient = Matrix.multiply(hidden_gradient, hidden_errors)
			hidden_gradient = Matrix.scalar(hidden_gradient, learning_rate)
			
			var inputs_t: Matrix
			
			if layer_index != 0:
				inputs_t = Matrix.transpose(outputs[layer_index - 1])
			else:
				inputs_t = Matrix.transpose(inputs)
			var weight_delta = Matrix.dot_product(hidden_gradient, inputs_t)
			
			network[layer_index].weights = Matrix.add(layer.weights, weight_delta)
			network[layer_index].bias = Matrix.add(layer.bias, hidden_gradient)
			
			
		
