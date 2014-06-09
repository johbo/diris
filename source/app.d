import std.exception;
import std.string;
import std.stdio;

import deimos.zmq.zmq;
import msgpack;


void main(string[] args)
{
  args = args[1 .. $];
  enforce(args.length == 1, "Need zmq endpoint as first argument");

  auto endpoint = args[0];
  auto my_endpoint = "todo";

  writefln("Connecting to %s", endpoint);

  // TODO: should be wrapped in struct to handle it like a resource?
  // or a class?
  void* ctx = zmq_ctx_new();
  scope(exit) { zmq_ctx_destroy(ctx); }

  // Create a socket
  // TODO: same as above, struct or class ?
  void* req = zmq_socket(ctx, ZMQ_REQ);
  scope(exit) { zmq_close(req); }

  // Connect it
  zmq_connect(req, toStringz(endpoint));

  send_message(req, "Hallo");

  /* Iris message format

     0: ID, a uuid
     1: type, one of REQ, REP, ACK, NACK, ERROR
     2: subject, string
     3: headers, msgpack dict / map
     4. body, msgpack encoded body

  */

  // Looks like a tuple, pack headers and pack body
  // So this should be good enough to simulate it

  auto example_frame = [
    "uuid",
    "msgtype",
    "subject",
    "packed_headers",
    "packed_body"
  ];
}


void send_message(void* socket, string msg, int flags=0) {
  // Prepare message and send it
  // TODO: That looks ugly, moving bits and bytes around, should be somehow
  // wrapped in a nice way
  zmq_msg_t request;
  zmq_msg_init_size(&request, msg.length);

  ///memcpy (zmq_msg_data (&request), "Hello", 5);
  ///Slicing calls memcpy internally.
  immutable(void*) source = msg.ptr;
  (zmq_msg_data(&request))[0..5] = source[0..5];

  writeln("Client: Sending: ", msg);
  zmq_sendmsg(socket, &request, flags);

  zmq_msg_close(&request);
}


struct Message {

  enum ACK = "ACK",
    REP = "REP",
    REQ = "REQ",
    NACK = "NACK",
    ERROR = "ERROR";
}

unittest {
  assert(Message.ACK == "ACK");
}


unittest {
  auto p = Packer();
  p.packArray("Hello", "World", "!");

  immutable ubyte[] expected_data = [
    147, 165, 72, 101, 108, 108, 111, 165, 87, 111, 114, 108, 100, 161, 33];
  assert(p.stream.data == expected_data);
}
