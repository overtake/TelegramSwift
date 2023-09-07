libcamera_sources = ['libcamera.c',
                'libcamera-device.c',
                'libcamera-client.c',
                'libcamera-source.c',
                'libcamera_wrapper.cpp']

libdrm_dep = dependency('libdrm', version : '>= 2.4.98',
                        required : get_option('libcamera'))
if libdrm_dep.found()
libcameralib = shared_library('spa-libcamera',
                          libcamera_sources,
                          include_directories : [ spa_inc ],
                          dependencies : [ libudev_dep, libcamera_dep, pthread_lib, libdrm_dep  ],
                          install : true,
		          install_dir : spa_plugindir / 'libcamera')
endif
