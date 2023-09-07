/* Spa libcamera support
 *
 * Copyright (C) 2020, Collabora Ltd.
 *     Author: Raghavendra Rao Sidlagatta <raghavendra.rao@collabora.com>
 *
 * libcamera_wrapper.cpp
 *
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
#include <pthread.h>
#include <stdio.h>
#include <string.h>
#include <errno.h>

#include <climits>
#include <fcntl.h>
#include <iomanip>
#include <iostream>
#include <sstream>
#include <sys/mman.h>
#include <unistd.h>

#include <drm_fourcc.h>

#include <spa/support/log.h>
#include <spa/support/system.h>
#include <spa/param/props.h>
#include <spa/param/video/raw.h>

#include <libcamera/camera.h>
#include <libcamera/camera_manager.h>
#include <libcamera/request.h>
#include <libcamera/framebuffer_allocator.h>
#include <libcamera/buffer.h>
#include <libcamera/property_ids.h>
#include <libcamera/controls.h>

#include <libcamera/control_ids.h>
#include <linux/videodev2.h>

using namespace libcamera;
using namespace controls;

#include "libcamera_wrapper.h"

#define DEFAULT_WIDTH			640
#define DEFAULT_HEIGHT			480
#define DEFAULT_PIXEL_FMT		DRM_FORMAT_YUYV

/* Compressed formats
 *
 * TODO: Should be removed when the format gets merged in the
 * libdrm.*/
#ifndef DRM_FORMAT_MJPEG
# define DRM_FORMAT_MJPEG	fourcc_code('M', 'J', 'P', 'G') /* Motion-JPEG */
#endif

extern "C" {

	static struct {
		spa_video_format video_format;
		unsigned int drm_fourcc;
	} format_map[] = {
		{ SPA_VIDEO_FORMAT_ENCODED, DRM_FORMAT_MJPEG },
		{ SPA_VIDEO_FORMAT_RGB, DRM_FORMAT_BGR888 },
		{ SPA_VIDEO_FORMAT_BGR, DRM_FORMAT_RGB888 },
		{ SPA_VIDEO_FORMAT_ARGB, DRM_FORMAT_BGRA8888 },
		{ SPA_VIDEO_FORMAT_NV12, DRM_FORMAT_NV12 },
		{ SPA_VIDEO_FORMAT_NV21, DRM_FORMAT_NV21 },
		{ SPA_VIDEO_FORMAT_NV16, DRM_FORMAT_NV16 },
		{ SPA_VIDEO_FORMAT_NV61, DRM_FORMAT_NV61 },
		{ SPA_VIDEO_FORMAT_NV24, DRM_FORMAT_NV24 },
		{ SPA_VIDEO_FORMAT_UYVY, DRM_FORMAT_UYVY },
		{ SPA_VIDEO_FORMAT_VYUY, DRM_FORMAT_VYUY },
		{ SPA_VIDEO_FORMAT_YUY2, DRM_FORMAT_YUYV },
		{ SPA_VIDEO_FORMAT_YVYU, DRM_FORMAT_YVYU },
		/* \todo NV42 is used in libcamera but is not mapped in here yet. */
	};

	typedef struct ring_buf {
		uint32_t read_index;
		uint32_t write_index;
	}ring_buf;

	typedef struct LibCamera {
		std::unique_ptr<CameraManager> cm_;
		std::shared_ptr<Camera> cam_;
		std::unique_ptr<CameraConfiguration> config_;
		FrameBufferAllocator *allocator_;
		std::map<Stream*, std::string> streamName_;
		std::vector<std::unique_ptr<Request>> requests_;

		uint32_t nbuffers_;
		uint32_t nplanes_;
		uint32_t bufIdx_;
		int64_t **fd_;
		uint32_t maxSize_;
		uint32_t width_;
		uint32_t height_;
		uint32_t pixelFormat_;
		uint32_t stride_;

		struct ring_buf ringbuf_;
		void *ringbuf_data_[MAX_NUM_BUFFERS] = {};
		struct spa_log *log_;
		struct spa_system *system_;
		int eventfd_ = -1;
		pthread_mutex_t lock;

		/* Methods */
		int32_t listProperties();
		void requestComplete(Request *request);
		void item_free_fn();
		void ring_buffer_init();
		void *ring_buffer_read();
		void ring_buffer_write(void *p);
		bool open();
		void close();
		int request_capture();
		int start();
		void stop();
		void connect();
		void disconnect();
		bool set_config();

		std::shared_ptr<Camera> get_camera();
		std::string choose_camera();

		/* Mutators */
		void set_streamcfg_width(uint32_t w);
		void set_streamcfg_height(uint32_t h);
		void set_streamcfgpixel_format(uint32_t fmt);
		void set_max_size(uint32_t s);
		void set_nbuffers(uint32_t n);
		void set_nplanes(uint32_t n);
		void set_stride(uint32_t s);
		void set_fd(Stream *stream);
		void ring_buffer_set_read_index(uint32_t idx);
		void ring_buffer_set_write_index(uint32_t idx);
		void ring_buffer_update_read_index();
		void ring_buffer_update_write_index();
		void reset_ring_buffer_data();
		int32_t set_control(ControlList &controls, uint32_t control_id, float value);

		/* Accessors */
		uint32_t get_streamcfg_width();
		uint32_t get_streamcfg_height();
		uint32_t get_streamcfgpixel_format();
		uint32_t get_max_size();
		uint32_t get_nbuffers();
		uint32_t get_nplanes();
		uint32_t get_stride();
		uint32_t ring_buffer_get_read_index();
		uint32_t ring_buffer_get_write_index();
	}LibCamera;

	uint32_t LibCamera::get_max_size() {
		return this->maxSize_;
	}

	void LibCamera::set_max_size(uint32_t s) {
		this->maxSize_ = s;
	}

	uint32_t LibCamera::get_nbuffers() {
		return this->nbuffers_;
	}

	void LibCamera::set_nbuffers(uint32_t n) {
		this->nbuffers_ = n;
	}

	void LibCamera::set_nplanes(uint32_t n) {
		this->nplanes_ = n;
	}

	void LibCamera::set_stride(uint32_t s) {
		this->stride_ = s;
	}

	uint32_t LibCamera::get_stride() {
		return this->stride_;
	}

	void LibCamera::set_fd(Stream *stream) {
		this->fd_ = new int64_t*[this->nbuffers_];

		uint32_t bufIdx = 0;
		for (const std::unique_ptr<FrameBuffer> &buffer : this->allocator_->buffers(stream)) {
			uint32_t nplanes = buffer->planes().size();
			this->fd_[bufIdx] = new int64_t[this->nplanes_];
			for(uint32_t planeIdx = 0; planeIdx < nplanes; ++planeIdx) {
				const FrameBuffer::Plane &plane = buffer->planes().front();
				this->fd_[bufIdx][planeIdx] = plane.fd.fd();
			}
			bufIdx++;
		}
	}

	uint32_t LibCamera::get_nplanes() {
		return this->nplanes_;
	}

	void LibCamera::ring_buffer_init() {
		this->ringbuf_.read_index = 0;
		this->ringbuf_.write_index = 0;
	}

	uint32_t LibCamera::ring_buffer_get_read_index() {
		uint32_t idx;
		idx = __atomic_load_n(&this->ringbuf_.read_index, __ATOMIC_RELAXED);

		return idx;
	}

	uint32_t LibCamera::ring_buffer_get_write_index() {
		uint32_t idx;
		idx = __atomic_load_n(&this->ringbuf_.write_index, __ATOMIC_RELAXED);

		return idx;
	}

	void LibCamera::ring_buffer_set_read_index(uint32_t idx) {
		__atomic_store_n(&this->ringbuf_.read_index, idx, __ATOMIC_RELEASE);
	}

	void LibCamera::ring_buffer_set_write_index(uint32_t idx) {
		__atomic_store_n(&this->ringbuf_.write_index, idx, __ATOMIC_RELEASE);
	}

	void LibCamera::ring_buffer_update_read_index() {
		uint32_t idx;

		idx = this->ring_buffer_get_read_index();
		this->ringbuf_data_[idx] = nullptr;
		++idx;
		if(idx == MAX_NUM_BUFFERS) {
			idx = 0;
		}
		this->ring_buffer_set_read_index(idx);
	}

	void LibCamera::ring_buffer_update_write_index() {
		uint32_t idx;

		idx = this->ring_buffer_get_write_index();
		++idx;
		if(idx == MAX_NUM_BUFFERS) {
			idx = 0;
		}
		this->ring_buffer_set_write_index(idx);
	}

	void LibCamera::ring_buffer_write(void *p)
	{
		uint32_t idx;

		idx = this->ring_buffer_get_write_index();
		pthread_mutex_lock(&this->lock);
		ringbuf_data_[idx] = p;
		pthread_mutex_unlock(&this->lock);
	}

	void *LibCamera::ring_buffer_read()
	{
		uint32_t idx;
		void *p;

		idx = this->ring_buffer_get_read_index();
		pthread_mutex_lock(&this->lock);
		p = (void *)this->ringbuf_data_[idx];
		pthread_mutex_unlock(&this->lock);

		return p;
	}

	void LibCamera::item_free_fn() {
		uint32_t ringbuf_read_index;
		struct OutBuf *pOut = NULL;
		struct CamData *pDatas = NULL;

		ringbuf_read_index = this->ring_buffer_get_read_index();
		for(int i = 0; i < MAX_NUM_BUFFERS; i++) {
			pOut = (struct OutBuf *)ringbuf_data_[ringbuf_read_index];
			if(pOut) {
				pDatas = pOut->datas;
				if(pDatas) {
					libcamera_free_CamData(this, pDatas);
				}
				libcamera_free_OutBuf(this, pOut);
			}
			++ringbuf_read_index;
			if(ringbuf_read_index == MAX_NUM_BUFFERS) {
				ringbuf_read_index = 0;
			}
		}
	}

	std::string LibCamera::choose_camera() {
		if (!this->cm_) {
			return std::string();
		}

		if (this->cm_->cameras().empty()) {
			return std::string();
		}
		/* If only one camera is available, use it automatically. */
		else if (this->cm_->cameras().size() == 1) {
			return this->cm_->cameras()[0]->id();
		}
		/* TODO::
		 * 1. Allow the user to provide a camera name to select.			*
		 * 2. Select the camera based on the camera name provided by User 	*
		 */
		/* For time being, return the first camera if more than 1 camera devices are available */
		else {
			return this->cm_->cameras()[0]->id();
		}
	}

	std::shared_ptr<Camera> LibCamera::get_camera() {
		std::string camName = this->choose_camera();
		std::shared_ptr<Camera> cam;

		if (camName == "") {
			return nullptr;
		}

		cam = this->cm_->get(camName);
		if (!cam) {
			return nullptr;
		}

		/* Sanity check that the camera has streams. */
		if (cam->streams().empty()) {
			return nullptr;
		}

		return cam;
	}

	uint32_t LibCamera::get_streamcfg_width() {
		return this->width_;
	}

	uint32_t LibCamera::get_streamcfg_height() {
		return this->height_;
	}

	uint32_t LibCamera::get_streamcfgpixel_format() {
		return this->pixelFormat_;
	}

	void LibCamera::set_streamcfg_width(uint32_t w) {
		this->width_ = w;
	}

	void LibCamera::set_streamcfg_height(uint32_t h) {
		this->height_ = h;
	}

	void LibCamera::set_streamcfgpixel_format(uint32_t fmt) {
		this->pixelFormat_ = fmt;
	}

	bool LibCamera::set_config() {
    	if(!this->cam_) {
    		return false;
    	}

    	this->config_ = this->cam_->generateConfiguration({ StreamRole::VideoRecording });
    	if (!this->config_ || this->config_->size() != 1) {
    		return false;
		}

		StreamConfiguration &cfg = this->config_->at(0);

		cfg.size.width = this->get_streamcfg_width();
		cfg.size.height = this->get_streamcfg_height();
		cfg.pixelFormat = PixelFormat(this->get_streamcfgpixel_format());

		/* Validate the configuration. */
		if (this->config_->validate() == CameraConfiguration::Invalid) {
			return false;
		}

    	if (this->cam_->configure(this->config_.get())) {
    		return false;
		}

		this->listProperties();

		this->allocator_ = new FrameBufferAllocator(this->cam_);
		uint32_t nbuffers = UINT_MAX, nplanes = 0;

		Stream *stream = cfg.stream();
		int ret = this->allocator_->allocate(stream);
		if (ret < 0) {
			return -ENOMEM;
		}

		uint32_t allocated = this->allocator_->buffers(cfg.stream()).size();
		nbuffers = std::min(nbuffers, allocated);

		this->set_nbuffers(nbuffers);

		int id = 0;
		uint32_t max_size = 0;
		for (const std::unique_ptr<FrameBuffer> &buffer : this->allocator_->buffers(stream)) {
			nplanes = buffer->planes().size();
			const FrameBuffer::Plane &plane = buffer->planes().front();
			max_size = std::max(max_size, plane.length);
			++id;
		}
		this->set_max_size(max_size);
		this->set_nplanes(nplanes);
		this->set_fd(stream);
		this->set_stride(cfg.stride);

		return true;
	}

	int LibCamera::request_capture() {
    	int ret = 0;

    	StreamConfiguration &cfg = this->config_->at(0);
		Stream *stream = cfg.stream();

		for (const std::unique_ptr<FrameBuffer> &buffer : this->allocator_->buffers(stream)) {
			std::unique_ptr<Request> request = this->cam_->createRequest();
			if (!request) {
				spa_log_error(this->log_, "Cannot create request");
				return -ENOMEM;
			}

			if (request->addBuffer(stream, buffer.get())) {
				spa_log_error(this->log_, "Failed to associating buffer with request");
				return -ENOMEM;
			}

			this->requests_.push_back(std::move(request));
		}

		return ret;
    }

	bool LibCamera::open() {
		std::shared_ptr<Camera> cam;
		int ret = 0;

		cam = this->get_camera();
		if(!cam) {
			return false;
		}

		ret = cam->acquire();
		if (ret) {
			return false;
		}

		this->cam_ = cam;

		if(!this->set_config()) {
			return false;
		}

		return true;
	}

	int LibCamera::start() {
		if(!this->set_config()) {
			return -1;
		}

		this->streamName_.clear();
		for (unsigned int index = 0; index < this->config_->size(); ++index) {
			StreamConfiguration &cfg = this->config_->at(index);
			this->streamName_[cfg.stream()] = "stream" + std::to_string(index);
		}

		if(this->request_capture()) {
			spa_log_error(this->log_, "failed to create request");
			return -1;
		}

		spa_log_info(this->log_, "Starting camera ...");

		/* start the camera now */
		if (this->cam_->start()) {
			spa_log_error(this->log_, "failed to start camera");
			return -1;
		}

		this->ring_buffer_init();

		for (std::unique_ptr<Request> &request : this->requests_) {
			int ret = this->cam_->queueRequest(request.get());
			if (ret < 0) {
				spa_log_error(this->log_, "Cannot enqueue request");
				return ret;
			}
		}
		return 0;
	}

	void LibCamera::stop() {
		this->disconnect();

		uint32_t bufIdx = 0;
		StreamConfiguration &cfg = this->config_->at(0);
		Stream *stream = cfg.stream();

		for (const std::unique_ptr<FrameBuffer> &buffer : this->allocator_->buffers(stream)) {
			delete [] this->fd_[bufIdx];
			bufIdx++;
		}
		delete [] this->fd_;

    	spa_log_info(this->log_, "Stopping camera ...");
    	this->cam_->stop();
    	if(this->allocator_) {
	    	delete this->allocator_;
	    	this->allocator_ = nullptr;
    	}

	    this->item_free_fn();
	}

	void LibCamera::close() {
    	this->stop();
		this->cam_->release();
	}

	void LibCamera::connect()
	{
		this->cam_->requestCompleted.connect(this, &LibCamera::requestComplete);
	}

	void LibCamera::disconnect()
	{
		this->cam_->requestCompleted.disconnect(this, &LibCamera::requestComplete);
	}

	uint32_t libcamera_get_streamcfg_width(LibCamera *camera) {
		return camera->get_streamcfg_width();
	}

	uint32_t libcamera_get_streamcfg_height(LibCamera *camera) {
		return camera->get_streamcfg_height();
	}

	uint32_t libcamera_get_streamcfgpixel_format(LibCamera *camera) {
		return camera->get_streamcfgpixel_format();
	}

	void libcamera_set_streamcfg_width(LibCamera *camera, uint32_t w) {
		camera->set_streamcfg_width(w);
	}

	void libcamera_set_streamcfg_height(LibCamera *camera, uint32_t h) {
		camera->set_streamcfg_height(h);
	}

	void libcamera_set_streamcfgpixel_format(LibCamera *camera, uint32_t fmt) {
		camera->set_streamcfgpixel_format(fmt);
	}

	void libcamera_ringbuffer_read_update(LibCamera *camera) {
		camera->ring_buffer_update_read_index();
	}

	void *libcamera_get_ring_buffer_data(LibCamera *camera) {
		return camera->ring_buffer_read();
	}

	void libcamera_free_OutBuf(LibCamera *camera, OutBuf *p) {
		pthread_mutex_lock(&camera->lock);
    	if(p != nullptr) {
    		delete p;
    		p = nullptr;
    	}
    	pthread_mutex_unlock(&camera->lock);
    }

    void libcamera_free_CamData(LibCamera *camera, CamData *p) {
    	pthread_mutex_lock(&camera->lock);
    	if(p != nullptr) {
    		delete p;
    		p = nullptr;
    	}
    	pthread_mutex_unlock(&camera->lock);
    }

	void libcamera_set_log(LibCamera *camera, struct spa_log *log) {
		camera->log_ = log;
	}

	void libcamera_set_spa_system(LibCamera *camera, struct spa_system *system) {
		camera->system_ = system;
	}

	void libcamera_set_eventfd(LibCamera *camera, int fd) {
		camera->eventfd_ = fd;
	}

	spa_video_format libcamera_map_drm_fourcc_format(unsigned int fourcc) {
		for (const auto &item : format_map) {
			if (item.drm_fourcc == fourcc) {
				return item.video_format;
			}
		}
		return (spa_video_format)UINT32_MAX;
	}

	uint32_t libcamera_drm_to_video_format(unsigned int drm) {
		return libcamera_map_drm_fourcc_format(drm);
	}

	uint32_t libcamera_video_format_to_drm(uint32_t format)
	{
		if (format == SPA_VIDEO_FORMAT_ENCODED) {
			return DRM_FORMAT_INVALID;
		}

		for (const auto &item : format_map) {
			if (item.video_format == format) {
				return item.drm_fourcc;
			}
		}

		return DRM_FORMAT_INVALID;
	}

	uint32_t libcamera_enum_streamcfgpixel_format(LibCamera *camera, uint32_t idx) {
		if(!camera) {
			return -1;
		}
		if (!camera->config_) {
			spa_log_error(camera->log_, "Cannot get stream information without a camera");
			return -EINVAL;
		}

		for (const StreamConfiguration &cfg : *camera->config_) {
			uint32_t index = 0;
			const StreamFormats &formats = cfg.formats();
			for (PixelFormat pixelformat : formats.pixelformats()) {
				if(index == idx) {
					return pixelformat.fourcc();
				}
				++index;
			}
		}
		/* We shouldn't be here */
		return UINT32_MAX;
	}

	void libcamera_get_streamcfg_size(LibCamera *camera, uint32_t idx, uint32_t *width, uint32_t *height) {
		if(!camera) {
			return;
		}
		if (!camera->config_) {
			spa_log_error(camera->log_, "Cannot get stream information without a camera");;
			return;
		}

		for (const StreamConfiguration &cfg : *camera->config_) {
			const StreamFormats &formats = cfg.formats();
			for (PixelFormat pixelformat : formats.pixelformats()) {
				uint32_t index = 0;
				for (const Size &size : formats.sizes(pixelformat)) {
					if(index == idx) {
						*width = size.width;
						*height = size.height;
						return;
					}
					++index;
				}
			}
		}
		/* We shouldn't be here */
		*width = *height = UINT32_MAX;
	}

	int LibCamera::listProperties()
	{
		if (!cam_) {
			spa_log_error(log_, "Cannot list properties without a camera");;
			return -EINVAL;
		}

		spa_log_info(log_, "listing properties");
		for (const auto &prop : cam_->properties()) {
			const ControlId *id = properties::properties.at(prop.first);
			const ControlValue &value = prop.second;

			spa_log_info(log_, "Property: %s = %s",id->name().c_str(), value.toString().c_str());
		}

		return 0;
	}

	int64_t libcamera_get_fd(LibCamera *camera, int bufIdx, int planeIdx) {
		if((bufIdx >= (int)camera->nbuffers_) || (planeIdx >= (int)camera->nplanes_)){
			return -1;
		} else {
			return camera->fd_[bufIdx][planeIdx];
		}
	}

	int libcamera_get_max_size(LibCamera *camera) {
		return camera->get_max_size();
	}

	void libcamera_connect(LibCamera *camera) {
    	if(!camera || !camera->cam_) {
    		return;
    	}
    	camera->connect();
    }

    uint32_t libcamera_get_nbuffers(LibCamera *camera) {
		return camera->get_nbuffers();
    }

    uint32_t libcamera_get_nplanes(LibCamera *camera) {
    	return camera->get_nplanes();
    }

    uint32_t libcamera_get_stride(LibCamera *camera) {
    	return camera->get_stride();
    }

	int libcamera_start_capture(LibCamera *camera) {
		if (!camera || !camera->cm_ || !camera->cam_) {
			return -1;
		}

		return camera->start();
	}

    void libcamera_disconnect(LibCamera *camera) {
    	if(!camera || !camera->cam_) {
    		return;
    	}
    	camera->disconnect();
    }

    void libcamera_stop_capture(LibCamera *camera) {
    	if(!camera || !camera->cm_ || !camera->cam_) {
    		return;
    	}

    	camera->stop();
    }

	LibCamera* newLibCamera() {
		int ret = 0;
		pthread_mutexattr_t attr;
		std::unique_ptr<CameraManager> cm = std::make_unique<CameraManager>();
		LibCamera* camera = new LibCamera();

		ret = cm->start();
		if (ret) {
			deleteLibCamera(camera);
			return nullptr;
		}

		camera->cm_ = std::move(cm);

		camera->bufIdx_ = 0;

		camera->set_streamcfg_width(DEFAULT_WIDTH);
		camera->set_streamcfg_height(DEFAULT_HEIGHT);
		camera->set_streamcfgpixel_format(DEFAULT_PIXEL_FMT);

		if(!camera->open()) {
			deleteLibCamera(camera);
			return nullptr;
		}

		pthread_mutexattr_init(&attr);
		pthread_mutex_init(&camera->lock, &attr);

		camera->ring_buffer_init();

		return camera;
	}

    void deleteLibCamera(LibCamera *camera) {
    	if(camera == nullptr) {
    		return;
    	}

    	pthread_mutex_destroy(&camera->lock);

    	camera->close();

    	if(camera->cm_)
    		camera->cm_->stop();

    	delete camera;
    	camera = nullptr;
    }

    void LibCamera::requestComplete(Request *request) {
    	if (request->status() == Request::RequestCancelled) {
    		return;
    	}

    	++bufIdx_;
		if(bufIdx_ >= nbuffers_) {
			bufIdx_ = 0;
		}

		const Request::BufferMap &buffers = request->buffers();

		for (auto it = buffers.begin(); it != buffers.end(); ++it) {
			FrameBuffer *buffer = it->second;
			unsigned int nplanes = buffer->planes().size();
			OutBuf *pBuf = new OutBuf();

			pBuf->bufIdx = bufIdx_;
			pBuf->n_datas = nplanes;
			pBuf->datas = new CamData[pBuf->n_datas];

			unsigned int planeIdx = 0;
			const std::vector<FrameBuffer::Plane> &planes = buffer->planes();
			const FrameMetadata &metadata = buffer->metadata();
			for (const FrameMetadata::Plane &plane : metadata.planes) {
				pBuf->datas[planeIdx].idx = planeIdx;
				pBuf->datas[planeIdx].type = 3; /*SPA_DATA_DmaBuf;*/
				pBuf->datas[planeIdx].fd = planes[planeIdx].fd.fd();
				pBuf->datas[planeIdx].size = plane.bytesused;
				pBuf->datas[planeIdx].maxsize = buffer->planes()[planeIdx].length;
				pBuf->datas[planeIdx].sequence = metadata.sequence;
				pBuf->datas[planeIdx].timestamp.tv_sec = metadata.timestamp / 1000000000;
				pBuf->datas[planeIdx].timestamp.tv_usec = (metadata.timestamp / 1000) % 1000000;
				++planeIdx;
			}

			/* Push the buffer to ring buffer */
			if(pBuf && pBuf->datas) {
				this->ring_buffer_write(pBuf);
				/* Now update the write index of the ring buffer */
				this->ring_buffer_update_write_index();
				if(this->system_ && (this->eventfd_ > 0)) {
					if (spa_system_eventfd_write(this->system_, this->eventfd_, 1) < 0) {
						spa_log_error(log_, "Failed to write on event fd");
					}
				}
			}
		}

		/*
		 * Create a new request and populate it with one buffer for each
		 * stream.
		 */
		for (auto it = buffers.begin(); it != buffers.end(); ++it) {
			const Stream *stream = it->first;
			FrameBuffer *buffer = it->second;

			request->reuse();
			request->addBuffer(stream, buffer);
			cam_->queueRequest(request);
		}
    }

    int32_t LibCamera::set_control(ControlList &controls, uint32_t control_id, float value) {
    	switch(control_id) {
    		case SPA_PROP_brightness:
    			controls.set(controls::Brightness, value);
    		break;

    		case SPA_PROP_contrast:
    			controls.set(controls::Contrast, value);
    		break;

    		case SPA_PROP_saturation:
    			controls.set(controls::Saturation, value);
    		break;

    		case SPA_PROP_exposure:
    			controls.set(controls::ExposureValue, value);
    		break;

    		case SPA_PROP_gain:
    			controls.set(controls::AnalogueGain, value);
    		break;

    		default:
    		return -1;
    	}
    	return 0;
    }

    int32_t libcamera_set_control(LibCamera *camera, uint32_t control_id, float value) {
    	int32_t res;

    	if(!camera || !camera->cm_ || !camera->cam_)
    		return -1;

        std::unique_ptr<Request> request = camera->cam_->createRequest();
    	ControlList &controls = request->controls();
    	res = camera->set_control(controls, control_id, value);
        camera->cam_->queueRequest(request.get());

    	return res;
    }
}
