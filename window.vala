using Gtk;
using Cairo;
using GLib;
using Pango;


class Window : Gtk.Window {

    private unowned MsgpackRpc rpc;
    private unowned Renderer renderer;
    private DrawingArea canvas;
    private Grid grid;

    public Window (MsgpackRpc rpc, Renderer renderer) {
        this.rpc = rpc;
        this.renderer = renderer;
        this.grid = new Grid (renderer);

        renderer.flush.connect (() => {
            // TODO: track what parts of canvas need to be redrawn
            canvas.queue_draw ();
        });

        this.title = "Nvim Vala";
        set_default_size (800, 600);

        canvas = new DrawingArea ();
        canvas.can_focus = true;
        canvas.focusable = true;
        canvas.resize.connect (on_resize);
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
        int start_length = input.length;

        // TODO: functional keys, shift etc
        switch (keyval) {
            case Gdk.Key.Escape:
                input = "esc";
                break;
            case Gdk.Key.Return:
                input = "cr";
                break;
            case Gdk.Key.BackSpace:
                input = "bs";
                break;
        }

        if (0 != (Gdk.ModifierType.CONTROL_MASK & state)) {
            input = "c-" + input;
        }
        if (0 != (Gdk.ModifierType.META_MASK & state) || 0 != (Gdk.ModifierType.ALT_MASK & state)) {
            input = "m-" + input;
        }
        if (0 != (Gdk.ModifierType.SUPER_MASK & state)) {
            input = "d-" + input;
        }

        if (input.length != start_length) {
            input = "<" + input + ">";
        }

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
        ctx.set_source_surface (grid.surface, 0, 0);
        ctx.paint ();
    }

    private void on_resize (int width, int height) {
        grid.resize (width, height, this.get_surface ());
    }

}
