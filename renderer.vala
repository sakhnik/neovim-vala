
class Renderer : GLib.Object {
    private unowned MsgpackRpc _rpc;

    private uint32 _fg = 0xffffff;
    private uint32 _bg = 0;

    private class _HlAttr {
        bool _has_fg = false;
        uint32 _fg = 0;
        bool _has_bg = false;
        uint32 _bg = 0;
        bool bold = false;
        bool reverse = false;
    }

    private HashTable<uint32, _HlAttr?> _attributes = new HashTable<uint32, _HlAttr?> (direct_hash, direct_equal);

    private uint32 _width = 80;
    private uint32 _height = 25;

    private struct _Cell {
        string text;
        uint32 hl_id;
    }

    private _Cell[,] _grid;


    public Renderer (MsgpackRpc rpc) {
        _rpc = rpc;
        set_hl_attr (0, new _HlAttr ());
    }

    public void attach_ui ()
    {
        _rpc.set_on_notification (on_notification);
        _rpc.start ();

        _grid = new _Cell[_width, _height];

        _rpc.request (
            (packer) => {
                unowned uint8[] ui_attach = "nvim_ui_attach".data;
                packer.pack_str (ui_attach.length);
                packer.pack_str_body (ui_attach);
                packer.pack_array(3);
                packer.pack_int (80);
                packer.pack_int (25);
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

    private void on_notification (uint8[] method, MessagePack.Object obj) {
        unowned uint8[] redraw = "redraw".data;

        if (method.length != redraw.length || 0 != Memory.cmp(method, redraw, redraw.length)) {
            print ("Unexpected notification %.*s\n", method.length, method);
            return;
        }

        unowned var arr = obj.array.objects;
        for (size_t i = 0; i < arr.length; ++i) {
            unowned var event = arr[i].array.objects;
            unowned var subtype = event[0].str.str;
            if (subtype.length == "flush".length && 0 == Memory.cmp(subtype, "flush".data, subtype.length)) {
                print ("flush\n");
            }
        //    else if (subtype == "grid_cursor_goto")
        //    {
        //        _GridCursorGoto(event);
        //    }
        //    else if (subtype == "grid_line")
        //    {
        //        std::cout << "[s";  // save
        //        _GridLine(event);
        //        std::cout << "[u";  // restore
        //    }
        //    else if (subtype == "grid_scroll")
        //    {
        //        std::cout << "[s";  // save
        //        _GridScroll(event);
        //        std::cout << "[u";  // restore
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
            }
        }
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

    //void _GridLine(const msgpack::object_array &event)
    //{
    //    for (size_t j = 1; j < event.size; ++j)
    //    {
    //        const auto &inst = event.ptr[j].via.array;
    //        int grid = inst.ptr[0].as<int>();
    //        if (grid != 1)
    //            throw std::runtime_error("Multigrid not supported");
    //        int row = inst.ptr[1].as<int>();
    //        int col = inst.ptr[2].as<int>();
    //        const auto &cells = inst.ptr[3].via.array;

    //        unsigned hl_id;
    //        for (size_t c = 0; c < cells.size; ++c)
    //        {
    //            const auto &cell = cells.ptr[c].via.array;
    //            int repeat = 1;
    //            std::string text = cell.ptr[0].as<std::string>();
    //            // if repeat is greater than 1, we are guaranteed to send an hl_id
    //            // https://github.com/neovim/neovim/blob/master/src/nvim/api/ui.c#L483
    //            if (cell.size > 1)
    //                hl_id = cell.ptr[1].as<unsigned>();
    //            if (cell.size > 2)
    //                repeat = cell.ptr[2].as<int>();
    //            std::cout << "[" << (row+1) << ";" << (col+1) << "H";
    //            std::cout << _attributes[hl_id]();

    //            int start_col = col;
    //            _Cell buf_cell{.hl_id = hl_id};
    //            for (size_t i = 0; i < text.size(); ++i)
    //            {
    //                char ch = text[i];
    //                if (!buf_cell.text.empty() && (static_cast<uint8_t>(ch) & 0xC0) != 0x80)
    //                {
    //                    _grid[row * _size.ws_col + col] = buf_cell;
    //                    buf_cell.text.clear();
    //                    ++col;
    //                }
    //                buf_cell.text.push_back(ch);
    //            }
    //            _grid[row * _size.ws_col + col] = buf_cell;
    //            buf_cell.text.clear();
    //            ++col;
    //            std::cout << text;

    //            int stride = col - start_col;
    //            while (--repeat)
    //            {
    //                for (int i = 0; i < stride; ++i, ++col)
    //                    _grid[row * _size.ws_col + col] = _grid[row * _size.ws_col + col - stride];
    //                std::cout << text;
    //            }
    //        }
    //    }
    //}

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
