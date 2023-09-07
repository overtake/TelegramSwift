pipewire_gst_sources = [
  'gstpipewire.c',
  'gstpipewirecore.c',
  'gstpipewireclock.c',
  'gstpipewireformat.c',
  'gstpipewirepool.c',
  'gstpipewiresink.c',
  'gstpipewiresrc.c',
]

if not get_option('gstreamer-device-provider').disabled()
  pipewire_gst_sources += [ 'gstpipewiredeviceprovider.c' ]
endif

pipewire_gst_headers = [
  'gstpipewireclock.h',
  'gstpipewirecore.h',
  'gstpipewiredeviceprovider.h',
  'gstpipewireformat.h',
  'gstpipewirepool.h',
  'gstpipewiresink.h',
  'gstpipewiresrc.h',
]

pipewire_gst_c_args = [
  '-DHAVE_CONFIG_H',
  '-D_GNU_SOURCE',
]

pipewire_gst = shared_library('gstpipewire',
    pipewire_gst_sources,
    c_args : pipewire_gst_c_args,
    include_directories : [configinc, spa_inc],
    dependencies : [gst_dep, pipewire_dep],
    install : true,
    install_dir : '@0@/gstreamer-1.0'.format(get_option('libdir')),
)

plugins = [pipewire_gst]
