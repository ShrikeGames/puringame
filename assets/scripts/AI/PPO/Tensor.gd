extends Object
class_name Tensor

const EPSILON: float = 1e-8

# Multiply a matrix (Array of Arrays) by a vector.
# Assumes:
# - matrix is of dimensions [rows x cols]
# - vector is of length equal to rows.
# Returns a vector of length equal to cols.
static func matrix_vector_mul(matrix: Array, vector: Array) -> Array:
	var result: Array = []
	if matrix.size() == 0:
		return result
	var rows: int = matrix.size()
	var cols: int = matrix[0].size()
	# For each column j, sum over rows: matrix[i][j] * vector[i]
	for j in range(cols):
		var sum: float = 0.0
		for i in range(rows):
			sum += matrix[i][j] * vector[i]
		result.append(sum)
	return result

# Elementwise addition of two vectors.
static func vector_add(v1: Array, v2: Array) -> Array:
	var result: Array = []
	for i in range(v1.size()):
		result.append(v1[i] + v2[i])
	return result

# Elementwise subtraction of two vectors.
static func vector_subtract(v1: Array, v2: Array) -> Array:
	var result: Array = []
	for i in range(v1.size()):
		result.append(v1[i] - v2[i])
	return result

static func vector_subtract_single_value(v1: Array, v2: float) -> Array:
	var result: Array = []
	for i in range(v1.size()):
		result.append(v1[i] - v2)
	return result

# Elementwise addition of two matrices.
static func matrix_add(m1: Array, m2: Array) -> Array:
	var result: Array = []
	for i in range(m1.size()):
		var row: Array = []
		for j in range(m1[i].size()):
			row.append(m1[i][j] + m2[i][j])
		result.append(row)
	return result

# Elementwise subtraction of two matrices.
static func matrix_subtract(m1: Array, m2: Array) -> Array:
	var result: Array = []
	for i in range(m1.size()):
		var row: Array = []
		for j in range(m1[i].size()):
			row.append(m1[i][j] - m2[i][j])
		result.append(row)
	return result

# Outer product of two vectors: returns a matrix.
static func outer_product(v1: Array, v2: Array) -> Array:
	var result: Array = []
	for i in range(v1.size()):
		var row: Array = []
		for j in range(v2.size()):
			row.append(v1[i] * v2[j])
		result.append(row)
	return result

# Transpose of a matrix.
static func transpose(matrix: Array) -> Array:
	if matrix.size() == 0:
		return []
	var result: Array = []
	var rows: int = matrix.size()
	var cols: int = matrix[0].size()
	for j in range(cols):
		var new_row: Array = []
		for i in range(rows):
			new_row.append(matrix[i][j])
		result.append(new_row)
	return result

# ReLU activation applied elementwise.
static func relu(vector: Array) -> Array:
	var result: Array = []
	for v in vector:
		result.append(max(0.0, v))
	return result

# Derivative of ReLU applied elementwise.
static func relu_derivative(vector: Array) -> Array:
	var result: Array = []
	for v in vector:
		var v2: float = 0
		if v > 0.0:
			v2 = 1.0
		result.append(v2)
	return result

# Softmax activation.
static func softmax(vector: Array) -> Array:
	var max_val: float = - INF
	for v in vector:
		if v > max_val:
			max_val = v
	var exps: Array = []
	var sum_exp: float = 0.0
	for v in vector:
		var exp_val: float = exp(v - max_val)
		exps.append(exp_val)
		sum_exp += exp_val
	var result: Array = []
	for val in exps:
		result.append(val / sum_exp)
	return result

# Returns a vector (Array) of zeros of the given size.
static func zeros_vector(size: int) -> Array:
	var result: Array = []
	for i in range(size):
		result.append(0.0)
	return result

# Returns a matrix of zeros with the given number of rows and columns.
static func zeros_matrix(rows: int, cols: int) -> Array:
	var result: Array = []
	for i in range(rows):
		var row: Array = []
		for j in range(cols):
			row.append(0.0)
		result.append(row)
	return result

# Divide every element of a matrix (or vector) by a scalar.
static func scalar_divide(mat: Array, scalar: float) -> Array:
	var result: Array = []
	for i in range(mat.size()):
		if mat[i] is Array:
			var row: Array = []
			for j in range(mat[i].size()):
				row.append(mat[i][j] / scalar)
			result.append(row)
		else:
			result.append(mat[i] / scalar)
	return result

# Multiply every element of a matrix by a scalar.
static func matrix_scalar_multiply(mat: Array, scalar: float) -> Array:
	var result: Array = []
	for i in range(mat.size()):
		var row: Array = []
		for j in range(mat[i].size()):
			row.append(mat[i][j] * scalar)
		result.append(row)
	return result

# Multiply every element of a vector by a scalar.
static func vector_scalar_multiply(vector: Array, scalar: float) -> Array:
	var result: Array = []
	for v in vector:
		result.append(v * scalar)
	return result

# Divide every element of a vector by a scalar.
static func vector_divide(vector: Array, scalar: float) -> Array:
	var result: Array = []
	for v in vector:
		result.append(v / scalar)
	return result

# Elementwise multiplication of two vectors.
static func elementwise_multiply(v1: Array, v2: Array) -> Array:
	var result: Array = []
	for i in range(v1.size()):
		result.append(v1[i] * v2[i])
	return result

# Batch normalization
static func batch_norm(vector: Array, params: Dictionary) -> Array:
	var mean: float = params.get("mean", 0.0)
	var variance: float = params.get("variance", 1.0)
	var result: Array = []
	for v in vector:
		result.append((v - mean) / sqrt(variance + EPSILON))
	return result

static func sigmoid(vector: Array) -> Array:
	var result: Array = []
	for v in vector:
		result.append(1.0 / (1.0 + exp(-v)))
	return result

static func clamp(vector: Array, min_val: float, max_val: float) -> Array:
	var result: Array = []
	for v in vector:
		result.append(clampf(v, min_val, max_val))
	return result

static func mean(vector: Array) -> float:
	"""
	Calculates the mean (average) of a vector (1D array).
	- vector: The input array of floats.
	- Returns: The mean of the vector.
	"""
	if vector.size() == 0:
		return 0.0  # Return 0 for an empty array to avoid division by zero
	var sum: float = 0.0
	for v in vector:
		sum += v
	return sum / vector.size()
	
static func std(vector: Array) -> float:
	"""
	Calculates the standard deviation of a vector (1D array).
	- vector: The input array of floats.
	- Returns: The standard deviation of the vector.
	"""
	if vector.size() == 0:
		return 0.0  # Return 0 for an empty array to avoid division by zero
	var mean_val: float = mean(vector)
	var variance: float = 0.0
	for v in vector:
		variance += pow(v - mean_val, 2)
		variance /= vector.size()
	return sqrt(variance)
