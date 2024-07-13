extends Node
class_name PurinBag

var bag:Array[int] = []

func generate_purin_bag(max_level:float=0):
	#print("generate bag of max level: ", max_level)
	var new_bag:Array[int] = [0]
	# add each level of purin to the bag
	for level in range(0, max_level + 1):
		new_bag.append(level)
	# shuffle it randomly
	new_bag.shuffle()
	#print("new_bag: ", new_bag)
	return new_bag

func restock_bag(max_level:int):
	if bag.is_empty():
		#print("bag is empty")
		bag = generate_purin_bag(max(0, round(max_level*0.5)))
	
func drop_purin(max_level:int):
	#print("drop_purin: ", max_level)
	if bag.is_empty():
		restock_bag(max_level)
	return bag.pop_front()

func get_current_purin_level(max_level:int):
	#print("get_current_purin_level: ", max_level)
	if bag.is_empty():
		restock_bag(max_level)
	return bag.front()
	
	
func get_next_purin_level(max_level:int):
	#print("get_next_purin_level: ", max_level)
	if len(bag) < 2:
		restock_bag(max_level)
	return bag[min(1, len(bag)-1)]
	
