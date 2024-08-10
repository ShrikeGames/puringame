extends RigidBody2D
class_name Purin
signal combine
signal bonk

var combined: bool = false
var show_debug_info: bool = false
@export var image: Sprite2D
@export var collider: CollisionShape2D
@export var number_label: RichTextLabel
@export var debug_text: RichTextLabel
@export var debug_line: Line2D
@export var evil: bool
@export var game_over_countdown: AnimatedSprite2D
@export var particle_system: GPUParticles2D
var game_over_timer_sec: float


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
	if Global.numbered_purin and number_label:
		number_label.text = "[center][color=fff]%s[/color][/center]"%[get_meta("level", 1)]
		number_label.visible = true

func reset_lines():
	for i in range(0, debug_line.get_point_count()):
		debug_line.set_point_position(i, Vector2(0, 0))


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


func cast_ray_purin(start_pos:Vector2, x_offset:float, space_state, target_purin:Purin = null):
	var search_height:float = 1200
	var query = PhysicsRayQueryParameters2D.create(
		start_pos + Vector2(x_offset, 0), start_pos + Vector2(0, -search_height)
	)
	query.exclude = [self]
	if target_purin!= null:
		query.exclude.append(target_purin.get_rid())
	query.collision_mask = 1
	query.hit_from_inside = true
	var result = space_state.intersect_ray(query)
	if result and is_instance_valid(result.collider):
		return true
		
	return false
	
func can_reach_purin(purin:Purin, _game:PlayerController, space_state, drop_purin_level:int=0):
	if purin.has_meta("offset_to_reach"):
		return true
		
	var radius:float = purin.get_meta("radius", 10)
	var start_pos:Vector2 = Vector2(purin.global_position.x, purin.global_position.y - radius -5)
	var offset_size:float = Global.purin_sizes[drop_purin_level] * 0.5
	
	# check if you can drop it directly on top without hitting something to either side
	var center_hits:bool = cast_ray_purin(start_pos, 0, space_state, purin)
	var left_hits:bool = cast_ray_purin(start_pos, -offset_size, space_state, null)
	var right_hits:bool = cast_ray_purin(start_pos, offset_size, space_state, null)
	if not center_hits and not left_hits and not right_hits:
		purin.set_meta("offset_to_reach", 0)
		return true
	if not center_hits and not left_hits:
		purin.set_meta("offset_to_reach", -offset_size)
		return true
	if not center_hits and not right_hits:
		purin.set_meta("offset_to_reach", offset_size)
		return true
	return false
	
func number_possible_combines():
	reset_lines()
	var target_level = self.get_meta("level", 0) + 1
	var count:int = 0
	for body in get_colliding_bodies():
		if is_instance_valid(body) and is_instance_of(body, Purin):
			var level_diff = target_level - body.get_meta("level", 0)
			count += 1 - abs(level_diff*0.1)
	return count
	
func number_matching_nearby(purin_list:Array, search_radius:float = 100):
	var count:int = 0
	for purin in purin_list:
		var distance:float = purin.position.distance_squared_to(position)
		if distance <= search_radius and purin.get_meta("level") == self.get_meta("level"):
			count +=1
		
	return count
