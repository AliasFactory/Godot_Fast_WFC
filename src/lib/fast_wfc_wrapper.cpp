/**
 * Fast WFC Wrapper Implementation
 * 
 * Implementation of the Godot GDExtension wrapper for the fast-wfc library.
 * Handles data conversion, error handling, and algorithm execution.
 */

#include "../include/fast_wfc_wrapper.hpp"
#include <godot_cpp/core/class_db.hpp>
#include <godot_cpp/core/error_macros.hpp>
#include <godot_cpp/variant/utility_functions.hpp>
#include <godot_cpp/classes/image_texture.hpp>
#include <algorithm>
#include "../fast-wfc/example/src/include/image.hpp"

using namespace godot;

/**
 * Generates a random seed for WFC algorithms
 * Returns a random integer seed
 */
int get_random_seed() {
    #ifdef __linux__
        return std::random_device()();
    #else
        return std::rand();
    #endif
}

void FastWFCWrapper::_bind_methods() {
    // Core generation method
    ClassDB::bind_method(D_METHOD("generate"), &FastWFCWrapper::generate);
    
    // Overlapping WFC methods
    ClassDB::bind_method(D_METHOD("initialize_overlapping_from_array", "color_array", "out_width", "out_height", "pattern_size", 
                                "periodic_input", "periodic_output", "ground", "symmetry", "seed"),
                        &FastWFCWrapper::initialize_overlapping_from_array, 
                        DEFVAL(false), DEFVAL(8), DEFVAL(-1));
    
    ClassDB::bind_method(D_METHOD("initialize_overlapping_from_path", "image_path", "out_width", "out_height", "pattern_size", 
                                 "periodic_input", "periodic_output", "ground", "symmetry", "seed"),
                         &FastWFCWrapper::initialize_overlapping_from_path, 
                         DEFVAL(false), DEFVAL(8), DEFVAL(-1));
    
    ClassDB::bind_method(D_METHOD("set_pattern_from_array", "color_array", "x", "y"),
                         &FastWFCWrapper::set_pattern_from_array);
    
    ClassDB::bind_method(D_METHOD("set_pattern_from_path", "pattern_path", "x", "y"),
                         &FastWFCWrapper::set_pattern_from_path);
    
    // Tiling WFC methods
    ClassDB::bind_method(D_METHOD("initialize_tiling", "tile_data", "adjacency_rules", 
                                 "width", "height", "periodic_output", "seed"),
                         &FastWFCWrapper::initialize_tiling,
                         DEFVAL(-1));
    
    ClassDB::bind_method(D_METHOD("set_tile", "tile_key", "orientation", "x", "y"),
                         &FastWFCWrapper::set_tile);
    
    // Output methods
    ClassDB::bind_method(D_METHOD("save_result_to_image", "path"),
                         &FastWFCWrapper::save_result_to_image);
    
    // Register enums
    BIND_ENUM_CONSTANT(TYPE_OVERLAPPING);
    BIND_ENUM_CONSTANT(TYPE_TILING);
}

FastWFCWrapper::FastWFCWrapper() : current_type(TYPE_OVERLAPPING) {
    wfc_instance = std::unique_ptr<OverlappingWFC<::Color>>(nullptr);
    last_result = std::optional<Array2D<::Color>>(std::nullopt);
}

FastWFCWrapper::~FastWFCWrapper() {
    // Smart pointers handle cleanup automatically
}

Array FastWFCWrapper::generate() {
    try {
        if (std::holds_alternative<std::unique_ptr<OverlappingWFC<::Color>>>(wfc_instance)) {
            auto& wfc = std::get<std::unique_ptr<OverlappingWFC<::Color>>>(wfc_instance);
            
            if (!wfc) {
                UtilityFunctions::printerr("FastWFCWrapper: Overlapping WFC instance not initialized");
                return Array();
            }
            
            auto result_opt = wfc->run();
            if (result_opt.has_value()) {
                last_result = result_opt;
                return array2D_to_godot_color_array(result_opt.value());
            } else {
                UtilityFunctions::printerr("FastWFCWrapper: Overlapping WFC generation failed");
                return Array();
            }
        }
        else if (std::holds_alternative<std::unique_ptr<TilingWFC<godot::Variant>>>(wfc_instance)) {
            auto& wfc = std::get<std::unique_ptr<TilingWFC<godot::Variant>>>(wfc_instance);
            
            if (!wfc) {
                UtilityFunctions::printerr("FastWFCWrapper: Tiling WFC instance not initialized");
                return Array();
            }

            auto result_opt = wfc->run();
            if (result_opt.has_value()) {
                last_result = result_opt;
                return convert_variant_result_to_godot_array(result_opt.value());
            } else {
                UtilityFunctions::printerr("FastWFCWrapper: Tiling WFC generation failed");
                return Array();
            }
        }
        
        UtilityFunctions::printerr("FastWFCWrapper: No WFC instance initialized");
        return Array();
        
    } catch (const std::exception& e) {
        UtilityFunctions::printerr(String("FastWFCWrapper: Exception during generation: ") + e.what());
        return Array();
    } catch (...) {
        UtilityFunctions::printerr("FastWFCWrapper: Unknown error during generation");
        return Array();
    }
}

void FastWFCWrapper::initialize_overlapping_from_array(const Array& color_array,
                                                     int out_width, int out_height, int pattern_size,
                                                     bool periodic_input, bool periodic_output,
                                                     bool ground, int symmetry, int seed) {
    current_type = TYPE_OVERLAPPING;
    int actual_seed = (seed == -1) ? get_random_seed() : seed;
    
    if (color_array.size() == 0) {
        UtilityFunctions::printerr("FastWFCWrapper: Empty color array provided");
        return;
    }
    
    // Validate array structure
    int input_height = color_array.size();
    int input_width = 0;
    if (input_height > 0 && color_array[0].get_type() == Variant::ARRAY) {
        Array first_row = color_array[0];
        input_width = first_row.size();
    } else {
        UtilityFunctions::printerr("FastWFCWrapper: Invalid color array format - expected 2D array");
        return;
    }
    
    // Convert to internal format
    Array2D<::Color> input_array = godot_color_array_to_array2d(color_array);
    
    // Configure WFC options
    OverlappingWFCOptions options = {
        periodic_input,
        periodic_output,
        static_cast<unsigned>(out_height),
        static_cast<unsigned>(out_width),
        static_cast<unsigned>(symmetry),
        ground,
        static_cast<unsigned>(pattern_size)
    };
    
    // Create WFC instance
    wfc_instance = std::make_unique<OverlappingWFC<::Color>>(input_array, options, actual_seed);
}

void FastWFCWrapper::initialize_overlapping_from_path(const String& image_path, int out_width, int out_height, 
                                                    int pattern_size, bool periodic_input, bool periodic_output,
                                                    bool ground, int symmetry, int seed) {
    current_type = TYPE_OVERLAPPING;
    int actual_seed = (seed == -1) ? get_random_seed() : seed;
    
    std::string std_path = image_path.utf8().get_data();
    auto input_array_opt = read_image(std_path);
    
    if (!input_array_opt.has_value()) {
        UtilityFunctions::printerr(String("FastWFCWrapper: Failed to load image: ") + image_path);
        return;
    }
    
    // Configure WFC options
    OverlappingWFCOptions options = {
        periodic_input,
        periodic_output,
        static_cast<unsigned>(out_height),
        static_cast<unsigned>(out_width),
        static_cast<unsigned>(symmetry),
        ground,
        static_cast<unsigned>(pattern_size)
    };
    
    // Create WFC instance
    wfc_instance = std::make_unique<OverlappingWFC<::Color>>(input_array_opt.value(), options, actual_seed);
}

bool FastWFCWrapper::set_pattern_from_array(const Array& color_array, int x, int y) {
    if (current_type != TYPE_OVERLAPPING) {
        UtilityFunctions::printerr("FastWFCWrapper: set_pattern_from_array only works with overlapping WFC");
        return false;
    }
    
    if (!std::holds_alternative<std::unique_ptr<OverlappingWFC<::Color>>>(wfc_instance)) {
        UtilityFunctions::printerr("FastWFCWrapper: Overlapping WFC not initialized");
        return false;
    }
    
    if (color_array.size() == 0) {
        UtilityFunctions::printerr("FastWFCWrapper: Empty pattern array provided");
        return false;
    }
    
    Array2D<::Color> pattern_array = godot_color_array_to_array2d(color_array);
    auto& wfc = std::get<std::unique_ptr<OverlappingWFC<::Color>>>(wfc_instance);
    
    return wfc->set_pattern(pattern_array, static_cast<unsigned>(x), static_cast<unsigned>(y));
}

bool FastWFCWrapper::set_pattern_from_path(const String& pattern_path, int x, int y) {
    if (current_type != TYPE_OVERLAPPING) {
        UtilityFunctions::printerr("FastWFCWrapper: set_pattern_from_path only works with overlapping WFC");
        return false;
    }
    
    std::string std_path = pattern_path.utf8().get_data();
    auto pattern_array_opt = read_image(std_path);
    
    if (!pattern_array_opt.has_value()) {
        UtilityFunctions::printerr(String("FastWFCWrapper: Failed to load pattern: ") + pattern_path);
        return false;
    }
    
    if (std::holds_alternative<std::unique_ptr<OverlappingWFC<::Color>>>(wfc_instance)) {
        auto& wfc = std::get<std::unique_ptr<OverlappingWFC<::Color>>>(wfc_instance);
        
        if (!wfc) {
            UtilityFunctions::printerr("FastWFCWrapper: Overlapping WFC not initialized");
            return false;
        }
        
        return wfc->set_pattern(pattern_array_opt.value(), static_cast<unsigned>(x), static_cast<unsigned>(y));
    }
    
    return false;
}

void FastWFCWrapper::initialize_tiling(const Dictionary& tile_data, const Array& adjacency_rules,
                                        int width, int height, bool periodic_output, int seed) {
    current_type = TYPE_TILING;
    int actual_seed = (seed == -1) ? get_random_seed() : seed;
    
    tile_keys.clear();
    
    // Convert tile definitions to internal format
    std::vector<Tile<godot::Variant>> tiles;
    int tile_id = 0;
    
    Array keys = tile_data.keys();
    for (int i = 0; i < keys.size(); i++) {
        String key = keys[i];
        Dictionary tile_info = tile_data[key];
        
        // Map tile key to numeric ID
        tile_keys.push_back(std::make_pair(key, tile_id++));
        
        // Parse symmetry type
        String sym_str = tile_info["symmetry"];
        Symmetry symmetry = Symmetry::X;
        if (sym_str == "I") symmetry = Symmetry::I;
        else if (sym_str == "L") symmetry = Symmetry::L;
        else if (sym_str == "T") symmetry = Symmetry::T;
        else if (sym_str == "backslash") symmetry = Symmetry::backslash;
        else if (sym_str == "P") symmetry = Symmetry::P;
        
        // Get tile weight
        double weight = tile_info.has("weight") ? static_cast<double>(tile_info["weight"]) : 1.0;
        
        // Convert tile content
        Variant content = tile_info["content"];
        if (content.get_type() == Variant::ARRAY) {
            Array content_array = content;
            
            if (content_array.size() > 0 && content_array[0].get_type() == Variant::ARRAY) {
                int tile_height = content_array.size();
                int tile_width = Array(content_array[0]).size();
                
                Array2D<godot::Variant> tile_array(tile_height, tile_width);
                for (int y = 0; y < tile_height; y++) {
                    Array row = content_array[y];
                    for (int x = 0; x < tile_width; x++) {
                        tile_array.get(y, x) = godot::Variant(row[x]);
                    }
                }
                tiles.push_back(Tile<godot::Variant>(tile_array, symmetry, weight));
            }
        }
    }
    
    // Convert adjacency rules to internal format
    std::vector<std::tuple<unsigned, unsigned, unsigned, unsigned>> neighbors;
    for (int i = 0; i < adjacency_rules.size(); i++) {
        Dictionary rule = adjacency_rules[i];
        
        String tile1_key = rule["tile1"];
        unsigned orientation1 = rule["orientation1"];
        String tile2_key = rule["tile2"];
        unsigned orientation2 = rule["orientation2"];
        
        // Look up tile IDs
        int tile1_id = find_tile_id(tile1_key);
        int tile2_id = find_tile_id(tile2_key);
        
        if (tile1_id >= 0 && tile2_id >= 0) {
            neighbors.push_back(std::make_tuple(
                static_cast<unsigned>(tile1_id),
                orientation1,
                static_cast<unsigned>(tile2_id),
                orientation2
            ));
        }
    }
    
    // Configure tiling options
    TilingWFCOptions options;
    options.periodic_output = periodic_output;
    
    // Create tiling WFC instance
    wfc_instance = std::make_unique<TilingWFC<godot::Variant>>(
        tiles, neighbors, height, width, options, actual_seed);
}

bool FastWFCWrapper::set_tile(const String& tile_key, int orientation, int x, int y) {
    if (current_type != TYPE_TILING) {
        UtilityFunctions::printerr("FastWFCWrapper: set_tile only works with tiling WFC");
        return false;
    }
    
    if (std::holds_alternative<std::unique_ptr<TilingWFC<godot::Variant>>>(wfc_instance)) {
        auto& wfc = std::get<std::unique_ptr<TilingWFC<godot::Variant>>>(wfc_instance);
        
        if (!wfc) {
            UtilityFunctions::printerr("FastWFCWrapper: Tiling WFC not initialized");
            return false;
        }
        
        int tile_id = find_tile_id(tile_key);
        if (tile_id < 0) {
            UtilityFunctions::printerr(String("FastWFCWrapper: Unknown tile key: ") + tile_key);
            return false;
        }
        
        return wfc->set_tile(static_cast<unsigned>(tile_id), orientation, x, y);
    }
    
    return false;
}

bool FastWFCWrapper::save_result_to_image(const String& path) {
    std::string std_path = path.utf8().get_data();
    
    if (std::holds_alternative<std::optional<Array2D<::Color>>>(last_result)) {
        auto& result_opt = std::get<std::optional<Array2D<::Color>>>(last_result);
        
        if (result_opt.has_value()) {
            write_image_png(std_path, result_opt.value());
            return true;
        }
    }
    else if (std::holds_alternative<std::optional<Array2D<godot::Variant>>>(last_result)) {
        auto& result_opt = std::get<std::optional<Array2D<godot::Variant>>>(last_result);
        
        if (result_opt.has_value()) {
            const Array2D<godot::Variant>& variant_array = result_opt.value();
            Array2D<::Color> color_array(variant_array.height, variant_array.width);
            
            // Convert variants to colors for image export
            for (size_t y = 0; y < variant_array.height; y++) {
                for (size_t x = 0; x < variant_array.width; x++) {
                    godot::Variant var = variant_array.get(y, x);
                    ::Color color;
                    
                    if (var.get_type() == godot::Variant::COLOR) {
                        godot::Color godot_color = var;
                        color = {
                            static_cast<unsigned char>(godot_color.r * 255),
                            static_cast<unsigned char>(godot_color.g * 255),
                            static_cast<unsigned char>(godot_color.b * 255)
                        };
                    } else {
                        // Default color for non-color variants
                        color = {255, 0, 0};
                    }
                    
                    color_array.get(y, x) = color;
                }
            }
            
            write_image_png(std_path, color_array);
            return true;
        }
    }
    
    UtilityFunctions::printerr("FastWFCWrapper: No result available to save");
    return false;
}

Array2D<::Color> FastWFCWrapper::godot_color_array_to_array2d(const Array& color_array) {
    if (color_array.size() == 0) {
        return Array2D<::Color>(0, 0);
    }
    
    int height = color_array.size();
    Array first_row = color_array[0];
    int width = first_row.size();
    
    Array2D<::Color> result(height, width);
    
    for (int y = 0; y < height; y++) {
        Array row = color_array[y];
        for (int x = 0; x < width && x < row.size(); x++) {
            godot::Color godot_color = row[x];
            ::Color color = {
                static_cast<unsigned char>(godot_color.r * 255),
                static_cast<unsigned char>(godot_color.g * 255),
                static_cast<unsigned char>(godot_color.b * 255)
            };
            result.get(y, x) = color;
        }
    }
    
    return result;
}

Array FastWFCWrapper::array2D_to_godot_color_array(const Array2D<::Color>& result) {
    Array output_array;
    
    for (size_t y = 0; y < result.height; y++) {
        Array row;
        for (size_t x = 0; x < result.width; x++) {
            const ::Color& color = result.get(y, x);
            godot::Color godot_color(
                color.r / 255.0f,
                color.g / 255.0f,
                color.b / 255.0f
            );
            row.append(godot_color);
        }
        output_array.append(row);
    }
    
    return output_array;
}

Array FastWFCWrapper::convert_variant_result_to_godot_array(const Array2D<godot::Variant>& result) {
    Array output_array;
    
    for (size_t y = 0; y < result.height; y++) {
        Array row;
        for (size_t x = 0; x < result.width; x++) {
            row.append(result.get(y, x));
        }
        output_array.append(row);
    }
    
    return output_array;
}

int FastWFCWrapper::find_tile_id(const String& key) const {
    auto it = std::find_if(tile_keys.begin(), tile_keys.end(),
                         [&key](const std::pair<String, int>& pair) {
                             return pair.first == key;
                         });
    
    return (it != tile_keys.end()) ? it->second : -1;
}