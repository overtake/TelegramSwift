# PipeWire Overview

PipeWire is a new low-level multimedia framework designed from scratch that
aims to provide

* graph based processing
* support for out-of-process processing graphs with minimal overhead
* flexible and extensible media format negotiation and buffer allocation
* Hard real-time capable plugins
* achieve very low-latency for both audio and video processing

The framework is used to build a modular daemon that can be configured to:

* be a low-latency audio server with features like pulseaudio and/or jack
* a video capture server that can manage hardware video capture devices and
  provide access to them
* a central hub where video can be made available for other applications
  such as the gnome-shell screencast API.

## Motivation

Linux has no unified framework for exchanging multimedia content between
applications or even devices. In most cases, developers realized that
a user-space daemon is needed to make this possible:

* For video content, we typically rely on the compositor to render our
  data.
* For video capture, we usually go directly to the hardware devices, with
  all security implications and inflexible routing that this brings.
* For consumer audio, we use PulseAudio to manage and mix multiple streams
  from clients
* For Pro audio, we use JACK to manage the graph of nodes.

None of these solutions (except perhaps to some extend Wayland), however,
were designed to support the security features that are required when
dealing with flatpaks or other containerized applications. PipeWire
aims to solve this problem and provides a unified framework to run both
consumer and Pro audio as well as video capture and processing in a
secure way.


## Components

Currently PipeWire ships with the following components:

* a PipeWire daemon that implements the IPC and graph processing
* an example session manager that manages objects in the PipeWire
  daemon.
* a set of tools to introspect and use the PipeWire daemon.
* a library to develop PipeWire applications and plugins.

### The PipeWire daemon

### The example session manager

### Tools

### Application development
