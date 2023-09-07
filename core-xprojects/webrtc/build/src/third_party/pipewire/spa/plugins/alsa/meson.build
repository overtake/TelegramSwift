subdir('acp')
subdir('mixer')

spa_alsa_sources = ['alsa.c',
                'alsa-udev.c',
                'alsa-acp-device.c',
                'alsa-pcm-device.c',
                'alsa-pcm-sink.c',
                'alsa-pcm-source.c',
                'alsa-pcm.c',
                'alsa-seq-bridge.c',
                'alsa-seq.c']

spa_alsa = shared_library(
  'spa-alsa',
  [ spa_alsa_sources ],
  c_args : acp_c_args,
  include_directories : [spa_inc, configinc],
  dependencies : [ alsa_dep, libudev_dep, mathlib, epoll_shim_dep, libinotify_dep ],
  link_with : [ acp_lib ],
  install : true,
  install_dir : spa_plugindir / 'alsa'
)

alsa_udevrules = [
  '90-pipewire-alsa.rules',
]

executable('spa-acp-tool',
  [ 'acp-tool.c' ],
  c_args : acp_c_args,
  include_directories : [spa_inc ],
  dependencies : [ alsa_dep, mathlib ],
  link_with : [ acp_lib ],
  install : true,
)


executable('test-timer',
  [ 'test-timer.c' ],
  dependencies : [ alsa_dep, mathlib, epoll_shim_dep ],
  install : false,
)

if libudev_dep.found()
  install_data(alsa_udevrules,
    install_dir : udevrulesdir,
  )
endif
