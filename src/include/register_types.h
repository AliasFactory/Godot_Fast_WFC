// register_types.h
#ifndef WFC_WRAPPER_REGISTER_TYPES_H
#define WFC_WRAPPER_REGISTER_TYPES_H

#include <godot_cpp/core/class_db.hpp>

using namespace godot;

void initialize_wfc_wrapper_module(ModuleInitializationLevel p_level);
void uninitialize_wfc_wrapper_module(ModuleInitializationLevel p_level);

#endif // WFC_WRAPPER_REGISTER_TYPES_H