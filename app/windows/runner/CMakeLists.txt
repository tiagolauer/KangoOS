cmake_minimum_required(VERSION 3.14)
project(runner LANGUAGES CXX)

# Define the application target. To change its name, change BINARY_NAME in the
# top-level CMakeLists.txt, not the value here, or `flutter run` will no longer
# work.
#
# Any new source files that you add to the application should be added here.
add_executable(${BINARY_NAME} WIN32
  "flutter_window.cpp"
  "main.cpp"
  "utils.cpp"
  "win32_window.cpp"
  "${FLUTTER_MANAGED_DIR}/generated_plugin_registrant.cc"
  "Runner.rc"
  "runner.exe.manifest"
)

# Apply the standard set of build settings. This can be removed for applications
# that need different build settings.
apply_standard_settings(${BINARY_NAME})

# Add preprocessor definitions for the build version.
target_compile_definitions(${BINARY_NAME} PRIVATE "FLUTTER_VERSION=\"${FLUTTER_VERSION}\"")
target_compile_definitions(${BINARY_NAME} PRIVATE "FLUTTER_VERSION_MAJOR=${FLUTTER_VERSION_MAJOR}")
target_compile_definitions(${BINARY_NAME} PRIVATE "FLUTTER_VERSION_MINOR=${FLUTTER_VERSION_MINOR}")
target_compile_definitions(${BINARY_NAME} PRIVATE "FLUTTER_VERSION_PATCH=${FLUTTER_VERSION_PATCH}")
target_compile_definitions(${BINARY_NAME} PRIVATE "FLUTTER_VERSION_BUILD=${FLUTTER_VERSION_BUILD}")

# Disable Windows macros that collide with C++ standard library functions.
target_compile_definitions(${BINARY_NAME} PRIVATE "NOMINMAX")

# Add dependency libraries and include directories. Add any application-specific
# dependencies here.
target_link_libraries(${BINARY_NAME} PRIVATE flutter flutter_wrapper_app)
target_link_libraries(${BINARY_NAME} PRIVATE "dwmapi.lib")
target_include_directories(${BINARY_NAME} PRIVATE "${CMAKE_SOURCE_DIR}")

# Run the Flutter tool portions of the build. This must not be removed.
add_dependencies(${BINARY_NAME} flutter_assemble)

# The screen-OCR helper ships next to the runner. This copy has to live in the
# runner's own CMakeLists: add_custom_command(TARGET ...) only accepts targets
# created in the same directory scope.
add_dependencies(${BINARY_NAME} screen_ocr)
add_custom_command(
  TARGET ${BINARY_NAME} POST_BUILD
  COMMAND ${CMAKE_COMMAND} -E copy_if_different
          "$<TARGET_FILE:screen_ocr>"
          "$<TARGET_FILE_DIR:${BINARY_NAME}>/screen_ocr.exe"
  COMMENT "Bundling screen_ocr helper (screen-text LTM capture)"
  VERBATIM
)

find_program(DART_EXECUTABLE NAMES dart dart.exe)
if(DART_EXECUTABLE)
  set(UIA_CAPTURE_SOURCE "${CMAKE_CURRENT_SOURCE_DIR}/../../bin/uia_capture.dart")
  add_custom_command(
    TARGET ${BINARY_NAME} POST_BUILD
    COMMAND "${DART_EXECUTABLE}" compile exe "${UIA_CAPTURE_SOURCE}"
            -o "$<TARGET_FILE_DIR:${BINARY_NAME}>/uia_capture.exe"
    COMMENT "Compiling uia_capture helper (visible-text LTM capture)"
    VERBATIM
  )
else()
  message(WARNING "dart executable not found on PATH; uia_capture.exe will "
    "not be built. The 'capture visible text' setting will silently no-op.")
endif()
