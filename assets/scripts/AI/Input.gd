extends Node2D
class_name AIInput

@export var drop_line: Line2D
var value:Value
var disabled:bool = false

func _on_ready():
	drop_line.add_point(to_local(global_position))
	drop_line.add_point(to_local(global_position))
	init()

func init():
	drop_line.default_color = "000000"
	drop_line.width = 1
	drop_line.visible = true
	disabled = false
	value = Value.new()

func update(space_state) -> void:
	if disabled:
		return
	drop_line.set_point_position(0, to_local(global_position))
	
	var query = PhysicsRayQueryParameters2D.create(
		global_position, global_position + Vector2(0, 800)
	)
	query.exclude = [self]
	var result = space_state.intersect_ray(query)
	if result and is_instance_valid(result.collider) and result.collider.get_instance_id() != self.get_instance_id():
		drop_line.set_point_position(1, to_local(result.position))
		value.position = result.position
		if is_instance_of(result.collider, Purin):
			value.level = result.collider.get_meta("level", 0)
			value.purin = result.collider
		else:
			value.level = -1
			value.purin = null
			
	disabled = true
