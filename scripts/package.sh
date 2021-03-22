#!/bin/bash -e

if [[ "$WORKSPACE_MSYS2" ]]; then
  cd "$WORKSPACE_MSYS2"
fi

mkdir -p dist/nvv/{bin,lib,share}
cp build/nvv.exe dist/nvv/bin

dlls=$(ntldd.exe -R build/nvv.exe | grep -Po "[^ ]+?msys64[^ ]+" | sort -u | grep -Po '[^\\]+$')
for dll in $dlls; do
  cp /mingw64/bin/$dll dist/nvv/bin
done
cp /mingw64/bin/gspawn* dist/nvv/bin

cp -R /mingw64/lib/gdk-pixbuf-2.0 dist/nvv/lib/
cp -R /mingw64/share/{glib-2.0,icons} dist/nvv/share/

pushd dist
zip -r nvv-win64.zip *
popd
