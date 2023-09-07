acp_sources = [
  'acp.c',
  'compat.c',
  'alsa-mixer.c',
  'alsa-ucm.c',
  'alsa-util.c',
  'conf-parser.c',
]

acp_c_args = [
  '-D_GNU_SOURCE',
  '-DHAVE_ALSA_UCM',
  '-DHAVE_CONFIG_H',
  '-DHAVE_READLINK',
]

acp_lib = static_library(
  'acp',
  acp_sources,
  c_args : acp_c_args,
  include_directories : [configinc, spa_inc ],
  dependencies : [ alsa_dep, mathlib, ]
  )
