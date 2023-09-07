## Building

Pipewire uses a build tool called *Meson* as a basis for its build
process.  It's a tool with some resemblance to Autotools and CMake. Meson
again generates build files for a lower level build tool called *Ninja*,
working in about the same level of abstraction as more familiar GNU Make
does.

Meson uses a user-specified build directory and all files produced by Meson
are in that build directory. This build directory will be called `builddir`
in this document.

Generate the build files for Ninja:

```
$ meson setup builddir
```

Once this is done, the next step is to review the build options:

```
$ meson configure builddir
```

Define the installation prefix:

```
$ meson configure builddir -Dprefix=/usr # Default: /usr/local
```

Pipewire specific build options are listed in the "Project options"
section. They are defined in `meson_options.txt`.

Finally, invoke the build:

```
$ ninja -C builddir
```

Just to avoid any confusion: `autogen.sh` is a script invoked by *Jhbuild*,
which orchestrates multi-component builds.

## Running

If you want to run PipeWire without installing it on your system, there is a
script that you can run. This puts you in an environment in which PipeWire can
be run from the build directory, and ALSA, PulseAudio and JACK applications
will use the PipeWire emulation libraries automatically
in this environment. You can get into this environment with:

```
$ ./pw-uninstalled.sh
```

In most cases you would want to run the default pipewire daemon. Look
below for how to make this daemon start automatically using systemd.
If you want to run pipewire from the build directory, you can do this
by doing:

```
cd builddir/
make run
```

This will use the default config file to configure and start the daemon.
The default config will also start pipewire-media-session, a default
example media session and pipewire-pulse, a PulseAudio compatible server.

You can also enable more debugging with the PIPEWIRE_DEBUG environment
variable like so:

```
cd builddir/
PIPEWIRE_DEBUG=4 make run
```

You might have to stop the pipewire service/socket that might have been
started already, with:

```
systemctl --user stop pipewire.service \
                      pipewire.socket \
                      pipewire-media-session.service \
                      pipewire-pulse.service \
                      pipewire-pulse.socket
```

## Installing

PipeWire comes with quite a bit of libraries and tools, run
inside `builddir`:

```
sudo meson install
```

to install everything onto the system into the specified prefix.
Some additional steps will have to be performed to integrate
with the distribution as shown below.

### PipeWire daemon

A correctly installed PipeWire system should have a pipewire
process and a pipewire-media-session (or alternative) process
running. PipeWire is usually started as a systemd unit using
socket activation or as a service.

Configuration of the PipeWire daemon can be found in
/etc/pipewire/pipewire.conf. Please refer to the comments in the
config file for more information about the configuration options.

The daemon is started with:
```
systemctl --user start pipewire.service pipewire.socket
```

If you did not start the media-session in pipewire.conf, you will
also need to start it like this:
```
systemctl --user start pipewire-media-session.service
```
To make it start on system startup:
```
systemctl --user enable pipewire-media-session.service
```
you can write ```enable --now``` to start service immediately.

### ALSA plugin

The ALSA plugin is usually installed in:

On Fedora:
```
/usr/lib64/alsa-lib/libasound_module_pcm_pipewire.so
```
On Ubuntu:
```
/usr/lib/x86_64-linux-gnu/alsa-lib/libasound_module_pcm_pipewire.so
```

There is also a config file installed in:

```
/usr/share/alsa/alsa.conf.d/50-pipewire.conf
```

The plugin will be picked up by alsa when the following files
are in /etc/alsa/conf.d/

```
/etc/alsa/conf.d/50-pipewire.conf -> /usr/share/alsa/alsa.conf.d/50-pipewire.conf
/etc/alsa/conf.d/99-pipewire-default.conf
```

With this setup, aplay -l should list a pipewire: device that can be used as
a regular alsa device for playback and record.

### JACK emulation

PipeWire reimplements the 3 libraries that JACK applications use to make
them run on top of PipeWire.

These libraries are found here:

```
/usr/lib64/pipewire-0.3/jack/libjacknet.so -> libjacknet.so.0
/usr/lib64/pipewire-0.3/jack/libjacknet.so.0 -> libjacknet.so.0.304.0
/usr/lib64/pipewire-0.3/jack/libjacknet.so.0.304.0
/usr/lib64/pipewire-0.3/jack/libjackserver.so -> libjackserver.so.0
/usr/lib64/pipewire-0.3/jack/libjackserver.so.0 -> libjackserver.so.0.304.0
/usr/lib64/pipewire-0.3/jack/libjackserver.so.0.304.0
/usr/lib64/pipewire-0.3/jack/libjack.so -> libjack.so.0
/usr/lib64/pipewire-0.3/jack/libjack.so.0 -> libjack.so.0.304.0
/usr/lib64/pipewire-0.3/jack/libjack.so.0.304.0

```

The provided pw-jack script uses LD_LIBRARY_PATH to set the library
search path to these replacement libraries. This allows you to run
jack apps on both the real JACK server or on PipeWire with the script.

It is also possible to completely replace the JACK libraries by adding
a file `pipewire-jack-x86_64.conf` to `/etc/ld.so.conf.d/` with
contents like:

```
/usr/lib64/pipewire-0.3/jack/
```

Note that when JACK is replaced by PipeWire, the SPA JACK plugin (installed
in /usr/lib64/spa-0.2/jack/libspa-jack.so) is not useful anymore and
distributions should make them conflict.


### PulseAudio replacement

PipeWire reimplements the PulseAudio server protocol as a small service
that runs on top of PipeWire.

The binary is normally placed here:

```
/usr/bin/pipewire-pulse
```

The server can be started with provided systemd activation files or
from PipeWire itself. (See `/etc/pipewire/pipewire.conf`)

```
systemctl --user start pipewire-pulse.service pipewire-pulse.socket
```

You can also start additional PulseAudio servers listening on other
sockets with the -a option. See `pipewire-pulse -h` for more info.
