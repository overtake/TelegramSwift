# Architecture

There are 2 main components that make up the PipeWire library:

 1) An implementation of a graph based media processing engine.
 2) An asynchronous IPC mechanism to manipulate and introspect
    a graph in another process.

There is usually a daemon that implements the global graph and
clients that operate on this graph.

The IPC mechanism in PipeWire is inspired by wayland in that it
follows the same design principles of objects and methods/events
along with how this API is presented to the user.

PipeWire has a plugin architecture that allows new features to
be added (or removed) by the user. Plugins can hook into many
aspects of PipeWire and change the behaviour or number of
features dynamically.

## Principles

The PipeWire API is an object oriented asynchronous protocol.
All requests and replies are method invocations on some object.

Objects are identified with a unique ID. Each object implements an
interface and requests result in invocations of methods on the
interface.

The protocol is message based. A message sent by a client to the
server is called a method. A message from the server to the client
is called an event. Unlike Wayland, these messages are not (yet)
described in an external protocol file but implemented directly in
a protocol plugin. Protocol plugins can be added to add new
objects or even protocols when required.

Messages are encoded with [SPA PODs](spa/pod.md), which make it
possible to encode complex objects with right types.

Events from the server can be a reply to a method or can be emitted
when the server state changes.

Upon connecting to a server, it will broadcast its state. Clients
should listen for these state changes and cache them. There is no
need (or mechanism) to query the state of the server.

The server also has a registry object that, when listening to,
will broadcast the presence of global objects and any changes in
their state.

State about objects can be obtained by binding to them and listening
for state changes.

## Versioning

All interfaces have a version number. The maximum supported version
number of an interface is advertized in the registry global event.

A client asks for a specific version of an interface when it binds
to them. It is the task of the server to adapt to the version of the
client.

Interfaces increase their version number when new methods or events
are added. Methods or events should never be removed or changed for
simplicity.

## Proxies and resources

When a client connects to a PipeWire daemon, a new `struct pw_proxy`
object is created with ID 0. The `struct pw_core` interface is
assigned to the proxy.

On the server side there is an equivalent `struct pw_resource` with
ID 0. Whenever the client sends a message on the proxy (by calling
a method on the interface of the proxy) it will transparently result
in a callback on the resource with the same ID.

Likewise if the server sends a message (an event) on a resource, it
will result in an event on the client proxy with the same ID.

PipeWire will notify a client when a resource ID (and thus also proxy
ID) becomes unused. The client is responsible for destroying the
proxy when it no longer wants to use it.


## Interfaces

### `struct pw_loop`

An abstraction for a `poll(2)` loop. It is usually part of one of:

* `struct pw_main_loop`: a helper that can run and stop a `pw_loop`.

* `struct pw_thread_loop`: a helper that can run and stop a `pw_loop`
		in a different thread. It also has some helper
		functions for various thread related synchronization
		issues.

* `struct pw_data_loop`: a helper that can run and stop a `pw_loop`
		in a real-time thread along with some useful helper
		functions.


### `struct pw_context`

The main context for PipeWire resources. It keeps track of the mainloop,
loaded modules, the processing graph and proxies to remote PipeWire
instances.

An application has to select an implementation of a `struct pw_loop`
when creating a context.

The context has methods to create the various objects you can use to
build a server or client application.


### `struct pw_core`

A proxy to a remote PipeWire instance. This is used to send messages
to a remote PipeWire daemon and to receive events from it.

A core proxy can be used to receive errors from the remote daemon
or to perform a roundtrip message to flush out pending requests.

Other core methods and events are used internally for the object
life cycle management.

### `struct pw_registry`

A proxy to a PipeWire registry object. It emits events about the
available objects on the server and can be used to bind to those
objects in order to call methods or receive events from them.

### `struct pw_module`

A proxy to a loadable module. Modules implement functionality such
as provide new objects or policy.

### `struct pw_factory`

A proxy to an object that can create other objects.

### `struct pw_device`

A proxy to a device object. Device objects model a physical hardware
or software device in the system and can create other objects
such as nodes or other devices.

### `struct pw_node`

A Proxy to a processing node in the graph. Nodes can have input and
output ports and the ports can be linked together to form a graph.

### `struct pw_port`

A Proxy to an input or output port of a node.  They can be linked
together to form a processing graph.

### `struct pw_link`

A proxy to a link between in output and input port. A link negotiates
a format and buffers between ports. A port can be linked to many other
ports and PipeWire will manage mixing and duplicating the buffers.


## High level helper objects

Some high level objects are implemented to make it easier to interface
with a PipeWire graph.

### `struct pw_filter`

A `struct pw_filter` allows you implement a processing filter that can
be added to a PipeWire graph. It is comparable to a JACK client.

### `struct pw_stream`

a `struct pw_stream` makes it easy to implement a playback or capture
client for the graph. It takes care of format conversion and buffer
sizes. It is comparable to Core Audio AudioQueue or a PulseAudio
stream.


## Security

With the default native protocol, clients connect to PipeWire using
a named socket. This results in a client socket that is used to
send messages.

For sandboxed clients, it is possible to get the client socket via
other ways, like using the portal. In that case, a portal will
do the connection for the client and then hands the connection socket
to the client.

All objects in PipeWire have per client permission bits, currently
READ, WRITE, EXECUTE and METADATA. A client can not see an object
unless it has READ permissions. Similarly, a client can only execute
methods on an object when the EXECUTE bit is set and to modify the
state of an object, the client needs WRITE permissions.

A client (the portal after it makes a connection) can drop permissions
on an object. Once dropped, it can never reacquire the permission.

Clients with WRITE/EXECUTE permissions on another client can
add and remove permissions for the client at will.

Clients with MODIFY permissions on another object can set or remove
metadata on that object.

Clients that need permissions assigned to them can be started in
blocked mode and resume when permissions are assigned to them by
a session manager or portal, for example.

PipeWire uses memfd (`memfd_create(2)`) or DMA-BUF for sharing media
and data between clients. Clients can thus not look at other clients
data unless they can see the objects and connect to them.

## Implementation

PipeWire also exposes an API to implement the server side objects in
a graph.
