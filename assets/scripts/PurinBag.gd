extends Node2D
class_name PurinBag

@export var how_many_to_show: int = 5
@export var bag_node:Node2D
var purin_indicator:Resource  = load("res://assets/scenes/PurinIndicator.tscn")
var bag: Array[PurinIndicator] = []
var max_purin_level:int = 0
var scales: Array[float] = [1,0.7,0.6,0.5,0.3,0.2,0.1,0.1,0.1]
func _on_ready() -> void:
	max_purin_level = 0
	self.bag = generate_purin_bag()
	update_bag_visuals()

func generate_purin_bag() -> Array[PurinIndicator]:
	#print("generate bag of max level: ", max_level)
	var new_bag: Array[PurinIndicator] = []
	# add each level of purin to the bag
	for level in range(0, 1+int(max_purin_level*0.5)):
		var indicator:PurinIndicator = purin_indicator.instantiate()
		indicator.level = min(level, int(max_purin_level*0.5))
		indicator.set_frame(indicator.level)
		indicator.pause()
		var indicator_scale:float = scales[indicator.level]
		indicator.scale = Vector2(indicator_scale, indicator_scale)
		new_bag.append(indicator)
		if bag_node != null:
			bag_node.add_child(indicator)
		else:
			# so it can be cleaned up automatically when this is deleted
			indicator.visible = false
			self.add_child(indicator)
	# shuffle it randomly
	new_bag.shuffle()
	#print("new_bag: ", new_bag)
	return new_bag

func update_bag_visuals() -> void:
	if bag_node == null:
		return
	for purin in bag_node.get_children():
		purin.visible = false
	var y_pos:float = 0.0
	var i:int = 0
	for indicator in bag:
		if i > 0:
			indicator.set_frame(indicator.level)
			indicator.position = Vector2(0, y_pos)
			indicator.visible = true
			if i == 1:
				y_pos += 125
			else:
				y_pos += 75
		if i > how_many_to_show:
			break
		i += 1
	
func restock_bag() -> void:
	if bag == null or bag.is_empty():
		bag = generate_purin_bag()
		update_bag_visuals()
		return
		
	if len(bag) < 3:
		bag.append_array(generate_purin_bag())
		update_bag_visuals()
		return
	

func drop_purin() -> Dictionary:
	#print("drop_purin: ", max_level)
	restock_bag()
	var purin_dropped:PurinIndicator = bag.pop_front()
	var dropped_level:int = purin_dropped.level
	var dropped_evil: bool = purin_dropped.evil
	purin_dropped.queue_free()
	update_bag_visuals()
	return {"level": dropped_level, "evil": dropped_evil}


func get_current_purin() -> Dictionary:
	#print("get_current_purin_level: ", max_level)
	restock_bag()
	var first_purin:PurinIndicator = bag[0]
	update_bag_visuals()
	return {"level": first_purin.level, "evil": first_purin.evil}

func get_next_purin() -> Dictionary:
	#print("get_current_purin_level: ", max_level)
	restock_bag()
	var second_purin:PurinIndicator = bag[0]
	return {"level": second_purin.level, "evil": second_purin.evil}


func get_next_purin_level() -> int:
	#print("get_next_purin_level: ", max_level)
	restock_bag()
	var second_purin:int = bag[1].level
	update_bag_visuals()
	return second_purin

func add_evil_purin(level:int) -> void:
	# overrides the next non-evil purin with a new evil one
	var i:int = 0
	for indicator in bag:
		if not indicator.evil and i > 0:
			#indicator.level = min(level, int(max_purin_level*0.5))
			indicator.set_frame(indicator.level)
			indicator.evil = true
			indicator.pause()
			var indicator_scale:float = scales[indicator.level]
			indicator.scale = Vector2(indicator_scale, indicator_scale)
			break
		i += 1
	update_bag_visuals()
