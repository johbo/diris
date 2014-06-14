import std.stdio;
import std.string;

import deimos.zmq.zmq;


class Context {

  this() {
    _zmq_ctx = zmq_ctx_new();
  }

  ~this() {
    zmq_ctx_destroy(_zmq_ctx);
  }

  auto socket(int socket_type) {
    return new Socket(this, socket_type);
  }

  private void* _zmq_ctx;

}


class Socket {

  this(Context zctx, int socket_type) {
    _socket = zmq_socket(zctx._zmq_ctx, socket_type);
  }

  ~this() {
    zmq_close(_socket);
  }

  void setsockopt(int option, string value) {
    zmq_setsockopt(_socket, option, value.ptr, value.length);
  }

  void bind(string endpoint) {
    zmq_bind(_socket, toStringz(endpoint));
  }

  void connect(string endpoint) {
    zmq_connect(_socket, toStringz(endpoint));
  }

  void send(MsgFrame frame, int flags=0) {
    zmq_sendmsg(_socket, &frame._msg, flags);
  }

  void send(T)(T data, int flags=0) {
    this.send(new MsgFrame(data), flags);
  }

  MsgFrame recv(int flags=0) {
    auto msg = new MsgFrame;
    msg.recv(this);
    return msg;
  }

  ubyte[][] recv_multipart(int flags=0) {
    ubyte[][] frames;
    MsgFrame frame;

    do {
      frame = recv();
      frames ~= frame.content();
    } while (frame.more);

    return frames;
  }

  private void* _socket;

}


class MsgFrame {

  // TODO: Figure out if copying of the memory is really correct here

  this() {
    zmq_msg_init(&_msg);
  }

  this(ubyte[] msg) {
    zmq_msg_init_size(&_msg, msg.length);
    // memcpy (zmq_msg_data (&request), "Hello", 5);
    // Slicing calls memcpy internally. (I hope)
    void* source = msg.ptr;
    (zmq_msg_data(&_msg))[0 .. msg.length] = source[0 .. msg.length];
  }

  this(string msg) {
    this(cast(ubyte[]) msg);
  }

  ~this() {
    zmq_msg_close(&_msg);
  }

  void recv(Socket socket, int flags=0) {
    zmq_recvmsg(socket._socket, &_msg, flags);
  }

  void send(Socket socket, int flags=0) {
    socket.send(this, flags);
  }

  ubyte[] content() {
    void* data = zmq_msg_data(&_msg);
    size_t size = zmq_msg_size(&_msg);

    // hope that creates a copy of the data and appends NULL
    // TODO: not sure if the NULL at the end is really needed
    auto frame = new ubyte[size + 1];
    frame[0 .. size] = cast(ubyte[]) data[0 .. size];

    return frame;
  }

  @property
  bool more() {
    return zmq_msg_more(&_msg) > 0;
  }

  private zmq_msg_t _msg;
}


unittest {
  auto c = new Context;
}
