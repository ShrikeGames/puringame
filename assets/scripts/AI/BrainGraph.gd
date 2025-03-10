extends Node2D
class_name BrainGraph

@export var graph_edit:GraphEdit

var prev_nodes:Array = []
# Called when the node enters the scene tree for the first time.
func _ready():
	update_visuals()

func update_visuals():
	if Global.brain:
		graph_edit.clear_connections()
		var layer_nodes:Array = []
		# number of nodes in each layer
		var layer_structure:Array = Global.brain.target_Q_network.layer_structure
		print(layer_structure)
		#var weight_matrices = Global.brain.Q_network.v_weights
		for i in range(layer_structure.size()):
			# create a graph node for each node in the layer
			for j in range(layer_structure[i]):
				var node = GraphNode.new()
				node.title = "L%d N%d" % [i, j]  # Layer and neuron index
				node.set_position_offset(Vector2(i * 200, j * 50))  # Space neurons out
				node.name = "L%dN%d" % [i, j]  # Unique name
				graph_edit.add_child(node)
				layer_nodes.append(node)
			if i > 0:
				# Draw connections if not the first layer
				for j in range(0, layer_nodes.size()):
					for k in range(layer_nodes.size()):
						#var weight = weight_matrices[i - 1][j][k]
						graph_edit.connect_node(prev_nodes[j].name, 0, layer_nodes[k].name, 0)

						# Create a label to display the weight
						#var label = Label.new()
						#label.text = "%.2f" % weight
						#label.set_position((prev_nodes[j].position + layer_nodes[k].position) / 2)
						#graph_edit.add_child(label)
	
