
==============
 Talk to iris
==============

Needed:

- [X] empty project with dub

  Used `dub`

- [X] add msgpack as dependency

  Straight forward with `dub`.

- [X] msgpack a structure

- [X] msgpack an iris structure

- [X] add zeromq as dependency

  easy thanks to `dub`

- [X] ZeroMQ - open tcp endpoint

- [X] send example structure iris.ping // echo.echo

- [X] receive result

- [ ] verify result of "iris.ping"

- [ ] create structure out of the result

- [ ] listen for requests and react, support "iris.ping"

- [ ] Zookeeper: discover a service

  At first, can put the tcp endpoint directly



Check if a struct works
=======================


To manage resources either a `struct` or a `class` should work. Since a
`struct` is destroyed more reliable, that might be the right thing to do as
long as we do not pass it around by value.

On the other side, a class would be a thing that has reference semantics and is
passed around properly by default.
