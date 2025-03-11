extends Node
class_name AsyncTrainer

signal training_completed
signal training_started
signal training_error(error_message: String)

var daemon_thread: Thread
var queue_mutex: Mutex = Mutex.new()
var training_queue: Array[Dictionary] = []
var is_running:bool = false

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
		#print("asFASDGDS")
		queue_mutex.lock()
		var training_data = _get_next_training_item()
		queue_mutex.unlock()
		# Debug print to verify we're getting data
		#print("Got training item: ", training_data)
		
		# Changed condition to properly check dictionary
		if training_data:
			print("_notify_training_started")
			# Create thread-local copy by creating new Tensors with same data
			var local_data := {
				"states": Tensor.from_array(training_data.states.data),
				"actions": Tensor.from_array(training_data.actions.data),
				"rewards": Tensor.from_array(training_data.rewards.data),
				"next_states": Tensor.from_array(training_data.next_states.data),
				"dones": Tensor.from_array(training_data.dones.data),
				"ppo": training_data.ppo
			}
			print("Local data created, attempting training...")
			
			# Perform training
			var success = _try_train(local_data.ppo, local_data)
			print("Training result: ", success)
			if success:
				print("_notify_training_completed")
		else:
			# No work to do, sleep briefly
			OS.delay_msec(100)
	

func _get_next_training_item() -> Dictionary:
	if not training_queue.is_empty():
		return training_queue.pop_front()
	return {}

func _verify_training_data(data: Dictionary) -> bool:
	return (data != null
		and data.has("states")
		and data.has("actions")
		and data.has("rewards")
		and data.has("next_states")
		and data.has("dones")
		and data.has("ppo")
		and is_instance_valid(data.ppo))

func _try_train(ppo, local_data: Dictionary) -> bool:
	print("try train")
	if not is_instance_valid(ppo):
		call_deferred("_notify_training_error", "Invalid PPO instance")
		return false
	
	ppo.thread_safe_train(local_data)
	# new brain was trained, replace the global one
	Global.best_brain = ppo
	Global.best_brain.save_model(Global.ai_brain_path)
	return true

func enqueue_training(data: Dictionary) -> void:
	print("enqueue_training data size:", data.size())
	queue_mutex.lock()
	training_queue.append(data)
	queue_mutex.unlock()
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
