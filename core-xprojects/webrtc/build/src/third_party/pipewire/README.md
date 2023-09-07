# PipeWire

[PipeWire](https://pipewire.org) is a server and user space API to
deal with multimedia pipelines. This includes:

  - Making available sources of video (such as from a capture devices or
    application provided streams) and multiplexing this with
    clients.
  - Accessing sources of video for consumption.
  - Generating graphs for audio and video processing.

Nodes in the graph can be implemented as separate processes,
communicating with sockets and exchanging multimedia content using fd
passing.

## Building and installation

The preferred way to install PipeWire is to install it with your
distribution package system. This ensures PipeWire is integrated
into the rest of your system for the best experience.

If you want to build and install PipeWire yourself, refer to
[install](INSTALL.md) for instructions.

## Usage

The most important purpose of PipeWire is to run your favorite apps.

Some applications use the native PipeWire API, such as most compositors
(gnome-shell, wayland, ...) to implement screen sharing. These apps will
just work automatically.

Most audio applications can use either ALSA, JACK or PulseAudio as a
backend. PipeWire provides support for all 3 backends. Depending on how
your distribution has configured things this should just work automatically
or with the provided scripts shown below.

PipeWire can use environment variables to control the behaviour of
applications:

* `PIPEWIRE_DEBUG=<level>`         to increase the debug level
* `PIPEWIRE_LOG=<filename>`        to redirect log to filename
* `PIPEWIRE_LOG_SYSTEMD=false`     to disable logging to systemd journal
* `PIPEWIRE_LATENCY=<num/denom>`   to configure latency as a fraction. 10/1000
                                   configures a 10ms latency. Usually this is
				   expressed as a fraction of the samplerate,
				   like 256/48000, which uses 256 samples at a
				   samplerate of 48KHz for a latency of 5.33ms.
* `PIPEWIRE_NODE=<id>`             to request a link to the specified node

### Using tools

`pw-cat` can be used to play and record audio and midi. Use `pw-cat -h` to get
some more help. There are some aliases like `pw-play` and `pw-record` to make
things easier:

```
$ pw-play /home/wim/data/01.\ Firepower.wav
```

### Running JACK applications

Depending on how the system was configured, you can either run PipeWire and
JACK side-by-side or have PipeWire take over the functionality of JACK
completely.

In dual mode, JACK apps will by default use the JACK server. To direct a JACK
app to PipeWire, you can use the `pw-jack` script like this:

```
$ pw-jack <appname>
```

If you replaced JACK with PipeWire completely, `pw-jack` does not have any
effect and can be omitted.

JACK applications will automatically use the buffer-size chosen by the
server. You can force a maximum buffer size (latency) by setting the
`PIPEWIRE_LATENCY` environment variable like so:

```
PIPEWIRE_LATENCY=128/48000 jack_simple_client
```
Requests the `jack_simple_client` to run with a buffer of 128 or
less samples.


### Running PulseAudio applications

PipeWire can run a PulseAudio compatible replacement server. You can't
use both servers at the same time. Usually your package manager will
make the server conflict so that you can only install one or the
other.

PulseAudio applications still use the regular PulseAudio client
libraries and you don't need to do anything else than change the
server implementation.

A successful swap of the server can be verified by checking the
output of

```
pactl info
```
It should include the string:
```
...
Server Name: PulseAudio (on PipeWire 0.3.x)
...
```

You can use pavucontrol to change profiles and ports, change volumes
or redirect streams, just like with PulseAudio.


### Running ALSA applications

If the PipeWire alsa module is installed, it can be seen with

```
$ aplay -L
```

ALSA applications can then use the `pipewire:` device to use PipeWire
as the audio system.

### Running GStreamer applications

PipeWire includes 2 GStreamer elements called `pipewiresrc` and
`pipewiresink`. They can be used in pipelines such as this:

```
$ gst-launch-1.0 pipewiresrc ! videoconvert ! autovideosink
```

Or to play a beeping sound:

```
$ gst-launch-1.0 audiotestsrc ! pipewiresink
```

PipeWire provides a device monitor as well so that

```
$ gst-device-monitor-1.0
```

shows the PipeWire devices and applications like cheese will
automatically use the PipeWire video source when possible.

### Inspecting the PipeWire state

There is currently no native graphical tool to inspect the PipeWire graph
but we recommend to use one of the excellent JACK tools, such as `Carla`,
`catia`, `qjackctl`, ...
You will not be able to see all features like the video
ports but it is a good start.

`pw-mon` dumps and monitors the state of the PipeWire daemon.

`pw-dot` can dump a graph of the pipeline, check out the help for
how to do this.

`pw-top` monitors the real-time status of the graph. This is handy to
find out what clients are running and how much DSP resources they
use.

`pw-dump` dumps the state of the PipeWire daemon in JSON format. This
can be used to find out the properties and parameters of the objects
in the PipeWire daemon.

There is a more complicated tool to inspect the state of the server
with `pw-cli`. This tool can be used interactively or it can execute
single commands like this to get the server information:

```
$ pw-cli info 0
```

## Documentation

Find tutorials and design documentation [here](doc/index.md).

The (incomplete) autogenerated API docs are [here](https://docs.pipewire.org).

The Wiki can be found [here](https://gitlab.freedesktop.org/pipewire/pipewire/-/wikis/home)

## Contributing

PipeWire is Free Software and is developed in the open. It is licensed under
the [MIT license](COPYING).

Contributors are encouraged to submit merge requests or file bugs on
[gitlab](https://gitlab.freedesktop.org/pipewire).

Join us on IRC at #pipewire on [Freenode](https://freenode.net/).

We adhere to the Contributor Covenant for our [code of conduct](CODE_OF_CONDUCT.md).

[Donate using Liberapay](https://liberapay.com/PipeWire/donate).
