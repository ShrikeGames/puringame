extends Node2D

# TODO

var nna:NeuralNetworkAdvanced

func _ready():
	var layer_nodes:Array[Array] = []
	
	for layer_index in range(0, nna.layers.size()):
		var layer = nna.layers[layer_index]
		var node_count:int = layer["size"]
		var spacing:float = 800.0 / float(node_count)
		var nodes:Array[Vector2] = []
		for node_index in range(0, node_count):
			nodes.append(Vector2(spacing + (spacing*node_index), spacing + (spacing*node_index)))
		layer_nodes.append(nodes)
		
#			"weights": weights,
#			"bias": bias,
#			"activation": activation,
#			"activation_name": activation["name"],
#			"size": nodes,
#			"rows": weight_rows,
#			"cols": weight_cols


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta):
	pass
