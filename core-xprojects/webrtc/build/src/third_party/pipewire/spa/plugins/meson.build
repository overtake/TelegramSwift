if alsa_dep.found()
  subdir('alsa')
endif
if not get_option('audioconvert').disabled()
  subdir('audioconvert')
endif
if not get_option('audiomixer').disabled()
  subdir('audiomixer')
endif
if not get_option('control').disabled()
  subdir('control')
endif
if not get_option('audiotestsrc').disabled()
  subdir('audiotestsrc')
endif
subdir('bluez5')
if avcodec_dep.found() and avformat_dep.found()
  subdir('ffmpeg')
endif
if jack_dep.found()
  subdir('jack')
endif
if not get_option('support').disabled()
  subdir('support')
endif
if not get_option('test').disabled()
  subdir('test')
endif
if not get_option('videoconvert').disabled()
  subdir('videoconvert')
endif
if not get_option('videotestsrc').disabled()
  subdir('videotestsrc')
endif
if not get_option('volume').disabled()
  subdir('volume')
endif
if vulkan_headers
  subdir('vulkan')
endif
if libudev_dep.found() and not get_option('v4l2').disabled()
  subdir('v4l2')
endif
if libcamera_dep.found()
  subdir('libcamera')
endif
