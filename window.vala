using Gtk;
using Cairo;
using GLib;
using Pango;


public class Window : Gtk.Window {

    public Window() {
        this.title = "Nvim Vala";
        set_default_size (800, 600);

        var canvas = new DrawingArea ();
        canvas.set_draw_func (draw_func);
        child = canvas;
    }

    private void draw_func (DrawingArea drawing_area, Cairo.Context ctx, int width, int height) {
        const int SIZE = 30;
        ctx.set_source_rgb (0, 0, 0);

        ctx.set_line_width (SIZE / 4);
        ctx.set_tolerance (0.1);

        ctx.set_line_join (LineJoin.ROUND);
        ctx.set_dash (new double[] {SIZE / 4.0, SIZE / 4.0}, 0);

        ctx.save ();

        ctx.new_path ();
        ctx.translate (100 + SIZE, 100 + SIZE);
        ctx.move_to (SIZE, 0);
        ctx.rel_line_to (SIZE, 2 * SIZE);
        ctx.rel_line_to (-2 * SIZE, 0);
        ctx.close_path ();

        ctx.fill ();

        ctx.set_font_size (40);
        ctx.select_font_face ("Monospace", FontSlant.NORMAL, FontWeight.NORMAL);
        Cairo.TextExtents extents;
        ctx.text_extents ("Hello, world!", out extents);
        ctx.move_to (width / 2 - extents.width, height / 2);
        ctx.show_text ("Hello, world!");

        ctx.restore ();
    }
}