class MsgpackRpc : GLib.Object {

    public delegate void OnNotificationType (string method, MessagePack.Object data);
    private unowned OnNotificationType _on_notification;

    public void set_on_notification (OnNotificationType on_notification) {
        _on_notification = on_notification;
    }

    public delegate void OnResponseType (MessagePack.Object err, MessagePack.Object resp);

    private MessagePack.Unpacker _unp = new MessagePack.Unpacker ();
    private uint32 _seq = 0;
    private uint8[] _out_buffer = {};


    private class RequestData {
        public OnResponseType on_response;
        public RequestData (owned OnResponseType on_response) {
            this.on_response = (owned) on_response;
        }
    }
    private HashTable<uint32, RequestData> _requests = new HashTable<uint32, RequestData> (int_hash, int_equal);


    public MsgpackRpc(IOChannel input, IOChannel output) {

        output.add_watch (IOCondition.IN | IOCondition.HUP, (channel, condition) => {
            if (condition == IOCondition.HUP) {
                print ("The fd has been closed.\n");
                return false;
            }

            try {
                string data;
                channel.read_line (out data, null, null);
                _handle_data(data);
            } catch (IOChannelError e) {
                print ("IOChannelError: %s\n", e.message);
                return false;
            } catch (ConvertError e) {
                print ("ConvertError: %s\n", e.message);
                return false;
            }

            return true;
        });

        input.add_watch (IOCondition.OUT | IOCondition.HUP, (channel, condition) => {
            if (condition == IOCondition.HUP) {
                print ("The fd has been closed.\n");
                return false;
            }

            if (_out_buffer.length == 0) {
                return false;
            }

            try {
                size_t len;
                input.write_chars ((char[])_out_buffer, out len);
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

    public delegate void PackRequestType (MessagePack.Packer packer);

    public void request (PackRequestType pack_request, owned OnResponseType on_response) {
        var seq = _seq++;
        _requests.set (seq, new RequestData ((owned)on_response));

        // serializes multiple objects using msgpack::packer.
        MessagePack.Packer packer = new MessagePack.Packer ((data) => {
            // TODO Use memcpy
            foreach (uint8 b in data) {
                _out_buffer += b;
            }
            return 0;
        });
        packer.pack_array (4);
        packer.pack_uint32 (0);
        packer.pack_uint32 (seq);
        pack_request (packer);
    }

    private void _handle_data(string data) {
        _unp.buffer_consumed(data.length);

        MessagePack.Unpacked result;
        while (true) {
            var res = _unp.next (out result);
            if (res != MessagePack.UnpackReturn.SUCCESS) {
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
                _on_notification((string)arr.objects[1].str.str, arr.objects[2]);
            }
        }
    }
}