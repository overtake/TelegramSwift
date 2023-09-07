subdir('spa')

pipewire_module_c_args = [
  '-DHAVE_CONFIG_H',
  '-D_GNU_SOURCE',
]

pipewire_module_access = shared_library('pipewire-module-access', [ 'module-access.c' ],
  c_args : pipewire_module_c_args,
  include_directories : [configinc, spa_inc],
  install : true,
  install_dir : modules_install_dir,
  install_rpath: modules_install_dir,
  dependencies : [mathlib, dl_lib, pipewire_dep],
)

pipewire_module_loopback = shared_library('pipewire-module-loopback',
  [ 'module-loopback.c' ],
  c_args : pipewire_module_c_args,
  include_directories : [configinc, spa_inc],
  install : true,
  install_dir : modules_install_dir,
  install_rpath: modules_install_dir,
  dependencies : [mathlib, dl_lib, pipewire_dep],
)

pipewire_module_echo_cancel = shared_library('pipewire-module-echo-cancel',
  [ 'module-echo-cancel.c',
    'module-echo-cancel/aec-null.c',
    'module-echo-cancel/aec-webrtc.cc' ],
  c_args : pipewire_module_c_args,
  include_directories : [configinc, spa_inc],
  install : true,
  install_dir : modules_install_dir,
  install_rpath: modules_install_dir,
  dependencies : [mathlib, dl_lib, pipewire_dep],
)

pipewire_module_profiler = shared_library('pipewire-module-profiler',
  [ 'module-profiler.c',
    'module-profiler/protocol-native.c', ],
  c_args : pipewire_module_c_args,
  include_directories : [configinc, spa_inc],
  install : true,
  install_dir : modules_install_dir,
  install_rpath: modules_install_dir,
  dependencies : [mathlib, dl_lib, pipewire_dep],
)

if dbus_dep.found()
pipewire_module_rtkit = shared_library('pipewire-module-rtkit', [ 'module-rtkit.c' ],
  c_args : pipewire_module_c_args,
  include_directories : [configinc, spa_inc],
  install : true,
  install_dir : modules_install_dir,
  install_rpath: modules_install_dir,
  dependencies : [dbus_dep, mathlib, dl_lib, pipewire_dep],
)
pipewire_module_portal = shared_library('pipewire-module-portal', [ 'module-portal.c' ],
  c_args : pipewire_module_c_args,
  include_directories : [configinc, spa_inc],
  install : true,
  install_dir : modules_install_dir,
  install_rpath: modules_install_dir,
  dependencies : [dbus_dep, mathlib, dl_lib, pipewire_dep],
)
endif

pipewire_module_client_node = shared_library('pipewire-module-client-device',
  [ 'module-client-device.c',
    'module-client-device/resource-device.c',
    'module-client-device/proxy-device.c',
    'module-client-device/protocol-native.c', ],
  c_args : pipewire_module_c_args,
  include_directories : [configinc, spa_inc],
  install : true,
  install_dir : modules_install_dir,
  install_rpath: modules_install_dir,
  dependencies : [mathlib, dl_lib, pipewire_dep],
)

pipewire_module_link_factory = shared_library('pipewire-module-link-factory',
  [ 'module-link-factory.c' ],
  c_args : pipewire_module_c_args,
  include_directories : [configinc, spa_inc],
  install : true,
  install_dir : modules_install_dir,
  install_rpath: modules_install_dir,
  dependencies : [mathlib, dl_lib, pipewire_dep],
)

pipewire_module_protocol_deps = [mathlib, dl_lib, pipewire_dep]

if systemd_dep.found()
  pipewire_module_protocol_deps += systemd_dep
endif

pipewire_module_protocol_native = shared_library('pipewire-module-protocol-native',
  [ 'module-protocol-native.c',
    'module-protocol-native/local-socket.c',
    'module-protocol-native/portal-screencast.c',
    'module-protocol-native/protocol-native.c',
    'module-protocol-native/v0/protocol-native.c',
    'module-protocol-native/connection.c' ],
  c_args : pipewire_module_c_args,
  include_directories : [configinc, spa_inc],
  install : true,
  install_dir : modules_install_dir,
  install_rpath: modules_install_dir,
  dependencies : pipewire_module_protocol_deps,
)

pipewire_module_protocol_pulse_deps = pipewire_module_protocol_deps

if dbus_dep.found()
  pipewire_module_protocol_pulse_deps += dbus_dep
endif

pipewire_module_protocol_pulse = shared_library('pipewire-module-protocol-pulse',
  [ 'module-protocol-pulse.c',
    'module-protocol-pulse/manager.c',
    'module-protocol-pulse/pulse-server.c',
    'module-protocol-pulse/modules/module-loopback.c',
    'module-protocol-pulse/modules/module-native-protocol-tcp.c',
    'module-protocol-pulse/modules/module-null-sink.c',
    'module-protocol-pulse/modules/module-remap-sink.c',
    'module-protocol-pulse/modules/module-remap-source.c',
    'module-protocol-pulse/modules/module-simple-protocol-tcp.c',
  ],
  c_args : pipewire_module_c_args,
  include_directories : [configinc, spa_inc],
  install : true,
  install_dir : modules_install_dir,
  install_rpath: modules_install_dir,
  dependencies : pipewire_module_protocol_pulse_deps,
)

pipewire_module_protocol_simple = shared_library('pipewire-module-protocol-simple',
  [ 'module-protocol-simple.c' ],
  c_args : pipewire_module_c_args,
  include_directories : [configinc, spa_inc],
  install : true,
  install_dir : modules_install_dir,
  install_rpath: modules_install_dir,
  dependencies : pipewire_module_protocol_deps,
)

pipewire_module_client_node = shared_library('pipewire-module-client-node',
  [ 'module-client-node.c',
    'module-client-node/remote-node.c',
    'module-client-node/client-node.c',
    'module-client-node/protocol-native.c',
    'module-client-node/v0/client-node.c',
    'module-client-node/v0/transport.c',
    'module-client-node/v0/protocol-native.c',
    'spa/spa-node.c', ],
  c_args : pipewire_module_c_args,
  include_directories : [configinc, spa_inc],
  link_with : pipewire_module_protocol_native,
  install : true,
  install_dir : modules_install_dir,
  install_rpath: modules_install_dir,
  dependencies : [mathlib, dl_lib, pipewire_dep],
)

pipewire_module_metadata = shared_library('pipewire-module-metadata',
  [ 'module-metadata.c',
    'module-metadata/proxy-metadata.c',
    'module-metadata/metadata.c',
    'module-metadata/protocol-native.c'],
  c_args : pipewire_module_c_args,
  include_directories : [configinc, spa_inc],
  link_with : pipewire_module_protocol_native,
  install : true,
  install_dir : modules_install_dir,
  install_rpath: modules_install_dir,
  dependencies : [mathlib, dl_lib, pipewire_dep],
)

test('pw-test-protocol-native',
	executable('pw-test-protocol-native',
		[ 'module-protocol-native/test-connection.c',
		  'module-protocol-native/connection.c' ],
			c_args : libpipewire_c_args,
			include_directories : [configinc, spa_inc ],
			dependencies : [pipewire_dep],
			install : installed_tests_enabled,
			install_dir : installed_tests_execdir),
	env : [
		'SPA_PLUGIN_DIR=@0@/spa/plugins/'.format(meson.build_root()),
		'PIPEWIRE_CONFIG_DIR=@0@/src/daemon/'.format(meson.build_root()),
		'PIPEWIRE_MODULE_DIR=@0@/src/modules/'.format(meson.build_root())
	])

if installed_tests_enabled
  test_conf = configuration_data()
  test_conf.set('exec', installed_tests_execdir / 'pw-test-protocol-native')
  configure_file(
    input: installed_tests_template,
    output: 'pw-test-protocol-native.test',
    install_dir: installed_tests_metadir,
    configuration: test_conf
  )
endif

pipewire_module_adapter = shared_library('pipewire-module-adapter',
  [ 'module-adapter.c',
    'module-adapter/adapter.c',
    'spa/spa-node.c' ],
  c_args : pipewire_module_c_args,
  include_directories : [configinc, spa_inc],
  install : true,
  install_dir : modules_install_dir,
  install_rpath: modules_install_dir,
  dependencies : [mathlib, dl_lib, rt_lib, pipewire_dep],
)

pipewire_module_session_manager = shared_library('pipewire-module-session-manager',
  [ 'module-session-manager.c',
    'module-session-manager/client-endpoint/client-endpoint.c',
    'module-session-manager/client-endpoint/endpoint-stream.c',
    'module-session-manager/client-endpoint/endpoint.c',
    'module-session-manager/client-session/client-session.c',
    'module-session-manager/client-session/endpoint-link.c',
    'module-session-manager/client-session/session.c',
    'module-session-manager/endpoint-link.c',
    'module-session-manager/endpoint-stream.c',
    'module-session-manager/endpoint.c',
    'module-session-manager/protocol-native.c',
    'module-session-manager/proxy-session-manager.c',
    'module-session-manager/session.c',
  ],
  c_args : pipewire_module_c_args,
  include_directories : [configinc, spa_inc],
  install : true,
  install_dir : modules_install_dir,
  install_rpath: modules_install_dir,
  dependencies : [mathlib, dl_lib, pipewire_dep],
)
