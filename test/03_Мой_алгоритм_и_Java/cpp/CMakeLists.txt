cmake_minimum_required(VERSION 3.16)
project(test_suite_minimization LANGUAGES CXX)

set(CMAKE_CXX_STANDARD 17)
set(CMAKE_CXX_STANDARD_REQUIRED ON)
set(CMAKE_CXX_EXTENSIONS OFF)

add_library(minimizer_lib
    src/json.cpp
    src/model.cpp
    src/boundary.cpp
    src/minimizer.cpp
)
target_include_directories(minimizer_lib PUBLIC include)

add_executable(test_suite_minimization src/main.cpp)
target_link_libraries(test_suite_minimization PRIVATE minimizer_lib)

enable_testing()
add_executable(minimizer_tests tests/test_minimizer.cpp)
target_link_libraries(minimizer_tests PRIVATE minimizer_lib)
add_test(NAME minimizer_tests COMMAND minimizer_tests)

if(MSVC)
    target_compile_options(minimizer_lib PRIVATE /W4)
else()
    target_compile_options(minimizer_lib PRIVATE -Wall -Wextra -Wpedantic)
endif()
