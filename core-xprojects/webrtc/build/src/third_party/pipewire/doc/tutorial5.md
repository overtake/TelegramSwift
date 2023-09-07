[[previous]](tutorial4.md) [[index]](tutorial-index.md) [[next]](tutorial6.md)

# Capturing video frames (Tutorial 5)

In this tutorial we show how to use a stream to capture a
stream of video frames.

Even though we are now working with a different media type and
we are capturing instead of playback, you will see that this
example is very similar to the previous [tutorial 4](tutorial4.md).

Let's take a look at the code before we break it down:

```c
#include <spa/param/video/format-utils.h>
#include <spa/debug/types.h>
#include <spa/param/video/type-info.h>

#include <pipewire/pipewire.h>

struct data {
	struct pw_main_loop *loop;
	struct pw_stream *stream;

	struct spa_video_info format;
};

static void on_process(void *userdata)
{
	struct data *data = userdata;
	struct pw_buffer *b;
	struct spa_buffer *buf;

	if ((b = pw_stream_dequeue_buffer(data->stream)) == NULL) {
		pw_log_warn("out of buffers: %m");
		return;
	}

	buf = b->buffer;
	if (buf->datas[0].data == NULL)
		return;

	/** copy frame data to screen */
	printf("got a frame of size %d\n", buf->datas[0].chunk->size);

	pw_stream_queue_buffer(data->stream, b);
}

static void on_param_changed(void *userdata, uint32_t id, const struct spa_pod *param)
{
	struct data *data = userdata;

	if (param == NULL || id != SPA_PARAM_Format)
		return;

	if (spa_format_parse(param,
			&data->format.media_type,
			&data->format.media_subtype) < 0)
		return;

	if (data->format.media_type != SPA_MEDIA_TYPE_video ||
	    data->format.media_subtype != SPA_MEDIA_SUBTYPE_raw)
		return;

	if (spa_format_video_raw_parse(param, &data->format.info.raw) < 0)
		return;

	printf("got video format:\n");
	printf("  format: %d (%s)\n", data->format.info.raw.format,
			spa_debug_type_find_name(spa_type_video_format,
				data->format.info.raw.format));
	printf("  size: %dx%d\n", data->format.info.raw.size.width,
			data->format.info.raw.size.height);
	printf("  framerate: %d/%d\n", data->format.info.raw.framerate.num,
			data->format.info.raw.framerate.denom);

	/** prepare to render video of this size */
}

static const struct pw_stream_events stream_events = {
	PW_VERSION_STREAM_EVENTS,
	.param_changed = on_param_changed,
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
			"video-capture",
			pw_properties_new(
				PW_KEY_MEDIA_TYPE, "Video",
				PW_KEY_MEDIA_CATEGORY, "Capture",
				PW_KEY_MEDIA_ROLE, "Camera",
				NULL),
			&stream_events,
			&data);

	params[0] = spa_pod_builder_add_object(&b,
		SPA_TYPE_OBJECT_Format, SPA_PARAM_EnumFormat,
		SPA_FORMAT_mediaType,       SPA_POD_Id(SPA_MEDIA_TYPE_video),
		SPA_FORMAT_mediaSubtype,    SPA_POD_Id(SPA_MEDIA_SUBTYPE_raw),
		SPA_FORMAT_VIDEO_format,    SPA_POD_CHOICE_ENUM_Id(7,
						SPA_VIDEO_FORMAT_RGB,
						SPA_VIDEO_FORMAT_RGB,
						SPA_VIDEO_FORMAT_RGBA,
						SPA_VIDEO_FORMAT_RGBx,
						SPA_VIDEO_FORMAT_BGRx,
						SPA_VIDEO_FORMAT_YUY2,
						SPA_VIDEO_FORMAT_I420),
		SPA_FORMAT_VIDEO_size,      SPA_POD_CHOICE_RANGE_Rectangle(
						&SPA_RECTANGLE(320, 240),
						&SPA_RECTANGLE(1, 1),
						&SPA_RECTANGLE(4096, 4096)),
		SPA_FORMAT_VIDEO_framerate, SPA_POD_CHOICE_RANGE_Fraction(
						&SPA_FRACTION(25, 1),
						&SPA_FRACTION(0, 1),
						&SPA_FRACTION(1000, 1)));

	pw_stream_connect(data.stream,
			  PW_DIRECTION_INPUT,
			  argc > 1 ? (uint32_t)atoi(argv[1]) : PW_ID_ANY,
			  PW_STREAM_FLAG_AUTOCONNECT |
			  PW_STREAM_FLAG_MAP_BUFFERS,
			  params, 1);

	pw_main_loop_run(data.loop);

	pw_stream_destroy(data.stream);
	pw_main_loop_destroy(data.loop);

	return 0;
}
```

Save as tutorial5.c and compile with:

```
gcc -Wall tutorial5.c -o tutorial5 -lm $(pkg-config --cflags --libs libpipewire-0.3)
```

Most of the application is structured like the previous
[tutorial 4](tutorial4.md).

We create a stream object with different properties to make it a Camera
Video Capture stream.

```c
	data.stream = pw_stream_new_simple(
			pw_main_loop_get_loop(data.loop),
			"video-capture",
			pw_properties_new(
				PW_KEY_MEDIA_TYPE, "Video",
				PW_KEY_MEDIA_CATEGORY, "Capture",
				PW_KEY_MEDIA_ROLE, "Camera",
				NULL),
			&stream_events,
			&data);
```

In addition to the `process` event, we are also going to listen to a new event,
`param_changed`:

```c
static const struct pw_stream_events stream_events = {
	PW_VERSION_STREAM_EVENTS,
	.param_changed = on_param_changed,
	.process = on_process,
};
```

Because we capture a stream of a wide range of different
video formats and resolutions, we have to describe our accepted formats in
a different way:

```c
	const struct spa_pod *params[1];
	uint8_t buffer[1024];
	struct spa_pod_builder b = SPA_POD_BUILDER_INIT(buffer, sizeof(buffer));

	params[0] = spa_pod_builder_add_object(&b,
		SPA_TYPE_OBJECT_Format, SPA_PARAM_EnumFormat,
		SPA_FORMAT_mediaType,       SPA_POD_Id(SPA_MEDIA_TYPE_video),
		SPA_FORMAT_mediaSubtype,    SPA_POD_Id(SPA_MEDIA_SUBTYPE_raw),
		SPA_FORMAT_VIDEO_format,    SPA_POD_CHOICE_ENUM_Id(7,
						SPA_VIDEO_FORMAT_RGB,
						SPA_VIDEO_FORMAT_RGB,
						SPA_VIDEO_FORMAT_RGBA,
						SPA_VIDEO_FORMAT_RGBx,
						SPA_VIDEO_FORMAT_BGRx,
						SPA_VIDEO_FORMAT_YUY2,
						SPA_VIDEO_FORMAT_I420),
		SPA_FORMAT_VIDEO_size,      SPA_POD_CHOICE_RANGE_Rectangle(
						&SPA_RECTANGLE(320, 240),
						&SPA_RECTANGLE(1, 1),
						&SPA_RECTANGLE(4096, 4096)),
		SPA_FORMAT_VIDEO_framerate, SPA_POD_CHOICE_RANGE_Fraction(
						&SPA_FRACTION(25, 1),
						&SPA_FRACTION(0, 1),
						&SPA_FRACTION(1000, 1)));
```

This is using a `struct spa_pod_builder` to make a `struct spa_pod *` object
in the buffer array on the stack. The parameter is of type `SPA_PARAM_EnumFormat`
which means that it enumerates the possible formats for this stream.

In this example we use the builder to create some `CHOICE` entries for
the format properties.

We have an enumeration of formats, we need to first give the amount of enumerations
that follow, then the default (preferred) value, followed by alternatives in order
of preference:

```c
	SPA_FORMAT_VIDEO_format,    SPA_POD_CHOICE_ENUM_Id(7,
					SPA_VIDEO_FORMAT_RGB,	/* default */
					SPA_VIDEO_FORMAT_RGB,	/* alternative 1 */
					SPA_VIDEO_FORMAT_RGBA,	/* alternative 2 */
					SPA_VIDEO_FORMAT_RGBx,	/* .. etc.. */
					SPA_VIDEO_FORMAT_BGRx,
					SPA_VIDEO_FORMAT_YUY2,
					SPA_VIDEO_FORMAT_I420),
```

We also have a `RANGE` of values for the size. We need to give a default (preferred)
size and then a min and max value:

```c
	SPA_FORMAT_VIDEO_size,      SPA_POD_CHOICE_RANGE_Rectangle(
					&SPA_RECTANGLE(320, 240),	/* default */
					&SPA_RECTANGLE(1, 1),		/* min */
					&SPA_RECTANGLE(4096, 4096)),	/* max */
```

We have something similar for the framerate.

Note that there are other video parameters that we don't specify here. This
means that we don't have any restrictions for their values.

See [SPA POD](spa/pod.md) for more information about how to make these
POD objects.

Now we're ready to connect the stream and run the main loop:

```c
	pw_stream_connect(data.stream,
			  PW_DIRECTION_INPUT,
			  argc > 1 ? (uint32_t)atoi(argv[1]) : PW_ID_ANY,
			  PW_STREAM_FLAG_AUTOCONNECT |
			  PW_STREAM_FLAG_MAP_BUFFERS,
			  params, 1);

	pw_main_loop_run(data.loop);
```

To connect we specify that we have a `PW_DIRECTION_INPUT` stream. `PW_ID_ANY`
means that we are ok with connecting to any producer. We also allow the user
to pass an optional target id.

We're setting the `PW_STREAM_FLAG_AUTOCONNECT` flag to make an automatic
connection to a suitable camera and `PW_STREAM_FLAG_MAP_BUFFERS` to let the
stream mmap the data for us.

And last we pass the extra parameters for our stream. Here we only have the
allowed formats (`SPA_PARAM_EnumFormat`).


Running the mainloop will start the connection and negotiation process.
First our `param_changed` event will be called with the format that was
negotiated between our stream and the camera. This is always something that
is compatible with what we enumerated in the EnumFormat param when we
connected.

Let's take a look at how we can parse the format in the `param_changed`
event:

```c
static void on_param_changed(void *userdata, uint32_t id, const struct spa_pod *param)
{
	struct data *data = userdata;

	if (param == NULL || id != SPA_PARAM_Format)
		return;
```

First check if there is a param. A NULL param means that it is cleared. The id
of the param tells you what param it is. We are only interested in Format
param (`SPA_PARAM_Format`).

We can parse the media type and subtype as below and ensure that it is
of the right type. In our example this will always be true but when your
EnumFormat contains different media types or subtypes, this is how you can
parse them:

```c
	if (spa_format_parse(param,
			&data->format.media_type,
			&data->format.media_subtype) < 0)
		return;

	if (data->format.media_type != SPA_MEDIA_TYPE_video ||
	    data->format.media_subtype != SPA_MEDIA_SUBTYPE_raw)
		return;
```

For the `video/raw` media type/subtype there is a utility function to
parse out the values into a `struct spa_video_info`. This makes it easier
to deal with.

```c
	if (spa_format_video_raw_parse(param, &data->format.info.raw) < 0)
		return;

	printf("got video format:\n");
	printf("  format: %d (%s)\n", data->format.info.raw.format,
			spa_debug_type_find_name(spa_type_video_format,
				data->format.info.raw.format));
	printf("  size: %dx%d\n", data->format.info.raw.size.width,
			data->format.info.raw.size.height);
	printf("  framerate: %d/%d\n", data->format.info.raw.framerate.num,
			data->format.info.raw.framerate.denom);

	/** prepare to render video of this size */
}
```

In this example we dump the video size and parameters but in a real playback
or capture application you might want to set up the screen or encoder to
deal with the format.

After negotiation, the process function is called for each new frame. Check out
[tutorial 4](tutorial4.md) for another example.

```c
static void on_process(void *userdata)
{
	struct data *data = userdata;
	struct pw_buffer *b;
	struct spa_buffer *buf;

	if ((b = pw_stream_dequeue_buffer(data->stream)) == NULL) {
		pw_log_warn("out of buffers: %m");
		return;
	}

	buf = b->buffer;
	if (buf->datas[0].data == NULL)
		return;

	/** copy frame data to screen */
	printf("got a frame of size %d\n", buf->datas[0].chunk->size);

	pw_stream_queue_buffer(data->stream, b);
}
```

In a real playback application, one would do something with the data, like
copy it to the screen or encode it into a file.

[[previous]](tutorial4.md) [[index]](tutorial-index.md) [[next]](tutorial6.md)
