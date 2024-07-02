extends RigidBody2D
class_name Purin
signal combine
signal bonk

var combined:bool = false;
func _on_body_entered(body:Node2D):
	if (self.has_meta("combined") and self.get_meta("combined")) or (body.has_meta("combined") and body.get_meta("combined")): 
		return;
	
	if not is_instance_of(self, Purin) or not is_instance_of(body, Purin): 
		return;
	
	if body.get_meta("type") == self.get_meta("type"):
		self.set_meta("combined", true);
		body.set_meta("combined", true);
		combine.emit(body, self);
	elif not self.has_meta("bonked") or not self.get_meta("bonked"):
		bonk.emit(body, self);
		self.set_meta("bonked", true);
