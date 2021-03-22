#!/bin/bash -e

echo $PATH

meson setup build --buildtype=release
cd build
ninja
