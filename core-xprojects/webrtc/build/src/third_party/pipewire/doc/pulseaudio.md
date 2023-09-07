# ALSA

This explains the mapping between alsa cards and streams and session manager
objects.


## ALSA Cards

An ALSA card is exposed as a PipeWire device

## Streams

Each alsa PCM is opened and a Node is created for each PCM stream.

# Session Manager

## ALSA UCM

The mapping of the PipeWire object hierarchy to the ALSA object hierarchy is the following:

One PipeWire device is created for every ALSA card.

For each UCM verb, a Node is created for the associated PCM devices.
For each UCM verb, an Endpoint is created.

In a first step: For each available combination of UCM device and modifier,
a stream is created. Streams are marked with compatible other streams.

Streams with the same modifier and mutually exclusive devices are grouped
into one stream and the UCM devices are exposed on the endpoint as destinations.


## ALSA fallback

Each PCM stream (node) becomes an endpoint. The endpoint references the
alsa device id

Each endpoint has 1 stream (for now) called HiFi Playback / HiFi Capture.

More streams can be created depending on the format of the node.


## ALSA pulse UCM

Using the alsa backend of pulseaudio we can create the following streams


## ALSA pulse fallback

The pulse alsa backend will use the mixer controls and some probing to
create the following nodes and endpoints


# PulseAudio

PulseAudio uses the session manager API to construct cards with profiles
and sink/source with ports.

If an Endpoint references a Device, a card object is created for the device.

Each Endpoint becomes a sink/source.

Each Stream in the endpoint becomes a profile on the PulseAudio card. Because
only one profile is selected on the device, only 1 stream is visible on
the endpoint. This clashes with the notion that multiple streams can be
active at the same time but is a pulseaudio limitation.

Each Endpoint destination becomes a port on the sink/source.
