extends RigidBody2D
class_name Purin
signal combine
signal bonk

var combined: bool = false
var show_debug_info: bool = false
@export var debug_text: RichTextLabel
@export var debug_line: Line2D
@export var evil:Sprite2D

func _on_ready():
	debug_line.add_point(Vector2(0, 0))
	debug_line.add_point(Vector2(0, 0))
	debug_line.add_point(Vector2(0, 0))
	debug_line.add_point(Vector2(0, 0))
	debug_line.add_point(Vector2(0, 0))
	debug_line.add_point(Vector2(0, 0))
	debug_line.default_color = "333333"
	debug_line.width = 2

func _on_body_entered(body):
	if (
		(self.has_meta("combined") and self.get_meta("combined"))
		or (body.has_meta("combined") and body.get_meta("combined"))
	):
		return

	if not is_instance_of(self, Purin) or not is_instance_of(body, Purin):
		return

	if body.get_meta("type") == self.get_meta("type"):
		self.set_meta("combined", true)
		body.set_meta("combined", true)
		combine.emit(body, self)
	elif not self.has_meta("bonked") or not self.get_meta("bonked"):
		bonk.emit(body, self)
		self.set_meta("bonked", true)


func ray_cast(direction: Vector2, index: int):
	if show_debug_info:
		debug_line.set_point_position(index, to_local(global_position))
		debug_line.set_point_position(index + 1, to_local(global_position))
	var space_state = get_world_2d().direct_space_state

	var query = PhysicsRayQueryParameters2D.create(global_position, global_position + direction)
	query.exclude = [self]

	var result = space_state.intersect_ray(query)

	if (
		result
		and result.collider
		and is_instance_of(result.collider, Purin)
		and result.collider.get_instance_id() != self.get_instance_id()
	):
		if show_debug_info:
			debug_line.set_point_position(index + 1, to_local(result.position))
		return 1
	return 0


func num_above_purin():
	var search_radius: int = get_meta("radius", 200) * 1.25
	var count: int = (
		ray_cast(Vector2(0, -400), 0)
		+ ray_cast(Vector2(-search_radius, -search_radius), 2)
		+ ray_cast(Vector2(search_radius, -search_radius), 4)
	)
	return count


func number_possible_combines():
	var target_level = self.get_meta("level", 0) + 1
	var count: int = 0
	for body in get_colliding_bodies():
		if is_instance_of(body, Purin) and body.has_meta("level"):
			var level = body.get_meta("level", 0)
			if level == target_level:
				count += 1
	
	return count
