#!/bin/bash -e

if [[ "$GITHUB_WORKSPACE" ]]; then
  cd "/$(sed 's/[:\]\+/\//g' <<<"$GITHUB_WORKSPACE")"
fi

meson setup build --buildtype=release
cd build
ninja
