pipewire_module_spa_c_args = [
  '-DHAVE_CONFIG_H',
  '-D_GNU_SOURCE',
]

pipewire_module_spa_node = shared_library('pipewire-module-spa-node',
  [ 'module-node.c', 'spa-node.c' ],
  c_args : pipewire_module_spa_c_args,
  include_directories : [configinc, spa_inc],
  install : true,
  install_dir : modules_install_dir,
  dependencies : [mathlib, dl_lib, pipewire_dep],
)

pipewire_module_spa_device = shared_library('pipewire-module-spa-device',
  [ 'module-device.c', 'spa-device.c' ],
  c_args : pipewire_module_spa_c_args,
  include_directories : [configinc, spa_inc],
  install : true,
  install_dir : modules_install_dir,
  dependencies : [mathlib, dl_lib, pipewire_dep],
)

pipewire_module_spa_node_factory = shared_library('pipewire-module-spa-node-factory',
  [ 'module-node-factory.c', 'spa-node.c' ],
  c_args : pipewire_module_spa_c_args,
  include_directories : [configinc, spa_inc],
  install : true,
  install_dir : modules_install_dir,
  dependencies : [mathlib, dl_lib, pipewire_dep],
)

pipewire_module_spa_device_factory = shared_library('pipewire-module-spa-device-factory',
  [ 'module-device-factory.c', 'spa-device.c' ],
  c_args : pipewire_module_spa_c_args,
  include_directories : [configinc, spa_inc],
  install : true,
  install_dir : modules_install_dir,
  dependencies : [mathlib, dl_lib, pipewire_dep],
)
