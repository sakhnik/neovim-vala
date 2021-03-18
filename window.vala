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
        string key = Gdk.keyval_name (keyval);
        print ("* key pressed %u (%s) %u\n", keyval, key, keycode);

        if (key.length != 1) {
            return false;
        }

        rpc.request (
            (packer) => {
                unowned uint8[] nvim_input = "nvim_input".data;
                packer.pack_str (nvim_input.length);
                packer.pack_str_body (nvim_input);
                packer.pack_array (1);
                packer.pack_str (key.length);
                packer.pack_str_body (key.data);
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

        //const int SIZE = 30;
        ctx.set_source_rgb (0, 0, 0);

        //ctx.set_line_width (SIZE / 4);
        //ctx.set_tolerance (0.1);

        //ctx.set_line_join (LineJoin.ROUND);
        //ctx.set_dash (new double[] {SIZE / 4.0, SIZE / 4.0}, 0);

        ctx.save ();

        //ctx.new_path ();
        //ctx.translate (100 + SIZE, 100 + SIZE);
        //ctx.move_to (SIZE, 0);
        //ctx.rel_line_to (SIZE, 2 * SIZE);
        //ctx.rel_line_to (-2 * SIZE, 0);
        //ctx.close_path ();

        //ctx.fill ();

        ctx.set_font_size (20);
        ctx.select_font_face ("Monospace", FontSlant.NORMAL, FontWeight.NORMAL);
        Cairo.TextExtents extents;
        ctx.text_extents ("█", out extents);

        unowned var grid = renderer.get_grid ();
        for (int row = 0; row < grid.length[0]; ++row) {
            for (int col = 0; col < grid.length[1]; ++col) {
                ctx.move_to (col * extents.width, (row + 1) * extents.height);
                ctx.show_text (grid[row, col].text);
            }
        }

        ctx.restore ();
    }

}
