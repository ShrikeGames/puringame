extends Node2D
class_name NNGraph

# TODO

var nna:NeuralNetworkAdvanced
var nodes:Array[Array] = []
@export var nodes_node:Node2D

func _ready():
	for layer_index in range(0, nna.layers.size()):
		var layer = nna.layers[layer_index]
		var node_count:int = layer["size"]
		var spacing_x:float = 800.0 / float(1+node_count)
		var spacing_y:float = 800.0 / float(1+nna.layers.size())
		var weights:Matrix = layer["weights"]
		var bias:Matrix = layer["bias"]
		var layer_nodes:Array[NNNode] = []
		for node_index in range(0, node_count):
			var nnnode:NNNode = Global.nnnode_resource.instantiate()
			nnnode.position = Vector2(spacing_x + (spacing_x*node_index), (spacing_y*layer_index))
			if weights:
				nnnode.weights = weights.data[node_index]
				for weight_index in range(0, len(nnnode.weights)):
					var connection_line:Line2D = Line2D.new()
					connection_line.add_point(Vector2(0,0))
					connection_line.add_point(nodes[layer_index-1][weight_index].position - nnnode.position)
					nnnode.add_child(connection_line)
					nnnode.lines.append(connection_line)
				if bias:
					nnnode.bias = bias.data[node_index]
					
			nodes_node.add_child(nnnode)
			layer_nodes.append(nnnode)
		nodes.append(layer_nodes)
		update_graph(0, nna, [], true)


func update_graph(_delta, updated_nna:NeuralNetworkAdvanced, input:Array=[], update_graphics:bool = false):
	nna = updated_nna
	if len(input) <= 0:
		return
	var layer_index:int = 0
	for node in nodes:
		var node_index:int = 0
		for nnnode in node:
			var value:float = 0.0
			if layer_index == 0:
				value = input[node_index]
				nnnode.score = value
			elif layer_index >= 1:
				value = node[node_index-1].score
				if update_graphics:
					var weight_index:int = 0
					var layer = nna.layers[layer_index]
					var weights:Matrix = layer["weights"]
					nnnode.weights = weights.data[node_index]
					var bias:Matrix = layer["bias"]
					nnnode.bias = bias.data[node_index]
					value = value * (nnnode.weights[weight_index])
					weight_index += 1
					for connection_line in nnnode.lines:
						connection_line.width = 3*abs(value)
						if nnnode.score > 0:
							connection_line.default_color = Color(0, 1, 0, 0.6)
						else:
							connection_line.default_color = Color(1, 0, 0, 0.3)
					value += nnnode.bias[0]
				nnnode.score = value
			if value != 0:
				var font_colour:String = "#333333"
				if value > 0:
					font_colour = "#00FF00"
				elif value < 0:
					font_colour = "#FF0000"
				nnnode.text_label.text = "[center][color=%s]%s[/color][/center]"%[font_colour, value]
			
			node_index += 1
		layer_index += 1
