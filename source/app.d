import core.thread;
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
  auto my_endpoint = "tcp://127.0.0.1:12345";

  writefln("Connecting to %s", endpoint);

  // TODO: should be wrapped in struct to handle it like a resource?
  // or a class?
  void* ctx = zmq_ctx_new();
  scope(exit) { zmq_ctx_destroy(ctx); }

  // Create a socket
  // TODO: same as above, struct or class ?
  void* req = zmq_socket(ctx, ZMQ_ROUTER);
  scope(exit) { zmq_close(req); }
  // void* rec = zmq_socket(ctx, ZMQ_ROUTER);
  // scope(exit) { zmq_close(rec); }

  // ID needed when I want to receive messages back
  zmq_setsockopt(req, ZMQ_IDENTITY, my_endpoint.ptr, my_endpoint.length);

  // zmq_setsockopt(rec, ZMQ_IDENTITY, toStringz(my_endpoint), my_endpoint.length);
  // zmq_bind(rec, toStringz(my_endpoint));

  // Connect it
  zmq_connect(req, toStringz(endpoint));

  // TODO: seems that it takes some time to connect
  Thread.sleep(dur!("msecs")(100));

  /* Iris message format

     0: ID, a uuid
     1: type, one of REQ, REP, ACK, NACK, ERROR
     2: subject, string
     3: headers, msgpack dict / map
     4. body, msgpack encoded body

  */

  // First send the recipient ID, that's the one from the server
  send_message(req, endpoint, ZMQ_SNDMORE);

  // placeholder msgpack data
  auto p = Packer();
  p.packMap();
  ubyte[] empty = p.stream.data.dup;

  // Next the iris message, trying out a ping
  send_message(req, "dummy-message", ZMQ_SNDMORE);
  send_message(req, Message.REQ, ZMQ_SNDMORE);
  send_message(req, "iris.ping", ZMQ_SNDMORE);
  send_message(req, empty, ZMQ_SNDMORE);
  send_message(req, pack(["payload": 42]));


  // Thread.sleep(dur!("seconds")(1));

  // zmq_disconnect(req, toStringz(endpoint));

  // Looks like a tuple, pack headers and pack body
  // So this should be good enough to simulate it

}


void send_message(void* socket, string msg, int flags=0) {
  writeln("Client: Sending: ", msg);
  return send_message(socket, cast(ubyte[]) msg, flags);
}


void send_message(void* socket, ubyte[] msg, int flags=0) {
  // Prepare message and send it

  // TODO: That looks ugly, moving bits and bytes around, should be somehow
  // wrapped in a nice way
  zmq_msg_t request;
  zmq_msg_init_size(&request, msg.length);

  //memcpy (zmq_msg_data (&request), "Hello", 5);
  //Slicing calls memcpy internally. (I hope)
  void* source = msg.ptr;
  (zmq_msg_data(&request))[0 .. msg.length] = source[0 .. msg.length];

  zmq_sendmsg(socket, &request, flags);

  zmq_msg_close(&request);
}


struct Message {

  enum {
    ACK = "ACK",
    REP = "REP",
    REQ = "REQ",
    NACK = "NACK",
    ERROR = "ERROR"
  }
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
