extends RigidBody2D
class_name Purin
signal combine
signal bonk

var combined: bool = false
var show_debug_info: bool = false
@export var image:Sprite2D
@export var collider:CollisionShape2D
@export var debug_text: RichTextLabel
@export var debug_line: Line2D
@export var evil:Sprite2D
@export var game_over_countdown:AnimatedSprite2D
var game_over_timer_sec:float

func _on_ready():
	debug_line.add_point(Vector2(0, 0))
	debug_line.add_point(Vector2(0, 0))
	debug_line.add_point(Vector2(0, 0))
	debug_line.add_point(Vector2(0, 0))
	debug_line.add_point(Vector2(0, 0))
	debug_line.add_point(Vector2(0, 0))
	debug_line.add_point(Vector2(0, 0))
	debug_line.add_point(Vector2(0, 0))
	debug_line.add_point(Vector2(0, 0))
	debug_line.add_point(Vector2(0, 0))
	debug_line.add_point(Vector2(0, 0))
	debug_line.add_point(Vector2(0, 0))
	debug_line.default_color = "333333"
	debug_line.width = 2
	game_over_timer_sec = 0
	
func reset_lines():
	for i in range(0, debug_line.get_point_count()):
		debug_line.set_point_position(i, Vector2(0,0))

func _on_body_entered(body):
	if (
		(self.has_meta("combined") and self.get_meta("combined"))
		or (body.has_meta("combined") and body.get_meta("combined"))
	):
		return

	if not is_instance_of(self, Purin) or not is_instance_of(body, Purin):
		return

	if body.get_meta("level") == self.get_meta("level"):
		self.set_meta("combined", true)
		body.set_meta("combined", true)
		combine.emit(body, self)
	elif not self.has_meta("bonked") or not self.get_meta("bonked"):
		bonk.emit(body, self)
		self.set_meta("bonked", true)


func ray_cast(direction: Vector2, index: int, target_level:int=-1, show_lines:bool=false):
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
		if target_level >= 0:
			#print(target_level)
			if result.collider.get_meta("level", -1) == target_level:
				if show_debug_info and show_lines:
					debug_line.set_point_position(index, to_local(global_position))
					debug_line.set_point_position(index + 1, to_local(result.position))
				return 1
			return 0
		if show_debug_info and show_lines:
			debug_line.set_point_position(index, to_local(global_position))
			debug_line.set_point_position(index + 1, to_local(result.position))
		return 1
	return 0


func num_above_purin():
	var search_radius: int = get_meta("radius", 200) * 1.25
	var count: int = (
		ray_cast(Vector2(0, -400), 0)
		+ ray_cast(Vector2(-search_radius, -search_radius*0.5), 2)
		+ ray_cast(Vector2(search_radius, -search_radius*0.5), 4)
	)
	return count


func number_possible_combines():
	reset_lines()
	var target_level = self.get_meta("level", 0)
	var search_radius: int = get_meta("radius", 200) * 1.25
	var count: int = (
		+ ray_cast(Vector2(search_radius, 0), 6, target_level, true)
		+ ray_cast(Vector2(-search_radius, 0), 8, target_level, true)
		+ ray_cast(Vector2(search_radius, search_radius), 10, target_level, true)
		+ ray_cast(Vector2(-search_radius, search_radius), 12, target_level, true)
	)
	return count
