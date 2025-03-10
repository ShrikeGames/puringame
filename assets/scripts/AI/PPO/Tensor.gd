extends Resource

class_name Tensor

var data: PackedFloat32Array
var gradients: PackedFloat32Array
var requires_grad: bool = true
var grad_fn: Callable

func _init(data: PackedFloat32Array, requires_grad: bool = true):
	self.data = data
	self.requires_grad = requires_grad
	# Initialize gradients array with same size as data
	self.gradients = PackedFloat32Array()
	for _i in range(data.size()):
		self.gradients.append(0.0)

func zero_gradients() -> void:
	if gradients.size() != data.size():
		# Reinitialize gradients if sizes don't match
		gradients = PackedFloat32Array()
		for _i in range(data.size()):
			gradients.append(0.0)
	else:
		# Zero out existing gradients
		for i in range(gradients.size()):
			gradients[i] = 0.0

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


func __sub(other: Tensor) -> Tensor:
	if data.size() != other.data.size():
		push_error("Tensor size mismatch in __sub")
		return Tensor.new(PackedFloat32Array())
		
	var result_data = PackedFloat32Array()
	for i in range(data.size()):
		result_data.append(data[i] - other.data[i])
	
	var result = Tensor.new(result_data, requires_grad or other.requires_grad)
	if result.requires_grad:
		var self_ref = self
		var other_ref = other
		result.grad_fn = func(grad: PackedFloat32Array):
			if self_ref.requires_grad:
				for i in range(data.size()):
					self_ref.gradients[i] += grad[i]
			if other_ref.requires_grad:
				for i in range(data.size()):
					other_ref.gradients[i] += -grad[i]
	return result

func pow(exponent: float) -> Tensor:
	var result_data = PackedFloat32Array()
	for i in range(data.size()):
		result_data.append(pow(data[i], exponent))
	
	var result = Tensor.new(result_data, requires_grad)
	if requires_grad:
		var self_ref = self
		var exp = exponent
		result.grad_fn = func(grad: PackedFloat32Array):
			for i in range(self_ref.data.size()):
				self_ref.gradients[i] += grad[i] * exp * pow(self_ref.data[i], exp - 1.0)
	return result

func clamp(min_value: float, max_value: float) -> Tensor:
	var result_data = PackedFloat32Array()
	for i in range(data.size()):
		result_data.append(clamp(data[i], min_value, max_value))
	
	var result = Tensor.new(result_data, requires_grad)
	if requires_grad:
		var self_ref = self
		var min_val = min_value
		var max_val = max_value
		result.grad_fn = func(grad: PackedFloat32Array):
			for i in range(self_ref.data.size()):
				if self_ref.data[i] > min_val and self_ref.data[i] < max_val:
					self_ref.gradients[i] += grad[i]
	return result

func debug_grad_flow(name: String = "") -> void:
	if requires_grad:
		print(name + " - data size: ", data.size(), 
			  " gradients size: ", gradients.size(),
			  " has grad_fn: ", grad_fn != null)
		if gradients.size() > 0:
			var grad_mean = 0.0
			for g in gradients:
				grad_mean += abs(g)
			grad_mean /= gradients.size()
			print("  grad mean: ", grad_mean)
	else:
		print(name + " - requires_grad: false")

func backward(gradient: PackedFloat32Array = PackedFloat32Array()) -> void:
	if not requires_grad:
		return
	
	# Initialize gradient if not provided
	if gradient.size() == 0:
		gradient = PackedFloat32Array()
		for _i in range(data.size()):
			gradient.append(1.0)
	elif gradient.size() != data.size():
		push_error("Gradient size mismatch: expected " + str(data.size()) + ", got " + str(gradient.size()))
		return
	
	# Apply gradient function if it exists
	if grad_fn:
		grad_fn.call(gradient)
	else:
		# Default behavior for leaf tensors
		for i in range(data.size()):
			gradients[i] += gradient[i]

# Add debug function to check gradients
func print_gradients(name: String = "") -> void:
	print(name, " gradients: size=", gradients.size())#, " values=", gradients)

# Update operation functions to properly track gradients
func __mul(other: Tensor) -> Tensor:
	if data.size() != other.data.size():
		push_error("Tensor size mismatch in __mul")
		return Tensor.new(PackedFloat32Array())
		
	var result_data = PackedFloat32Array()
	for i in range(data.size()):
		result_data.append(data[i] * other.data[i])
	
	var result = Tensor.new(result_data, requires_grad or other.requires_grad)
	if result.requires_grad:
		var self_ref = self
		var other_ref = other
		result.grad_fn = func(grad: PackedFloat32Array):
			if self_ref.requires_grad:
				for i in range(data.size()):
					self_ref.gradients[i] += grad[i] * other_ref.data[i]
			if other_ref.requires_grad:
				for i in range(data.size()):
					other_ref.gradients[i] += grad[i] * self_ref.data[i]
	return result

func __div(other: Tensor) -> Tensor:
	if data.size() != other.data.size():
		push_error("Tensor size mismatch in __div")
		return Tensor.new(PackedFloat32Array())
		
	var result_data = PackedFloat32Array()
	for i in range(data.size()):
		result_data.append(data[i] / other.data[i])
	
	var result = Tensor.new(result_data, requires_grad or other.requires_grad)
	if result.requires_grad:
		var self_ref = self
		var other_ref = other
		result.grad_fn = func(grad: PackedFloat32Array):
			if self_ref.requires_grad:
				for i in range(data.size()):
					self_ref.gradients[i] += grad[i] / other_ref.data[i]
			if other_ref.requires_grad:
				for i in range(data.size()):
					other_ref.gradients[i] += -grad[i] * self_ref.data[i] / (other_ref.data[i] * other_ref.data[i])
	return result

func __log() -> Tensor:
	var result_data = PackedFloat32Array()
	for value in data:
		result_data.append(log(value + 1e-8))
	var result = Tensor.new(result_data, requires_grad)
	if requires_grad:
		result.grad_fn = func(grad: PackedFloat32Array):
			for i in range(data.size()):
				gradients[i] += grad[i] / (data[i] + 1e-8)
	return result

func mean() -> Tensor:
	if data.size() == 0:
		push_error("Cannot compute mean of empty tensor")
		return Tensor.new(PackedFloat32Array([0.0]))
	
	var sum = 0.0
	for value in data:
		sum += value
	
	var mean_value = sum / data.size()
	var result = Tensor.new(PackedFloat32Array([mean_value]), requires_grad)
	
	if requires_grad:
		result.grad_fn = func(grad: PackedFloat32Array):
			var scale = grad[0] / data.size()
			for i in range(data.size()):
				gradients[i] += scale
	
	return result

func zero_grad() -> void:
	for i in range(gradients.size()):
		gradients[i] = 0.0

