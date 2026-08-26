cmake_minimum_required(VERSION 3.14)
project(audio_capture LANGUAGES CXX)

add_executable(audio_capture "audio_capture.cpp")

target_compile_features(audio_capture PRIVATE cxx_std_17)
target_compile_definitions(audio_capture PRIVATE "NOMINMAX" "UNICODE" "_UNICODE")
target_link_libraries(audio_capture PRIVATE ole32.lib user32.lib)
