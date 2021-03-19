using Gtk;
using Cairo;
using GLib;
using Pango;


class Window : Gtk.Window {

    private unowned MsgpackRpc rpc;
    private unowned Renderer renderer;

    public Window (MsgpackRpc rpc, Renderer renderer) {
        this.rpc = rpc;
        this.renderer = renderer;

        renderer.flush.connect (() => {
            // TODO: track what parts of canvas need to be redrawn
            child.queue_draw ();
        });

        this.title = "Nvim Vala";
        set_default_size (800, 600);

        var canvas = new DrawingArea ();
        canvas.can_focus = true;
        canvas.focusable = true;
        canvas.set_draw_func (draw_func);

        var controller = new Gtk.EventControllerKey ();
        controller.propagation_phase = PropagationPhase.CAPTURE;
        controller.key_pressed.connect (on_key_pressed);
        canvas.add_controller (controller);

        canvas.resize.connect (on_resize);
        child = canvas;
    }

    public override bool grab_focus () {
        return true;
    }

    private bool on_key_pressed (uint keyval, uint keycode, Gdk.ModifierType state) {
        //string key = Gdk.keyval_name (keyval);
        //print ("* key pressed %u (%s) %u\n", keyval, key, keycode);

        unichar uc = Gdk.keyval_to_unicode (keyval);
        string input = uc.to_string ();

        string[] modifiers = {};
        if (0 != (Gdk.ModifierType.CONTROL_MASK & state)) {
            modifiers += "c-";
        }
        if (0 != (Gdk.ModifierType.META_MASK & state) || 0 != (Gdk.ModifierType.ALT_MASK & state)) {
            modifiers += "m-";
        }
        if (0 != (Gdk.ModifierType.SUPER_MASK & state)) {
            modifiers += "d-";
        }

        if (modifiers.length > 0) {
            StringBuilder sb = new StringBuilder ();
            sb.append_c ('<');
            foreach (unowned var s in modifiers) {
                sb.append (s);
            }
            sb.append (input);
            sb.append_c ('>');
            input = sb.str;
        }

        // TODO: functional keys, shift etc

        rpc.request (
            (packer) => {
                unowned uint8[] nvim_input = "nvim_input".data;
                packer.pack_str (nvim_input.length);
                packer.pack_str_body (nvim_input);
                packer.pack_array (1);
                packer.pack_str (input.length);
                packer.pack_str_body (input.data);
            },
            (err, resp) => {
                if (err.type != MessagePack.Type.NIL) {
                    printerr ("Input error\n");
                }
            }
        );

        return true;
    }

    private string font_face = "Monospace";

    [Compact]
    private class CellInfo {
        public double w;
        public double h;
        public double y0;
    }
    private CellInfo? cell_info;

    private CellInfo calculate_cell_info (Cairo.Context ctx) {
        ctx.set_font_size (20);
        ctx.select_font_face (font_face, FontSlant.NORMAL, FontWeight.NORMAL);
        Cairo.FontExtents fext;

        ctx.font_extents (out fext);
        CellInfo cell_info = new CellInfo ();
        cell_info.w = fext.max_x_advance;
        cell_info.h = fext.height;
        cell_info.y0 = fext.descent;
        return cell_info;
    }

    private static void set_source_rgb (Cairo.Context ctx, uint32 rgb) {
        ctx.set_source_rgb (
            ((double)(rgb >> 16)) / 255,
            ((double)((rgb >> 8) & 0xff)) / 255,
            ((double)(rgb & 0xff)) / 255
            );
    }

    private void draw_func (DrawingArea drawing_area, Cairo.Context ctx, int width, int height) {

        if (cell_info == null) {
            cell_info = calculate_cell_info (ctx);
        }

        ctx.set_source_rgb (0, 0, 0);
        ctx.set_font_size (20);
        ctx.select_font_face (font_face, FontSlant.NORMAL, FontWeight.NORMAL);

        var w = cell_info.w;
        var h = cell_info.h;
        var y0 = cell_info.y0;

        unowned var grid = renderer.get_grid ();
        for (int row = 0; row < grid.length[0]; ++row) {
            for (int col = 0; col < grid.length[1]; ++col) {
                unowned var cell = grid[row, col];
                unowned var attr = renderer.get_hl_attr (cell.hl_id);
                ctx.save ();
                ctx.translate (col * w, row * h);
                set_source_rgb (ctx, attr.bg.get_rgb ());
                ctx.rectangle (0, y0, w, h);
                ctx.fill ();
                set_source_rgb (ctx, attr.fg.get_rgb ());
                ctx.move_to (0, h);
                ctx.select_font_face (font_face,
                                      attr.italic ? FontSlant.ITALIC : FontSlant.NORMAL,
                                      attr.bold ? FontWeight.BOLD : FontWeight.NORMAL);
                ctx.show_text (cell.text);
                if (attr.underline) {
                    ctx.set_line_width (w * 0.1);
                    ctx.move_to (0, h * 1.1);
                    ctx.line_to (w, h * 1.1);
                    ctx.stroke ();
                }

                if (attr.undercurl) {
                    ctx.save ();
                    ctx.set_source_rgba (1, 0, 0, 0.5);
                    ctx.set_line_width (w * 0.1);
                    ctx.move_to (0, h * 1.1);
                    ctx.curve_to (0.2 * w, h, 0.3 * w, h, 0.5 * w, h * 1.1);
                    ctx.curve_to (0.7 * w, h * 1.2, 0.8 * w, h * 1.2, 1.0 * w, h * 1.1);
                    ctx.stroke ();
                    ctx.restore ();
                }
                ctx.restore ();
            }
        }

        // Draw primitive block semi-transparent cursor
        unowned var cursor = renderer.get_cursor ();
        ctx.save ();
        ctx.set_line_width (w * 0.1);
        ctx.set_tolerance (0.1);
        ctx.set_source_rgba (1.0, 1.0, 1.0, 0.5);
        ctx.rectangle (cursor.col * w, cursor.row * h + y0, w, h);
        ctx.fill ();
        ctx.restore ();
    }

    private void on_resize (int width, int height) {
        if (cell_info == null) {
            // Cell info is calculated when drawing. If haven't happened yet,
            // wait for another cycle.
            print ("resize to %dx%d -> no cell info yet\n", width, height);
            return;
        }

        int rows = (int)(height / cell_info.h);
        int cols = (int)(width / cell_info.w);

        unowned var grid = renderer.get_grid ();
        if (rows == grid.length[0] && cols == grid.length[1]) {
            // No need to resize yet.
            return;
        }

        print ("resize to %dx%d -> %dx%d\n", width, height, rows, cols);
        rpc.request (
            (packer) => {
                unowned uint8[] ui_resize = "nvim_ui_try_resize".data;
                packer.pack_str (ui_resize.length);
                packer.pack_str_body (ui_resize);
                packer.pack_array(2);
                packer.pack_uint32 (cols);
                packer.pack_uint32 (rows);
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
