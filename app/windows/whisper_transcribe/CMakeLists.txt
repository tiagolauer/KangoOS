cmake_minimum_required(VERSION 3.14)
project(whisper_transcribe LANGUAGES C CXX)

include(FetchContent)

# whisper.cpp and ggml declare install() rules for their headers and libraries.
# Flutter sets CMAKE_INSTALL_PREFIX to a generator expression that only resolves
# at build time, so those rules fail the INSTALL target with "cannot create
# directory .../$<TARGET_FILE_DIR:kangoos_app>/lib". The helper executable is
# copied by the runner in a POST_BUILD step, so nothing here needs installing.
#
# The override has to be guarded rather than unconditional: CMake macros are
# global once defined, so a bare no-op install() would also silence the runner's
# own install rules and delete the INSTALL target that `flutter build windows`
# invokes. KANGOOS_SUPPRESS_INSTALL is only ever set in this directory, so it is
# visible to whisper's subdirectories and undefined for sibling directories.
# CMAKE_SKIP_INSTALL_RULES is not an alternative: it stops the per-directory
# cmake_install.cmake files from being generated while the parent still
# includes them.
set(KANGOOS_SUPPRESS_INSTALL TRUE)
macro(install)
  if(NOT KANGOOS_SUPPRESS_INSTALL)
    _install(${ARGV})
  endif()
endmacro()

set(WHISPER_BUILD_TESTS OFF CACHE BOOL "" FORCE)
set(WHISPER_BUILD_EXAMPLES OFF CACHE BOOL "" FORCE)
set(WHISPER_BUILD_SERVER OFF CACHE BOOL "" FORCE)
set(GGML_OPENMP OFF CACHE BOOL "" FORCE)
set(BUILD_SHARED_LIBS OFF CACHE BOOL "" FORCE)

FetchContent_Declare(
  whisper_cpp
  GIT_REPOSITORY https://github.com/ggml-org/whisper.cpp
  GIT_TAG 080bbbe85230f624f0b52127f1ae1218247989f9
)
FetchContent_MakeAvailable(whisper_cpp)

add_executable(whisper_transcribe "whisper_transcribe.cpp")

target_compile_features(whisper_transcribe PRIVATE cxx_std_17)
target_link_libraries(whisper_transcribe PRIVATE whisper advapi32.lib)
