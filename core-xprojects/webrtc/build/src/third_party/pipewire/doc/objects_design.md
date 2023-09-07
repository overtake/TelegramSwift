# Objects Design

This document is a design reference on the various objects that exist
in the PipeWire media and session management graphs, explaining what these
objects are, how they are meant to be used and how they relate to other
kinds of objects and concepts that exist in subsystems or other libraries.

## The media graph

The media graph represents and enables the media flow inside the PipeWire
daemon and between the daemon and its clients. It consists of nodes, ports
and links.

```
+------------+                    +------------+
|            |                    |            |
|         +--------+  Link  +--------+         |
|   Node  |  Port  |--------|  Port  |  Node   |
|         +--------+        +--------+         |
|            |                    |            |
+------------+                    +------------+
```

### Node

A **node** is a media processing element. It consumes and/or produces buffers
that contain data, such as audio or video.

A node may operate entirely inside the PipeWire daemon or it may be operating
in a client process. In the second case, media is transferred to/from that
client using the PipeWire protocol.

In an analogy to GStreamer, a _node_ is similar (but not equal) to a
GStreamer _element_.

### Port

A **port** is attached on a **node** and provides an interface for input
or output of media on the node. A node may have multiple ports.

A port always has a direction, input or output:
 * Input: it allows media input into the node (in other terms, it is a _sink_)
 * Output: it outputs media out of the node (in other terms, it is a _source_)

In an analogy to GStreamer, a _port_ is similar (but not equal) to a
GStreamer _pad_.

### Link

A **link** connects 2 ports of opposite direction, making media flow from
the output port to the input port.

## The session management graph

The session management graph is a virtual, higher-level representation of the
media flow. It is created entirely by the session manager and it can affect
the routing on the media graph only through the session manager's actions.

The session management graph is useful to abstract the complexity of the
actual media flow both for the target user and for the policy management
codebase.

```
+---------------------+                                +----------------------+
|                     |                                |                      |
|            +----------------+  Endpoint Link  +----------------+            |
|  Endpoint  |Endpoint Stream |-----------------|Endpoint Stream |  Endpoint  |
|            +----------------+                 +----------------+            |
|                     |                                |                      |
+---------------------+                                +----------------------+
```

### Endpoint

An **endpoint** is a session management object that provides a representation
of user-conceivable places where media can be routed to/from.

Examples of endpoints associated with hardware on a desktop-like system:
 * Laptop speakers
 * USB webcam
 * Bluetooth headset microphone
 * Line out stereo jack port

Examples of endpoints associated with hardware in a car:
 * Speakers amplifier
 * Front right seat microphone array
 * Rear left seat headphones
 * Bluetooth phone voice gateway
 * Hardware FM radio device

Examples of endpoints associated with software:
 * Desktop screen capture source
 * Media player application
 * Camera application

In most cases an endpoint maps to a node on the media graph, but this is not
always the case. An endpoint may be backed by several nodes or no nodes at all.
Different endpoints may also be sharing nodes in some cases.

An endpoint that does not map to any node may be useful to represent hardware
that the session manager needs to be able to control, but there is no way
to route media to/from that hardware through the PipeWire media graph. For
example, in a car we may have a CD player device that is directly wired to the
speakers amplifier and therefore audio flows between them without passing
through the controlling CPU. However, it is useful for the session manager to
be able to represent the *CD player endpoint* and the _endpoint link_ between
it and the amplifier, so that it can apply audio policy that takes into account
whether the CD player is playing or not.

#### Target

An **endpoint** may be grouping together targets that can be reached by
following the same route and they are mutually exclusive with each other.

For example, the speakers and the headphones jack on a laptop are usually
mutually exclusive by hardware design (hardware mutes the speakers when the
headphones are enabled) and they share the same ALSA PCM device, so audio still
follows the same route to reach both.

In this case, a session manager may choose to group these two targets into the
same endpoint, using a parameter on the _endpoint_ object to allow the user
to choose the target (if the hardware allows configuring this at all).

### Endpoint Stream

An **endpoint stream** is attached to an **endpoint** and represents a logical
path that can be taken to reach this endpoint, often associated with
a _use case_.

For example, the "Speakers amplifier" endpoint in a car might have the
following streams:
 * _Music_: a path to play music;
       the implementation will output this to all speakers, using the volume
       that has been configured for the "Music" use case
 * _Voice_: a path to play a voice message, such as a navigation message or
       feedback from a voice assistant; the implementation will output this
       to the front speakers only, lowering the volume of the music (if any)
       on these speakers at the same time
 * _Emergency_: a path to play an emergency situation sound (a beep,
       or equivalent); the implementation will output this on all speakers,
       increasing the volume to a factory-defined value if necessary (to ensure
       that it is audible) while muting audio from all other streams at the
       same time

In another example, a microphone that can be used for activating a voice
assistant might have the following streams:
 * _Capture_: a path to capture directly from the microphone; this can be used
       by an application that listens for the assistant's wake-word in order
       to activate the full voice recognition engine
 * _CaptureDelayed_: a path to capture with a constant delay (meaning that
       starting capturing now will actually capture something that was spoken
       a little earlier); this can be used by the full voice recognition engine,
       allowing it to start after the wake-word has been spoken while capturing
       audio that also includes the wake-word

Endpoint streams may be mutually exclusive or they may used simultaneously,
depending on the implementation.

Endpoint streams may be implemented in many ways:
 * By plugging additional nodes in the media graph that link to the device node
   (ex. a simple buffering node linked to an alsa source node could implement
   the _CaptureDelayed_ stream in the above microphone example)
 * By using a different device node (ex. different ALSA device on the same card)
   that has a special meaning for the hardware
 * By triggering switches on the hardware (ex. modify ALSA controls on the
   same device)

### Endpoint Link

An **endpoint link** connects 2 streams from 2 different endpoints, creating
a logical representation of media flow between the endpoints.

An **endpoint link** may be implemented by creating one or more _links_ in the
underlying media graph, or it may be implemented by configuring hardware
resources to enable media flow, in case the flow does not pass through the
media graph.

#### Constructing

Constructing an **endpoint link** is done by asking the _endpoint stream_
objects to prepare it. First, the source stream is asked to provide linking
information. When the information is retrieved, the sink stream is asked to
use this information to prepare and to provide its own linking information.
When this is done, the session manager is asked to create the link using the
provided information.

This mechanism allows stream implementations:
 * to prepare for linking, adjusting hardware paths if necessary
 * to check for stream linking compatibility; not all streams can be connected
   to all others (ex. streams with media flow in the hardware cannot be linked
   to streams that are backed by nodes in the media graph)
 * to provide implementation-specific information for linking; in the standard
   case this is going to be a list of _ports_ to be linked in the media graph,
   but in a hardware-flow case it can be any kind of hardware-specific detail

## Other related objects

### Device

A **device** represents a handle to an underlying API that is used to create
higher level objects, such as nodes, or other devices.

Well-known devices include:
| Device API | Description |
| :---       | :---        |
| alsa.pcm.device | A handle to an ALSA card (ex. `hw:0`, `hw:1`, etc) |
| alsa.seq.device | A handle to an ALSA Midi device |
| v4l2.device     | A handle to a V4L2 device (`/dev/video0`, `/dev/video1`, etc..) |
| jack.device     | A JACK client, allowing PipeWire to slave to JACK for audio input/output |

A device may have a _profile_, which allows the user to choose between
multiple configurations that the device may be capable of having, or to simply
turn the device _off_, which means that the handle is closed and not used
by PipeWire.

### Session

The **session** represents the session manager and can be used to expose
global properties or methods that affect the session management.

#### Default endpoints

The session is responsible for book-keeping the default device endpoints (one
for each kind of device) that is to be used to link new clients when
simulating a PulseAudio-like behavior, where the user can choose from the UI
device preferences.

For example, a system may have both "Speakers" and "HDMI" endpoints on the
"Audio Output" category and the user may be offered to make a choice within
the UI to select which endpoint she wants to use by default for audio output.
This preference is meant to be stored in the session object.

#### Multiple sessions

It is not currently defined whether it is allowed to have multiple sessions
or not and how the system should behave if this happens.

## Mappings to underlying subsystem objects

### ALSA UCM

This is a ***proposal***

| ALSA / UCM | PipeWire |
| :---       | :---     |
| ALSA card  | device |
| UCM verb   | device profile |
| UCM device | endpoint (+ target, grouping conflicting devices into the same endpoint) |
| UCM modifier | endpoint stream |
| PCM stream | node   |

In UCM mode, an ALSA card is represented as a PipeWire device, with the
available UCM verbs listed as profiles of the device.

Activating a profile (i.e. a verb) will create the necessary nodes for the
available PCM streams and at the same time it will also create one endpoint
for each UCM device. Optionally, conflicting UCM devices can be grouped in
the same endpoint, listing the conflicting options as targets of the endpoint.

The available UCM modifiers for each UCM device will be added as streams, plus
one "default" stream for accessing the device with no modifiers.

### ALSA fallback

| ALSA | PipeWire |
| :--- | :---     |
| card       | device |
| PCM stream | node + endpoint |

In the case where UCM (or another similar mechanism) is not available,
ALSA cards are represented as PipeWire devices with only 2 profiles: On/Off

When the On profile is activated, a node and an associated endpoint are created
for every available PCM stream.

Endpoints in this case have only one "default" stream, unless they are extended
by the session manager to have software-backed streams.

### V4L2

***FIXME***

| V4L2 | PipeWire |
| :--- | :---     |
| device | device + node |

## Relationship to other APIs

### PulseAudio

#### Mapping PipeWire objects for access by PulseAudio clients

| PipeWire | PulseAudio |
| :---     | :---       |
| device                              | card       |
| device profile                      | card profile |
| endpoint (associated with a device) | sink / source |
| endpoint (associated with a client) | sink-input / source-output |
| endpoint target                     | port |
| endpoint stream                     | N/A, pa clients will be limited to the default stream |

#### Mapping PulseAudio clients to PipeWire

| PulseAudio | PipeWire |
| :---       | :---     |
| stream     | client + node + endpoint (no targets, 1 default stream) |

### Jack

Note: This section is about JACK clients connecting to PipeWire through the
JACK compatibility library. The scenario where PipeWire connects to another
JACK server as a client is out of scope here.

#### Mapping PipeWire objects for access by JACK clients

| PipeWire | JACK |
| :---     | :--- |
| node     | client |
| port     | port   |
| device   | N/A    |
| endpoint | N/A    |

#### Mapping JACK clients to PipeWire

| JACK | PipeWire |
| :--- | :---     |
| client | client + node |
| port   | port |

JACK clients do not create endpoints. A session manager should be JACK aware
in order to anticipate direct node linking
