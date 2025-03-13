extends Node2D
class_name Eyes
@export_category("Nodes")
@export var raycasts:Array[RayCast2D] = []
@export var raycast_visuals:Array[Line2D] = []
@export var collision_body:RigidBody2D

@export_category("Stats")
# 0 degrees would only see directly in front of itself, 360 degrees can see everything around it
# 180 degrees is everything in front of it
@export var fov_degrees:float = 180
# how many raycasts are done within the fov
@export var num_raycasts:int = 12
# distance raycasts will travel to look for collisions
@export var sight:float = 900.0
var initialized:bool = false
var use_cone:bool = false

@export_category("Debug")
@export var show_raycasts:bool = true
@export var NO_COLLISION_COLOUR:Color = Color(0.5,0.5,0.5,0.3)
@export var COLLISION_COLOUR:Color = Color(0.9,0.5,0.5,0.75)


func init(_fov_degrees:float, _num_raycasts:int, _sight:float):
	if initialized:
		return
	# Called once when Agent is created
	fov_degrees = _fov_degrees
	num_raycasts = _num_raycasts
	sight = _sight
	if raycasts.size() >=0:
		for raycast in raycasts:
			raycast.queue_free()
	if raycast_visuals.size() >=0:
		for raycast_visual in raycast_visuals:
			raycast_visual.queue_free()
			
	raycasts = []
	raycast_visuals = []
	if use_cone:
		self.rotation_degrees = -90
		var _degree_diff:float = fov_degrees / float(num_raycasts)
		# create raycasts evenly distributed across the field of view
		for i in range(0, num_raycasts+1):
			var raycast:RayCast2D = RayCast2D.new()
			# Calculate the angle in radians
			var angle:float = deg_to_rad(-fov_degrees * 0.5 + i * _degree_diff)
			# Compute x and y using trigonometry
			var x:float = cos(angle) * sight
			var y:float = sin(angle) * sight
			raycast.position = Vector2(0,0)
			raycast.target_position = Vector2(x, y)
			raycast.enabled = true
			raycast.set_collision_mask_value(1, true)
			
			# Exclude the collision_body from detection
			if collision_body:
				raycast.add_exception(collision_body)
			
			if show_raycasts:
				var raycast_visual:Line2D = Line2D.new()
				
				raycast_visual.default_color = NO_COLLISION_COLOUR
				raycast_visual.width = 3
				raycast_visual.add_point(Vector2(0, 0))
				raycast_visual.add_point(Vector2(x, y))
				raycast.set_meta("visual", raycast_visual)
				add_child(raycast_visual)
			
			raycasts.append(raycast)
			add_child(raycast)
	else:
		var spacing:float = 720.0/float(num_raycasts)
		for i in range(0, num_raycasts+1):
			var x:float = 40 + (i * spacing)
			var raycast:RayCast2D = RayCast2D.new()
			var y:float = 900.0
			raycast.position = Vector2(x, 0)
			raycast.target_position = Vector2(0, y)
			if show_raycasts:
				var raycast_visual:Line2D = Line2D.new()
				raycast_visual.default_color = NO_COLLISION_COLOUR
				raycast_visual.width = 3
				raycast_visual.add_point(Vector2(x,0))
				raycast_visual.add_point(Vector2(x,y))
				raycast.set_meta("visual", raycast_visual)
				add_child(raycast_visual)
			raycasts.append(raycast)
			add_child(raycast)
			
	initialized = true
	
func get_input(_raycast: RayCast2D) -> RayCastInput:
	# Calculate distance from raycast collision
	var _input:RayCastInput = RayCastInput.new()
	
	var level:int = -1
	var distance: float = 0.0
	var is_purin:bool = false
	var x_pos:float = -1
	if show_raycasts:
		var _visual: Line2D = _raycast.get_meta("visual")
		_visual.set_point_position(1, _visual.get_point_position(0))
	
	if _raycast.is_colliding():
		var origin: Vector2 = _raycast.global_transform.get_origin()
		var collision: Vector2 = _raycast.get_collision_point()
		x_pos = collision.x
		var collider = _raycast.get_collider()
		if is_instance_valid(collider) and is_instance_of(collider, Purin):
			distance = origin.distance_to(collision)
			level = collider.get_meta("level", -1)
			is_purin = true
			if show_raycasts:
				var _visual: Line2D = _raycast.get_meta("visual")
				_visual.set_point_position(1, to_local(collision))
				_visual.default_color = collider.get_meta("colour", COLLISION_COLOUR)
				_visual.default_color.a = 0.25
		elif is_instance_valid(collider) and not is_instance_of(collider, Purin):
			if use_cone:
				distance = origin.distance_to(collision)
			else:
				distance = 0
			level = -1
			is_purin = false
			if show_raycasts:
				var _visual: Line2D = _raycast.get_meta("visual")
				_visual.set_point_position(1, to_local(collision))
				_visual.default_color = collider.get_meta("colour", COLLISION_COLOUR)
				_visual.default_color.a = 0.25
	else:
		is_purin = false
		var _pos:Vector2 = _raycast.target_position
		_pos.x = clampf(_pos.x, 0, 900)
		_pos.y = clampf(_pos.y, 0, 900)
		x_pos = _pos.x
		distance = sqrt((pow(_pos.x, 2) + pow(_pos.y, 2)))
		if show_raycasts:
			var _visual: Line2D = _raycast.get_meta("visual")
			_visual.default_color = NO_COLLISION_COLOUR
			_visual.set_point_position(1, _pos)
			
	_input.distance = min(max(0, distance), sight)
	_input.level = level
	_input.is_purin = is_purin
	_input.x_pos = x_pos
	return _input
	
func get_inputs_from_raycasts(held_purin_level:int, _next_purin_level:int, _left_edge:Node2D, _right_edge:Node2D) -> Array:
	assert(raycasts.size() != 0, "Can not get inputs from RayCasts that are not set!")

	var _input_array: Array[float] = []
	var _basic_suggested_output: Array[int] = []
	for ray in raycasts:
		var _input:RayCastInput = get_input(ray)
		if is_instance_valid(ray):
			# 1 distance
			_input_array.append(clampf(_input.distance/sight, 0.0, 1.0))
			
			# 2 level matches
			if _input.is_purin:
				#_input_array.append(clampf((_input.level+1)/10.0, 0.0, 1.0))
				# results are between 0 and 1, where 1 is a perfect match and a difference of 9 is ~0.07
				#var level_diff_score:float = clampf(exp(-pow(held_purin_level-_input.level, 2)/25.0), 0.0, 1.0)
				var level_diff_score = 0
				if held_purin_level == _input.level:
					level_diff_score = 1
				_input_array.append(level_diff_score)
			else:
				#_input_array.append(0)
				_input_array.append(0)
			
		_input.queue_free()
	return _input_array
