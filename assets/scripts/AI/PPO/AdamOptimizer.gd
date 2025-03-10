extends Optimizer

class_name AdamOptimizer

var parameters: Dictionary
var learning_rate: float
var beta1: float = 0.9
var beta2: float = 0.999
var epsilon: float = 1e-8

var m: Dictionary
var v: Dictionary
var t: int = 0

func _init(parameters: Dictionary, learning_rate: float = 0.001):
	self.parameters = parameters
	self.learning_rate = learning_rate
	
	m = {}
	v = {}
	
	for key in parameters.keys():
		m[key] = Tensor.new(PackedFloat32Array())
		v[key] = Tensor.new(PackedFloat32Array())
		
		for _i in range(parameters[key].size()):
			m[key].data.append(0.0)
			v[key].data.append(0.0)

func zero_grad():
	for param in parameters.values():
		param.zero_gradients()

func step():
	t += 1
	
	for key in parameters.keys():
		var param = parameters[key]
		if not param.gradients:
			push_error("No gradients found for parameter: " + str(key))
			continue
			
		for i in range(param.size()):
			if i >= param.gradients.size():
				push_error("Gradient index out of bounds: " + str(i))
				continue
				
			m[key].data[i] = beta1 * m[key].data[i] + (1 - beta1) * param.gradients[i]
			v[key].data[i] = beta2 * v[key].data[i] + (1 - beta2) * param.gradients[i] * param.gradients[i]
			
			var m_hat = m[key].data[i] / (1 - pow(beta1, t))
			var v_hat = v[key].data[i] / (1 - pow(beta2, t))
			
			param.data[i] -= learning_rate * m_hat / (sqrt(v_hat) + epsilon)
