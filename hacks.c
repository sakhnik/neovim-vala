#include <msgpack/object.h>

void my_print (msgpack_object o, FILE* out)
{
  return msgpack_object_print(out, o);
}
