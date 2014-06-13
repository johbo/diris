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

  void send(zmq_msg_t* msg, int flags=0) {
    zmq_sendmsg(_socket, msg, flags);
  }

  // TODO: make it private!
  void* _socket;

}


unittest {
  auto c = new Context;
}
