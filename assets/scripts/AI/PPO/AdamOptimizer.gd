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
        m.append(PoolRealArray(param.size()))
        v.append(PoolRealArray(param.size()))

func zero_grad():
    # This function would reset gradients, but for simplicity, we assume gradients are managed externally
    pass

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