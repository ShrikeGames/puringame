extends Node2D
@export var drop_line:Line2D;
var space_state
# Called when the node enters the scene tree for the first time.
func _ready():
	drop_line.add_point(Vector2(0,0));
	drop_line.add_point(Vector2(0,0));
	drop_line.add_point(Vector2(0,0));
	drop_line.add_point(Vector2(0,0));
	drop_line.default_color = "FF0000";
	drop_line.width = 5;

func _process(_delta):
	drop_line.set_point_position(0, to_local(global_position));
	drop_line.set_point_position(1, to_local(global_position));
	space_state = get_world_2d().direct_space_state;
	var query = PhysicsRayQueryParameters2D.create(global_position, global_position + Vector2(0, 800));
	query.exclude = [self];
	var result = space_state.intersect_ray(query);
	if result and result.collider and result.collider.get_instance_id() != self.get_instance_id():
		drop_line.set_point_position(1, to_local(result.position));
		drop_line.set_point_position(2, to_local(result.position));
