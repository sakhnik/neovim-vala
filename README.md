# neovim-vala
NeoVim UI implemented in gtk4/vala

I need an easy deployable low latency UI for NeoVim in Windows. It should be both simple and flexible.
Turns out, it's quite easy to code after experiments with [SpyUI](https://github.com/sakhnik/nvim-gdb/blob/07aa4b435a832b122154a157ab6892ac4efb81fb/test/spy_ui.py).

## TODO

- [x] Calculate width, height from the window size and chosen font
- [x] Redraw only changed parts of the screen, use an offscreen surface like in gtk4-demo
- [x] Improve redrawing by combining adjacent cells with the same hl_id
- [ ] Test MinGW build
- [ ] Setup GitHub actions to build for Win32, appimage for Linux
- [ ] Automatic testing
- [ ] Cursor shapes
- [ ] Make redrawing atomic with flush
- [ ] Handle special keys like arrows, functional keys
- [ ] Handle the rest of highlight attributes
- [ ] Handle errors and failures
- [ ] Use pango for text layout
- [ ] Allow selecting GUI font
- [ ] Consider externalizing popup menus to add scrollbars
- [ ] Configuration of fonts and behaviour tweaking (consider using lua)
- [ ] Mouse support
- [ ] Change mouse pointer on busy_start/busy_stop notifications
