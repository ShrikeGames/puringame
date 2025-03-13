extends Node2D
class_name Graph

@export var max_points: int = 900  # Maximum number of points per graph
@export var max_width: float = 900  # Width of the graph
@export var max_height: float = 150  # Height of the graph

# Dictionary to store graphs and their associated data
var graphs: Dictionary = {}

func _ready():
	# Example: Initialize some default graphs
	add_graph("rewards", Color.GREEN_YELLOW)
	add_graph("score", Color.PALE_GREEN)
	add_graph("return", Color.GREEN)
	add_graph("advantage", Color.WHITE)
	add_graph("policy", Color.RED)
	add_graph("value", Color.DARK_RED)

func add_graph(graph_key: String, color: Color) -> void:
	"""
	Adds a new graph to the display.
	- graph_key: A unique identifier for the graph (e.g., "rewards", "score").
	- color: The color of the graph's line.
	"""
	var line = Line2D.new()
	line.width = 1
	line.default_color = color
	add_child(line)

	# Initialize graph data
	graphs[graph_key] = {
		"line": line,
		"raw_values": [],  # Stores original y-values
		"highest_value": -INF,  # Tracks the highest y-value
		"lowest_value": INF,  # Tracks the lowest y-value
	}

func add_point(graph_key: String, y_val: float) -> void:
	"""
	Adds a point to the specified graph.
	- graph_key: The key of the graph to add the point to.
	- y_val: The y-value to add.
	"""
	if not graphs.has(graph_key):
		push_error("Graph key not found: ", graph_key)
		return

	var graph_data = graphs[graph_key]

	# Store raw value
	graph_data["raw_values"].append(y_val)

	# Remove oldest points if exceeding max_points
	if graph_data["raw_values"].size() > max_points:
		graph_data["raw_values"].pop_front()

	# Update min/max values dynamically
	graph_data["highest_value"] = max(graph_data["highest_value"], y_val)
	graph_data["lowest_value"] = min(graph_data["lowest_value"], y_val)

	# Ensure we have a valid range
	var range: float = graph_data["highest_value"] - graph_data["lowest_value"]
	if range == 0:
		range = 1  # Prevent divide by zero

	# Rescale points
	graph_data["line"].clear_points()
	for i in range(graph_data["raw_values"].size()):
		# X scaling: Keep points evenly distributed
		var t: float = float(i) / float(graph_data["raw_values"].size() - 1) if graph_data["raw_values"].size() > 1 else 1.0
		var x = lerp(0, int(max_width), t)

		# Y scaling: Map raw values to [max_height, 0]
		var y = max_height - ((graph_data["raw_values"][i] - graph_data["lowest_value"]) / range) * max_height

		graph_data["line"].add_point(Vector2(x, y))
