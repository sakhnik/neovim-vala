using Gtk;
using Cairo;


class Grid {

    private unowned Renderer renderer;

    public Grid (Renderer renderer) {
        this.renderer = renderer;

        //renderer.flush.connect (flush);
        renderer.changed.connect (draw);
    }

    private int rows = 0;
    private int cols = 0;
    public Cairo.Surface surface;
    // Defer initial surface painting until the moment when the actual
    // background color is known.
    private bool surface_primed = false;

    private string font_face =
#if OS_windows
        "Courier New"
#else
        "Monospace"
#endif
        ;

    [Compact]
    private class CellInfo {
        public double w;
        public double h;
        public double descent;
    }
    private CellInfo? cell_info;

    private CellInfo calculate_cell_info (Cairo.Context ctx) {
        ctx.set_font_size (20);
        ctx.select_font_face (font_face, FontSlant.NORMAL, FontWeight.NORMAL);

        Cairo.TextExtents text;
        string ruler = "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz";
        ctx.text_extents (ruler, out text);

        Cairo.FontExtents fext;
        ctx.font_extents (out fext);

        CellInfo cell_info = new CellInfo ();
        cell_info.w = text.x_advance / ruler.length;
        if (cell_info.w > fext.max_x_advance) {
            cell_info.w = fext.max_x_advance;
        }
        cell_info.h = fext.height;
        cell_info.descent = fext.descent;
        return cell_info;
    }

    private static void set_source_rgb (Cairo.Context ctx, uint32 rgb) {
        ctx.set_source_rgb (
            ((double)(rgb >> 16)) / 255,
            ((double)((rgb >> 8) & 0xff)) / 255,
            ((double)(rgb & 0xff)) / 255
            );
    }

    private void draw (int top, int bot, int left, int right) {

        Cairo.Context ctx = new Cairo.Context (surface);

        if (!surface_primed) {
            // We know the background color by now, it's time to paint
            // the whole surface to clean any parts that aren't going to be
            // actively repainted (beyond cells).
            set_source_rgb (ctx, renderer.bg);
            ctx.rectangle (0, 0, cell_info.w * (cols + 1), cell_info.h * (rows + 1));
            ctx.fill ();
            surface_primed = true;
        }

        ctx.set_font_size (20);
        ctx.select_font_face (font_face, FontSlant.NORMAL, FontWeight.NORMAL);

        unowned var grid = renderer.get_grid ();
        for (int row = top; row < bot; ++row) {

            // Accumulate cells into lines with the same hl_id for better text rendering.
            // TODO: consider following the text beyond `right'.
            string text = "";
            uint hl_id = 0;
            int col0 = 0;

            for (int col = left; col < right; ++col) {
                unowned var cell = grid[row, col];
                if (text.length == 0) {
                    hl_id = cell.hl_id;
                    text = cell.text != null ? cell.text : " ";
                    col0 = col;
                } else {
                    if (hl_id == cell.hl_id) {
                        text += cell.text != null ? cell.text : " ";
                    } else {
                        draw_range (ctx, text, hl_id, row, col0);
                        hl_id = cell.hl_id;
                        text = cell.text != null ? cell.text : " ";
                        col0 = col;
                    }
                }
            }

            if (text.length != 0) {
                draw_range (ctx, text, hl_id, row, col0);
            }
        }

        var w = cell_info.w;
        var h = cell_info.h;

        // Draw primitive block semi-transparent cursor
        unowned var cursor = renderer.get_cursor ();
        if (cursor.row >= top && cursor.row < bot &&
            cursor.col >= left && cursor.col < right) {
            ctx.save ();
            ctx.set_tolerance (0.1);
            ctx.set_line_width (w * 0.1);
            ctx.set_source_rgba (1.0, 1.0, 1.0, 0.5);
            ctx.translate (cursor.col * w, cursor.row * h);
            if (renderer.mode == "insert") {
                ctx.rectangle (0, 0, 0.2 * w, h);
            } else if (renderer.mode == "replace" || renderer.mode == "operator") {
                ctx.rectangle (0, 0.75 * h, w, 0.25 * h);
            } else {
                ctx.rectangle (0, 0, w, h);
            }
            ctx.fill ();
            ctx.restore ();
        }
    }

    private void draw_range (Cairo.Context ctx, string text, uint hl_id, int row, int col) {
        var w = cell_info.w;
        var h = cell_info.h;

        unowned var attr = renderer.get_hl_attr (hl_id);
        var fg = attr.fg.get_rgb ();
        var bg = attr.bg.get_rgb ();
        if (attr.reverse) {
            var t = fg;
            fg = bg;
            bg = t;
        }

        ctx.save ();

        // Paint the background rectangle
        ctx.translate (col * w, row * h);
        set_source_rgb (ctx, bg);
        ctx.rectangle (0, 0, w * text.length, h);
        ctx.fill ();

        // Print the foreground text
        set_source_rgb (ctx, fg);
        ctx.move_to (0, h - cell_info.descent);
        ctx.select_font_face (font_face,
                              attr.italic ? FontSlant.ITALIC : FontSlant.NORMAL,
                              attr.bold ? FontWeight.BOLD : FontWeight.NORMAL);
        ctx.show_text (text);

        // Draw highlight attributes
        if (attr.underline) {
            ctx.set_line_width (w * 0.1);
            double y = h - 0.5 * cell_info.descent;
            ctx.move_to (0, y);
            ctx.line_to (w * text.length, y);
            ctx.stroke ();
        }

        if (attr.undercurl) {
            for (int i = 0; i < text.length; ++i) {
                ctx.save ();
                ctx.translate (i * w, 0);
                ctx.set_source_rgba (1, 0, 0, 0.5);
                ctx.set_line_width (w * 0.1);
                double y0 = h - cell_info.descent;
                double y1 = h - 0.5 * cell_info.descent;
                double y2 = h;
                ctx.move_to (0, y1);
                ctx.curve_to (0.2 * w, y0, 0.3 * w, y0, 0.5 * w, y1);
                ctx.curve_to (0.7 * w, y2, 0.8 * w, y2, 1.0 * w, y1);
                ctx.stroke ();
                ctx.restore ();
            }
        }

        ctx.restore ();
    }

    public void resize (int width, int height, Gdk.Surface orig_surface) {
        var old_surface = surface;
        surface = orig_surface.create_similar_surface (Cairo.Content.COLOR_ALPHA, width, height);
        Cairo.Context ctx = new Cairo.Context (surface);

        if (old_surface != null) {
            ctx.set_source_surface (old_surface, 0, 0);
            ctx.paint ();
        }

        cell_info = calculate_cell_info (ctx);
        int new_rows = (int)(height / cell_info.h);
        int new_cols = (int)(width / cell_info.w);

        if (surface_primed) {
            // Make sure to paint the edges beyond the cells with the actual background color.
            set_source_rgb (ctx, renderer.bg);
            double w = cell_info.w;
            double h = cell_info.h;

            double x = w * int.min(new_cols, cols);
            double y = h * int.min(new_rows, rows);

            ctx.rectangle (0, y, width, height - y);
            ctx.fill ();
            ctx.rectangle (x, 0, width - x, height);
            ctx.fill ();
        }

        if (new_rows == rows && new_cols == cols) {
            return;
        }

        rows = new_rows;
        cols = new_cols;
        renderer.try_resize (rows, cols);
    }
}
