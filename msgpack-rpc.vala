using MessagePack;

class MsgpackRpc : GLib.Object {

    private IOChannel _input;
    private IOChannel _output;

    public delegate void OnNotificationType (uint8[] method, MessagePack.Object data);
    private unowned OnNotificationType _on_notification;

    public void set_on_notification (OnNotificationType on_notification) {
        _on_notification = on_notification;
    }

    public delegate void OnResponseType (MessagePack.Object err, MessagePack.Object resp);

    private Unpacker _unp = new Unpacker ();
    private uint32 _seq = 0;
    private uint8[] _out_buffer = {};


    private class RequestData {
        public OnResponseType on_response;
        public RequestData (owned OnResponseType on_response) {
            this.on_response = (owned) on_response;
        }
    }
    private HashTable<uint32, RequestData> _requests = new HashTable<uint32, RequestData> (direct_hash, direct_equal);


    public MsgpackRpc(IOChannel input, IOChannel output) {
        _input = input;
        _output = output;
    }

    public void start () {

        _output.add_watch (IOCondition.IN | IOCondition.HUP, (channel, condition) => {
            if (condition == IOCondition.HUP) {
                print ("The fd has been closed.\n");
                return false;
            }

            try {
                _unp.reserve_buffer (1024);
                size_t bytes_read;
                channel.read_chars ((char[])_unp.buffer (), out bytes_read);
                if (bytes_read == 0) {
                    return false;
                }
                _handle_data(bytes_read);
            } catch (IOChannelError e) {
                print ("IOChannelError: %s\n", e.message);
                return false;
            } catch (ConvertError e) {
                print ("ConvertError: %s\n", e.message);
                return false;
            }

            return true;
        });
    }

    private void start_writing () {
        _input.add_watch (IOCondition.OUT | IOCondition.HUP, (channel, condition) => {
            if (condition == IOCondition.HUP) {
                print ("The fd has been closed.\n");
                return false;
            }

            if (_out_buffer.length == 0) {
                return false;
            }

            try {
                size_t len;
                _input.write_chars ((char[])_out_buffer, out len);
                int new_len = (int) (_out_buffer.length - len);
                _out_buffer.move ((int)len, 0, new_len);
                _out_buffer.resize (new_len);
            } catch (IOChannelError e) {
                print ("IOChannelError: %s\n", e.message);
                return false;
            } catch (ConvertError e) {
                print ("ConvertError: %s\n", e.message);
                return false;
            }

            return true;
        });
    }

    public delegate void PackRequestType (Packer packer);

    public void request (PackRequestType pack_request, owned OnResponseType on_response) {
        var seq = _seq++;
        _requests.set (seq, new RequestData ((owned)on_response));

        // serializes multiple objects using msgpack::packer.
        Packer packer = new Packer ((data) => {
            // TODO Use memcpy
            foreach (uint8 b in data) {
                _out_buffer += b;
            }
            return 0;
        });
        packer.pack_array (4);
        packer.pack_int (0);
        packer.pack_uint32 (seq);
        pack_request (packer);

        start_writing ();
    }

    private void _handle_data(size_t bytes_read) {
        _unp.buffer_consumed(bytes_read);

        Unpacked result;
        while (true) {
            var res = _unp.next (out result);
            if (res != UnpackReturn.SUCCESS) {
                break;
            }

            unowned MessagePack.Object obj = result.data;
            unowned MessagePack.Array arr = obj.array;
            if (arr.objects[0].u64 == 1) {
                // Response
                uint32 seq = (uint32)arr.objects[1].u64;
                var request_data = _requests.get (seq);
                request_data.on_response (arr.objects[2], arr.objects[3]);
                _requests.remove (seq);
            } else if (arr.objects[0].u64 == 2) {
                // Notification
                _on_notification(arr.objects[1].str.str, arr.objects[2]);
            }
        }
    }
}
