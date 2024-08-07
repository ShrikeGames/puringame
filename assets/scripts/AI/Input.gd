extends Node2D
class_name AIInput

@export var drop_line: Line2D
@export var debug_text: RichTextLabel
var value:Value
var disabled:bool = false

func _on_ready():
	drop_line.add_point(to_local(global_position))
	drop_line.add_point(to_local(global_position))
	drop_line.add_point(to_local(global_position))
	drop_line.add_point(to_local(global_position))
	
	init()

func init():
	drop_line.default_color = "00ff00"
	drop_line.width = 3
	drop_line.visible = true
	debug_text.visible = true
	disabled = false
	value = Value.new()

func raycast(space_state, offset:Vector2):
	var value_result:Value = Value.new()
	var query = PhysicsRayQueryParameters2D.create(
		global_position + offset, global_position + Vector2(0, 900)
	)
	query.exclude = [self]
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
	
	value_result.position = Vector2(global_position.x, global_position.y + 800)
	value_result.level = -1
	value_result.purin = null
	return value_result
	
func update(space_state, radius, game, ai_controller, held_purin_level, next_purin_cost) -> void:
	if disabled:
		return
	
	var left_value:Value = raycast(space_state, Vector2(-radius, 0))
	left_value.cost = left_value.evaluate(game, ai_controller, held_purin_level, next_purin_cost)
	
	
	var right_value:Value = raycast(space_state, Vector2(radius, 0))
	right_value.cost = right_value.evaluate(game, ai_controller, held_purin_level, next_purin_cost)
	
	
	# return the worst of the two since it will hit something on the way down for the better one
	if left_value.cost >= right_value.cost:
		var new_position:Vector2 = Vector2((left_value.position.x + right_value.position.x) * 0.5, left_value.position.y)
		
		drop_line.set_point_position(0, Vector2(to_local(left_value.position).x, 0))
		drop_line.set_point_position(1, to_local(left_value.position))
		drop_line.set_point_position(2, Vector2(to_local(right_value.position).x, to_local(left_value.position).y))
		drop_line.set_point_position(3, Vector2(to_local(right_value.position).x, 0))
		value.level = left_value.level
		value.purin = left_value.purin
		value.cost = left_value.cost
		value.position = new_position
	else:
		var new_position:Vector2 = Vector2((left_value.position.x + right_value.position.x) * 0.5, right_value.position.y)
		
		drop_line.set_point_position(0, Vector2(to_local(left_value.position).x, 0))
		drop_line.set_point_position(1, Vector2(to_local(left_value.position).x, to_local(right_value.position).y))
		drop_line.set_point_position(2, to_local(right_value.position))
		drop_line.set_point_position(3, Vector2(to_local(right_value.position).x, 0))
		value.level = right_value.level
		value.purin = right_value.purin
		value.cost = right_value.cost
		value.position = new_position
	
	

