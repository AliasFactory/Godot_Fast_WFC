/**
 * Fast WFC Wrapper for Godot
 * 
 * A GDExtension wrapper around the fast-wfc C++ library, providing Wave Function Collapse
 * functionality for procedural generation in Godot projects.
 * 
 * Supports both overlapping and tiling WFC algorithms:
 * - Overlapping WFC: Generates textures based on input image patterns
 * - Tiling WFC: Generates layouts using predefined tiles with adjacency rules
 * 
 */

#ifndef FAST_WFC_WRAPPER_HPP
#define FAST_WFC_WRAPPER_HPP

#include <godot_cpp/classes/node3d.hpp>
#include <godot_cpp/classes/image.hpp>
#include <godot_cpp/variant/dictionary.hpp>
#include <godot_cpp/variant/array.hpp>
#include <godot_cpp/core/property_info.hpp>
#include <memory>
#include <variant>
#include <vector>
#include <utility>
#include <optional>

#include "../fast-wfc/src/include/overlapping_wfc.hpp"
#include "../fast-wfc/src/include/tiling_wfc.hpp"
#include "../fast-wfc/example/src/include/color.hpp"

namespace godot {

/**
 * FastWFCWrapper
 * 
 * Main interface for Wave Function Collapse algorithms in Godot
 * 
 * This class provides a unified interface to both overlapping and tiling WFC algorithms.
 * It handles the conversion between Godot data types and the underlying C++ implementation.
 * 
 * Usage patterns:
 * 1. Initialize with either overlapping or tiling method
 * 2. Optionally set constraints using set_pattern/set_tile methods
 * 3. Call generate() to run the WFC algorithm
 * 4. Use save_result_to_image() to export results
 * 
 * Thread safety: This class is not thread-safe. Use separate instances for concurrent generation.
 */
class FastWFCWrapper : public Node3D {
    GDCLASS(FastWFCWrapper, Node3D)
    
public:
    /**
     * WFCType
     * 
     * Defines the type of WFC algorithm to use
     */
    enum WFCType {
        TYPE_OVERLAPPING = 0,  ///< Overlapping WFC for texture generation
        TYPE_TILING = 1        ///< Tiling WFC for tile-based generation
    };
    
    /**
     * Constructor - initializes wrapper in overlapping mode
     */
    FastWFCWrapper();
    
    /**
     * Destructor - handles cleanup of WFC instances
     */
    ~FastWFCWrapper() noexcept;
    
    // ===== GENERATION =====
    
    /**
     * @brief Runs the WFC algorithm and returns the generated result
     * 
     * Must be called after initialization. The algorithm will attempt to generate
     * a valid output that satisfies all constraints. May fail if constraints are
     * impossible to satisfy.
     * 
     * @return Array containing the generated result, or empty Array on failure
     *         - Overlapping WFC: 2D array of Color objects
     *         - Tiling WFC: 2D array of tile identifiers
     */
    Array generate();
    
    // ===== OVERLAPPING WFC INITIALIZATION =====
    
    /**
     * @brief Initializes overlapping WFC from a color array
     * 
     * @param color_array 2D array of Color objects representing the input pattern
     * @param out_width Output width in pixels
     * @param out_height Output height in pixels  
     * @param pattern_size Size of patterns to extract (typically 2-4)
     * @param periodic_input Whether input wraps around edges
     * @param periodic_output Whether output should wrap around edges
     * @param ground Whether to enforce ground patterns at bottom
     * @param symmetry Number of symmetries to consider (1-8)
     * @param seed Random seed (-1 for random)
     */
    void initialize_overlapping_from_array(const Array& color_array, int out_width, int out_height, 
                                         int pattern_size, bool periodic_input, bool periodic_output,
                                         bool ground = false, int symmetry = 8, int seed = -1);
    
    /**
     * @brief Initializes overlapping WFC from an image file
     * 
     * @param image_path Path to input image file
     * @param out_width Output width in pixels
     * @param out_height Output height in pixels
     * @param pattern_size Size of patterns to extract (typically 2-4)
     * @param periodic_input Whether input wraps around edges
     * @param periodic_output Whether output should wrap around edges
     * @param ground Whether to enforce ground patterns at bottom
     * @param symmetry Number of symmetries to consider (1-8)
     * @param seed Random seed (-1 for random)
     */
    void initialize_overlapping_from_path(const String& image_path, int out_width, int out_height, 
                                        int pattern_size, bool periodic_input, bool periodic_output,
                                        bool ground = false, int symmetry = 8, int seed = -1);
    
    // ===== OVERLAPPING WFC CONSTRAINTS =====
    
    /**
     * @brief Sets a specific pattern constraint at given coordinates
     * 
     * Forces the algorithm to place a specific pattern at the given location.
     * Pattern must match the pattern_size used during initialization.
     * 
     * @param color_array 2D array representing the pattern to place
     * @param x X coordinate in the wave grid
     * @param y Y coordinate in the wave grid
     * @return true if constraint was successfully applied
     */
    bool set_pattern_from_array(const Array& color_array, int x, int y);
    
    /**
     * @brief Sets a pattern constraint from an image file
     * 
     * @param pattern_path Path to pattern image file
     * @param x X coordinate in the wave grid
     * @param y Y coordinate in the wave grid
     * @return true if constraint was successfully applied
     */
    bool set_pattern_from_path(const String& pattern_path, int x, int y);
    
    // ===== TILING WFC INITIALIZATION =====
    
    /**
     * @brief Initializes tiling WFC with tile definitions and adjacency rules
     * 
     * @param tile_data Dictionary mapping tile names to tile properties:
     *                  - "content": 2D array representing tile data
     *                  - "symmetry": Symmetry type ("X", "I", "L", "T", "backslash", "P")
     *                  - "weight": Relative frequency (optional, default 1.0)
     * @param adjacency_rules Array of adjacency rules, each containing:
     *                       - "tile1": First tile name
     *                       - "orientation1": First tile orientation (0-7)
     *                       - "tile2": Second tile name  
     *                       - "orientation2": Second tile orientation (0-7)
     * @param width Output width in tiles
     * @param height Output height in tiles
     * @param periodic_output Whether output wraps around edges
     * @param seed Random seed (-1 for random)
     */
    void initialize_tiling(const Dictionary& tile_data, const Array& adjacency_rules,
                          int width, int height, bool periodic_output, int seed = -1);
    
    // ===== TILING WFC CONSTRAINTS =====
    
    /**
     * @brief Sets a specific tile at given coordinates
     * 
     * Forces a specific tile with given orientation to be placed at the location.
     * 
     * @param tile_key Name of the tile to place
     * @param orientation Tile orientation (0-7):
     *                   0-3: 0°, 90°, 180°, 270° rotations
     *                   4-7: Same rotations with reflection
     * @param x X coordinate in the tile grid
     * @param y Y coordinate in the tile grid
     * @return true if tile was successfully set
     */
    bool set_tile(const String& tile_key, int orientation, int x, int y);
    
    // ===== OUTPUT =====
    
    /**
     * @brief Saves the last generated result to an image file
     * 
     * Only works after successful generation. Converts the result to PNG format.
     * 
     * @param path Output file path (should end with .png)
     * @return true if image was successfully saved
     */
    bool save_result_to_image(const String& path);
    
private:
    WFCType current_type;  ///< Currently active WFC algorithm type
    
    /// Storage for WFC algorithm instances using std::variant for type safety
    std::variant<
        std::unique_ptr<OverlappingWFC<::Color>>,
        std::unique_ptr<TilingWFC<godot::Variant>>
    > wfc_instance;
    
    /// Storage for the last generated result
    std::variant<
        std::optional<Array2D<::Color>>,
        std::optional<Array2D<godot::Variant>>
    > last_result;
    
    /// Mapping between tile keys and internal IDs for tiling WFC
    std::vector<std::pair<String, int>> tile_keys;
    
    // ===== HELPER METHODS =====
    
    /**
     * @brief Converts Godot color array to internal Array2D format
     * @param color_array Input Godot Array of Colors
     * @return Internal Array2D<::Color> representation
     */
    Array2D<::Color> godot_color_array_to_array2d(const Array& color_array);
    
    /**
     * @brief Converts internal Array2D to Godot color array
     * @param result Internal Array2D<::Color> result
     * @return Godot Array of Colors
     */
    Array array2D_to_godot_color_array(const Array2D<::Color>& result);
    
    /**
     * @brief Converts variant result to Godot array format
     * @param result Internal Array2D<Variant> result  
     * @return Godot Array representation
     */
    Array convert_variant_result_to_godot_array(const Array2D<godot::Variant>& result);
    
    /**
     * @brief Finds internal tile ID from tile key
     * @param key Tile key string
     * @return Internal tile ID, or -1 if not found
     */
    int find_tile_id(const String& key) const;
    
protected:
    /**
     * @brief Binds methods to Godot's class system
     */
    static void _bind_methods();
};

}  // namespace godot

// Register the enum with Godot's variant system
VARIANT_ENUM_CAST(godot::FastWFCWrapper::WFCType);

#endif // FAST_WFC_WRAPPER_HPP