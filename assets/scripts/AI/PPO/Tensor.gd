extends Resource

class_name Tensor

var data: PackedFloat32Array

func _init(data: PackedFloat32Array):
	self.data = data

static func from_array(array: PackedFloat32Array) -> Tensor:
	return Tensor.new(array)

func size() -> int:
	return data.size()

func sample() -> int:
	# Assuming the tensor represents probabilities, sample an index based on these probabilities
	var cumulative_sum = 0.0
	var random_value = randf()
	for i in range(data.size()):
		cumulative_sum += data[i]
		if random_value < cumulative_sum:
			return i
	return data.size() - 1

func __div(other: Tensor) -> Tensor:
	var result = PackedFloat32Array()
	for i in range(data.size()):
		result.append(data[i] / other.data[i])
	return Tensor.new(result)

func __mul(other: Tensor) -> Tensor:
	var result = PackedFloat32Array()
	for i in range(data.size()):
		result.append(data[i] * other.data[i])
	return Tensor.new(result)

func __sub(other: Tensor) -> Tensor:
	var result = PackedFloat32Array()
	for i in range(data.size()):
		result.append(data[i] - other.data[i])
	return Tensor.new(result)

func pow(exponent: float) -> Tensor:
	var result = PackedFloat32Array()
	for i in range(data.size()):
		result.append(pow(data[i], exponent))
	return Tensor.new(result)

func mean() -> float:
	var sum = 0.0
	for i in range(data.size()):
		sum += data[i]
	return sum / data.size()

func clamp(min_value: float, max_value: float) -> Tensor:
	var result = PackedFloat32Array()
	for i in range(data.size()):
		result.append(clamp(data[i], min_value, max_value))
	return Tensor.new(result)
