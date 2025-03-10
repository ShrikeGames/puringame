extends Node
class_name ExperiencePool

var buffer = []
var mutex = Mutex.new()

func add_experience(exp: Dictionary):
	mutex.lock()
	buffer.append(exp)
	mutex.unlock()

func get_buffer_size():
	return buffer.size()
	
func sample_batch(batch_size: int) -> Array:
	mutex.lock()
	var indices = []
	for _i in range(batch_size):
		indices.append(randi() % buffer.size())
	var batch = []
	for idx in indices:
		batch.append(buffer[idx])
	mutex.unlock()
	return batch
