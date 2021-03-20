using Gtk;
using Cairo;


class Grid {

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
        public double y0;
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

    public void draw (Renderer renderer, Cairo.Context ctx) {

        // TODO: use cairo_copy_clip_rectangle_list() to redraw only dirty parts.

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
                var fg = attr.fg.get_rgb ();
                var bg = attr.bg.get_rgb ();
                if (attr.reverse) {
                    var t = fg;
                    fg = bg;
                    bg = t;
                }

                ctx.save ();
                ctx.translate (col * w, row * h);
                set_source_rgb (ctx, bg);
                ctx.rectangle (0, y0, w, h);
                ctx.fill ();
                set_source_rgb (ctx, fg);
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

    public bool calc_size (int width, int height, out int rows, out int cols) {
        if (cell_info == null) {
            // Cell info is calculated when drawing. If haven't happened yet,
            // wait for another cycle.
            print ("resize to %dx%d -> no cell info yet\n", width, height);
            rows = 0;
            cols = 0;
            return false;
        }

        rows = (int)(height / cell_info.h);
        cols = (int)(width / cell_info.w);
        return true;
    }
}
