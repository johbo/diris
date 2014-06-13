import core.thread;
import std.array;
import std.exception;
import std.string;
import std.stdio;

import deimos.zmq.zmq;
import msgpack;

import zmq;


void main(string[] args)
{
  args = args[1 .. $];
  enforce(args.length == 1, "Need zmq endpoint as first argument");

  auto endpoint = args[0];
  auto my_endpoint = "tcp://127.0.0.1:12345";

  writefln("Connecting to %s", endpoint);

  // TODO: should be wrapped in struct to handle it like a resource?
  // or a class?
  auto zctx = new Context;

  // Create a socket
  auto zreq = zctx.socket(ZMQ_ROUTER);
  auto zrec = zctx.socket(ZMQ_ROUTER);

  // ID needed when I want to receive messages back
  zreq.setsockopt(ZMQ_IDENTITY, my_endpoint);
  zreq.connect(endpoint);

  zrec.setsockopt(ZMQ_IDENTITY, my_endpoint);
  zrec.bind(my_endpoint);

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
  auto req = zreq._socket;
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
  writeln("Sending payload 42");
  send_message(req, pack(["payload": 42]));


  auto rec = zrec._socket;
  receive_message(rec);



  // zmq_disconnect(req, toStringz(endpoint));

  // Looks like a tuple, pack headers and pack body
  // So this should be good enough to simulate it

}


void receive_message(void* socket) {
  ubyte[][] frames;
  string msg_type;

  do {
    frames = receive_one_message(socket);
    msg_type = cast(string) frames[2][0 .. $ - 1];
    writeln("Got a message of type ", msg_type);
  } while(msg_type != Message.REP);

  // trying to unpack the data and do something with it
  auto u = unpack(frames[5]);
  if (u.type == Value.type.map) {
    writeln(u.as!(string[string])());
  } if (u.type == Value.type.unsigned) {
    writeln("Response ", u.via.uinteger);
  } else {
    writeln(u.value);
  }
}


ubyte[][] receive_one_message(void* socket) {
  zmq_msg_t request;
  ubyte[][] frames;
  ubyte[] frame;

  // get the frames
  do {
    zmq_msg_init(&request);
    scope(exit) { zmq_msg_close(&request); }

    zmq_recvmsg(socket, &request, 0);
    void* data = zmq_msg_data(&request);
    auto size = zmq_msg_size(&request);

    // hope that creates a copy of the data and appends NULL
    frame = new ubyte[size + 1];
    frame[0 .. size] = cast(ubyte[]) data[0 .. size];

    frames ~= frame;
  } while (zmq_msg_more(&request));

  return frames;
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
