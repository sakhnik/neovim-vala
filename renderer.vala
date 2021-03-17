
class Renderer : GLib.Object {

    private unowned MsgpackRpc _rpc;

    //private uint32 _fg = 0xffffff;
    //private uint32 _bg = 0;

    private class _HlAttr {
        //bool _has_fg = false;
        //uint32 _fg = 0;
        //bool _has_bg = false;
        //uint32 _bg = 0;
        //bool bold = false;
        //bool reverse = false;
    }

    private HashTable<uint32, _HlAttr?> _attributes = new HashTable<uint32, _HlAttr?> (direct_hash, direct_equal);

    private uint32 _width = 80;
    private uint32 _height = 25;

    public struct Cell {
        string text;
        uint64 hl_id;
    }

    private Cell[,] _grid;

    public unowned Cell[,] get_grid () {
        return _grid;
    }

    public signal void flush ();

    public Renderer (MsgpackRpc rpc) {
        _rpc = rpc;
        set_hl_attr (0, new _HlAttr ());
    }

    public void attach_ui ()
    {
        _rpc.set_on_notification (on_notification);
        _rpc.start ();

        _grid = new Cell[_height, _width];

        _rpc.request (
            (packer) => {
                unowned uint8[] ui_attach = "nvim_ui_attach".data;
                packer.pack_str (ui_attach.length);
                packer.pack_str_body (ui_attach);
                packer.pack_array(3);
                packer.pack_uint32 (_width);
                packer.pack_uint32 (_height);
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

    private delegate void HandlerType (MessagePack.Object[]? event);

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
                handler = handle_flush;
            } else if (memEqual (subtype, "grid_line".data)) {
                handler = grid_line;
            }
        //    else if (subtype == "grid_cursor_goto")
        //    {
        //        _GridCursorGoto(event);
        //    }
        //    else if (subtype == "grid_scroll")
        //    {
        //        _GridScroll(event);
        //    }
        //    else if (subtype == "hl_attr_define")
        //    {
        //        _HlAttrDefine(event);
        //    }
        //    else if (subtype == "default_colors_set")
        //    {
        //        _HlDefaultColorsSet(event);
        //    }
            else {
                print ("Ignoring redraw %.*s\n", subtype.length, subtype);
                continue;
            }

            if (event.length == 1) {
                handler (null);
            } else {
                for (size_t j = 1; j < event.length; ++j) {
                    unowned var instance = event[j].array.objects;
                    handler (instance);
                }
            }
        }
    }

    private void handle_flush (MessagePack.Object[]? event) {
        print ("*** flush\n");
        flush ();
    }

    //void _GridCursorGoto(const msgpack::object_array &event)
    //{
    //    for (size_t j = 1; j < event.size; ++j)
    //    {
    //        const auto &inst = event.ptr[j].via.array;
    //        int grid = inst.ptr[0].as<int>();
    //        if (grid != 1)
    //            throw std::runtime_error("Multigrid not supported");
    //        int row = inst.ptr[1].as<int>();
    //        int col = inst.ptr[2].as<int>();

    //        std::cout << "[" << (row+1) << ";" << (col+1) << "H";
    //    }
    //}

    private void grid_line (MessagePack.Object[]? event) {
        int64 grid = event[0].i64;
        if (grid != 1) {
            //throw std::runtime_error("Multigrid not supported");
            return;
        }
        int64 row = event[1].i64;
        int64 col = event[2].i64;
        unowned var cells = event[3].array.objects;

        uint64 hl_id = 0;
        for (size_t c = 0; c < cells.length; ++c) {
            unowned var cell = cells[c].array.objects;
            int64 repeat = 1;

            uint8[] text = cell[0].str.str;

            // if repeat is greater than 1, we are guaranteed to send an hl_id
            // https://github.com/neovim/neovim/blob/master/src/nvim/api/ui.c#L483
            if (cell.length > 1) {
                hl_id = cell[1].u64;
            }
            if (cell.length > 2) {
                repeat = cell[2].i64;
            }

            int64 start_col = col;
            Cell buf_cell = Cell() {hl_id = hl_id};
            uint8[] char_buf = {};
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

            int64 stride = col - start_col;
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

    //void _GridScroll(const msgpack::object_array &event)
    //{
    //    for (size_t j = 1; j < event.size; ++j)
    //    {
    //        const auto &inst = event.ptr[j].via.array;
    //        int grid = inst.ptr[0].as<int>();
    //        if (grid != 1)
    //            throw std::runtime_error("Multigrid not supported");
    //        int top = inst.ptr[1].as<int>();
    //        int bot = inst.ptr[2].as<int>();
    //        int left = inst.ptr[3].as<int>();
    //        int right = inst.ptr[4].as<int>();
    //        int rows = inst.ptr[5].as<int>();
    //        int cols = inst.ptr[6].as<int>();
    //        if (cols)
    //            throw std::runtime_error("Column scrolling not expected");

    //        int start = 0;
    //        int stop = 0;
    //        int step = 0;

    //        --bot;
    //        if (rows > 0)
    //        {
    //            start = top;
    //            stop = bot - rows + 1;
    //            step = 1;
    //        }
    //        else if (rows < 0)
    //        {
    //            start = bot;
    //            stop = top - rows - 1;
    //            step = -1;
    //        }
    //        else
    //            throw std::runtime_error("Rows should not equal 0");

    //        // this is very inefficient, but there doesn't appear to be a curses function for extracting whole lines incl.
    //        // attributes. another alternative would be to keep our own copy of the screen buffer
    //        for (int r = start; r != stop; r += step)
    //        {
    //            std::cout << "[" << (r+1) << ";" << (left+1) << "H";
    //            size_t idx = r * _size.ws_col + left;
    //            unsigned hl_id = _grid[idx].hl_id;
    //            std::cout << _attributes[hl_id]();
    //            for (int c = left; c < right; ++c, ++idx)
    //            {
    //                if (hl_id != _grid[idx].hl_id)
    //                {
    //                    hl_id = _grid[idx].hl_id;
    //                    std::cout << _attributes[hl_id]();
    //                }
    //                std::cout << _grid[idx].text;
    //            }
    //        }
    //    }
    //}

    //void _HlDefaultColorsSet(const msgpack::object_array &event)
    //{
    //    const auto &inst = event.ptr[1].via.array;
    //    _fg = inst.ptr[0].as<unsigned>();
    //    _bg = inst.ptr[1].as<unsigned>();
    //}

    //void _HlAttrDefine(const msgpack::object_array &event)
    //{
    //    for (size_t j = 1; j < event.size; ++j)
    //    {
    //        const auto &inst = event.ptr[j].via.array;
    //        unsigned hl_id = inst.ptr[0].as<unsigned>();
    //        const auto &rgb_attr = inst.ptr[1].via.map;

    //        std::optional<unsigned> fg, bg;
    //        //const auto &cterm_attr = inst.ptr[2].via.map;
    //        for (size_t i = 0; i < rgb_attr.size; ++i)
    //        {
    //            std::string key{rgb_attr.ptr[i].key.as<std::string>()};
    //            if (key == "foreground")
    //            {
    //                fg = rgb_attr.ptr[i].val.as<unsigned>();
    //            }
    //            else if (key == "background")
    //            {
    //                bg = rgb_attr.ptr[i].val.as<unsigned>();
    //            }
    //        }
    //        bool reverse{false};
    //        bool bold{false};
    //        // info = inst[3]
    //        // nvim api docs state that boolean keys here are only sent if true
    //        for (size_t i = 0; i < rgb_attr.size; ++i)
    //        {
    //            std::string key{rgb_attr.ptr[i].key.as<std::string>()};
    //            if (key == "reverse")
    //            {
    //                reverse = true;
    //            }
    //            else if (key == "bold")
    //            {
    //                bold = true;
    //            }
    //        }
    //        _AddHlAttr(hl_id, fg, bg, bold, reverse);
    //    }
    //}

    private void set_hl_attr (uint32 hl_id, _HlAttr? attr) {
        if (attr == null) {
            _attributes.remove (hl_id);
        } else {
            _attributes.set (hl_id, attr);
        }
    }
}
