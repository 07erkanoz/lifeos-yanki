cmake_minimum_required(VERSION 3.13)
project(runner LANGUAGES CXX)

add_executable(${BINARY_NAME}
  "main.cc"
  "egl_config_fix.cc"
  "my_application.cc"
  "quick_search.cc"
  "${FLUTTER_MANAGED_DIR}/generated_plugin_registrant.cc"
)
apply_standard_settings(${BINARY_NAME})
target_compile_definitions(${BINARY_NAME} PRIVATE APPLICATION_ID="${APPLICATION_ID}")
target_link_libraries(${BINARY_NAME} PRIVATE flutter)
target_link_libraries(${BINARY_NAME} PRIVATE PkgConfig::GTK)
target_link_libraries(${BINARY_NAME} PRIVATE ${CMAKE_DL_LIBS})
target_include_directories(${BINARY_NAME} PRIVATE "${CMAKE_SOURCE_DIR}")
pkg_check_modules(X11 REQUIRED IMPORTED_TARGET x11)
target_link_libraries(${BINARY_NAME} PRIVATE PkgConfig::X11)
