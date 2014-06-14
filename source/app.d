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
  send_message(zreq, endpoint, ZMQ_SNDMORE);

  // placeholder msgpack data
  auto p = Packer();
  p.packMap();
  ubyte[] empty = p.stream.data.dup;

  // Next the iris message, trying out a ping
  send_message(zreq, "dummy-message", ZMQ_SNDMORE);
  send_message(zreq, Message.REQ, ZMQ_SNDMORE);
  send_message(zreq, "iris.ping", ZMQ_SNDMORE);
  send_message(zreq, empty, ZMQ_SNDMORE);
  writeln("Sending payload 42");
  send_message(zreq, pack(["payload": 42]));


  receive_message(zrec);



  // zmq_disconnect(req, toStringz(endpoint));

  // Looks like a tuple, pack headers and pack body
  // So this should be good enough to simulate it

}


void receive_message(Socket socket) {
  ubyte[][] frames;
  string msg_type;

  do {
    frames = socket.recv_multipart();
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


void send_message(Socket socket, string msg, int flags=0) {
  writeln("Client: Sending: ", msg);
  return send_message(socket, cast(ubyte[]) msg, flags);
}


void send_message(Socket socket, ubyte[] msg, int flags=0) {
  // Prepare message and send it
  MsgFrame frame = new MsgFrame(msg);
  frame.send(socket, flags);
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
