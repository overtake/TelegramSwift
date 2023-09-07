PipeWire
--------

PipeWire is a media server that can run graphs of multimedia nodes.
Nodes can run inside the server or in separate processes.

Some of the requirements are:

 - must be efficient for raw video using fd passing and audio with
   shared ringbuffers
 - must be able to provide/consume/process media from any process
 - policy to restrict access to devices and streams
 - extensible

Although an initial goal, the design is not limited to raw video
only and should be able to handle compressed video and other
media as well.

PipeWire uses the SPA plugin API for the nodes in the graph. SPA is
a plugin API designed for low-latency and efficient processing of
any multimedia format.

Some of the application we intend to build

 - v4l2 device provider. Provide controlled access to v4l2 devices
   and share 1 device between multiple processes.

 - gnome-shell video provider. Gnome-shell provides a node that
   gives the contents of the frame buffer for screen sharing or
   screen recording.

 - audio server. Mix and playback multiple audio streams. The design
   is more like CRAS (Chromium audio server) than pulseaudio and with
   the added benefit that processing can be arranged in a graph.

 - Pro audio graph processing like JACK.

 - Media playback backend


Protocol
--------

The native protocol and object model is similar to wayland but with custom
serialization/deserialization of messages. This is because the datastructures
in the messages are more complicated and not easily expressible in xml format.


Extensibility
-------------

The functionality of the server is implemented and extended with modules and
extensions. Modules are server side bits of logic that hook into various
places to provide extra features. This mostly means controlling the processing
graph in some way.

Extensions are the client side version of the modules. Most extensions provide
both a client side and server side init function. New interfaces or new object
implementation can easily be added with modules/extensions.

Some of the extensions that can be written

 - protocol extensions: a client/server side API (.h) together with protocol
   extensions and server/client side logic to implement a new object or
   interface.

 - a module to check security of method calls

 - a module to automatically create or link or relink nodes

 - a module to suspend idle nodes
