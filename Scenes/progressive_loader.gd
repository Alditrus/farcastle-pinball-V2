extends Node

# List all heavy child nodes/scenes that should load progressively
@export var nodes_to_defer: Array[NodePath] = []
@export var load_delay_ms: float = 50.0  # Delay between each node

func _ready():
	# Disable all heavy nodes initially
	for node_path in nodes_to_defer:
		var node = get_node(node_path)
		if node:
			node.process_mode = Node.PROCESS_MODE_DISABLED
	
	# Load them progressively
	_load_nodes_progressively()

func _load_nodes_progressively():
	for node_path in nodes_to_defer:
		var node = get_node(node_path)
		if node:
			node.process_mode = Node.PROCESS_MODE_INHERIT
			await get_tree().create_timer(load_delay_ms / 1000.0).timeout
	
	print("✅ All nodes loaded progressively")
