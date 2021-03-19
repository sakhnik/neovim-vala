# neovim-vala
NeoVim UI implemented in gtk4/vala

I need an easy deployable low latency UI for NeoVim in Windows. It should be both simple and flexible.
Turns out, it's quite easy to code after experiments with [SpyUI](https://github.com/sakhnik/nvim-gdb/blob/07aa4b435a832b122154a157ab6892ac4efb81fb/test/spy_ui.py).

## TODO

- [x] Calculate width, height from the window size and chosen font
- [ ] Test MinGW build
- [ ] Redraw only changed parts of the screen
- [ ] Setup GitHub actions to build for Win32, appimage for Linux
- [ ] Automatic testing
- [ ] Cursor shapes
- [ ] Handle special keys like arrows, functional keys
- [ ] Handle the rest of highlight attributes
- [ ] Handle errors and failures
- [ ] Allow selecting GUI font
- [ ] Consider externalizing popup menus to add scrollbars
- [ ] Configuration of fonts and behaviour tweaking (consider using lua)
