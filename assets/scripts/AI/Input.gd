extends Node2D
class_name AIInput

@export var drop_line: Line2D
@export var bounce_line: Line2D
@export var debug_text: RichTextLabel
var value:Value
var disabled:bool = false
var debug:bool = false
func _on_ready():
	drop_line.add_point(to_local(global_position))
	drop_line.add_point(to_local(global_position))
	drop_line.add_point(to_local(global_position))
	drop_line.add_point(to_local(global_position))
	bounce_line.add_point(to_local(global_position))
	bounce_line.add_point(to_local(global_position))
	
	
	init()

func init():
	drop_line.default_color = "00ff00"
	drop_line.width = 3
	drop_line.visible = true
	debug_text.visible = true
	disabled = false
	value = Value.new()

func reset():
	disabled = true
	drop_line.visible = false
	debug_text.visible = false
	bounce_line.visible = false
	bounce_line.set_point_position(0, Vector2(0,0))
	bounce_line.set_point_position(1, Vector2(0,0))
	drop_line.set_point_position(0, Vector2(0,0))
	drop_line.set_point_position(1, Vector2(0,0))
	drop_line.set_point_position(2, Vector2(0,0))
	drop_line.set_point_position(3, Vector2(0,0))
	
	
func raycast(space_state, start_position:Vector2=global_position, offset:Vector2=Vector2(0,0), direction:Vector2 = Vector2(0, 900), left_purin:Purin=null, right_purin:Purin=null):
	var value_result:Value = Value.new()
	var query = PhysicsRayQueryParameters2D.create(
		start_position + offset, start_position + direction
	)
	query.exclude = [self]
	if left_purin:
		query.exclude.append(left_purin.get_rid())
	if right_purin:
		query.exclude.append(right_purin.get_rid())
		
	query.collision_mask = 1
	var result = space_state.intersect_ray(query)
	if result and is_instance_valid(result.collider) and result.collider.get_instance_id() != self.get_instance_id():
		
		if is_instance_of(result.collider, Purin):
			var target_pos:Vector2 = result.position
			value_result.position = target_pos
			value_result.level = result.collider.get_meta("level", 0)
			value_result.purin = result.collider
		else:
			var target_pos:Vector2 = result.position
			value_result.position = target_pos
			value_result.level = -1
			value_result.purin = null
			
		
		return value_result
	
	value_result.level = -1
	value_result.purin = null
	return value_result
	
func update(space_state, radius, game, ai_controller, held_purin_level:int, held_is_evil:bool = false, next_purin_level:int = 0, next_purin_is_evil:bool = false, next_purin_cost:float = 9999) -> void:
	if disabled:
		return
	
	var left_value:Value = raycast(space_state, global_position, Vector2(-radius, 0))
	left_value.cost = left_value.evaluate(game, ai_controller, held_purin_level, held_is_evil, next_purin_level, next_purin_is_evil, next_purin_cost)
	
	
	var right_value:Value = raycast(space_state, global_position, Vector2(radius, 0))
	right_value.cost = right_value.evaluate(game, ai_controller, held_purin_level, held_is_evil, next_purin_level, next_purin_is_evil, next_purin_cost)
	
	var new_position:Vector2
	value.normal = (right_value.position - left_value.position).normalized()
	# return the worst of the two since it will hit something on the way down for the better one
	if left_value.cost >= right_value.cost:
		new_position = Vector2((left_value.position.x + right_value.position.x) * 0.5, left_value.position.y)
		value.level = left_value.level
		value.purin = left_value.purin
		value.cost = left_value.cost
#		drop_line.set_point_position(0, Vector2(to_local(left_value.position).x, 0))
#		drop_line.set_point_position(1, to_local(left_value.position))
#		drop_line.set_point_position(2, Vector2(to_local(right_value.position).x, to_local(left_value.position).y))
#		drop_line.set_point_position(3, Vector2(to_local(right_value.position).x, 0))
		
		value.position = new_position
	else:
		new_position = Vector2((left_value.position.x + right_value.position.x) * 0.5, right_value.position.y)
		value.level = right_value.level
		value.purin = right_value.purin
		value.cost = right_value.cost
		
#		drop_line.set_point_position(0, Vector2(to_local(left_value.position).x, 0))
#		drop_line.set_point_position(1, Vector2(to_local(left_value.position).x, to_local(right_value.position).y))
#		drop_line.set_point_position(2, to_local(right_value.position))
#		drop_line.set_point_position(3, Vector2(to_local(right_value.position).x, 0))
		
		value.position = new_position
	
	drop_line.set_point_position(0, Vector2(to_local(left_value.position).x, 0))
	drop_line.set_point_position(1, to_local(left_value.position))
	drop_line.set_point_position(2, to_local(right_value.position))
	drop_line.set_point_position(3, Vector2(to_local(right_value.position).x, 0))
	
	if value.purin and held_purin_level != value.purin.get_meta("level"):
		var reflection_distance:float = 100
		var slope:Vector2 = value.normal * (reflection_distance)
		var bounce_start_pos:Vector2 = value.position
		var bounce_value:Value = raycast(space_state, bounce_start_pos, Vector2(0,0), slope, left_value.purin, right_value.purin)

		# if it collides with something then it's good, the purin probably won't move too far
		if bounce_value.position:
			bounce_value.cost = bounce_value.evaluate(game, ai_controller, held_purin_level, held_is_evil, next_purin_level, next_purin_is_evil, next_purin_cost)
			if bounce_value.purin != null and bounce_value.purin != value.purin and bounce_value.cost < value.cost:
				value.level = bounce_value.level
				value.purin = bounce_value.purin
				value.cost = bounce_value.cost
				value.position = bounce_start_pos
			bounce_line.set_point_position(0, to_local(bounce_start_pos))
			bounce_line.set_point_position(1, to_local(bounce_value.position))
		else:
			if value.cost > 0:
				value.cost += 2
