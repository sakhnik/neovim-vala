#!/bin/bash -e

pacman -S --noconfirm \
  mingw-w64-x86_64-gcc \
  mingw-w64-x86_64-vala \
  mingw-w64-x86_64-gtk4 \
  mingw-w64-x86_64-msgpack-c \
  mingw-w64-x86_64-pkg-config \
  mingw-w64-x86_64-ninja \
  mingw-w64-x86_64-meson \
  mingw-w64-x86_64-ntldd-git \
  zip
