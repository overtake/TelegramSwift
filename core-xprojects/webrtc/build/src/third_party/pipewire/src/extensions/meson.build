pipewire_ext_sm_headers = [
  'session-manager/impl-interfaces.h',
  'session-manager/interfaces.h',
  'session-manager/introspect.h',
  'session-manager/introspect-funcs.h',
  'session-manager/keys.h',
]

pipewire_ext_headers = [
  'client-node.h',
  'metadata.h',
  'profiler.h',
  'protocol-native.h',
  'session-manager.h',
]

install_headers(pipewire_ext_sm_headers,
  subdir : pipewire_headers_dir / 'extensions' / 'session-manager')

install_headers(pipewire_ext_headers,
  subdir : pipewire_headers_dir / 'extensions')
