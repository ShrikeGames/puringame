extends Camera2D

@export var camera_move_speed:float = 500;
@export var camera_zoom_speed:float = 0.1;
# Called when the node enters the scene tree for the first time.
func _ready():
	pass # Replace with function body.


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta):
	if Input.is_action_pressed("scroll_down") or Input.is_action_pressed("move_down"):
		self.position.y += camera_move_speed * delta;
	if Input.is_action_pressed("scroll_up") or Input.is_action_pressed("move_up"):
		self.position.y -= camera_move_speed * delta;
	if Input.is_action_pressed("move_right"):
		self.position.x += camera_move_speed * delta;
	if Input.is_action_pressed("move_left"):
		self.position.x -= camera_move_speed * delta;
	if Input.is_action_pressed("zoom_out"):
		self.zoom.x = max(0.1, self.zoom.x - (camera_zoom_speed * delta));
		self.zoom.y = self.zoom.x;
	if Input.is_action_pressed("zoom_in"):
		self.zoom.x = min(1, self.zoom.x + (camera_zoom_speed * delta));
		self.zoom.y = self.zoom.x;
	
