class_name NeuralNetworkAdvanced
# source: https://github.com/ryash072007/Godot-AI-Kit
# Date: 2024-08-11
var network: Array
var learning_rate: float = 0.001
var layer_structure: Array[int] = []
var layers: Array[Dictionary] = []

var max_training_data_rows:int = 2000
var mutation_rate:float = 0.3
var mutation_min_range:float = -1.0
var mutation_max_range:float = 1.0
var total_score:float = 0
var total_loss:float = 0
var fitness:float = 0
var target_fitness:float = 0
var MAPPINGS: Dictionary = {
	"FILLER_MASK": {
		"function": Callable(NeuralNetworkAdvanced, "remove_filler_values"),
		"derivative": Callable(NeuralNetworkAdvanced, "remove_filler_values"),
		"name": "remove_filler_values"
	},
}
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

func add_layer(nodes: int, activation: Dictionary = ACTIVATIONS.SIGMOID, mutate:bool = true, input_weights:Array=[], input_bias:Array=[], col_size = 1):
	var weights:Matrix
	var bias:Matrix
	
	if input_weights.is_empty():
		#print("Create new random weights")
		if layer_structure.size() != 0:
			weights = Matrix.rand(Matrix.new(nodes, layer_structure[-1]), 1)
	else:
		#print("Load weights from array")
		weights = Matrix.from_array2(input_weights, col_size)
		
	
	if input_bias.is_empty():
		bias = Matrix.rand(Matrix.new(nodes, 1), 0)
	else:
		bias = Matrix.from_array(input_bias)
	# don't mutate the input layer
	if mutate and layer_structure.size() != 0:
		weights = Matrix.mutate(weights, mutation_rate, mutation_min_range, mutation_max_range)
		bias = Matrix.mutate(bias, mutation_rate, mutation_min_range, mutation_max_range)
		
	var weight_rows:int = 0
	var weight_cols:int = 0
	if layer_structure.size() != 0:
		weight_rows = weights.rows
		weight_cols = weights.cols
		
	var layer_data: Dictionary = {
		"weights": weights,
		"bias": bias,
		"activation": activation,
		"activation_name": activation["name"],
		"size": nodes,
		"rows": weight_rows,
		"cols": weight_cols
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

static func remove_filler_values(value:float, _row: int, _col: int) -> float:
	if value != -1.0:
		return 1.0
	return 0.0

func calculate_loss(predicted_output: Matrix, expected_output: Matrix, mask: Matrix) -> float:
	var output_errors: Matrix = Matrix.subtract(expected_output, predicted_output)
	# Apply the mask to ignore filler values
	output_errors = Matrix.multiply(output_errors, mask)
	var squared_errors: Matrix = Matrix.square(output_errors)
	# Sum of all squared errors
	var sum_squared_errors: float = Matrix.sum(squared_errors)
	# Count of valid entries
	var valid_count: float = Matrix.sum(mask)
	
	# Avoid division by zero
	if valid_count == 0:
		return 0
		
	return sum_squared_errors / valid_count  # Return the mean squared error

func load_data_from_file(file_path: String, max_count:int = max_training_data_rows) -> Array:
	var inputs: Array = []
	var targets: Array = []
	var file_access := FileAccess.open(file_path, FileAccess.READ)
	file_access.seek(0)
	var rows_read:int = 0
	while not file_access.eof_reached() and (rows_read < max_count or max_count < 0):
		var line:String = file_access.get_line()
		if line != "" and line != "\n":
			var line_data:Array = line.split(", ")
			var input:Array = line_data
			for i in range(0,len(input)):
				input[i] = float(input[i])
			inputs.append(input)
			targets.append([float(line_data.pop_front())])
			rows_read += 1
	return [targets, inputs]
	
func train_bulk_cached(data:Array):
	print("Train NNA in bulk")
	if data.size() == 0:
		return

	var targets: Array = data[0]
	var inputs: Array = data[1]
	for i in range(targets.size()):
		train(inputs[i], targets[i])
	return targets.size()
	
func train_bulk(file_path: String, max_count:int = max_training_data_rows):
	var data:Array = load_data_from_file(file_path, max_count)
	
	if data.size() == 0:
		return

	var targets: Array = data[0]
	var inputs: Array = data[1]
	for i in range(targets.size()):
		train(inputs[i], targets[i])
	return targets.size()
	
func train(input_array: Array, target_array: Array):
	var inputs: Matrix = Matrix.from_array(input_array)
	var targets: Matrix = Matrix.from_array(target_array)
	train_matrix(inputs, targets)
	
func train_matrix(inputs: Matrix, targets: Matrix):
	var mask = Matrix.map(targets, self.MAPPINGS.FILLER_MASK.function)
	
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
	
	# output from last layer in network
	var predicted_output: Matrix = outputs[network.size() - 1]
	
	var loss:float = calculate_loss(predicted_output, expected_output, mask)
	total_loss += loss
	
	var next_layer_errors: Matrix
	
	for layer_index in range(network.size() - 1, -1, -1):
		var layer: Dictionary = network[layer_index]
		var layer_outputs: Matrix = outputs[layer_index]
		#var layer_unactivated_output: Matrix = Matrix.transpose(unactivated_outputs[layer_index])

		if layer_index == network.size() - 1:
			var output_errors: Matrix = Matrix.subtract(expected_output, layer_outputs)
			output_errors = Matrix.multiply(output_errors, mask)
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
			
			hidden_gradient = Matrix.multiply(hidden_gradient, next_layer_errors)
			hidden_gradient = Matrix.scalar(hidden_gradient, learning_rate)
			
			var inputs_t: Matrix
			
			if layer_index != 0:
				inputs_t = Matrix.transpose(outputs[layer_index - 1])
			else:
				inputs_t = Matrix.transpose(inputs)
			var weight_delta = Matrix.dot_product(hidden_gradient, inputs_t)
			
			network[layer_index].weights = Matrix.add(layer.weights, weight_delta)
			network[layer_index].bias = Matrix.add(layer.bias, hidden_gradient)

func add_layer_from_layer_data(layer_data:Dictionary, mutate:bool=false) -> void:
	var weights:Array = layer_data["weights"]
	var col_size:int = layer_data["cols"]
	var bias:Array = layer_data["bias"]
	var activation_name:String = layer_data["activation_name"]
	if activation_name == "relu":
		add_layer(layer_data["size"], ACTIVATIONS.RELU, mutate, weights, bias, col_size)
	elif activation_name == "linear":
		add_layer(layer_data["size"], ACTIVATIONS.LINEAR, mutate, weights, bias, col_size)
	elif activation_name == "sigmoid":
		add_layer(layer_data["size"], ACTIVATIONS.SIGMOID, mutate, weights, bias, col_size)

func copy(mutate:bool = false, custom_mutation_rate:float=mutation_rate) -> NeuralNetworkAdvanced:
	var nna_copy:NeuralNetworkAdvanced = NeuralNetworkAdvanced.new()
	nna_copy.learning_rate = learning_rate
	nna_copy.mutation_rate = custom_mutation_rate
	nna_copy.mutation_min_range = mutation_min_range
	nna_copy.mutation_max_range = mutation_max_range
	nna_copy.total_loss = total_loss
	nna_copy.total_score = total_score
	nna_copy.fitness = fitness
	for layer in self.layers:
		var layer_data:Dictionary = {
			"weights": Matrix.to_array(layer["weights"]),
			"bias": Matrix.to_array(layer["bias"]),
			"activation_name": layer["activation_name"],
			"size": layer["size"],
			"rows": layer["rows"],
			"cols": layer["cols"]
		}
		nna_copy.add_layer_from_layer_data(layer_data, mutate)
	
	return nna_copy
	
func cross_breed(nna:NeuralNetworkAdvanced, percent_split:float=0.5, mutate:bool=false) -> NeuralNetworkAdvanced:
	var child_nna:NeuralNetworkAdvanced = nna.copy(mutate)
	for layer_index in range(0, len(network)):
		var weights1:Matrix = network[layer_index]["weights"]
		var weights2:Matrix = nna.network[layer_index]["weights"]
		child_nna.network[layer_index]["weights"] = Matrix.cross_breed(weights1, weights2, percent_split)
		var bias1:Matrix = network[layer_index]["bias"]
		var bias2:Matrix = nna.network[layer_index]["bias"]
		child_nna.network[layer_index]["bias"] = Matrix.cross_breed(bias1, bias2, percent_split)
	return child_nna

func get_string_info():
	var info:String ="LR: %s MR: %s FS: %s (%s%%)"%[snapped(learning_rate, 0.001), mutation_rate, snapped(fitness, 0.001), snapped((fitness/target_fitness)*100, 0.1)]
	for layer in self.layers:
		info = "[%s]%s"%[layer["size"], info]
	return info
