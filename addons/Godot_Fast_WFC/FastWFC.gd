@tool
extends EditorPlugin

# Fast WFC Plugin and Utilities
#
# This plugin provides Wave Function Collapse (WFC) functionality for Godot through:
# 1. A GDExtension wrapper around the fast-wfc C++ library
# 2. Utility functions for preparing data and interpreting results
# 
# All utility functions are available as static methods on the FastWFC class.
#


func _enter_tree():
	if not ClassDB.class_exists("FastWFCWrapper"):
		printerr("WARNING: FastWFCWrapper class not registered by GDExtension")

func _exit_tree():
	pass

#region Tilemap Data Functions

# Extracts tile data from a TileMapLayer and formats it for use with FastWFCWrapper.initialize_tiling()
#
# This function analyzes the tilemap to identify unique tiles, their transformations,
# and adjacency relationships. It also calculates frequency-based weights for each tile type.
#
# Parameters:
#   tile_map_layer: The TileMapLayer to extract data from
#   symmetry_rules: Dictionary mapping source IDs to symmetry types ("X", "I", "L", "T", "backslash", "P")
# Returns: Dictionary containing "tile_data" and "adjacency_rules" keys
#

static func create_tilemap_data(tile_map_layer: TileMapLayer, symmetry_rules: Dictionary) -> Dictionary:
	var tiles_data = _get_tile_data_dict(tile_map_layer)
	
	# Extract frequency data for weight calculation
	var total_tiles = 0
	var source_id_counts = {}
	
	if "__metadata" in tiles_data and "source_id_counts" in tiles_data["__metadata"]:
		source_id_counts = tiles_data["__metadata"]["source_id_counts"]
		for count in source_id_counts.values():
			total_tiles += count
	
	# Remove metadata before processing
	var clean_tiles_data = tiles_data.duplicate()
	clean_tiles_data.erase("__metadata")
	
	var wfc_format = _convert_to_wfc_format(clean_tiles_data)
	
	# Convert to WFC tile data format
	var tile_data_dict = {}
	for tile_key in wfc_format.tiles:
		var tile_info = wfc_format.tiles[tile_key]
		var content = [[0, 1, 2], [3, tile_info.source_id, 5], [6, 7, 8]]
		
		# Calculate frequency-based weight
		var weight = 1.0
		if total_tiles > 0 and tile_info.source_id in source_id_counts:
			var frequency = float(source_id_counts[tile_info.source_id]) / total_tiles
			weight = 0.1 + 9.9 * frequency
		
		tile_data_dict[tile_key] = {
			"content": content,
			"symmetry": symmetry_rules.get(tile_info.source_id, "X"),
			"weight": weight
		}
		
		if "atlas_coords" in tile_info:
			tile_data_dict[tile_key]["atlas_coords"] = tile_info.atlas_coords
	
	# Convert adjacency rules and remove duplicates
	var adjacency_array = []
	var seen_rules = {}
	
	for rule in wfc_format.neighbors:
		var rule_key = str(rule.tile1) + "_" + str(rule.orientation1) + "_" + str(rule.tile2) + "_" + str(rule.orientation2)
		
		if not rule_key in seen_rules:
			seen_rules[rule_key] = true
			adjacency_array.append({
				"tile1": rule.tile1,
				"orientation1": rule.orientation1,
				"tile2": rule.tile2,
				"orientation2": rule.orientation2
			})
	
	return {
		"tile_data": tile_data_dict,
		"adjacency_rules": adjacency_array
	}

# Extracts data for all tiles in the tilemap layer including transformation information
#
# Parameters:
#   tile_map_layer: The TileMapLayer to analyze
# Returns: Dictionary mapping coordinate strings to tile information, plus metadata
static func _get_tile_data_dict(tile_map_layer: TileMapLayer) -> Dictionary:
	var result = {}
	var source_id_counts = {}
	
	var cells = tile_map_layer.get_used_cells()
	
	for coords in cells:
		var flipped_h = tile_map_layer.is_cell_flipped_h(coords)
		var flipped_v = tile_map_layer.is_cell_flipped_v(coords) 
		var transposed = tile_map_layer.is_cell_transposed(coords)
		var source_id = tile_map_layer.get_cell_source_id(coords)
		
		# Count tile occurrences
		if not source_id in source_id_counts:
			source_id_counts[source_id] = 0
		source_id_counts[source_id] += 1
		
		var tile_info = {
			"source_id": source_id,
			"atlas_coords": tile_map_layer.get_cell_atlas_coords(coords),
			"alternative_tile": tile_map_layer.get_cell_alternative_tile(coords),
			"rotation_degrees": _get_rotation_from_transforms(flipped_h, flipped_v, transposed),
			"transform_flags": {
				"flipped_h": flipped_h,
				"flipped_v": flipped_v,
				"transposed": transposed
			}
		}
		
		var coord_key = str(coords.x) + "," + str(coords.y)
		result[coord_key] = tile_info
	
	result["__metadata"] = {"source_id_counts": source_id_counts}
	return result

# Analyzes tile positions to extract adjacency rules defining valid tile placements
#
# Parameters:
#   tiles_data: Dictionary of tile information by coordinate
# Returns: Array of adjacency rules with tile and direction information
static func _extract_adjacency_rules(tiles_data: Dictionary) -> Array:
	var rules = []
	var coords_dict = {}
	
	# Convert coordinate strings back to Vector2i
	for coord_str in tiles_data:
		if coord_str == "__metadata":
			continue
		var parts = coord_str.split(",")
		var coord = Vector2i(int(parts[0]), int(parts[1]))
		coords_dict[coord_str] = coord
	
	var directions = [Vector2i(1, 0), Vector2i(0, 1)]  # Right, Down
	var adjustments = [0, 270]  # Perspective adjustments
	
	# Check each tile and its neighbors
	for coord_str in tiles_data:
		if coord_str == "__metadata":
			continue
		
		var coord = coords_dict[coord_str]
		var tile = tiles_data[coord_str]
		
		for dir_idx in range(directions.size()):
			var neighbor_coord = coord + directions[dir_idx]
			var neighbor_key = str(neighbor_coord.x) + "," + str(neighbor_coord.y)
			
			if neighbor_key in tiles_data:
				var neighbor_tile = tiles_data[neighbor_key]
				
				var rule = {
					"tile1": {
						"source_id": tile["source_id"],
						"rotation_degrees": tile["rotation_degrees"] + adjustments[dir_idx]
					},
					"tile2": {
						"source_id": neighbor_tile["source_id"],
						"rotation_degrees": neighbor_tile["rotation_degrees"] + adjustments[dir_idx]
					},
					"direction": dir_idx
				}
				
				# Add identifying information
				if "atlas_coords" in tile:
					rule["tile1"]["atlas_coords"] = tile["atlas_coords"]
					rule["tile2"]["atlas_coords"] = neighbor_tile["atlas_coords"]
				
				if "alternative_tile" in tile:
					rule["tile1"]["alternative_tile"] = tile["alternative_tile"]
					rule["tile2"]["alternative_tile"] = neighbor_tile["alternative_tile"]
				
				rules.append(rule)
	
	return rules

# Converts Godot transform flags to rotation degrees
#
# Parameters:
#   flipped_h: Horizontal flip flag
#   flipped_v: Vertical flip flag  
#   transposed: Transpose flag
# Returns: Rotation angle in degrees (0, 90, 180, 270)
static func _get_rotation_from_transforms(flipped_h: bool, flipped_v: bool, transposed: bool) -> int:
	if transposed and flipped_h and not flipped_v:
		return 90
	elif flipped_h and flipped_v and not transposed:
		return 180
	elif transposed and flipped_v and not flipped_h:
		return 270
	return 0

# Processes extracted tile data into WFC-compatible format
#
# Identifies unique tile types, determines symmetries, calculates weights,
# and formats adjacency rules for the WFC algorithm.
#
# Parameters:
#   tiles_data: Raw tile data from tilemap extraction
# Returns: Dictionary with "tiles" and "neighbors" in WFC format
static func _convert_to_wfc_format(tiles_data: Dictionary) -> Dictionary:
	var adjacency_rules = _extract_adjacency_rules(tiles_data)
	
	# Handle source ID counts
	var source_id_counts = tiles_data.get("__source_id_counts", {})
	var temp_tiles_data = tiles_data.duplicate()
	temp_tiles_data.erase("__source_id_counts")
	
	var total_tiles = 0
	for count in source_id_counts.values():
		total_tiles += count
	
	# Identify unique tile groups
	var unique_tile_groups = {}
	
	for coord_str in temp_tiles_data:
		if coord_str == "__metadata":
			continue
		
		var tile = temp_tiles_data[coord_str]
		var base_key = str(tile["source_id"])
		
		if "atlas_coords" in tile:
			base_key += "_" + str(tile["atlas_coords"].x) + "_" + str(tile["atlas_coords"].y)
		
		if not base_key in unique_tile_groups:
			unique_tile_groups[base_key] = {
				"source_id": tile["source_id"],
				"rotations": [],
			}
			
			if "atlas_coords" in tile:
				unique_tile_groups[base_key]["atlas_coords"] = tile["atlas_coords"]
		
		var rotation = tile["rotation_degrees"]
		if not rotation in unique_tile_groups[base_key]["rotations"]:
			unique_tile_groups[base_key]["rotations"].append(rotation)
	
	# Create unique tiles with symmetry and weights
	var unique_tiles = {}
	
	for base_key in unique_tile_groups:
		var group = unique_tile_groups[base_key]
		var rotations = group["rotations"]
		rotations.sort()
		
		# Determine symmetry from observed rotations
		var symmetry = "X"
		if rotations.size() == 1:
			symmetry = "X"
		elif rotations.size() == 2:
			if (rotations == [0, 180]) or (rotations == [90, 270]):
				symmetry = "I"
			else:
				symmetry = "backslash"
		elif rotations.size() == 4:
			symmetry = "L"
		elif rotations.size() > 4:
			symmetry = "P"
		
		# Calculate frequency-based weight
		var source_id = group["source_id"]
		var count = source_id_counts.get(source_id, 1)
		var frequency = float(count) / max(total_tiles, 1)
		var weight = 0.1 + 9.9 * frequency
		
		unique_tiles[base_key] = {
			"source_id": group["source_id"],
			"possible_rotations": rotations,
			"symmetry": symmetry,
			"weight": weight
		}
		
		if "atlas_coords" in group:
			unique_tiles[base_key]["atlas_coords"] = group["atlas_coords"]
	
	# Create WFC-compatible adjacency rules
	var wfc_neighbors = []
	
	for rule in adjacency_rules:
		var tile1_base_key = str(rule["tile1"]["source_id"])
		var tile2_base_key = str(rule["tile2"]["source_id"])
		
		if "atlas_coords" in rule["tile1"]:
			tile1_base_key += "_" + str(rule["tile1"]["atlas_coords"].x) + "_" + str(rule["tile1"]["atlas_coords"].y)
			tile2_base_key += "_" + str(rule["tile2"]["atlas_coords"].x) + "_" + str(rule["tile2"]["atlas_coords"].y)
		
		var orientation1 = _get_orientation_index(rule["tile1"]["rotation_degrees"])
		var orientation2 = _get_orientation_index(rule["tile2"]["rotation_degrees"])
		
		var neighbor = {
			"tile1": tile1_base_key,
			"orientation1": orientation1,
			"tile2": tile2_base_key,
			"orientation2": orientation2,
			"direction": rule["direction"]
		}
		
		wfc_neighbors.append(neighbor)
	
	return {
		"tiles": unique_tiles,
		"neighbors": wfc_neighbors
	}

# Converts rotation degrees to WFC orientation index
#
# Parameters:
#   rotation_degrees: Rotation in degrees
# Returns: Orientation index (0-3) for WFC algorithm
static func _get_orientation_index(rotation_degrees: int) -> int:
	match rotation_degrees:
		0: return 0
		90: return 1
		180: return 2
		270: return 3
		360: return 0
		450: return 1
		_: 
			printerr("WARNING: Unexpected rotation: " + str(rotation_degrees))
			return 0

#endregion

#region Overlapping Pattern Functions

# Extracts color data from a texture for use with overlapping WFC
#
# Loads an image file and converts it to a 2D array of Color objects
# that can be used with FastWFCWrapper.initialize_overlapping_from_array().
#
# Parameters:
#   input_image_path: Path to the image file
# Returns: 2D array of Color objects representing the image pixels
#

static func png_to_color_array(input_image_path: String) -> Array:
	var texture = load(input_image_path)
	if not texture:
		printerr("Failed to load texture: " + input_image_path)
		return []
	
	var image = texture.get_image()
	var width = image.get_width()
	var height = image.get_height()
	var color_array = []
	
	for y in range(height):
		var row = []
		for x in range(width):
			row.append(image.get_pixel(x, y))
		color_array.append(row)
	
	return color_array

#endregion

#region Output Interpretation Functions

# Interprets raw WFC tiling output into a format usable by Godot tilemaps
#
# Processes the generated tile data by detecting 3x3 marker patterns
# and extracting the source ID and orientation information.
#
# Parameters:
#   result: Raw WFC output array containing tile markers
# Returns: Processed array with [source_id, orientation_id] pairs
#

static func interpret_tilemap_output(result: Array) -> Array:
	var interpreted_result = []
	var tile_size = 3  # Marker tiles are 3x3
	
	# Process in 3x3 chunks
	for y in range(0, result.size(), tile_size):
		var row = []
		for x in range(0, result[0].size(), tile_size):
			# Extract 3x3 chunk
			var tile_3x3 = []
			for dy in range(tile_size):
				var row_chunk = []
				for dx in range(tile_size):
					if y + dy < result.size() and x + dx < result[y + dy].size():
						row_chunk.append(result[y + dy][x + dx])
				tile_3x3.append(row_chunk)
			
			# Extract source ID (center value) and detect orientation
			var source_id = tile_3x3[1][1]
			var orientation_id = _detect_orientation(tile_3x3)
			row.append([source_id, orientation_id])
		
		interpreted_result.append(row)
	
	return interpreted_result

# Detects tile orientation from 3x3 marker pattern
#
# Analyzes the corner positions of a 3x3 marker tile to determine
# the orientation applied by the WFC algorithm.
#
# Original pattern: [[0,1,2], [3,S,5], [6,7,8]]
#
# Parameters:
#   tile_3x3: 3x3 array containing the marker pattern
# Returns: Orientation index (0-7) representing rotation and reflection
static func _detect_orientation(tile_3x3: Array) -> int:
	# Extract corner markers
	var top_left = tile_3x3[0][0]
	var top_right = tile_3x3[0][2]
	var bottom_left = tile_3x3[2][0]
	var bottom_right = tile_3x3[2][2]
	
	# Match corner patterns to orientations
	if top_left == 0 and top_right == 2 and bottom_left == 6 and bottom_right == 8:
		return 0  # No rotation
	elif top_left == 6 and top_right == 0 and bottom_left == 8 and bottom_right == 2:
		return 1  # 90° clockwise
	elif top_left == 8 and top_right == 6 and bottom_left == 2 and bottom_right == 0:
		return 2  # 180°
	elif top_left == 2 and top_right == 8 and bottom_left == 0 and bottom_right == 6:
		return 3  # 270° clockwise
	elif top_left == 2 and top_right == 0 and bottom_left == 8 and bottom_right == 6:
		return 4  # Reflection along x-axis
	elif top_left == 8 and top_right == 2 and bottom_left == 6 and bottom_right == 0:
		return 5  # Reflection + 90° clockwise
	elif top_left == 6 and top_right == 8 and bottom_left == 0 and bottom_right == 2:
		return 6  # Reflection + 180°
	elif top_left == 0 and top_right == 6 and bottom_left == 2 and bottom_right == 8:
		return 7  # Reflection + 270° clockwise
	else:
		printerr("Warning: Unrecognized tile orientation pattern")
		return 0

#endregion

#region XML Parsing Functions

# Parses XML file containing tile definitions and adjacency rules
#
# Parameters:
#   xml_path: Path to the XML configuration file
# Returns: Dictionary with parsed size, tiles, and neighbors data
static func _parse_xml_file(xml_path: String) -> Dictionary:
	var file = FileAccess.open(xml_path, FileAccess.READ)
	if not file:
		printerr("Failed to open XML file: " + xml_path)
		return {}
		
	var xml_content = file.get_as_text()
	file.close()
	
	var parser = XMLParser.new()
	var error = parser.open_buffer(xml_content.to_utf8_buffer())
	if error != OK:
		printerr("Failed to parse XML content")
		return {}
	
	var tiles = []
	var neighbors = []
	var size = 3
	var parsing_tiles = false
	var parsing_neighbors = false
	
	while parser.read() == OK:
		var node_type = parser.get_node_type()
		
		if node_type == XMLParser.NODE_ELEMENT:
			var node_name = parser.get_node_name()
			
			if node_name == "set":
				var size_attr = parser.get_named_attribute_value("size")
				if size_attr and size_attr.is_valid_int():
					size = size_attr.to_int()
					
			elif node_name == "tiles":
				parsing_tiles = true
				parsing_neighbors = false
				
			elif node_name == "neighbors":
				parsing_tiles = false
				parsing_neighbors = true
				
			elif node_name == "tile" and parsing_tiles:
				var tile_data = {}
				tile_data.name = parser.get_named_attribute_value("name")
				tile_data.symmetry = parser.get_named_attribute_value("symmetry")
				
				var weight_attr = ""
				if parser.has_attribute("weight"):
					weight_attr = parser.get_named_attribute_value("weight")

				if weight_attr != "" and weight_attr.is_valid_float():
					tile_data.weight = weight_attr.to_float()
				else:
					tile_data.weight = 0.5
				
				tiles.append(tile_data)
				
			elif node_name == "neighbor" and parsing_neighbors:
				var neighbor_data = {}
				neighbor_data.left = parser.get_named_attribute_value("left")
				neighbor_data.right = parser.get_named_attribute_value("right")
				neighbors.append(neighbor_data)
				
		elif node_type == XMLParser.NODE_ELEMENT_END:
			var node_name = parser.get_node_name()
			if node_name == "tiles":
				parsing_tiles = false
			elif node_name == "neighbors":
				parsing_neighbors = false
	
	return {
		"size": size,
		"tiles": tiles,
		"neighbors": neighbors
	}

# Parses tile reference string into components
#
# Tile references can be "tile_name" or "tile_name orientation_number".
#
# Parameters:
#   tile_ref: Tile reference string from XML
#   tile_name_to_id: Mapping of tile names to numeric IDs
# Returns: Dictionary with tile_name, tile_id, and orientation
static func _parse_tile_ref(tile_ref: String, tile_name_to_id: Dictionary) -> Dictionary:
	var parts = tile_ref.split(" ")
	var tile_name = parts[0]
	var orientation = 0
	
	if parts.size() > 1 and parts[1].is_valid_int():
		orientation = parts[1].to_int()
	
	return {
		"tile_name": tile_name,
		"tile_id": tile_name_to_id.get(tile_name, -1),
		"orientation": orientation
	}

# Loads tile rules from XML configuration file
#
# Parses an XML file containing tile definitions with symmetries, weights,
# and adjacency rules. Automatically assigns IDs if not provided.
# The marker is a square array of 9 items. How the frame is rotated and reflected is used to determineThe center is the tile ID. 
# the settings for the godot tilemap. The center tile is the tile ID.
#
# Orientation numbers in XML:
# - 0 or none: Base orientation (0°)
# - 1: 90° clockwise rotation
# - 2: 180° rotation  
# - 3: 270° clockwise rotation
#
# Parameters:
#   xml_path: Path to the XML configuration file
#   tile_name_to_id: Optional mapping of tile names to IDs (auto-generated if empty)
# Returns: Dictionary with "tile_data" and "adjacency_rules" for WFC initialization
#
# Example:
# [codeblock]
# var xml_data = FastWFC.load_xml_rules("res://data/tileset_rules.xml")
# wfc.initialize_tiling(xml_data.tile_data, xml_data.adjacency_rules, width, height, periodic, seed)
# [/codeblock]
static func load_xml_rules(xml_path: String, tile_name_to_id: Dictionary = {}) -> Dictionary:
	var xml_data = _parse_xml_file(xml_path)
	if not xml_data:
		printerr("Failed to parse XML file: " + xml_path)
		return {"tile_data": {}, "adjacency_rules": []}
	
	# Auto-generate tile IDs if not provided
	var counter = 0
	if tile_name_to_id.is_empty():
		for tile in xml_data.tiles:
			tile_name_to_id[tile.name] = counter
			counter += 1

	# Process tile definitions
	var tile_data = {}
	for tile in xml_data.tiles:
		var tile_id = tile_name_to_id.get(tile.name, -1)
		if tile_id != -1:
			var content = [[0, 1, 2], [3, tile_id, 5], [6, 7, 8]]
			
			tile_data[tile.name] = {
				"content": content,
				"symmetry": tile.symmetry,
				"weight": tile.get("weight", 1.0)
			}
	
	# Process adjacency rules
	var adjacency_rules = []
	for neighbor in xml_data.neighbors:
		var left = _parse_tile_ref(neighbor.left, tile_name_to_id)
		var right = _parse_tile_ref(neighbor.right, tile_name_to_id)
		
		if left.tile_id != -1 and right.tile_id != -1:
			adjacency_rules.append({
				"tile1": left.tile_name,
				"orientation1": left.orientation,
				"tile2": right.tile_name,
				"orientation2": right.orientation
			})
	
	return {
		"tile_data": tile_data,
		"adjacency_rules": adjacency_rules
	}

#endregion
