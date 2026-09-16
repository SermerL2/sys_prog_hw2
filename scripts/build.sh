# gcc -O0
gcc -O0 -g -o demo_gcc_O0   src/main.cpp src/scenarios.cpp src/handler.cpp

# gcc -O3
gcc -O3 -g -o demo_gcc_O3   src/main.cpp src/scenarios.cpp src/handler.cpp

# clang -O0
clang -O0 -g -o demo_clang_O0 src/main.cpp src/scenarios.cpp src/handler.cpp

# clang -O3
clang -O3 -g -o demo_clang_O3 src/main.cpp src/scenarios.cpp src/handler.cpp