extends Optimizer

class_name AdamOptimizer

var parameters: Array
var learning_rate: float
var beta1: float = 0.9
var beta2: float = 0.999
var epsilon: float = 1e-8

var m: Array
var v: Array
var t: int = 0

func _init(parameters: Array, learning_rate: float):
	self.parameters = parameters
	self.learning_rate = learning_rate

	m = []
	v = []
	for param in parameters:
		var m_array = PackedFloat32Array()
		var v_array = PackedFloat32Array()
		for _p in range(param.size()):
			m_array.append(0.0)
			v_array.append(0.0)
		m.append(m_array)
		v.append(v_array)

func zero_grad():
	for param in parameters:
		for i in range(param.size()):
			param[i] = 0.0

func step():
	t += 1
	for i in range(parameters.size()):
		var param = parameters[i]
		var grad = param  # Assuming param contains gradients for simplicity
		for j in range(param.size()):
			m[i][j] = beta1 * m[i][j] + (1 - beta1) * grad[j]
			v[i][j] = beta2 * v[i][j] + (1 - beta2) * grad[j]
			var m_hat = m[i][j] / (1 - pow(beta1, t))
			var v_hat = v[i][j] / (1 - pow(beta2, t))
			param[j] -= learning_rate * m_hat / (sqrt(v_hat) + epsilon)
