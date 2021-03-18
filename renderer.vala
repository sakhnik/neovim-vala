
class Renderer : GLib.Object {

    private unowned MsgpackRpc _rpc;

    public struct Vector {
        uint32 row;
        uint32 col;
    }

    private Vector _size;

    public struct Cell {
        string text;
        uint32 hl_id;
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
        set_hl_attr (0, new _HlAttr ());
    }

    public void attach_ui ()
    {
        _rpc.set_on_notification (on_notification);
        _rpc.start ();

        _grid = new Cell[_size.row, _size.col];

        _rpc.request (
            (packer) => {
                unowned uint8[] ui_attach = "nvim_ui_attach".data;
                packer.pack_str (ui_attach.length);
                packer.pack_str_body (ui_attach);
                packer.pack_array(3);
                packer.pack_uint32 (_size.col);
                packer.pack_uint32 (_size.row);
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

    private void grid_cursor_goto (MessagePack.Object[] event) {
        int64 grid = event[0].i64;
        if (grid != 1) {
            //throw std::runtime_error("Multigrid not supported");
            return;
        }
        _cursor.row = (uint32)event[1].u64;
        _cursor.col = (uint32)event[2].u64;
    }

    private void grid_line (MessagePack.Object[] event) {
        int64 grid = event[0].i64;
        if (grid != 1) {
            //throw std::runtime_error("Multigrid not supported");
            return;
        }
        uint32 row = (uint32)event[1].u64;
        uint32 col = (uint32)event[2].u64;
        unowned var cells = event[3].array.objects;

        uint32 hl_id = 0;
        for (size_t c = 0; c < cells.length; ++c) {
            unowned var cell = cells[c].array.objects;
            int64 repeat = 1;

            unowned uint8[] text = cell[0].str.str;

            // if repeat is greater than 1, we are guaranteed to send an hl_id
            // https://github.com/neovim/neovim/blob/master/src/nvim/api/ui.c#L483
            if (cell.length > 1) {
                hl_id = (uint32)cell[1].u64;
            }
            if (cell.length > 2) {
                repeat = cell[2].i64;
            }

            uint32 start_col = col;
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

            uint32 stride = col - start_col;
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
        } else if (rows < 0) {
            for (int row = bot - 1; row > top - rows - 1; --row) {
                var rfrom = row + rows;
                for (int col = left; col < right; ++col) {
                    _grid[row, col] = _grid[rfrom, col];
                }
            }
        } else {
            //throw std::runtime_error("Rows should not equal 0");
            return;
        }
    }

    private uint32 _bg = 0;
    private uint32 _fg = 0xffffff;

    private void default_colors_set (MessagePack.Object[] param) {
        _fg = (uint32)param[0].u64;
        _bg = (uint32)param[1].u64;
        print ("** fg=%x bg=%x\n", _fg, _bg);
    }

    private struct Color {
        bool is_defined;
        uint32 rgb;

        public static Color undefined () {
            return Color() {
                is_defined = false,
                rgb = 0
            };
        }

        public void set_rgb (uint32 val) {
            is_defined = true;
            rgb = val;
        }
    }

    private class _HlAttr {
        public Color fg = Color.undefined ();
        public Color bg = Color.undefined ();
        public bool bold = false;
        public bool reverse = false;
    }

    private HashTable<uint32, _HlAttr?> _attributes = new HashTable<uint32, _HlAttr?> (direct_hash, direct_equal);

    private void hl_attr_define (MessagePack.Object[] event) {
        uint32 hl_id = (uint32)event[0].u64;
        unowned var rgb_attr = event[1].map.entries;
        var attr = new _HlAttr ();

        // nvim api docs state that boolean keys here are only sent if true
        for (int i = 0; i < rgb_attr.length; ++i) {
            unowned var key = rgb_attr[i].key.str.str;
            if (memEqual (key, "foreground".data)) {
                attr.fg.set_rgb ((uint32)rgb_attr[i].value.u64);
            } else if (memEqual (key, "background".data)) {
                attr.bg.set_rgb ((uint32)rgb_attr[i].value.u64);
            } else if (memEqual (key, "reverse".data)) {
                attr.reverse = true;
            } else if (memEqual (key, "bold".data)) {
                attr.bold = true;
            }
        }

        set_hl_attr (hl_id, attr);
    }

    private void set_hl_attr (uint32 hl_id, _HlAttr? attr) {
        if (attr == null) {
            _attributes.remove (hl_id);
        } else {
            _attributes.set (hl_id, attr);
        }
    }

    public struct HlAttr {
        uint32 fg;
        uint32 bg;
        bool bold;
        bool reverse;
    }

    public HlAttr get_hl_attr (uint32 hl_id) {
        unowned var attr = _attributes.get (hl_id);
        if (attr != null) {
            HlAttr ret = HlAttr() {
                fg = attr.fg.is_defined ? attr.fg.rgb : _fg,
                bg = attr.bg.is_defined ? attr.bg.rgb : _bg,
                bold = attr.bold,
                reverse = attr.reverse
            };
            return ret;
        }
        HlAttr ret = HlAttr() {
            fg = _fg,
            bg = _bg,
            bold = false,
            reverse = false
        };
        return ret;
    }
}
