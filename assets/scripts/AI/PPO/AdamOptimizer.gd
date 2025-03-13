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

func _init(_parameters: Dictionary, _learning_rate: float = 0.001):
	self.parameters = _parameters
	self.learning_rate = _learning_rate
	
	m = {}
	v = {}
	
	#Initialize momentum and velocity for each parameter tensor
	for key in parameters.keys():
		var params = parameters[key]
		m[key] = []
		v[key] = []
		
		# Handle array of tensors
		if params is Array:
			for i in range(params.size()):
				#m[key].append(Tensor.new(PackedFloat32Array()))
				#v[key].append(Tensor.new(PackedFloat32Array()))
				for _j in range(params[i].size()):
					m[key][i].data.append(0.0)
					v[key][i].data.append(0.0)
		# Handle single tensor
		else:
			#m[key] = [Tensor.new(PackedFloat32Array())]
			#v[key] = [Tensor.new(PackedFloat32Array())]
			for _i in range(params.size()):
				m[key][0].data.append(0.0)
				v[key][0].data.append(0.0)

func zero_grad():
	for param in parameters.values():
		param.zero_gradients()

func step():
	t += 1
	
	for key in parameters.keys():
		var params = parameters[key]
		
		# Handle array of tensors
		if params is Array:
			for i in range(params.size()):
				var param = params[i]
				if not param.gradients:
					push_error("No gradients found for parameter: " + str(key) + "[" + str(i) + "]")
					continue
				
				for j in range(param.size()):
					if j >= param.gradients.size():
						push_error("Gradient index out of bounds: " + str(j))
						continue
					
					m[key][i].data[j] = beta1 * m[key][i].data[j] + (1 - beta1) * param.gradients[j]
					v[key][i].data[j] = beta2 * v[key][i].data[j] + (1 - beta2) * param.gradients[j] * param.gradients[j]
					
					var m_hat = m[key][i].data[j] / (1 - pow(beta1, t))
					var v_hat = v[key][i].data[j] / (1 - pow(beta2, t))
					
					param.data[j] -= learning_rate * m_hat / (sqrt(v_hat) + epsilon)
		# Handle single tensor
		else:
			var param = params
			if not param.gradients:
				push_error("No gradients found for parameter: " + str(key))
				continue
			
			for i in range(param.size()):
				if i >= param.gradients.size():
					push_error("Gradient index out of bounds: " + str(i))
					continue
				
				m[key][0].data[i] = beta1 * m[key][0].data[i] + (1 - beta1) * param.gradients[i]
				v[key][0].data[i] = beta2 * v[key][0].data[i] + (1 - beta2) * param.gradients[i] * param.gradients[i]
				
				var m_hat = m[key][0].data[i] / (1 - pow(beta1, t))
				var v_hat = v[key][0].data[i] / (1 - pow(beta2, t))
				
				param.data[i] -= learning_rate * m_hat / (sqrt(v_hat) + epsilon)
