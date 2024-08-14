class_name Activation
# source: https://github.com/ryash072007/Godot-AI-Kit
# Date: 2024-08-11

static func sigmoid(value: float, _row: int, _col: int) -> float:
	var result = 1 / (1 + exp(-value))
	if is_nan(result) or is_inf(result):
		print("value %s caused sigmoid to break with a value of %s"%[value, result])
	return max(-1,min(1, result))

static func dsigmoid(value: float, _row: int, _col: int) -> float:
	return value * (1 - value)

static func relu(value: float, _row: int, _col: int) -> float:
	var result = max(0.0, value)
	if is_nan(result) or is_inf(result):
		print("value %s caused relu to break with a value of %s"%[value, result])
	return result
	
static func linear(value: float, _row: int, _col: int) -> float:
	return value
	
static func dlinear(_value: float, _row: int, _col: int) -> float:
	return 1.0

static func drelu(value: float, _row: int, _col: int) -> float:
	if value < 0.0:
		return 0.0
	else:
		return 1.0

static func tanh_(value: float, _row: int, _col: int) -> float:
	return tanh(value)

static func dtanh(value: float, _row: int, _col: int) -> float:
	return 1 - pow(tanh(value), 2.0)

static func arcTan(value: float, _row: int, _col: int) -> float:
	return pow(tan(value), -1.0)

static func darcTan(value: float, _row: int, _col: int) -> float:
	return 1 / (pow(value, 2) + 1)

static func prelu(value: float, _row: int, _col: int) -> float:
	var alpha: float = 0.1
	return (alpha * value) if value < 0.0 else value

static func dprelu(value: float, _row: int, _col: int) -> float:
	var alpha: float = 0.1
	return alpha if value < 0.0 else 1.0

static func elu(value: float, _row: int, _col: int) -> float:
	var alpha: float = 0.1
	if value < 0:
		return alpha * (exp(value) - 1)
	else:
		return value

static func delu(value: float, _row: int, _col: int) -> float:
	var alpha: float = 0.1
	var result = (((alpha * (exp(value) - 1)) if value < 0.0 else value) + alpha) if value < 0.0 else 1.0
	if is_nan(result) or is_inf(result):
		print("value %s caused delu to break with a value of %s"%[value, result])
	return result

static func softplus(value: float, _row: int, _col: int) -> float:
	return log(exp(1)) * (1 + exp(value))

static func dsoftplus(value: float, _row: int, _col: int) -> float:
	return 1 / (1 + exp(-value))
