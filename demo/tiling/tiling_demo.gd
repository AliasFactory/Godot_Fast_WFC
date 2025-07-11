# Tiling WFC Demo
#
# Demonstrates the tiling variant of Wave Function Collapse for tile-based level generation.
# Shows three different approaches:
# 1. XML-based rules to direct tile rendering
# 2. XML-based rules to tilemap
# 3. Tilemap-based rules extraction to tilemap (non-functional work in progress)
#

extends Node

# FastWFC utility class for handy operations
const FastWFC = preload("../../FastWFC.gd")

# Output configuration
var image_output_path = "res://addons/fast-wfc/demo/tiling/Rooms_output.png"
@onready var global_image_output_path = ProjectSettings.globalize_path(image_output_path)

# Reference to tilemap layer
@onready var tile_map_layer: TileMapLayer = $"."

# Generation parameters
var output_width = 40
var output_height = 40
var periodic_output = false
var seed = 12345

# This information relates to the core WFC algorithm and how it interprets tile data.
# Tile orientation values for set_tile() calls:
# 0: No rotation (0°), no reflection
# 1: 90° clockwise rotation
# 2: 180° rotation
# 3: 270° clockwise rotation (90° counterclockwise)
# 4: Reflection along x-axis
# 5: Reflection + 90° clockwise rotation
# 6: Reflection + 180° rotation
# 7: Reflection + 270° clockwise rotation

# Symmetry type reference:
# X: Full symmetry (1 orientation) - identical in any orientation
# I: 2-fold rotational symmetry (2 orientations) - like corridors
# backslash: Diagonal symmetry (2 orientations) - diagonal lines
# T: 4-fold symmetry with reflection (4 orientations) - T-junctions
# L: 4-fold rotational symmetry (4 orientations) - corners
# P: No symmetry (8 orientations) - most versatile

# Normal weight values range from 0.0001 (extremely rare) to 20.0 (highly common) with a median of ~0.5
# based on the dataset used by the core WFC algorithm own demo project (included in /addons/fast-wfc/src/fast-wfc).

func _ready():
	await get_tree().process_frame
	tile_map_layer.visible = false
	#direct_tiling_demo()
	xml_tilemap_tiling_demo()

# Demonstrates tiling WFC using XML-defined rules and color-based tile content
#
# This approach combines XML rule definitions with actual image data for tiles.
# It loads tile images, applies XML-defined adjacency rules, and generates
# a complete dungeon layout with room constraints as a PNG.
func direct_tiling_demo():
	var wfc = FastWFCWrapper.new()
	
	# Define paths to tile images
	var tile_paths = {
		"bend": "res://addons/fast-wfc/demo/tiling/tiles/bend.png",
		"corner": "res://addons/fast-wfc/demo/tiling/tiles/corner.png",
		"corridor": "res://addons/fast-wfc/demo/tiling/tiles/corridor.png",
		"door": "res://addons/fast-wfc/demo/tiling/tiles/door.png",
		"empty": "res://addons/fast-wfc/demo/tiling/tiles/empty.png",
		"side": "res://addons/fast-wfc/demo/tiling/tiles/side.png",
		"t": "res://addons/fast-wfc/demo/tiling/tiles/t.png",
		"turn": "res://addons/fast-wfc/demo/tiling/tiles/turn.png",
		"wall": "res://addons/fast-wfc/demo/tiling/tiles/wall.png"
	}
	
	var output_path = "res://addons/fast-wfc/demo/tiling/tiling_output.png"
	var global_output_path = ProjectSettings.globalize_path(output_path)
	
	# Load XML rules and tile definitions
	var xml_data = FastWFC.load_xml_rules("res://addons/fast-wfc/demo/tiling/data.xml")

	# Replace tile content with actual color data from images
	var tile_data = {}
	for tile_name in tile_paths:
		var color_array = FastWFC.png_to_color_array(tile_paths[tile_name])
		if tile_name in xml_data.tile_data:
			tile_data[tile_name] = xml_data.tile_data[tile_name].duplicate()
			tile_data[tile_name].content = color_array # The core algorithm expects an array of almost any type, so we can use color arrays directly
	
	# Initialize WFC with combined data
	wfc.initialize_tiling(
		tile_data,
		xml_data.adjacency_rules,
		output_width,
		output_height,
		periodic_output,
		seed
	)
	
	# Create a spawn room in the center with specific constraints
	_create_spawn_room(wfc)
	
	# Generate the spawn room
	var result = wfc.generate()
	
	# Save result if successful
	if result.size() > 0:
		wfc.save_result_to_image(global_output_path)
		print("Tiling demo completed. Output: " + output_path)
	else:
		printerr("Tiling generation failed")
	
	wfc.queue_free()

# Demonstrates XML-based tiling WFC using marker tiles for encoding tile content
#
# Uses XML rules and creates marker-based tile content to minimize array size and skip image
# rendering. The encoding occurs in load_xml_rules(), and decoding in interpret_tilemap_output().
#
func xml_tilemap_tiling_demo():
	# Map tile file names to TileSet IDs for XML processing
	var tile_name_to_id = {
		"bend": 0, "corner": 1, "corridor": 2, "door": 3,
		"side": 4, "t": 5, "turn": 6, "wall": 7, "empty": 8
	}
	
	var wfc = FastWFCWrapper.new()
	var xml_data = FastWFC.load_xml_rules("res://addons/fast-wfc/demo/tiling/data.xml", tile_name_to_id)
	
	wfc.initialize_tiling(
		xml_data.tile_data,
		xml_data.adjacency_rules,
		output_width,
		output_height,
		periodic_output,
		seed
	)
	
	_create_spawn_room(wfc)
	
	var result = wfc.generate()
	
	if result.size() > 0:
		var interpreted_result = FastWFC.interpret_tilemap_output(result)
		_display_result(interpreted_result)
	else:
		printerr("XML rules generation failed")
	
	wfc.queue_free()

# (Work in Progress) Demonstrates tilemap rule extraction for WFC rule generation 
#
# This function shows how to extract tiles and adjacency rules directly
# from an existing tilemap. Currently non-functional but demonstrates
# the intended workflow for automatic rule extraction.
func tilemap_tiling_demo():
	var wfc = FastWFCWrapper.new()
	
	# Define symmetry rules for each tile source ID
	var symmetry_rules = {
		0: "L", 1: "L", 2: "I", 3: "T", 4: "X",
		5: "T", 6: "T", 7: "L", 8: "X"
	}
	
	# Extract tile data and rules from tilemap
	var wfc_data = FastWFC.create_tilemap_data(tile_map_layer, symmetry_rules)
	
	wfc.initialize_tiling(
		wfc_data.tile_data,
		wfc_data.adjacency_rules,
		output_width,
		output_height,
		periodic_output,
		seed	
	)
	
	var result = wfc.generate()
	
	if result.size() > 0:
		var interpreted_result = FastWFC.interpret_tilemap_output(result)
		_display_result(interpreted_result)		
	else:
		printerr("Tilemap extraction generation failed")
	
	wfc.queue_free()

# Creates a spawn room constraint in the center
#
# A very simplistic example function that places empty tiles in a 5x5 room pattern with 
# wall boundaries and a door entrance. The 'side' and 'corner' tiles that frame the room in the
# output do not need to be set manually because they are the only tiles that
# can appear under this set of rules  
#
# parameter: wfc Initialized FastWFCWrapper instance
func _create_spawn_room(wfc: FastWFCWrapper):
	#region make a spawn room
	wfc.set_tile("door", 2, 19, 22)
	
	# First row (row 20)
	wfc.set_tile("empty", 0, 20, 20)
	wfc.set_tile("empty", 0, 20, 21)
	wfc.set_tile("empty", 0, 20, 22)
	wfc.set_tile("empty", 0, 20, 23)
	wfc.set_tile("empty", 0, 20, 24)

	# Second row (row 21)
	wfc.set_tile("empty", 0, 21, 20)
	wfc.set_tile("empty", 0, 21, 21)
	wfc.set_tile("empty", 0, 21, 22)
	wfc.set_tile("empty", 0, 21, 23)
	wfc.set_tile("empty", 0, 21, 24)

	# Third row (row 22)
	wfc.set_tile("empty", 0, 22, 20)
	wfc.set_tile("empty", 0, 22, 21)
	wfc.set_tile("empty", 0, 22, 22)
	wfc.set_tile("empty", 0, 22, 23)
	wfc.set_tile("empty", 0, 22, 24)

	# Fourth row (row 23)
	wfc.set_tile("empty", 0, 23, 20)
	wfc.set_tile("empty", 0, 23, 21)
	wfc.set_tile("empty", 0, 23, 22)
	wfc.set_tile("empty", 0, 23, 23)
	wfc.set_tile("empty", 0, 23, 24)

	# Fifth row (row 24)
	wfc.set_tile("empty", 0, 24, 20)
	wfc.set_tile("empty", 0, 24, 21)
	wfc.set_tile("empty", 0, 24, 22)
	wfc.set_tile("empty", 0, 24, 23)
	wfc.set_tile("empty", 0, 24, 24)

	# Top wall (row 18)
	wfc.set_tile("wall", 0, 18, 18)
	wfc.set_tile("wall", 0, 18, 19)
	wfc.set_tile("wall", 0, 18, 20)
	wfc.set_tile("wall", 0, 18, 21)
	#wfc.set_tile("wall", 0, 18, 21) because door
	wfc.set_tile("wall", 0, 18, 23)
	wfc.set_tile("wall", 0, 18, 24)
	wfc.set_tile("wall", 0, 18, 25)
	wfc.set_tile("wall", 0, 18, 26)

	# Bottom wall (row 26)
	wfc.set_tile("wall", 0, 26, 18)
	wfc.set_tile("wall", 0, 26, 19)
	wfc.set_tile("wall", 0, 26, 20)
	wfc.set_tile("wall", 0, 26, 21)
	wfc.set_tile("wall", 0, 26, 22)
	wfc.set_tile("wall", 0, 26, 23)
	wfc.set_tile("wall", 0, 26, 24)
	wfc.set_tile("wall", 0, 26, 25)
	wfc.set_tile("wall", 0, 26, 26)

	# Left wall (column 18)
	wfc.set_tile("wall", 0, 19, 18)
	wfc.set_tile("wall", 0, 20, 18)
	wfc.set_tile("wall", 0, 21, 18)
	wfc.set_tile("wall", 0, 22, 18)
	wfc.set_tile("wall", 0, 23, 18)
	wfc.set_tile("wall", 0, 24, 18)
	wfc.set_tile("wall", 0, 25, 18)

	# Right wall (column 26)
	wfc.set_tile("wall", 0, 19, 26)
	wfc.set_tile("wall", 0, 20, 26)
	wfc.set_tile("wall", 0, 21, 26)
	wfc.set_tile("wall", 0, 22, 26)
	wfc.set_tile("wall", 0, 23, 26)
	wfc.set_tile("wall", 0, 24, 26)
	wfc.set_tile("wall", 0, 25, 26)
	#endregion

# Displays WFC result on a tilemap with proper transformations
#
# Creates a new TileMap node and applies the generated tile layout
# with correct orientations and transformations.
#
# Parameter: result_array Interpreted WFC output with [source_id, orientation] pairs
func _display_result(result_array: Array):
	var result_tilemap = TileMap.new()
	result_tilemap.tile_set = tile_map_layer.tile_set
	result_tilemap.name = "WFC_Result"
	get_parent().add_child(result_tilemap)
	
	# Godot tile transformation constants
	const FLIP_H = 4096
	const FLIP_V = 8192
	const TRANSPOSE = 16384
	
	# Orientation transformation mappings
	var orientation_flags = [
		0,                          # 0: No transformation
		TRANSPOSE | FLIP_H,         # 1: 90° clockwise 
		FLIP_H | FLIP_V,            # 2: 180° rotation
		TRANSPOSE | FLIP_V,         # 3: 270° clockwise
		FLIP_V,                     # 4: Reflection along x-axis
		TRANSPOSE,                  # 5: Reflection + 90°
		FLIP_H,                     # 6: Reflection + 180°
		TRANSPOSE | FLIP_H | FLIP_V # 7: Reflection + 270°
	]
	
	# Apply tiles to tilemap
	for y in range(result_array.size()):
		var row = result_array[y]
		for x in range(row.size()):
			var cell_data = row[x]
			var source_id = cell_data[0]
			var orientation_id = cell_data[1]
			
			var transform_flags = orientation_flags[orientation_id]
			result_tilemap.set_cell(0, Vector2i(x, y), source_id, Vector2i(0, 0), transform_flags)
	
	# Add camera for overview
	var camera = Camera2D.new()
	camera.zoom = Vector2(9, 9)
	
	# Center camera on the generated area
	var tile_size = result_tilemap.tile_set.tile_size
	var center_x = (output_width * tile_size.x) / 2
	var center_y = (output_height * tile_size.y) / 2
	camera.position = Vector2(center_x, center_y)
	
	result_tilemap.add_child(camera)
