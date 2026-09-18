#!/usr/bin/env bash
set -eu

# Сборка 4 бинарников: gcc/clang × -O0/-O3
gcc   -O0 -g -o demo_gcc_O0    src/main.cpp src/scenarios.cpp src/handler.cpp
gcc   -O3 -g -o demo_gcc_O3    src/main.cpp src/scenarios.cpp src/handler.cpp
clang -O0 -g -o demo_clang_O0  src/main.cpp src/scenarios.cpp src/handler.cpp
clang -O3 -g -o demo_clang_O3  src/main.cpp src/scenarios.cpp src/handler.cpp

echo "Сборка завершена:"
ls -1 demo_*