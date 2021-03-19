
class NeovimVala : GLib.Object {

    public static int main(string[] args) {

        // Handle Unicode properly
        Intl.setlocale(LocaleCategory.CTYPE, "");

        Gtk.init ();

        MainLoop loop = new MainLoop ();
        try {
            string[] spawn_args = {"nvim", "--embed"};
            for (int i = 1; i < args.length; ++i) {
                spawn_args += args[i];
            }
            Pid child_pid;

            int standard_input;
            int standard_output;

            Process.spawn_async_with_pipes (null /*cwd*/,
                                            spawn_args,
                                            null /*spawn_env*/,
                                            SpawnFlags.SEARCH_PATH | SpawnFlags.DO_NOT_REAP_CHILD,
                                            null,
                                            out child_pid,
                                            out standard_input,
                                            out standard_output,
                                            null);

            // stdout:
            IOChannel output = new IOChannel.unix_new (standard_output);
            output.set_encoding (null);  // handle as binary
            output.set_buffered (false);

            IOChannel input = new IOChannel.unix_new (standard_input);
            input.set_encoding (null);
            input.set_buffered (false);

            ChildWatch.add (child_pid, (pid, status) => {
                // Triggered when the child indicated by child_pid exits
                Process.close_pid (pid);
                loop.quit ();
            });

            MsgpackRpc rpc = new MsgpackRpc (input, output);
            Renderer renderer = new Renderer (rpc);

            renderer.attach_ui ();

            var window = new Window (rpc, renderer);
            window.present ();

            loop.run ();
        } catch (SpawnError e) {
            print ("Error: %s\n", e.message);
        } catch (IOChannelError e) {
            print ("Error: %s\n", e.message);
        }

        return 0;
    }
}
