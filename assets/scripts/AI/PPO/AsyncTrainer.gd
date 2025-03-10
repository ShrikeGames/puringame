extends Node
class_name AsyncTrainer

signal training_completed

var thread: Thread
var mutex: Mutex
var is_training: bool = false
var training_data: Dictionary
var training_queue = []
var queue_mutex = Mutex.new()

func _init():
	mutex = Mutex.new()

func start_training(data: Dictionary):
	queue_mutex.lock()
	training_queue.append(data)
	queue_mutex.unlock()

func _process_training_queue():
	while true:
		queue_mutex.lock()
		if training_queue.is_empty():
			queue_mutex.unlock()
			break
			
		var data = training_queue.pop_front()
		queue_mutex.unlock()
		mutex.lock()
		is_training = true
		mutex.unlock()
		thread = Thread.new()
		thread.start(Callable(self, "_train_on_batch"))
		thread.wait_to_finish()
		mutex.lock()
		is_training = false
		Global.best_brain.save_model(Global.ai_brain_path)
		mutex.unlock()

func _train_on_batch(data: Dictionary):
	print("Train on batch")
	# Do training in background
	var ppo = data.ppo
	ppo.train(
		data.states,
		data.actions,
		data.rewards,
		data.next_states,
		data.dones
	)

