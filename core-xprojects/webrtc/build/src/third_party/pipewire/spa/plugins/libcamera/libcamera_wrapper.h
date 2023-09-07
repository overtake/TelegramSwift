/* Spa libcamera support
 *
 * Copyright (C) 2020, Collabora Ltd.
 *     Author: Raghavendra Rao Sidlagatta <raghavendra.rao@collabora.com>
 *
 * libcamera_wrapper.h
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

#ifndef __LIBCAMERA_WRAPPER_H
#define __LIBCAMERA_WRAPPER_H

#ifdef __cplusplus
extern "C" {
#endif

#define MAX_NUM_BUFFERS				16

typedef struct CamData {
	uint32_t idx;
	uint32_t type;
	int64_t fd;
	uint32_t maxsize; /**< max size of data */
	uint32_t size; /**< size of valid data. Should be clamped to
					  *  maxsize. */
	struct timeval timestamp;
	uint32_t sequence;
	void *data;
}CamData;

typedef struct OutBuf {
	uint32_t bufIdx;
	uint32_t n_datas;		/**< number of data members */
	struct CamData *datas;	/**< array of data members */
}OutBuf;

typedef struct LibCamera LibCamera;

LibCamera *newLibCamera();

void deleteLibCamera(LibCamera *camera);

void libcamera_set_log(LibCamera *camera, struct spa_log *log);

bool libcamera_open(LibCamera *camera);

void libcamera_close(LibCamera *camera);

void libcamera_connect(LibCamera *camera);

void libcamera_disconnect(LibCamera *camera);

int libcamera_isCapturing(LibCamera *camera);

int libcamera_start_capture(LibCamera *camera);

void libcamera_stop_capture(LibCamera *camera);

int libcamera_get_refcnt(LibCamera *camera);

uint32_t libcamera_get_streamcfg_width(LibCamera *camera);

uint32_t libcamera_get_streamcfg_height(LibCamera *camera);

uint32_t libcamera_get_streamcfgpixel_format(LibCamera *camera);

uint32_t libcamera_enum_streamcfgpixel_format(LibCamera *camera, uint32_t idx);

uint32_t libcamera_video_format_to_drm(uint32_t fmt);

uint32_t libcamera_drm_to_video_format(unsigned int drm);

uint32_t libcamera_get_nbuffers(LibCamera *camera);

uint32_t libcamera_get_nplanes(LibCamera *camera);

int64_t libcamera_get_fd(LibCamera *camera, int bufIdx, int planeIdx);

int32_t libcamera_get_max_size(LibCamera *camera);

int32_t libcamera_set_control(LibCamera *camera, uint32_t control_id, float value);

void libcamera_set_streamcfg_width(LibCamera *camera, uint32_t w);

void libcamera_set_streamcfg_height(LibCamera *camera, uint32_t w);

void libcamera_set_streamcfgpixel_format(LibCamera *camera, uint32_t fmt);

void libcamera_get_streamcfg_size(LibCamera *camera, uint32_t idx, uint32_t *width, uint32_t *height);

uint32_t libcamera_get_stride(LibCamera *camera);

void *libcamera_get_ring_buffer_data(LibCamera *camera);

void libcamera_reset_ring_buffer_data(LibCamera *camera);

void libcamera_ringbuffer_read_update(LibCamera *camera);

void libcamera_consume_data(LibCamera *camera);

void libcamera_free_CamData(LibCamera *camera, CamData *p);

void libcamera_free_OutBuf(LibCamera *camera, OutBuf *p);

void libcamera_set_spa_system(LibCamera *camera, struct spa_system *system);

void libcamera_set_eventfd(LibCamera *camera, int fd);

#ifdef __cplusplus
}
#endif /* extern "C" */
#endif /* __LIBCAMERA_WRAPPER_H */