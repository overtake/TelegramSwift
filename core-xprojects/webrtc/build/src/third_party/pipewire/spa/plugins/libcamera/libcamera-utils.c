/* Spa
 *
 * Copyright (C) 2020, Collabora Ltd.
 *     Author: Raghavendra Rao Sidlagatta <raghavendra.rao@collabora.com>
 *
 * libcamera-utils.c
 *
 * Permission is hereby granted, free of charge, to any person obtaining a
 * copy of this software and associated documentation files (the "Software"),
 * to deal in the Software without restriction, including without limitation
 * the rights to use, copy, modify, merge, publish, distribute, sublicense,
 * and/or sell copies of the Software, and to permit persons to whom the
 * Software is furnished to do so, subject to the following conditions:
 *
 * The above copyright notice and this permission notice (including the next
 * paragraph) shall be included in all copies or substantial portions of the
 * Software.
 *
 * THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
 * IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
 * FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT.  IN NO EVENT SHALL
 * THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
 * LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING
 * FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER
 * DEALINGS IN THE SOFTWARE.
 */
#include <stdio.h>
#include <string.h>
#include <unistd.h>
#include <sched.h>
#include <errno.h>
#include <sys/mman.h>
#include <poll.h>

#include <linux/media.h>

static void libcamera_on_fd_events(struct spa_source *source);

int get_dev_fd(struct spa_libcamera_device *dev) {
	if(dev->fd == -1) {
		int fd = open("/dev/media0", O_RDONLY | O_NONBLOCK, 0);
		return fd;
	} else {
		return dev->fd;
	}
}

int spa_libcamera_open(struct spa_libcamera_device *dev)
{
	if(!dev) {
		return -1;
	}

	dev->fd = get_dev_fd(dev);

	return 0;
}

int spa_libcamera_is_capture(struct spa_libcamera_device *dev)
{
	if(!dev) {
		spa_log_error(dev->log, "Invalid argument");
		return false;
	}
	return true;
}

int spa_libcamera_close(struct spa_libcamera_device *dev)
{
	if(!dev) {
		spa_log_error(dev->log, "Invalid argument");
		return -1;
	}

	if (dev->fd == -1) {
		return 0;
	}

	if (dev->active || dev->have_format) {
		return 0;
	}

	if (close(dev->fd)) {
		spa_log_warn(dev->log, "close: %m");
	}

	dev->fd = -1;
	return 0;
}

static int spa_libcamera_buffer_recycle(struct impl *this, uint32_t buffer_id)
{
	struct port *port = &this->out_ports[0];
	struct buffer *b = &port->buffers[buffer_id];

	if (!SPA_FLAG_IS_SET(b->flags, BUFFER_FLAG_OUTSTANDING))
		return 0;

	SPA_FLAG_CLEAR(b->flags, BUFFER_FLAG_OUTSTANDING);
	return 0;
}

static int spa_libcamera_clear_buffers(struct impl *this)
{
	struct port *port = &this->out_ports[0];
	uint32_t i;

	if (port->n_buffers == 0)
		return 0;

	for (i = 0; i < port->n_buffers; i++) {
		struct buffer *b;
		struct spa_data *d;

		b = &port->buffers[i];
		d = b->outbuf->datas;

		if (SPA_FLAG_IS_SET(b->flags, BUFFER_FLAG_OUTSTANDING)) {
			spa_log_debug(this->log, "libcamera: queueing outstanding buffer %p", b);
			spa_libcamera_buffer_recycle(this, i);
		}
		if (SPA_FLAG_IS_SET(b->flags, BUFFER_FLAG_MAPPED)) {
			munmap(SPA_MEMBER(b->ptr, -d[0].mapoffset, void),
					d[0].maxsize - d[0].mapoffset);
		}
		if (SPA_FLAG_IS_SET(b->flags, BUFFER_FLAG_ALLOCATED)) {
			close(d[0].fd);
		}
		d[0].type = SPA_ID_INVALID;
	}

	port->n_buffers = 0;

	return 0;
}

struct format_info {
	char fourcc[32];
	uint32_t format;
	uint32_t media_type;
	uint32_t media_subtype;
};

#define VIDEO   SPA_MEDIA_TYPE_video
#define IMAGE   SPA_MEDIA_TYPE_image

#define RAW     SPA_MEDIA_SUBTYPE_raw

#define BAYER   SPA_MEDIA_SUBTYPE_bayer
#define MJPG    SPA_MEDIA_SUBTYPE_mjpg
#define JPEG    SPA_MEDIA_SUBTYPE_jpeg
#define DV      SPA_MEDIA_SUBTYPE_dv
#define MPEGTS  SPA_MEDIA_SUBTYPE_mpegts
#define H264    SPA_MEDIA_SUBTYPE_h264
#define H263    SPA_MEDIA_SUBTYPE_h263
#define MPEG1   SPA_MEDIA_SUBTYPE_mpeg1
#define MPEG2   SPA_MEDIA_SUBTYPE_mpeg2
#define MPEG4   SPA_MEDIA_SUBTYPE_mpeg4
#define XVID    SPA_MEDIA_SUBTYPE_xvid
#define VC1     SPA_MEDIA_SUBTYPE_vc1
#define VP8     SPA_MEDIA_SUBTYPE_vp8

#define FORMAT_UNKNOWN    SPA_VIDEO_FORMAT_UNKNOWN
#define FORMAT_ENCODED    SPA_VIDEO_FORMAT_ENCODED
#define FORMAT_RGB15      SPA_VIDEO_FORMAT_RGB15
#define FORMAT_BGR15      SPA_VIDEO_FORMAT_BGR15
#define FORMAT_RGB16      SPA_VIDEO_FORMAT_RGB16
#define FORMAT_BGR        SPA_VIDEO_FORMAT_BGR
#define FORMAT_RGB        SPA_VIDEO_FORMAT_RGB
#define FORMAT_BGRA       SPA_VIDEO_FORMAT_BGRA
#define FORMAT_BGRx       SPA_VIDEO_FORMAT_BGRx
#define FORMAT_ARGB       SPA_VIDEO_FORMAT_ARGB
#define FORMAT_xRGB       SPA_VIDEO_FORMAT_xRGB
#define FORMAT_GRAY8      SPA_VIDEO_FORMAT_GRAY8
#define FORMAT_GRAY16_LE  SPA_VIDEO_FORMAT_GRAY16_LE
#define FORMAT_GRAY16_BE  SPA_VIDEO_FORMAT_GRAY16_BE
#define FORMAT_YVU9       SPA_VIDEO_FORMAT_YVU9
#define FORMAT_YV12       SPA_VIDEO_FORMAT_YV12
#define FORMAT_YUY2       SPA_VIDEO_FORMAT_YUY2
#define FORMAT_YVYU       SPA_VIDEO_FORMAT_YVYU
#define FORMAT_UYVY       SPA_VIDEO_FORMAT_UYVY
#define FORMAT_Y42B       SPA_VIDEO_FORMAT_Y42B
#define FORMAT_Y41B       SPA_VIDEO_FORMAT_Y41B
#define FORMAT_YUV9       SPA_VIDEO_FORMAT_YUV9
#define FORMAT_I420       SPA_VIDEO_FORMAT_I420
#define FORMAT_NV12       SPA_VIDEO_FORMAT_NV12
#define FORMAT_NV12_64Z32 SPA_VIDEO_FORMAT_NV12_64Z32
#define FORMAT_NV21       SPA_VIDEO_FORMAT_NV21
#define FORMAT_NV16       SPA_VIDEO_FORMAT_NV16
#define FORMAT_NV61       SPA_VIDEO_FORMAT_NV61
#define FORMAT_NV24       SPA_VIDEO_FORMAT_NV24

static const struct format_info format_info[] = {
	/* RGB formats */
	{{"RGB332"}, FORMAT_UNKNOWN, VIDEO, RAW},
	{{"ARGB555"}, FORMAT_UNKNOWN, VIDEO, RAW},
	{{"XRGB555"}, FORMAT_RGB15, VIDEO, RAW},
	{{"ARGB555X"}, FORMAT_UNKNOWN, VIDEO, RAW},
	{{"XRGB555X"}, FORMAT_BGR15, VIDEO, RAW},
	{{"RGB565"}, FORMAT_RGB16, VIDEO, RAW},
	{{"RGB565X"}, FORMAT_UNKNOWN, VIDEO, RAW},
	{{"BGR666"}, FORMAT_UNKNOWN, VIDEO, RAW},
	{{"BGR24"}, FORMAT_BGR, VIDEO, RAW},
	{{"RGB24"}, FORMAT_RGB, VIDEO, RAW},
	{{"ABGR32"}, FORMAT_BGRA, VIDEO, RAW},
	{{"XBGR32"}, FORMAT_BGRx, VIDEO, RAW},
	{{"ARGB32"}, FORMAT_ARGB, VIDEO, RAW},
	{{"XRGB32"}, FORMAT_xRGB, VIDEO, RAW},

	/* Deprecated Packed RGB Image Formats (alpha ambiguity) */
	{{"RGB444"}, FORMAT_UNKNOWN, VIDEO, RAW},
	{{"RGB555"}, FORMAT_RGB15, VIDEO, RAW},
	{{"RGB555X"}, FORMAT_BGR15, VIDEO, RAW},
	{{"BGR32"}, FORMAT_BGRx, VIDEO, RAW},
	{{"RGB32"}, FORMAT_xRGB, VIDEO, RAW},

	/* Grey formats */
	{{"GREY"}, FORMAT_GRAY8, VIDEO, RAW},
	{{"Y4"}, FORMAT_UNKNOWN, VIDEO, RAW},
	{{"Y6"}, FORMAT_UNKNOWN, VIDEO, RAW},
	{{"Y10"}, FORMAT_UNKNOWN, VIDEO, RAW},
	{{"Y12"}, FORMAT_UNKNOWN, VIDEO, RAW},
	{{"Y16"}, FORMAT_GRAY16_LE, VIDEO, RAW},
	{{"Y16_BE"}, FORMAT_GRAY16_BE, VIDEO, RAW},
	{{"Y10BPACK"}, FORMAT_UNKNOWN, VIDEO, RAW},

	/* Palette formats */
	{{"PAL8"}, FORMAT_UNKNOWN, VIDEO, RAW},

	/* Chrominance formats */
	{{"UV8"}, FORMAT_UNKNOWN, VIDEO, RAW},

	/* Luminance+Chrominance formats */
	{{"YVU410"}, FORMAT_YVU9, VIDEO, RAW},
	{{"YVU420"}, FORMAT_YV12, VIDEO, RAW},
	{{"YVU420M"}, FORMAT_UNKNOWN, VIDEO, RAW},
	{{"YUYV"}, FORMAT_YUY2, VIDEO, RAW},
	{{"YYUV"}, FORMAT_UNKNOWN, VIDEO, RAW},
	{{"YVYU"}, FORMAT_YVYU, VIDEO, RAW},
	{{"UYVY"}, FORMAT_UYVY, VIDEO, RAW},
	{{"VYUY"}, FORMAT_UNKNOWN, VIDEO, RAW},
	{{"YUV422P"}, FORMAT_Y42B, VIDEO, RAW},
	{{"YUV411P"}, FORMAT_Y41B, VIDEO, RAW},
	{{"Y41P"}, FORMAT_UNKNOWN, VIDEO, RAW},
	{{"YUV444"}, FORMAT_UNKNOWN, VIDEO, RAW},
	{{"YUV555"}, FORMAT_UNKNOWN, VIDEO, RAW},
	{{"YUV565"}, FORMAT_UNKNOWN, VIDEO, RAW},
	{{"YUV32"}, FORMAT_UNKNOWN, VIDEO, RAW},
	{{"YUV410"}, FORMAT_YUV9, VIDEO, RAW},
	{{"YUV420"}, FORMAT_I420, VIDEO, RAW},
	{{"YUV420M"}, FORMAT_I420, VIDEO, RAW},
	{{"HI240"}, FORMAT_UNKNOWN, VIDEO, RAW},
	{{"HM12"}, FORMAT_UNKNOWN, VIDEO, RAW},
	{{"M420"}, FORMAT_UNKNOWN, VIDEO, RAW},

	/* two planes -- one Y, one Cr + Cb interleaved  */
	{{"NV12"}, FORMAT_NV12, VIDEO, RAW},
	{{"NV12M"}, FORMAT_NV12, VIDEO, RAW},
	{{"NV12MT"}, FORMAT_NV12_64Z32, VIDEO, RAW},
	{{"NV12MT_16X16"}, FORMAT_UNKNOWN, VIDEO, RAW},
	{{"NV21"}, FORMAT_NV21, VIDEO, RAW},
	{{"NV21M"}, FORMAT_NV21, VIDEO, RAW},
	{{"NV16"}, FORMAT_NV16, VIDEO, RAW},
	{{"NV16M"}, FORMAT_NV16, VIDEO, RAW},
	{{"NV61"}, FORMAT_NV61, VIDEO, RAW},
	{{"NV61M"}, FORMAT_NV61, VIDEO, RAW},
	{{"NV24"}, FORMAT_NV24, VIDEO, RAW},
	{{"NV42"}, FORMAT_UNKNOWN, VIDEO, RAW},

	/* Bayer formats - see http://www.siliconimaging.com/RGB%20Bayer.htm */
	{{"SBGGR8"}, FORMAT_UNKNOWN, VIDEO, BAYER},
	{{"SGBRG8"}, FORMAT_UNKNOWN, VIDEO, BAYER},
	{{"SGRBG8"}, FORMAT_UNKNOWN, VIDEO, BAYER},
	{{"SRGGB8"}, FORMAT_UNKNOWN, VIDEO, BAYER},

	/* compressed formats */
	{{"MJPEG"}, FORMAT_ENCODED, VIDEO, MJPG},
	{{"JPEG"}, FORMAT_ENCODED, VIDEO, MJPG},
	{{"PJPG"}, FORMAT_ENCODED, VIDEO, MJPG},
	{{"DV"}, FORMAT_ENCODED, VIDEO, DV},
	{{"MPEG"}, FORMAT_ENCODED, VIDEO, MPEGTS},
	{{"H264"}, FORMAT_ENCODED, VIDEO, H264},
	{{"H264_NO_SC"}, FORMAT_ENCODED, VIDEO, H264},
	{{"H264_MVC"}, FORMAT_ENCODED, VIDEO, H264},
	{{"H263"}, FORMAT_ENCODED, VIDEO, H263},
	{{"MPEG1"}, FORMAT_ENCODED, VIDEO, MPEG1},
	{{"MPEG2"}, FORMAT_ENCODED, VIDEO, MPEG2},
	{{"MPEG4"}, FORMAT_ENCODED, VIDEO, MPEG4},
	{{"XVID"}, FORMAT_ENCODED, VIDEO, XVID},
	{{"VC1_ANNEX_G"}, FORMAT_ENCODED, VIDEO, VC1},
	{{"VC1_ANNEX_L"}, FORMAT_ENCODED, VIDEO, VC1},
	{{"VP8"}, FORMAT_ENCODED, VIDEO, VP8},

	/*  Vendor-specific formats   */
	{{"WNVA"}, FORMAT_UNKNOWN, VIDEO, RAW},
	{{"SN9C10X"}, FORMAT_UNKNOWN, VIDEO, RAW},
	{{"PWC1"}, FORMAT_UNKNOWN, VIDEO, RAW},
	{{"PWC2"}, FORMAT_UNKNOWN, VIDEO, RAW},
};

static const struct format_info *video_format_to_info(uint32_t fmt) {
	size_t i;

	for (i = 0; i < SPA_N_ELEMENTS(format_info); i++) {
		if (format_info[i].format == fmt)
			return &format_info[i];
	}
	return NULL;
}

static const struct format_info *find_format_info_by_media_type(uint32_t type,
								uint32_t subtype,
								uint32_t format,
								int startidx)
{
	size_t i;

	for (i = startidx; i < SPA_N_ELEMENTS(format_info); i++) {
		if ((format_info[i].media_type == type) &&
		    (format_info[i].media_subtype == subtype) &&
		    (format == 0 || format_info[i].format == format))
			return &format_info[i];
	}
	return NULL;
}

#define FOURCC_ARGS(f) (f)&0x7f,((f)>>8)&0x7f,((f)>>16)&0x7f,((f)>>24)&0x7f

static int
spa_libcamera_enum_format(struct impl *this, int seq,
		     uint32_t start, uint32_t num,
		     const struct spa_pod *filter)
{
	struct port *port = &this->out_ports[0];
	int res;
	const struct format_info *info;
	uint32_t video_format;
	struct spa_libcamera_device *dev = &port->dev;
	uint8_t buffer[1024];
	struct spa_pod_builder b = { 0 };
	struct spa_pod_frame f[2];
	struct spa_result_node_params result;
	uint32_t width = 0, height = 0;

	if ((res = spa_libcamera_open(dev)) < 0) {
		spa_log_error(dev->log, "failed to open libcamera device");
		return res;
	}

	result.id = SPA_PARAM_EnumFormat;
	result.next = start;

	if (result.next == 0) {
		port->fmtdesc_index = 0;
		spa_zero(port->fmt);
	}

next_fmtdesc:
	port->fmtdesc_index++;

	result.index = result.next++;

	/* Enumerate all the video formats supported by libcamera */
	video_format = libcamera_drm_to_video_format(
		libcamera_enum_streamcfgpixel_format(dev->camera, port->fmtdesc_index));
	if(UINT32_MAX == video_format) {
		goto enum_end;
	}
	port->fmt.pixelformat = video_format;
	port->fmt.width = libcamera_get_streamcfg_width(dev->camera);
	port->fmt.height = libcamera_get_streamcfg_height(dev->camera);

	if (!(info = video_format_to_info(video_format))) {
		goto next_fmtdesc;
	}

	spa_pod_builder_init(&b, buffer, sizeof(buffer));
	spa_pod_builder_push_object(&b, &f[0], SPA_TYPE_OBJECT_Format, SPA_PARAM_EnumFormat);
	spa_pod_builder_add(&b,
			SPA_FORMAT_mediaType,    SPA_POD_Id(info->media_type),
			SPA_FORMAT_mediaSubtype, SPA_POD_Id(info->media_subtype),
			0);

	if (info->media_subtype == SPA_MEDIA_SUBTYPE_raw) {
		spa_pod_builder_prop(&b, SPA_FORMAT_VIDEO_format, 0);
		spa_pod_builder_id(&b, info->format);
	}

	spa_log_info(this->log, "%s:: In have_size: Got width = %u height = %u\n", __FUNCTION__, width, height);

	spa_pod_builder_prop(&b, SPA_FORMAT_VIDEO_size, 0);
	spa_pod_builder_rectangle(&b, port->fmt.width, port->fmt.height);

	spa_pod_builder_prop(&b, SPA_FORMAT_VIDEO_framerate, 0);
	spa_pod_builder_push_choice(&b, &f[1], SPA_CHOICE_None, 0);

	/* Below framerates are hardcoded until framerates are queried from libcamera */
	port->fmt.denominator = 30;
	port->fmt.numerator = 1;

	spa_pod_builder_fraction(&b,
				 port->fmt.denominator,
				 port->fmt.numerator);

	spa_pod_builder_pop(&b, &f[1]);
	result.param = spa_pod_builder_pop(&b, &f[0]);

	spa_node_emit_result(&this->hooks, seq, 0, SPA_RESULT_TYPE_NODE_PARAMS, &result);

	goto next_fmtdesc;

enum_end:
	res = 0;

	spa_libcamera_close(dev);
	return res;
}

static int spa_libcamera_set_format(struct impl *this, struct spa_video_info *format, bool try_only)
{
	struct port *port = &this->out_ports[0];
	struct spa_libcamera_device *dev = &port->dev;
	int res;
	struct camera_fmt fmt;
	const struct format_info *info = NULL;
	uint32_t video_format;
	struct spa_rectangle *size = NULL;
	struct spa_fraction *framerate = NULL;

	spa_zero(fmt);

	switch (format->media_subtype) {
	case SPA_MEDIA_SUBTYPE_raw:
		video_format = format->info.raw.format;
		size = &format->info.raw.size;
		framerate = &format->info.raw.framerate;
		break;
	case SPA_MEDIA_SUBTYPE_mjpg:
	case SPA_MEDIA_SUBTYPE_jpeg:
		video_format = SPA_VIDEO_FORMAT_ENCODED;
		size = &format->info.mjpg.size;
		framerate = &format->info.mjpg.framerate;
		break;
	case SPA_MEDIA_SUBTYPE_h264:
		video_format = SPA_VIDEO_FORMAT_ENCODED;
		size = &format->info.h264.size;
		framerate = &format->info.h264.framerate;
		break;
	default:
		video_format = SPA_VIDEO_FORMAT_ENCODED;
		break;
	}

	info = find_format_info_by_media_type(format->media_type,
					      format->media_subtype, video_format, 0);
	if (info == NULL || size == NULL || framerate == NULL) {
		spa_log_error(this->log, "libcamera: unknown media type %d %d %d", format->media_type,
			      format->media_subtype, video_format);
		return -EINVAL;
	}

	fmt.pixelformat = video_format;
	fmt.width = size->width;
	fmt.height = size->height;
	fmt.sizeimage = libcamera_get_max_size(dev->camera);
	fmt.bytesperline = libcamera_get_stride(dev->camera);
	fmt.numerator = framerate->denom;
	fmt.denominator = framerate->num;

	if ((res = spa_libcamera_open(dev)) < 0)
		return res;

	/* stop the camera first. It might have opened with different configuration*/
	libcamera_stop_capture(dev->camera);

	spa_log_info(dev->log, "libcamera: set %s %dx%d %d/%d\n", (char *)&info->fourcc,
		     fmt.width, fmt.height,
		     fmt.denominator, fmt.numerator);

	libcamera_set_streamcfgpixel_format(dev->camera, libcamera_video_format_to_drm(video_format));
	libcamera_set_streamcfg_width(dev->camera, size->width);
	libcamera_set_streamcfg_height(dev->camera, size->height);

	/* start the camera now with the configured params */
	libcamera_start_capture(dev->camera);

	dev->have_format = true;
	size->width = libcamera_get_streamcfg_width(dev->camera);
	size->height = libcamera_get_streamcfg_height(dev->camera);
	port->rate.denom = framerate->num = fmt.denominator;
	port->rate.num = framerate->denom = fmt.numerator;

	port->fmt = fmt;
	port->info.change_mask |= SPA_PORT_CHANGE_MASK_FLAGS | SPA_PORT_CHANGE_MASK_RATE;
	port->info.flags = (port->export_buf ? SPA_PORT_FLAG_CAN_ALLOC_BUFFERS : 0) |
		SPA_PORT_FLAG_LIVE |
		SPA_PORT_FLAG_PHYSICAL |
		SPA_PORT_FLAG_TERMINAL;
	port->info.rate = SPA_FRACTION(port->rate.num, port->rate.denom);

	spa_log_info(dev->log, " got format. width = %d height = %d and fmt = %s. bytesperline = %u sizeimage = %u\n", 
		fmt.width, fmt.height,
		(char *)&info->fourcc, fmt.bytesperline, fmt.sizeimage);

	return 0;
}

static int
spa_libcamera_enum_controls(struct impl *this, int seq,
		       uint32_t start, uint32_t num,
		       const struct spa_pod *filter)
{
	return -ENOTSUP;
}

static int mmap_read(struct impl *this)
{
	struct port *port = &this->out_ports[0];
	struct spa_libcamera_device *dev = &port->dev;
	struct buffer *b = NULL;
	struct spa_data *d = NULL;
	unsigned int sequence = 0;
	struct timeval timestamp;
	int64_t pts;
	struct OutBuf *pOut = NULL;
	struct CamData *pDatas = NULL;
	uint32_t bytesused = 0;

	timestamp.tv_sec = 0;
	timestamp.tv_usec = 0;

	if(dev->camera) {
		pOut = (struct OutBuf *)libcamera_get_ring_buffer_data(dev->camera);
		if(!pOut) {
			spa_log_debug(this->log, "Exiting %s as pOut is NULL\n", __FUNCTION__);
			return -1;
		}
		/* update the read index of the ring buffer */
		libcamera_ringbuffer_read_update(dev->camera);

		pDatas = pOut->datas;
		if(NULL == pDatas) {
			spa_log_debug(this->log, "Exiting %s on NULL pointer\n", __FUNCTION__);
			goto end;
		}

		b = &port->buffers[pOut->bufIdx];
		b->outbuf->n_datas = pOut->n_datas;

		if(NULL == b->outbuf->datas) {
			spa_log_debug(this->log, "Exiting %s as b->outbuf->datas is NULL\n", __FUNCTION__);
			goto end;
		}

		for(unsigned int i = 0;  i < pOut->n_datas; ++i) {
			struct CamData *pData = &pDatas[i];
			if(NULL == pData) {
				spa_log_debug(this->log, "Exiting %s on NULL pointer\n", __FUNCTION__);
				goto end;
			}
			b->outbuf->datas[i].flags = SPA_DATA_FLAG_READABLE;
			if(port->memtype == SPA_DATA_DmaBuf) {
				b->outbuf->datas[i].fd = pData->fd;
			}
			bytesused = b->outbuf->datas[i].chunk->size = pData->size;
			timestamp = pData->timestamp;
			sequence = pData->sequence;

			b->outbuf->datas[i].mapoffset = 0;
			b->outbuf->datas[i].chunk->offset = 0;
			b->outbuf->datas[i].chunk->flags = 0;
			//b->outbuf->datas[i].chunk->stride = pData->sstride; /* FIXME:: This needs to be appropriately filled */
			b->outbuf->datas[i].maxsize = pData->maxsize;

			spa_log_trace(this->log,"Spa libcamera Source::%s:: got bufIdx = %d and ndatas = %d\t",
				__FUNCTION__, pOut->bufIdx, pOut->n_datas);
			spa_log_trace(this->log," data[%d] --> fd = %ld bytesused = %d sequence = %d\n",
				i, b->outbuf->datas[i].fd, bytesused, sequence);
		}
	}

	pts = SPA_TIMEVAL_TO_NSEC(&timestamp);

	if (this->clock) {
		this->clock->nsec = pts;
		this->clock->rate = port->rate;
		this->clock->position = sequence;
		this->clock->duration = 1;
		this->clock->delay = 0;
		this->clock->rate_diff = 1.0;
		this->clock->next_nsec = pts + 1000000000LL / port->rate.denom;
	}

	if (b->h) {
		b->h->flags = 0;
		b->h->offset = 0;
		b->h->seq = sequence;
		b->h->pts = pts;
		b->h->dts_offset = 0;
	}

	d = b->outbuf->datas;
	d[0].chunk->offset = 0;
	d[0].chunk->size = bytesused;
	d[0].chunk->flags = 0;
	d[0].data = b->ptr;
	spa_log_trace(this->log,"%s:: b->ptr = %p d[0].data = %p\n",
				__FUNCTION__, b->ptr, d[0].data);
	spa_list_append(&port->queue, &b->link);
end:
	libcamera_free_CamData(dev->camera, pDatas);
	libcamera_free_OutBuf(dev->camera, pOut);
	return 0;
}

static void libcamera_on_fd_events(struct spa_source *source)
{
	struct impl *this = source->data;
	struct spa_io_buffers *io;
	struct port *port = &this->out_ports[0];
	struct buffer *b;
	uint64_t cnt;

	if (source->rmask & SPA_IO_ERR) {
		struct port *port = &this->out_ports[0];
		spa_log_error(this->log, "libcamera %p: error %08x", this, source->rmask);
		if (port->source.loop)
			spa_loop_remove_source(this->data_loop, &port->source);
		return;
	}

	if (!(source->rmask & SPA_IO_IN)) {
		spa_log_warn(this->log, "libcamera %p: spurious wakeup %d", this, source->rmask);
		return;
	}
	
	if (spa_system_eventfd_read(this->system, port->source.fd, &cnt) < 0) {
		spa_log_error(this->log, "Failed to read on event fd");
		return;
	}

	if (mmap_read(this) < 0) {
		spa_log_debug(this->log, "%s:: mmap_read failure\n", __FUNCTION__);
		return;
	}

	if (spa_list_is_empty(&port->queue)) {
		spa_log_debug(this->log, "Exiting %s as spa list is empty\n", __FUNCTION__);
		return;
	}

	io = port->io;
	if (io != NULL && io->status != SPA_STATUS_HAVE_DATA) {
		if (io->buffer_id < port->n_buffers)
			spa_libcamera_buffer_recycle(this, io->buffer_id);

		b = spa_list_first(&port->queue, struct buffer, link);
		spa_list_remove(&b->link);
		SPA_FLAG_SET(b->flags, BUFFER_FLAG_OUTSTANDING);

		io->buffer_id = b->id;
		io->status = SPA_STATUS_HAVE_DATA;
		spa_log_trace(this->log, "libcamera %p: now queued %d", this, b->id);
	}
	spa_node_call_ready(&this->callbacks, SPA_STATUS_HAVE_DATA);
}

static int spa_libcamera_use_buffers(struct impl *this, struct spa_buffer **buffers, uint32_t n_buffers)
{
	struct port *port = &this->out_ports[0];
	unsigned int i, j;
	struct spa_data *d;

	n_buffers = libcamera_get_nbuffers(port->dev.camera);
	if (n_buffers > 0) {
		d = buffers[0]->datas;

		if (d[0].type == SPA_DATA_MemPtr && d[0].data != NULL) {
			port->memtype = SPA_DATA_MemPtr;
		} else if (d[0].type == SPA_DATA_DmaBuf) {
			port->memtype = SPA_DATA_DmaBuf;
		} else {
			spa_log_error(this->log, "v4l2: can't use buffers of type %d", d[0].type);
			return -EINVAL;
		}
	}

	for (i = 0; i < n_buffers; i++) {
		struct buffer *b;

		b = &port->buffers[i];
		b->id = i;
		b->outbuf = buffers[i];
		b->flags = BUFFER_FLAG_OUTSTANDING;
		b->h = spa_buffer_find_meta_data(buffers[i], SPA_META_Header, sizeof(*b->h));

		spa_log_debug(this->log, "libcamera: import buffer %p", buffers[i]);

		if (buffers[i]->n_datas < 1) {
			spa_log_error(this->log, "libcamera: invalid memory on buffer %p", buffers[i]);
			return -EINVAL;
		}

		d = buffers[i]->datas;
		for(j = 0; j < buffers[i]->n_datas; ++j) {
			d[j].mapoffset = 0;
			d[j].maxsize = libcamera_get_max_size(port->dev.camera);

			if (port->memtype == SPA_DATA_MemPtr) {
				if (d[j].data == NULL) {
					d[j].fd = -1;
					d[j].data = mmap(NULL,
						    d[j].maxsize + d[j].mapoffset,
						    PROT_READ, MAP_SHARED,
						    libcamera_get_fd(port->dev.camera, i, j),
						    0);
					if (d[j].data == MAP_FAILED) {
						return -errno;
					}

					b->ptr = d[j].data;
					spa_log_debug(this->log, "libcamera: In spa_libcamera_use_buffers(). mmap ptr:%p for fd = %ld buffer: #%d",
						d[j].data, d[j].fd, i);
					SPA_FLAG_SET(b->flags, BUFFER_FLAG_MAPPED);
				} else {
					b->ptr = d[j].data;
					spa_log_debug(this->log, "libcamera: In spa_libcamera_use_buffers(). b->ptr = %p d[j].maxsize = %d for buffer: #%d",
						d[j].data, d[j].maxsize, i);
				}
				spa_log_debug(this->log, "libcamera: In spa_libcamera_use_buffers(). setting b->ptr = %p for buffer: #%d on libcamera",
						b->ptr, i);
			}
			else if (port->memtype == SPA_DATA_DmaBuf) {
				d[j].fd = libcamera_get_fd(port->dev.camera, i, j);
				spa_log_debug(this->log, "libcamera: Got fd = %ld for buffer: #%d", d[j].fd, i);
			}
			else {
				spa_log_error(this->log, "libcamera: Exiting spa_libcamera_use_buffers() with -EIO");
				return -EIO;
			}
		}

		spa_libcamera_buffer_recycle(this, i);
	}
	port->n_buffers = n_buffers;

	return 0;
}

static int
mmap_init(struct impl *this,
		struct spa_buffer **buffers, uint32_t n_buffers)
{
	struct port *port = &this->out_ports[0];
	unsigned int i, j;
	struct spa_data *d;

	spa_log_info(this->log, "libcamera: In mmap_init()");

	if (n_buffers > 0) {
		d = buffers[0]->datas;

		if (d[0].type != SPA_ID_INVALID &&
		    d[0].type & (1u << SPA_DATA_DmaBuf)) {
			port->memtype = SPA_DATA_DmaBuf;
		} else if (d[0].type & (1u << SPA_DATA_MemPtr)) {
			port->memtype = SPA_DATA_MemPtr;
		} else {
			spa_log_error(this->log, "v4l2: can't use buffers of type %d", d[0].type);
			return -EINVAL;
		}
	}

	/* get n_buffers from libcamera */
	uint32_t libcamera_nbuffers = libcamera_get_nbuffers(port->dev.camera);

	for (i = 0; i < libcamera_nbuffers; i++) {
		struct buffer *b;

		if (buffers[i]->n_datas < 1) {
			spa_log_error(this->log, "libcamera: invalid buffer data");
			return -EINVAL;
		}

		b = &port->buffers[i];
		b->id = i;
		b->outbuf = buffers[i];
		b->flags = BUFFER_FLAG_OUTSTANDING;
		b->h = spa_buffer_find_meta_data(buffers[i], SPA_META_Header, sizeof(*b->h));

		d = buffers[i]->datas;
		for(j = 0; j < buffers[i]->n_datas; ++j) {
			d[j].type = port->memtype;
			d[j].flags = SPA_DATA_FLAG_READABLE;
			d[j].mapoffset = 0;
			d[j].maxsize = libcamera_get_max_size(port->dev.camera);
			d[j].chunk->offset = 0;
			d[j].chunk->size = 0;
			d[j].chunk->stride = port->fmt.bytesperline; /* FIXME:: This needs to be appropriately filled */
			d[j].chunk->flags = 0;

			if(port->memtype == SPA_DATA_DmaBuf) {
				d[j].fd = libcamera_get_fd(port->dev.camera, i, j);
				spa_log_info(this->log, "libcamera: Got fd = %ld for buffer: #%d\n", d[j].fd, i);
				d[j].data = NULL;
				SPA_FLAG_SET(b->flags, BUFFER_FLAG_ALLOCATED);
			}
			else if(port->memtype == SPA_DATA_MemPtr) {
				d[j].fd = -1;
				d[j].data = mmap(NULL,
						    d[j].maxsize + d[j].mapoffset,
						    PROT_READ, MAP_SHARED,
						    libcamera_get_fd(port->dev.camera, i, j),
						    0);
				if (d[j].data == MAP_FAILED) {
					spa_log_error(this->log, "mmap: %m");
					continue;
				}
				b->ptr = d[j].data;
				SPA_FLAG_SET(b->flags, BUFFER_FLAG_MAPPED);
				spa_log_info(this->log, "libcamera: mmap ptr:%p", d[j].data);
			} else {
				spa_log_error(this->log, "libcamera: invalid buffer type");
				return -EIO;
			}
		}

		spa_libcamera_buffer_recycle(this, i);
	}
	port->n_buffers = libcamera_nbuffers;
	return 0;
}

static int
spa_libcamera_alloc_buffers(struct impl *this,
		       struct spa_buffer **buffers,
		       uint32_t n_buffers)
{
	int res;
	struct port *port = &this->out_ports[0];

	if (port->n_buffers > 0)
		return -EIO;

	if ((res = mmap_init(this, buffers, n_buffers)) < 0) {
		return -EIO;
	}

	return 0;
}

static int spa_libcamera_stream_on(struct impl *this)
{
	struct port *port = &this->out_ports[0];
	struct spa_libcamera_device *dev = &port->dev;

	if (!dev->have_format) {
		spa_log_error(this->log, "Exting %s with -EIO\n", __FUNCTION__);
		return -EIO;
	}

	if (dev->active) {
		return 0;
	}

	spa_log_info(this->log, "connecting camera");

	libcamera_connect(dev->camera);

	port->source.func = libcamera_on_fd_events;
	port->source.data = this;
	port->source.fd = spa_system_eventfd_create(this->system, SPA_FD_CLOEXEC | SPA_FD_NONBLOCK);
	port->source.mask = SPA_IO_IN | SPA_IO_ERR;
	port->source.rmask = 0;
	if (port->source.fd < 0) {
		spa_log_error(this->log, "Failed to create eventfd. Exting %s with -EIO\n", __FUNCTION__);
	} else {
		spa_loop_add_source(this->data_loop, &port->source);
		this->have_source = true;

		libcamera_set_spa_system(dev->camera, this->system);
		libcamera_set_eventfd(dev->camera, port->source.fd);
	}	

	dev->active = true;

	return 0;
}

static int do_remove_source(struct spa_loop *loop,
			    bool async,
			    uint32_t seq,
			    const void *data,
			    size_t size,
			    void *user_data)
{
	struct port *port = user_data;
	if (port->source.loop)
		spa_loop_remove_source(loop, &port->source);
	return 0;
}

static int spa_libcamera_stream_off(struct impl *this)
{
	struct port *port = &this->out_ports[0];
	struct spa_libcamera_device *dev = &port->dev;

	if (!dev->active)
		return 0;

	spa_log_info(this->log, "stopping camera");

	libcamera_stop_capture(dev->camera);

	spa_loop_invoke(this->data_loop, do_remove_source, 0, NULL, 0, true, port);

	spa_list_init(&port->queue);
	dev->active = false;

	return 0;
}
