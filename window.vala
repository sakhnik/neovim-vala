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

    private void draw_func (DrawingArea drawing_area, Cairo.Context ctx, int width, int height) {

        ctx.set_source_rgb (0, 0, 0);

        ctx.set_font_size (20);
        ctx.select_font_face ("Monospace", FontSlant.NORMAL, FontWeight.NORMAL);
        Cairo.FontExtents fext;

        ctx.font_extents (out fext);
        var w = fext.max_x_advance;
        var h = fext.height;
        var y0 = fext.descent;

        unowned var grid = renderer.get_grid ();
        for (int row = 0; row < grid.length[0]; ++row) {
            for (int col = 0; col < grid.length[1]; ++col) {
                unowned var cell = grid[row, col];
                var attr = renderer.get_hl_attr (cell.hl_id);
                ctx.save ();
                ctx.translate (col * w, row * h);
                ctx.set_source_rgb (
                    ((double)(attr.bg >> 16)) / 255,
                    ((double)((attr.bg >> 8) & 0xff)) / 255,
                    ((double)(attr.bg & 0xff)) / 255
                );
                ctx.rectangle (0, y0, w, h);
                ctx.fill ();
                ctx.set_source_rgb (
                    ((double)(attr.fg >> 16)) / 255,
                    ((double)((attr.fg >> 8) & 0xff)) / 255,
                    ((double)(attr.fg & 0xff)) / 255
                );
                ctx.move_to (0, h);
                ctx.show_text (cell.text);
                ctx.restore ();
            }
        }

        // Draw primitive block semi-transparent cursor
        unowned var cursor = renderer.get_cursor ();
        ctx.save ();
        ctx.set_line_width (w * 0.1);
        ctx.set_tolerance (0.1);
        ctx.set_source_rgba (0, 0, 0, 0.5);
        ctx.rectangle (cursor.col * w, cursor.row * h + y0, w, h);
        ctx.fill ();
        ctx.restore ();
    }

}
