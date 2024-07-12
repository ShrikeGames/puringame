extends Node
class_name PurinBag

var bag:Array[int] = []

func generate_purin_bag(max_level:int=0):
	var new_bag:Array[int] = [0]
	# add each level of purin to the bag
	for level in range(0, max_level + 1):
		new_bag.append(level)
	# shuffle it randomly
	new_bag.shuffle()
	return new_bag

func restock_bag(max_level:int):
	if bag.is_empty():
		bag = generate_purin_bag(round(max_level*0.5))
	else:
		bag.append_array(generate_purin_bag(round(max_level*0.5)))
		
func drop_purin(max_level:int):
	if bag.is_empty():
		restock_bag(max_level)
	return bag.pop_front()

func get_current_purin_level(max_level:int):
	if bag.is_empty():
		restock_bag(max_level)
	return bag.front()
	
	
func get_next_purin_level(max_level:int):
	if len(bag) < 2:
		restock_bag(max_level)
	return bag[min(1, len(bag)-1)]
	
