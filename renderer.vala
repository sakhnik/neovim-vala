
class Renderer : GLib.Object {

    private unowned MsgpackRpc _rpc;

    public struct Vector {
        int row;
        int col;
    }

    private Vector _size;

    public struct Cell {
        string text;
        uint hl_id;
    }

    private Cell[,] _grid;

    public unowned Cell[,] get_grid () {
        return _grid;
    }

    private Vector _cursor;

    public unowned Vector get_cursor () {
        return _cursor;
    }

    public signal void flush ();

    public Renderer (MsgpackRpc rpc) {
        _rpc = rpc;
        _size = Vector() { col = 80, row = 25 };
        _attributes.set (0, new HlAttr (&_fg, &_bg));
    }

    public void attach_ui () {
        _rpc.set_on_notification (on_notification);
        _rpc.start ();

        _grid = new Cell[_size.row, _size.col];

        _rpc.request (
            (packer) => {
                unowned uint8[] ui_attach = "nvim_ui_attach".data;
                packer.pack_str (ui_attach.length);
                packer.pack_str_body (ui_attach);
                packer.pack_array(3);
                packer.pack_int (_size.col);
                packer.pack_int (_size.row);
                packer.pack_map (2);
                unowned uint8[] rgb = "rgb".data;
                packer.pack_str (rgb.length);
                packer.pack_str_body (rgb);
                packer.pack_true ();
                unowned uint8[] ext_linegrid = "ext_linegrid".data;
                packer.pack_str (ext_linegrid.length);
                packer.pack_str_body (ext_linegrid);
                packer.pack_true ();
            },
            (err, resp) => {
                if (err.type != MessagePack.Type.NIL) {
                    printerr ("Failed to attach UI ");
                    //err.print (stderr);
                    printerr ("\n");
                    //throw new SpawnError.FAILED ("");
                }
            });
    }

    private static bool memEqual (uint8[] a, uint8[] b) {
        return a.length == b.length && 0 == Memory.cmp(a, b, a.length);
    }

    private delegate void HandlerType (MessagePack.Object[] event);

    private void on_notification (uint8[] method, MessagePack.Object obj) {

        if (!memEqual(method, "redraw".data)) {
            print ("Unexpected notification %.*s\n", method.length, method);
            return;
        }

        unowned var arr = obj.array.objects;
        for (size_t i = 0; i < arr.length; ++i) {

            HandlerType handler = null;

            unowned var event = arr[i].array.objects;
            unowned var subtype = event[0].str.str;
            if (memEqual (subtype, "flush".data)) {
                flush ();
            } else if (memEqual (subtype, "grid_resize".data)) {
                handler = grid_resize;
            } else if (memEqual (subtype, "grid_line".data)) {
                handler = grid_line;
            } else if (memEqual (subtype, "grid_cursor_goto".data)) {
                handler = grid_cursor_goto;
            } else if (memEqual (subtype, "default_colors_set".data)) {
                default_colors_set (event[1].array.objects);
            } else if (memEqual (subtype, "hl_attr_define".data)) {
                handler = hl_attr_define;
            } else if (memEqual (subtype, "grid_scroll".data)) {
                handler = grid_scroll;
            } else if (memEqual (subtype, "win_viewport".data)) {
                // just info to display, can skip
            } else {
                print ("Ignoring redraw %.*s\n", subtype.length, subtype);
                continue;
            }

            if (handler != null) {
                for (size_t j = 1; j < event.length; ++j) {
                    unowned var instance = event[j].array.objects;
                    handler (instance);
                }
            }
        }
    }

    private void grid_resize (MessagePack.Object[] event) {
        int64 grid = event[0].i64;
        if (grid != 1) {
            //throw std::runtime_error("Multigrid not supported");
            return;
        }
        int width = (int)event[1].i64;
        int height = (int)event[2].i64;
        _grid = new Cell[height, width];
    }

    public signal void changed (int top, int bot, int left, int right);

    private void grid_cursor_goto (MessagePack.Object[] event) {
        int64 grid = event[0].i64;
        if (grid != 1) {
            //throw std::runtime_error("Multigrid not supported");
            return;
        }
        var cursor0 = _cursor;
        _cursor.row = (int)event[1].i64;
        _cursor.col = (int)event[2].i64;
        // TODO reconsider whether the cursor should be part of the grid.
        // Maybe it's worth drawing separately.
        changed (cursor0.row, cursor0.row + 1, cursor0.col, cursor0.col + 1);
        changed (_cursor.row, _cursor.row + 1, _cursor.col, _cursor.col + 1);
    }

    private void grid_line (MessagePack.Object[] event) {
        int64 grid = event[0].i64;
        if (grid != 1) {
            //throw std::runtime_error("Multigrid not supported");
            return;
        }
        int row = (int)event[1].i64;
        int col = (int)event[2].i64;
        int col0 = col;
        unowned var cells = event[3].array.objects;

        uint hl_id = 0;
        for (size_t c = 0; c < cells.length; ++c) {
            unowned var cell = cells[c].array.objects;
            int repeat = 1;

            unowned uint8[] text = cell[0].str.str;

            // if repeat is greater than 1, we are guaranteed to send an hl_id
            // https://github.com/neovim/neovim/blob/master/src/nvim/api/ui.c#L483
            if (cell.length > 1) {
                hl_id = (uint)cell[1].u64;
            }
            if (cell.length > 2) {
                repeat = (int)cell[2].i64;
            }

            int start_col = col;
            Cell buf_cell = Cell() {hl_id = hl_id};
            uint8[] char_buf = {};
            // TODO: use string.to_utf8()
            for (size_t i = 0; i < text.length; ++i) {
                uint8 ch = text[i];
                if (char_buf.length != 0 && (ch & 0xC0) != 0x80) {
                    char_buf += 0;
                    buf_cell.text = (string)char_buf;
                    _grid[row, col] = buf_cell;
                    char_buf.resize (0);
                    ++col;
                }
                char_buf += ch;
            }
            char_buf += 0;
            buf_cell.text = (string)char_buf;
            _grid[row, col] = buf_cell;
            ++col;

            int stride = col - start_col;
            while (--repeat > 0) {
                for (int i = 0; i < stride; ++i, ++col) {
                    unowned var src = _grid[row, col - stride];
                    var dst = Cell() {
                        hl_id = src.hl_id,
                        text = src.text.dup()
                    };
                    _grid[row, col] = dst;
                }
            }
        }

        changed (row, row + 1, col0, col);
    }

    private void grid_scroll (MessagePack.Object[] event) {
        int64 grid = event[0].i64;
        if (grid != 1) {
            //throw std::runtime_error("Multigrid not supported");
            return;
        }
        int top = (int)event[1].i64;
        int bot = (int)event[2].i64;
        int left = (int)event[3].i64;
        int right = (int)event[4].i64;
        int rows = (int)event[5].i64;
        int cols = (int)event[6].i64;
        if (cols != 0) {
            //throw std::runtime_error("Column scrolling not expected");
            return;
        }

        if (rows > 0) {
            for (int row = top; row < bot - rows; ++row) {
                var rfrom = row + rows;
                for (int col = left; col < right; ++col) {
                    _grid[row, col] = _grid[rfrom, col];
                }
            }
            changed (top, bot - rows, left, right);
        } else if (rows < 0) {
            for (int row = bot - 1; row > top - rows - 1; --row) {
                var rfrom = row + rows;
                for (int col = left; col < right; ++col) {
                    _grid[row, col] = _grid[rfrom, col];
                }
            }
            changed (top + rows, bot, left, right);
        } else {
            //throw std::runtime_error("Rows should not equal 0");
            return;
        }
    }

    public uint32 bg { get; private set; default = 0; }
    private uint32 _fg = 0xffffff;

    private void default_colors_set (MessagePack.Object[] param) {
        _fg = (uint32)param[0].u64;
        bg = (uint32)param[1].u64;
    }

    public struct Color {
        bool is_defined;
        uint32 rgb;
        uint32* def_rgb;

        public static Color undefined (uint32* def) {
            return Color() {
                is_defined = false,
                rgb = 0,
                def_rgb = def
            };
        }

        public void set_rgb (uint32 val) {
            is_defined = true;
            rgb = val;
        }

        public uint32 get_rgb () {
            return is_defined ? rgb : *def_rgb;
        }
    }

    public class HlAttr {
        public Color fg;
        public Color bg;
        public bool bold = false;
        public bool reverse = false;
        public bool italic = false;
        public bool underline = false;
        public bool undercurl = false;

        public HlAttr (uint32* def_fg, uint32* def_bg) {
            fg = Color.undefined (def_fg);
            bg = Color.undefined (def_bg);
        }
    }

    private HashTable<uint, HlAttr?> _attributes = new HashTable<uint, HlAttr?> (direct_hash, direct_equal);

    private void hl_attr_define (MessagePack.Object[] event) {
        uint hl_id = (uint)event[0].u64;
        unowned var rgb_attr = event[1].map.entries;
        var attr = new HlAttr (&_fg, &_bg);

        // nvim api docs state that boolean keys here are only sent if true
        for (int i = 0; i < rgb_attr.length; ++i) {
            unowned var key = rgb_attr[i].key.str.str;
            if (memEqual (key, "foreground".data)) {
                attr.fg.set_rgb ((uint32)rgb_attr[i].value.u64);
            } else if (memEqual (key, "background".data)) {
                attr.bg.set_rgb ((uint32)rgb_attr[i].value.u64);
            } else if (memEqual (key, "reverse".data)) {
                attr.reverse = true;
            } else if (memEqual (key, "italic".data)) {
                attr.italic = true;
            } else if (memEqual (key, "underline".data)) {
                attr.underline = true;
            } else if (memEqual (key, "undercurl".data)) {
                attr.undercurl = true;
            } else if (memEqual (key, "bold".data)) {
                attr.bold = true;
            } else {
                print ("Unknown attribute: %.*s\n", key.length, key);
            }
        }

        _attributes.set (hl_id, attr);
    }

    // TODO consider immutability of the reference (const in C++)?
    public unowned HlAttr get_hl_attr (uint hl_id) {
        return _attributes.get (hl_id);
    }

    public void try_resize (int rows, int cols) {
        _rpc.request (
            (packer) => {
                unowned uint8[] ui_resize = "nvim_ui_try_resize".data;
                packer.pack_str (ui_resize.length);
                packer.pack_str_body (ui_resize);
                packer.pack_array(2);
                packer.pack_int (cols);
                packer.pack_int (rows);
            },
            (err, resp) => {
                if (err.type != MessagePack.Type.NIL) {
                    printerr ("Failed to resize UI ");
                    //err.print (stderr);
                    printerr ("\n");
                    //throw new SpawnError.FAILED ("");
                }
            });
    }
}
