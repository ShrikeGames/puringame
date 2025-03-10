extends Resource

class_name NeuralNetwork

var input_size: int
var hidden_size: int
var output_size: int

var weights_input_hidden: PoolRealArray
var weights_hidden_output: PoolRealArray
var bias_hidden: PoolRealArray
var bias_output: PoolRealArray

func _init(input_size: int, hidden_size: int, output_size: int):
    self.input_size = input_size
    self.hidden_size = hidden_size
    self.output_size = output_size

    weights_input_hidden = PoolRealArray()
    weights_hidden_output = PoolRealArray()
    bias_hidden = PoolRealArray()
    bias_output = PoolRealArray()

    # Initialize weights and biases with random values
    for i in range(input_size * hidden_size):
        weights_input_hidden.append(randf() * 2 - 1)
    for i in range(hidden_size * output_size):
        weights_hidden_output.append(randf() * 2 - 1)
    for i in range(hidden_size):
        bias_hidden.append(randf() * 2 - 1)
    for i in range(output_size):
        bias_output.append(randf() * 2 - 1)

func forward(input: PoolRealArray) -> PoolRealArray:
    var hidden = PoolRealArray()
    for i in range(hidden_size):
        var sum = 0.0
        for j in range(input_size):
            sum += input[j] * weights_input_hidden[i * input_size + j]
        sum += bias_hidden[i]
        hidden.append(tanh(sum))

    var output = PoolRealArray()
    for i in range(output_size):
        var sum = 0.0
        for j in range(hidden_size):
            sum += hidden[j] * weights_hidden_output[i * hidden_size + j]
        sum += bias_output[i]
        output.append(sum)

    return output

func parameters() -> Array:
    return [weights_input_hidden, weights_hidden_output, bias_hidden, bias_output]