# neovim-vala
NeoVim UI implemented in gtk4/vala

The project is **abandoned** in favour of [neovim-sdl2](http://github.com/sakhnik/neovim-sdl2).

I need an easy deployable low latency UI for NeoVim in Windows. It should be both simple and flexible.
Turns out, it's quite easy to code after experiments with [SpyUI](https://github.com/sakhnik/nvim-gdb/blob/07aa4b435a832b122154a157ab6892ac4efb81fb/test/spy_ui.py).

## TODO

- [x] Calculate width, height from the window size and chosen font
- [x] Redraw only changed parts of the screen, use an offscreen surface like in gtk4-demo
- [x] Improve redrawing by combining adjacent cells with the same hl_id
- [x] Test MinGW build
- [x] Setup GitHub actions to build for Win32
- [x] Cursor shapes
- [ ] Use pango for text layout
- [ ] Log to a file instead of stdout
- [ ] Properly close the editor when the window is about to be closed
- [ ] Allow selecting GUI font
- [ ] Mouse support
- [ ] Fast zoom with mouse wheel
- [ ] Automatic testing
- [ ] Make redrawing atomic with flush
- [ ] Get rid of console in windows
- [ ] Handle special keys like arrows, functional keys
- [ ] Handle the rest of highlight attributes
- [ ] Handle errors and failures
- [ ] Consider externalizing popup menus to add scrollbars
- [ ] Configuration of fonts and behaviour tweaking (consider using lua)
- [ ] Change mouse pointer on busy_start/busy_stop notifications
- [ ] Create window after neovim has been launched and initialized to avoid white flash during startup
- [ ] Setup automatic releases (win32, appimage)
- [ ] Track mode_info
