v4l2_sources = ['v4l2.c',
                'v4l2-device.c',
                'v4l2-udev.c',
                'v4l2-source.c']

v4l2lib = shared_library('spa-v4l2',
                          v4l2_sources,
                          include_directories : [ spa_inc ],
                          dependencies : [ libudev_dep, libinotify_dep ],
                          install : true,
		          install_dir : spa_plugindir / 'v4l2')
