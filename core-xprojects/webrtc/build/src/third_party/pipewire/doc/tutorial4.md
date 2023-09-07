[[previous]](tutorial3.md) [[index]](tutorial-index.md) [[next]](tutorial5.md)

# Playing a tone (Tutorial 4)

In this tutorial we show how to use a stream to play a tone.

Let's take a look at the code before we break it down:

```c
#include <math.h>

#include <spa/param/audio/format-utils.h>

#include <pipewire/pipewire.h>

#define M_PI_M2 ( M_PI + M_PI )

#define DEFAULT_RATE		44100
#define DEFAULT_CHANNELS	2
#define DEFAULT_VOLUME		0.7

struct data {
	struct pw_main_loop *loop;
	struct pw_stream *stream;
	double accumulator;
};

static void on_process(void *userdata)
{
	struct data *data = userdata;
	struct pw_buffer *b;
	struct spa_buffer *buf;
	int i, c, n_frames, stride;
	int16_t *dst, val;

	if ((b = pw_stream_dequeue_buffer(data->stream)) == NULL) {
		pw_log_warn("out of buffers: %m");
		return;
	}

	buf = b->buffer;
	if ((dst = buf->datas[0].data) == NULL)
		return;

	stride = sizeof(int16_t) * DEFAULT_CHANNELS;
	n_frames = buf->datas[0].maxsize / stride;

        for (i = 0; i < n_frames; i++) {
                data->accumulator += M_PI_M2 * 440 / DEFAULT_RATE;
                if (data->accumulator >= M_PI_M2)
                        data->accumulator -= M_PI_M2;

                val = sin(data->accumulator) * DEFAULT_VOLUME * 16767.f;
                for (c = 0; c < DEFAULT_CHANNELS; c++)
                        *dst++ = val;
        }

	buf->datas[0].chunk->offset = 0;
	buf->datas[0].chunk->stride = stride;
	buf->datas[0].chunk->size = n_frames * stride;

	pw_stream_queue_buffer(data->stream, b);
}

static const struct pw_stream_events stream_events = {
	PW_VERSION_STREAM_EVENTS,
	.process = on_process,
};

int main(int argc, char *argv[])
{
	struct data data = { 0, };
	const struct spa_pod *params[1];
	uint8_t buffer[1024];
	struct spa_pod_builder b = SPA_POD_BUILDER_INIT(buffer, sizeof(buffer));

	pw_init(&argc, &argv);

	data.loop = pw_main_loop_new(NULL);

	data.stream = pw_stream_new_simple(
			pw_main_loop_get_loop(data.loop),
			"audio-src",
			pw_properties_new(
				PW_KEY_MEDIA_TYPE, "Audio",
				PW_KEY_MEDIA_CATEGORY, "Playback",
				PW_KEY_MEDIA_ROLE, "Music",
				NULL),
			&stream_events,
			&data);

	params[0] = spa_format_audio_raw_build(&b, SPA_PARAM_EnumFormat,
			&SPA_AUDIO_INFO_RAW_INIT(
				.format = SPA_AUDIO_FORMAT_S16,
				.channels = DEFAULT_CHANNELS,
				.rate = DEFAULT_RATE ));

	pw_stream_connect(data.stream,
			  PW_DIRECTION_OUTPUT,
			  argc > 1 ? (uint32_t)atoi(argv[1]) : PW_ID_ANY,
			  PW_STREAM_FLAG_AUTOCONNECT |
			  PW_STREAM_FLAG_MAP_BUFFERS |
			  PW_STREAM_FLAG_RT_PROCESS,
			  params, 1);

	pw_main_loop_run(data.loop);

	pw_stream_destroy(data.stream);
	pw_main_loop_destroy(data.loop);

	return 0;
}
```

Save as tutorial4.c and compile with:

```
gcc -Wall tutorial4.c -o tutorial4 -lm $(pkg-config --cflags --libs libpipewire-0.3)
```

We start with the usual boilerplate, `pw_init()` and a `pw_main_loop_new()`.
We're going to store our objects in a structure so that we can pass them
around in callbacks later.

```c
struct data {
	struct pw_main_loop *loop;
	struct pw_stream *stream;
	double accumulator;
};

int main(int argc, char *argv[])
{
	struct data data = { 0, };

	pw_init(&argc, &argv);

	data.loop = pw_main_loop_new(NULL);
```

Next we create a stream object. It takes the mainloop as first argument and
a stream name as the second. Next we provide some properties for the stream
and a callback + data.

```c
	data.stream = pw_stream_new_simple(
			pw_main_loop_get_loop(data.loop),
			"audio-src",
			pw_properties_new(
				PW_KEY_MEDIA_TYPE, "Audio",
				PW_KEY_MEDIA_CATEGORY, "Playback",
				PW_KEY_MEDIA_ROLE, "Music",
				NULL),
			&stream_events,
			&data);
```

We are using `pw_stream_new_simple()` but there is also a `pw_stream_new()` that
takes an existing `struct pw_core` as the first argument and that requires you
to add the event handle manually, for more control. The `pw_stream_new_simple()`
is, as the name implies, easier to use because it creates  a `struct pw_context`
and `struct pw_core` automatically.

In the properties we need to give as much information about the stream as we
can so that the session manager can make good decisions about how and where
to route this stream. There are 3 important properties to configure:

* `PW_KEY_MEDIA_TYPE`      The media type, like Audio, Video, Midi
* `pw_KEY_MEDIA_CATEGORY`  The category, like Playback, Capture, Duplex, Monitor
* `PW_KEY_MEDIA_ROLE`      The media role, like Movie, Music, Camera, Screen,
					Communication, Game, Notification, DSP,
					Production, Accessibility, Test

The properties are owned by the stream and freed when the stream is destroyed
later.

This is the event structure that we use to listen for events:

```c
static const struct pw_stream_events stream_events = {
	PW_VERSION_STREAM_EVENTS,
	.process = on_process,
};
```

We are for the moment only interested now in the `process` event. This event
is called whenever we need to produce more data. We'll see how that function 
is implemented but first we need to setup the format of the stream:

```c
	const struct spa_pod *params[1];
	uint8_t buffer[1024];
	struct spa_pod_builder b = SPA_POD_BUILDER_INIT(buffer, sizeof(buffer));

#define DEFAULT_RATE		44100
#define DEFAULT_CHANNELS	2

	params[0] = spa_format_audio_raw_build(&b, SPA_PARAM_EnumFormat,
			&SPA_AUDIO_INFO_RAW_INIT(
				.format = SPA_AUDIO_FORMAT_S16,
				.channels = DEFAULT_CHANNELS,
				.rate = DEFAULT_RATE ));
```

This is using a `struct spa_pod_builder` to make a `struct spa_pod *` object
in the buffer array on the stack. The parameter is of type `SPA_PARAM_EnumFormat`
which means that it enumerates the possible formats for this stream. We have
only one, a Signed 16 bit stereo format at 44.1KHz.

We use `spa_format_audio_raw_build()` which is a helper function to make the param
with the builder. See [SPA POD](spa/pod.md) for more information about how to
make these POD objects.

Now we're ready to connect the stream and run the main loop:

```c
	pw_stream_connect(data.stream,
			  PW_DIRECTION_OUTPUT,
			  PW_ID_ANY,
			  PW_STREAM_FLAG_AUTOCONNECT |
			  PW_STREAM_FLAG_MAP_BUFFERS |
			  PW_STREAM_FLAG_RT_PROCESS,
			  params, 1);

	pw_main_loop_run(data.loop);
```

To connect we specify that we have a `PW_DIRECTION_OUTPUT` stream. `PW_ID_ANY`
means that we are ok with connecting to any consumer. Next we set some flags:

* `PW_STREAM_FLAG_AUTOCONNECT`  automatically connect this stream. This instructs
                                the session manager to link us to some consumer.
* `PW_STREAM_FLAG_MAP_BUFFERS`	mmap the buffers for us so we can access the
                                memory. If you don't set these flags you have
				either work with the fd or mmap yourself.
* `PW_STREAM_FLAG_RT_PROCESS` 	Run the process function in the realtime thread.
		                Only use this if the process function only
				uses functions that are realtime safe, this means
				no allocation or file access or any locking.

And last we pass the extra parameters for our stream. Here we only have the
allowed formats (`SPA_PARAM_EnumFormat`).

Running the mainloop will then start processing and will result in our
`process` callback to be called. Let's have a look at that function now.

The main program flow of the process function is:

* `pw_stream_dequeue_buffer()` to obtain a buffer to write into.
* Get pointers in buffer memory to write to
* write data into buffer
* adjust buffer with number of written bytes, offset, stride,
* `pw_stream_queue_buffer()` to queue the buffer for playback.

```c
static void on_process(void *userdata)
{
	struct data *data = userdata;
	struct pw_buffer *b;
	struct spa_buffer *buf;
	int i, c, n_frames, stride;
	int16_t *dst, val;

	if ((b = pw_stream_dequeue_buffer(data->stream)) == NULL) {
		pw_log_warn("out of buffers: %m");
		return;
	}

	buf = b->buffer;
	if ((dst = buf->datas[0].data) == NULL)
		return;

	stride = sizeof(int16_t) * DEFAULT_CHANNELS;
	n_frames = buf->datas[0].maxsize / stride;

        for (i = 0; i < n_frames; i++) {
                data->accumulator += M_PI_M2 * 440 / DEFAULT_RATE;
                if (data->accumulator >= M_PI_M2)
                        data->accumulator -= M_PI_M2;

                val = sin(data->accumulator) * DEFAULT_VOLUME * 16767.f;
                for (c = 0; c < DEFAULT_CHANNELS; c++)
                        *dst++ = val;
        }

	buf->datas[0].chunk->offset = 0;
	buf->datas[0].chunk->stride = stride;
	buf->datas[0].chunk->size = n_frames * stride;

	pw_stream_queue_buffer(data->stream, b);
}
```

Check out the docs for [buffers](spa/buffer.md) for more information
about how to work with buffers.

Try to change the number of channels, samplerate or format; the stream
will automatically convert to the format on the server.


[[previous]](tutorial3.md) [[index]](tutorial-index.md) [[next]](tutorial5.md)
