/**
 * Fast WFC GDExtension Registration
 * 
 * Handles the registration and initialization of the FastWFCWrapper class
 * with Godot's class database and extension system.
 */

#include "../include/register_types.h"
#include <gdextension_interface.h>
#include <godot_cpp/core/defs.hpp>
#include <godot_cpp/godot.hpp>
#include <godot_cpp/core/class_db.hpp>
#include "../include/fast_wfc_wrapper.hpp"

using namespace godot;

/**
 * Initializes the WFC wrapper module
 * 
 * Registers the FastWFCWrapper class with Godot's class database
 * during scene initialization.
 * 
 * Parameter p_level: Module initialization level provided by Godot
 */
void initialize_wfc_wrapper_module(ModuleInitializationLevel p_level) {
    if (p_level != MODULE_INITIALIZATION_LEVEL_SCENE) {
        return;
    }

    ClassDB::register_class<FastWFCWrapper>();
}

/**
 * Uninitializes the WFC wrapper module
 * 
 * Performs cleanup during module termination. Currently no specific
 * cleanup appears to be required.
 * 
 * Parameter p_level: Module initialization level provided by Godot
 */
void uninitialize_wfc_wrapper_module(ModuleInitializationLevel p_level) {
    if (p_level != MODULE_INITIALIZATION_LEVEL_SCENE) {
        return;
    }
}

/**
 * Main GDExtension entry point
 * 
 * Called by Godot to initialize the extension. Sets up the initialization
 * and termination callbacks, and configures the minimum initialization level.
 * 
 * Parameters:
 * p_get_proc_address: Function to get Godot API procedures
 * p_library: Library pointer for this extension
 * r_initialization: Initialization configuration structure
 * 
 * Returns: true if initialization succeeded, false otherwise
 */
extern "C" {
    GDExtensionBool GDE_EXPORT wfc_init(GDExtensionInterfaceGetProcAddress p_get_proc_address, 
                                        const GDExtensionClassLibraryPtr p_library, 
                                        GDExtensionInitialization *r_initialization) {
        try {
            godot::GDExtensionBinding::InitObject init_obj(p_get_proc_address, p_library, r_initialization);

            // Register initialization and termination callbacks
            init_obj.register_initializer(initialize_wfc_wrapper_module);
            init_obj.register_terminator(uninitialize_wfc_wrapper_module);
            init_obj.set_minimum_library_initialization_level(MODULE_INITIALIZATION_LEVEL_SCENE);

            return init_obj.init();
            
        } catch (const std::exception& e) {
            // Log initialization errors
            return false;
        } catch (...) {
            // Handle unknown initialization errors
            return false;
        }
    }
}