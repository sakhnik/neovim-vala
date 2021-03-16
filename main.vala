
class NeovimVala : GLib.Object {

    private static bool process_line (IOChannel channel, IOCondition condition, string stream_name) {
        if (condition == IOCondition.HUP) {
            print ("%s: The fd has been closed.\n", stream_name);
            return false;
        }

        try {
            string line;
            channel.read_line (out line, null, null);
            print ("%s: %s", stream_name, line);
        } catch (IOChannelError e) {
            print ("%s: IOChannelError: %s\n", stream_name, e.message);
            return false;
        } catch (ConvertError e) {
            print ("%s: ConvertError: %s\n", stream_name, e.message);
            return false;
        }

        return true;
    }

    public static int main(string[] args) {

        Intl.setlocale(LocaleCategory.CTYPE, "");

        Gtk.init ();

        MainLoop loop = new MainLoop ();
        try {
            string[] spawn_args = {"nvim", "--embed"};
            string[] spawn_env = Environ.get ();
            Pid child_pid;

            int standard_input;
            int standard_output;
            int standard_error;

            Process.spawn_async_with_pipes ("/",
                                            spawn_args,
                                            spawn_env,
                                            SpawnFlags.SEARCH_PATH | SpawnFlags.DO_NOT_REAP_CHILD,
                                            null,
                                            out child_pid,
                                            out standard_input,
                                            out standard_output,
                                            out standard_error);

            // stdout:
            IOChannel output = new IOChannel.unix_new (standard_output);
            output.set_encoding (null);
            output.set_buffered (false);

            // stderr:
            IOChannel error = new IOChannel.unix_new (standard_error);
            error.add_watch (IOCondition.IN | IOCondition.HUP, (channel, condition) => {
                return process_line (channel, condition, "stderr");
            });

            IOChannel input = new IOChannel.unix_new (standard_input);
            input.set_encoding (null);
            input.set_buffered (false);

            ChildWatch.add (child_pid, (pid, status) => {
                // Triggered when the child indicated by child_pid exits
                Process.close_pid (pid);
                loop.quit ();
            });

            MsgpackRpc rpc = new MsgpackRpc (input, output);

            rpc.set_on_notification ((method, obj) => {
                print ("notification %s\n", method);
            });

            rpc.start ();

            rpc.request (
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

            var renderer = new Renderer();
            renderer.present ();

            loop.run ();
        } catch (SpawnError e) {
            print ("Error: %s\n", e.message);
        } catch (IOChannelError e) {
            print ("Error: %s\n", e.message);
        }

        return 0;
    }
}
