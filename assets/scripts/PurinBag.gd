extends Node2D
class_name PurinBag

@export var how_many_to_show: int = 6
@export var bag_node:Node2D
var purin_indicator:Resource
var bag: Array[int] = []
var max_purin_level:int = 0
var scales: Array[float] = [1,0.7,0.6,0.5,0.3,0.2,0.1,0.1,0.1]
func _on_ready() -> void:
	max_purin_level = 0
	purin_indicator = load("res://assets/scenes/PurinIndicator.tscn")
	self.bag = generate_purin_bag()
	update_bag_visuals()

func generate_purin_bag() -> Array[int]:
	#print("generate bag of max level: ", max_level)
	var new_bag: Array[int] = []
	# add each level of purin to the bag
	for level in range(0, how_many_to_show-len(bag)):
		new_bag.append(min(level, int(max_purin_level*0.5)))
	# shuffle it randomly
	new_bag.shuffle()
	#print("new_bag: ", new_bag)
	return new_bag

func update_bag_visuals() -> void:
	if bag_node == null:
		return
	for purin in bag_node.get_children():
		purin.queue_free()
	var y_pos:float = 0.0
	# skip showing the first one, since NoiR holds it
	for i in range(1, len(bag)-1):
		var purin:int = bag[i]
		var indicator:AnimatedSprite2D = purin_indicator.instantiate()
		indicator.set_frame(purin)
		indicator.pause()
		indicator.position = Vector2(0, y_pos)
		var indicator_scale:float = scales[purin]
		indicator.scale = Vector2(indicator_scale, indicator_scale)
		bag_node.add_child(indicator)
		if i == 1:
			y_pos += 125
		else:
			y_pos += 75

func restock_bag() -> void:
	if bag == null or bag.is_empty():
		bag = generate_purin_bag()
		update_bag_visuals()
		return
		
	if len(bag) < 3:
		print("Not enough in the bag so add to it:", bag)
		bag.append_array(generate_purin_bag())
		print("After adding to it:", bag)
		update_bag_visuals()
		return
	

func drop_purin() -> int:
	#print("drop_purin: ", max_level)
	restock_bag()
	var purin_dropped:int = bag.pop_front()
	update_bag_visuals()
	return purin_dropped


func get_current_purin_level() -> int:
	#print("get_current_purin_level: ", max_level)
	restock_bag()
	var first_purin:int = bag[0]
	update_bag_visuals()
	return first_purin


func get_next_purin_level() -> int:
	#print("get_next_purin_level: ", max_level)
	restock_bag()
	var second_purin:int = bag[1]
	update_bag_visuals()
	return second_purin

