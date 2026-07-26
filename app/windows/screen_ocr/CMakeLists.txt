cmake_minimum_required(VERSION 3.14)
project(screen_ocr LANGUAGES CXX)

add_executable(screen_ocr "screen_ocr.cpp")

target_compile_features(screen_ocr PRIVATE cxx_std_17)
target_compile_definitions(screen_ocr PRIVATE "NOMINMAX" "UNICODE" "_UNICODE")
target_link_libraries(screen_ocr PRIVATE user32.lib gdi32.lib windowsapp.lib)
