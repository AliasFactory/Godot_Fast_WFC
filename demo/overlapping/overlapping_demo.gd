# Overlapping WFC Demo
#
# Demonstrates the overlapping variant of Wave Function Collapse for PNG generation.
# This example shows how to:
# 1. Initialize overlapping WFC from color arrays
# 2. Apply pattern constraints to control generation
# 3. Generate and save the resulting texture
#
# The demo uses a room layout input image and applies a 3x3 pattern constraint
# repeatedly across the top row to demonstrate constraint functionality.
#

extends Node

# FastWFC utility class for data conversion
const FastWFC = preload("../../FastWFC.gd")

# WFC wrapper instance
var wfc: FastWFCWrapper

# File paths
var input_image_path = "res://addons/Godot_Fast_WFC/demo/overlapping/Rooms.png"
var image_output_path = "res://addons/Godot_Fast_WFC/demo/overlapping/Rooms_output.png"
var constraint_path = "res://addons/Godot_Fast_WFC/demo/overlapping/3x3_pattern.png"

# Globalized paths for file operations
@onready var global_input_path = ProjectSettings.globalize_path(input_image_path)
@onready var global_image_output_path = ProjectSettings.globalize_path(image_output_path)
@onready var global_constraint_path = ProjectSettings.globalize_path(constraint_path)

# Generation parameters
var output_width = 200
var output_height = 200
var pattern_size = 3  # Larger values (e.g., 4) produce output closer to input
var periodic_input = true  # Rooms.png tiles seamlessly
var periodic_output = false  # Tileable outputs. Very handy. Doesnt always work
var ground = false  # No special ground pattern handling needed for this demo
var symmetry = 8  # Use all possible pattern rotations and reflections of detected patterns
var seed = 12345  # Deterministic seed

# Initializes and runs the overlapping WFC demonstration
func _ready():
	wfc = FastWFCWrapper.new()
	
	# Convert images to color arrays for WFC processing
	var color_array = FastWFC.png_to_color_array(input_image_path)
	var pattern_array = FastWFC.png_to_color_array(constraint_path)
	
	# Initialize overlapping WFC with input parameters
	wfc.initialize_overlapping_from_array(
		color_array,
		output_width,
		output_height,
		pattern_size,
		periodic_input,
		periodic_output,
		ground,
		symmetry,
		seed
	)

	# Apply pattern constraints across the top row
	# This forces the specified pattern to appear at regular intervals
	# Breaks periodic output on most seeds
	var constraint_spacing = 3
	for i in range(0, output_width, constraint_spacing):
		wfc.set_pattern_from_array(pattern_array, 0, i)
	
	# Generate the WFC result
	var result = wfc.generate()
	
	# Save the result to disk if generation succeeded
	if result.size() > 0:
		var success = wfc.save_result_to_image(global_image_output_path)
		if success:
			print("Overlapping WFC demo completed successfully")
			print("Output saved to: " + image_output_path)
		else:
			printerr("Failed to save output image")
	else:
		printerr("WFC generation failed - try adjusting parameters or seed")
	
	get_tree().quit()
