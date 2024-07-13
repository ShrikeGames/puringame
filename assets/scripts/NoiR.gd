extends Node2D
class_name NoiR
@export var drop_line: Line2D
@export var held_purin: Sprite2D
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
	var result = space_state.intersect_ray(query)
	if result and is_instance_valid(result.collider) and result.collider.get_instance_id() != self.get_instance_id():
		drop_line.set_point_position(1, to_local(result.position))

func change_held_purin(new_purin_texture:Texture2D):
	held_purin.texture = new_purin_texture


