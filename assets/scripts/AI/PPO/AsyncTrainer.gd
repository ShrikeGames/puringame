extends Node
class_name AsyncTrainer

signal training_completed
signal training_started
signal training_error(error_message: String)

var daemon_thread: Thread
var queue_mutex: Mutex = Mutex.new()
var training_queue: Array = []
var is_running: bool = false

func _init() -> void:
	start_daemon()

func start_daemon() -> void:
	if is_running:
		return
		
	daemon_thread = Thread.new()
	is_running = true
	daemon_thread.start(Callable(self, "_daemon_loop"))

func _daemon_loop() -> void:
	while true:
		queue_mutex.lock()
		var training_data = _get_next_training_item()
		queue_mutex.unlock()
		# Debug print to verify we're getting data
		#print("Got training item: ", training_data)
		
		# Changed condition to properly check dictionary
		if training_data.size() > 0:
			print("_notify_training_started")
			# Perform training
			var success = _try_train(training_data)
			print("Training result: ", success)
			if success:
				call_deferred("_notify_training_completed")
		else:
			# No work to do, sleep briefly
			OS.delay_msec(100)
	

func _get_next_training_item() -> Array:
	if not training_queue.is_empty():
		return training_queue.pop_front()
	return []

func _try_train(local_data: Array) -> bool:
	print("try train")
	print("Before train function")
	Global.best_brain.train(local_data[0], local_data[1], local_data[2], local_data[3], local_data[4])
	print("After train function")
	Global.best_brain.save_model(Global.ai_brain_path)
	print("After save function")
	return true

func enqueue_training(states_data:Array, actions_data:Array, rewards_data:Array, next_states_data:Array, dones:Array) -> void:
	print("enqueue_training data")
	queue_mutex.lock()
	training_queue.append([states_data, actions_data, rewards_data, next_states_data, dones])
	if training_queue.size() >= 30:
		training_queue.pop_front()
	queue_mutex.unlock()
#	if training_queue.size() >= 10 and Global.batch_size < 1024:
#		Global.training_interval *= 1.5
#		Global.batch_size *= 2
#	elif training_queue.size() >= 2 and Global.batch_size > 64:
#		Global.training_interval *= 0.5
#		Global.batch_size *= 0.5
	print("training_queue size:", training_queue.size())

func _notify_training_started() -> void:
	print("training_started")
	emit_signal("training_started")

func _notify_training_completed() -> void:
	print("training_completed")
	emit_signal("training_completed")

func _notify_training_error(message: String) -> void:
	print("training_error:", message)
	emit_signal("training_error", message)

func _notification(what: int) -> void:
	if what == NOTIFICATION_PREDELETE:
		is_running = false
		if daemon_thread and daemon_thread.is_started():
			daemon_thread.wait_to_finish()
