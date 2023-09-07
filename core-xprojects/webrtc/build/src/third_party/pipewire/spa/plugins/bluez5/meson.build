bluez5_deps = [ mathlib, dbus_dep, sbc_dep, bluez_dep ]
foreach dep: bluez5_deps
  if not dep.found()
    subdir_done()
  endif
endforeach

if not get_option('bluez5-backend-hsp-native').disabled()
  cdata.set('HAVE_BLUEZ_5_BACKEND_HSP_NATIVE', 1)
  cdata.set('HAVE_BLUEZ_5_BACKEND_NATIVE', 1)
endif
if not get_option('bluez5-backend-hfp-native').disabled()
  cdata.set('HAVE_BLUEZ_5_BACKEND_HFP_NATIVE', 1)
  cdata.set('HAVE_BLUEZ_5_BACKEND_NATIVE', 1)
endif
if not get_option('bluez5-backend-ofono').disabled()
  cdata.set('HAVE_BLUEZ_5_BACKEND_OFONO', 1)
endif
if not get_option('bluez5-backend-hsphfpd').disabled()
  cdata.set('HAVE_BLUEZ_5_BACKEND_HSPHFPD', 1)
endif

bluez5_sources = ['plugin.c',
		  'a2dp-codecs.c',
		  'a2dp-codec-sbc.c',
		  'a2dp-sink.c',
		  'a2dp-source.c',
		  'sco-sink.c',
		  'sco-source.c',
		  'sco-io.c',
		  'bluez5-device.c',
		  'bluez5-dbus.c']

bluez5_args = [ '-D_GNU_SOURCE' ]

if ldac_dep.found()
  bluez5_sources += [ 'a2dp-codec-ldac.c' ]
  bluez5_args += [ '-DENABLE_LDAC' ]
  bluez5_deps += ldac_dep
  if ldac_abr_dep.found()
    bluez5_args += [ '-DENABLE_LDAC_ABR' ]
    bluez5_deps += ldac_abr_dep
  endif
endif
if aptx_dep.found()
  bluez5_sources += [ 'a2dp-codec-aptx.c' ]
  bluez5_args += [ '-DENABLE_APTX' ]
  bluez5_deps += aptx_dep
endif
if fdk_aac_dep.found()
  bluez5_sources += [ 'a2dp-codec-aac.c' ]
  bluez5_args += [ '-DENABLE_AAC' ]
  bluez5_deps += fdk_aac_dep
endif

if not get_option('bluez5-backend-hsp-native').disabled() or not get_option('bluez5-backend-hfp-native').disabled()
  bluez5_sources += ['backend-native.c']
endif

if not get_option('bluez5-backend-ofono').disabled()
  bluez5_sources += ['backend-ofono.c']
endif

if not get_option('bluez5-backend-hsphfpd').disabled()
  bluez5_sources += ['backend-hsphfpd.c']
endif

bluez5lib = shared_library('spa-bluez5',
	bluez5_sources,
	include_directories : [ spa_inc, configinc ],
	c_args : bluez5_args,
	dependencies : bluez5_deps,
	install : true,
        install_dir : spa_plugindir / 'bluez5')
