#!/bin/bash -e

if [[ "$WORKSPACE_MSYS2" ]]; then
  cd "$WORKSPACE_MSYS2"
fi

cd build
mkdir -p dist/{bin,lib,share}
cp nvv.exe dist/bin

dlls=$(ntldd.exe -R nvv.exe | grep -Po "[^ ]+?msys64[^ ]+" | sort -u | grep -Po '[^\\]+$')
for dll in $dlls; do
  cp /mingw64/bin/$dll dist/bin
done

cp -R /mingw64/lib/gdk-pixbuf-2.0 dist/lib/
cp -R /mingw64/share/{glib-2.0,icons} dist/share/

pushd dist
zip -r ../nvim-win64.zip *
