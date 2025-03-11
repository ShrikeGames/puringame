extends Resource

class_name TrainingMetrics

var value_loss: float = 0.0
var policy_loss: float = 0.0
var entropy: float = 0.0
var advantage_mean: float = 0.0
var value_estimate_mean: float = 0.0
var probability_ratio_mean: float = 0.0
var timestamp: float = Time.get_unix_time_from_system()
var training_metrics_history:Array[String] = []

func collect_metrics(_value_loss: float, _policy_loss: float, _entropy: float, _advantages: Tensor, _values: Tensor, _ratio: Tensor) -> void:
	print("collect_metrics")
	self.value_loss = _value_loss
	self.policy_loss = _policy_loss
	self.entropy = _entropy
	self.advantage_mean = _advantages.mean().data[0]
	self.value_estimate_mean = _values.mean().data[0]
	self.probability_ratio_mean = _ratio.mean().data[0]
	
	# Log metrics
	var log_metrics_string:String = ""
	log_metrics_string += ("Training Metrics:")
	log_metrics_string += ("\n- [Metric] Value Loss: %.4f" % self.value_loss)
	log_metrics_string += ("\n- [Metric] Policy Loss: %.4f" % self.policy_loss)
	log_metrics_string += ("\n- [Metric] Entropy: %.4f" % self.entropy)
	log_metrics_string += ("\n- [Metric] Mean Advantage: %.4f" % self.advantage_mean)
	log_metrics_string += ("\n- [Metric] Mean Value Estimate: %.4f" % self.value_estimate_mean)
	log_metrics_string += ("\n- [Metric] Mean Probability Ratio: %.4f\n" % self.probability_ratio_mean)
	training_metrics_history.append(log_metrics_string)
	print(log_metrics_string)
