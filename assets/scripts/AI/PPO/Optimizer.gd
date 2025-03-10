extends Resource

class_name Optimizer

func _init():
	pass

func zero_grad():
	# This function should be overridden by subclasses to reset gradients
	pass

func step():
	# This function should be overridden by subclasses to update parameters
	pass
