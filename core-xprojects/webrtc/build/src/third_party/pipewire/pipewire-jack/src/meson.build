pipewire_jack_sources = [
  'export.c',
  'pipewire-jack.c',
  'ringbuffer.c',
  'uuid.c',
]

pipewire_jackserver_sources = pipewire_jack_sources
pipewire_jackserver_sources += [
  'control.c',
]

pipewire_dummy_sources = [
  'dummy.c',
]

pipewire_jack_c_args = [
  '-DHAVE_CONFIG_H',
  '-D_GNU_SOURCE',
  '-DPIC',
]

libjack_path = get_option('libjack-path')
if libjack_path == ''
  libjack_path = modules_install_dir / 'jack'
  libjack_path_dlopen = modules_install_dir_dlopen / 'jack'
else
  libjack_path_dlopen = libjack_path
endif

tools_config = configuration_data()
tools_config.set('LIBJACK_PATH', libjack_path_dlopen)

configure_file(input : 'pw-jack.in',
               output : 'pw-jack',
               configuration : tools_config,
               install_dir : pipewire_bindir)

pipewire_jack = shared_library('jack',
    pipewire_jack_sources,
    soversion : soversion,
    version : libversion,
    c_args : pipewire_jack_c_args,
    include_directories : [configinc, jack_inc],
    dependencies : [pipewire_dep, atomic_dep, mathlib],
    install : true,
    install_dir : libjack_path,
)

pipewire_jackserver = shared_library('jackserver',
    pipewire_jackserver_sources,
    soversion : soversion,
    version : libversion,
    c_args : pipewire_jack_c_args,
    include_directories : [configinc, jack_inc],
    dependencies : [pipewire_dep, atomic_dep, mathlib],
    install : true,
    install_dir : libjack_path,
)

pipewire_jackserver = shared_library('jacknet',
    pipewire_dummy_sources,
    soversion : soversion,
    version : libversion,
    c_args : pipewire_jack_c_args,
    include_directories : [configinc, jack_inc],
    dependencies : [pipewire_dep, mathlib],
    install : true,
    install_dir : libjack_path,
)

if get_option('jack-devel').enabled()
  pkgconfig.generate(filebase : 'jack',
  libraries : [pipewire_jack, pipewire_jackserver],
  name : 'jack',
  description : 'PipeWire JACK API',
  version : '1.9.17',
  extra_cflags : '-D_REENTRANT',
  variables: ['server_libs=-L${libdir} -ljackserver'])
endif

if sdl_dep.found()
  executable('video-dsp-play',
    '../examples/video-dsp-play.c',
    c_args : [ '-D_GNU_SOURCE' ],
    include_directories : [jack_inc],
    install : installed_tests_enabled,
    install_dir : installed_tests_execdir / 'examples' / 'jack',
    dependencies : [sdl_dep, mathlib],
    link_with: pipewire_jack,
  )
endif
