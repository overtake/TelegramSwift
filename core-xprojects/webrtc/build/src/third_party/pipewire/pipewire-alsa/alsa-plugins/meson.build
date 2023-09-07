pipewire_alsa_plugin_pcm_sources = [
  'pcm_pipewire.c',
]
pipewire_alsa_plugin_ctl_sources = [
  'ctl_pipewire.c',
]

pipewire_alsa_plugin_c_args = [
  '-DHAVE_CONFIG_H',
  '-DPIC',
]

pipewire_alsa_pcm_plugin = shared_library('asound_module_pcm_pipewire',
    pipewire_alsa_plugin_pcm_sources,
    c_args : pipewire_alsa_plugin_c_args,
    include_directories : [configinc],
    dependencies : [pipewire_dep, alsa_dep],
    install : true,
    install_dir : pipewire_libdir / 'alsa-lib',
)
pipewire_alsa_ctl_plugin = shared_library('asound_module_ctl_pipewire',
    pipewire_alsa_plugin_ctl_sources,
    c_args : pipewire_alsa_plugin_c_args,
    include_directories : [configinc],
    dependencies : [pipewire_dep, alsa_dep],
    install : true,
    install_dir : pipewire_libdir / 'alsa-lib',
)
