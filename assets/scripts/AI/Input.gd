extends Node2D
class_name AIInput

@export var drop_line: Line2D
@export var debug_text: RichTextLabel
var value:Value
var disabled:bool = false

func _on_ready():
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

func update(space_state) -> void:
	if disabled:
		return
	drop_line.set_point_position(0, to_local(global_position))
	
	var query = PhysicsRayQueryParameters2D.create(
		global_position, global_position + Vector2(0, 800)
	)
	query.exclude = [self]
	query.collision_mask = 1
	var result = space_state.intersect_ray(query)
	if result and is_instance_valid(result.collider) and result.collider.get_instance_id() != self.get_instance_id():
		drop_line.set_point_position(1, to_local(result.position))
		
		if is_instance_of(result.collider, Purin):
			var target_pos:Vector2 = result.position# + (result.normal * result.collider.get_meta("radius", 0))
			value.position = target_pos
			value.level = result.collider.get_meta("level", 0)
			value.purin = result.collider
		else:
			var target_pos:Vector2 = result.position
			value.position = target_pos
			value.level = -1
			value.purin = null
	else:
		var target_pos:Vector2 = Vector2(global_position.x, global_position.y + 800)
		value.position = target_pos
		value.level = -1
		value.purin = null
	disabled = true

