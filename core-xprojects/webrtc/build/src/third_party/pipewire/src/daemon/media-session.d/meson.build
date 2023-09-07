conf_files = [
  [ 'bluez-monitor.conf', 'bluez-monitor.conf' ],
  [ 'v4l2-monitor.conf', 'v4l2-monitor.conf' ],
  [ 'media-session.conf', 'media-session.conf' ],
  [ 'alsa-monitor.conf', 'alsa-monitor.conf' ],
  [ 'with-jack', 'with-jack' ],
  [ 'with-pulseaudio', 'with-pulseaudio' ],
]

foreach c : conf_files
  configure_file(input : c.get(0),
                 output : c.get(1),
                 configuration : conf_config,
                 install_dir : conf_install_dir / 'media-session.d')
endforeach

install_data(
  sources : [
    'with-jack',
    'with-pulseaudio' ],
  install_dir : conf_install_dir / 'media-session.d')
