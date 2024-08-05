extends Node2D
class_name NoiR
@export var drop_line: Line2D
@export var held_purin: PurinIndicator
var space_state


# Called when the node enters the scene tree for the first time.
func _on_ready():
	drop_line.add_point(Vector2(0, 0))
	drop_line.add_point(Vector2(0, 0))
	drop_line.default_color = "FF0000"
	drop_line.width = 5
	

func _process(_delta):
	drop_line.set_point_position(0, to_local(global_position))
	space_state = get_world_2d().direct_space_state
	var query = PhysicsRayQueryParameters2D.create(
		global_position, global_position + Vector2(0, 800)
	)
	query.exclude = [self]
	query.collision_mask = 1
	var result = space_state.intersect_ray(query)
	if (
		result
		and is_instance_valid(result.collider)
		and result.collider.visible
		and result.collider.get_instance_id() != self.get_instance_id()
	):
		drop_line.set_point_position(1, to_local(result.position))


func change_held_purin(purin_info:Dictionary):
	held_purin.set_frame(purin_info["level"])
	held_purin.evil = purin_info["evil"]
	held_purin.evil_visual.visible =held_purin.evil
		
	held_purin.pause()
