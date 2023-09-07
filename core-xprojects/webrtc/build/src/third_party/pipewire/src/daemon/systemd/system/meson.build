systemd_system_services_dir = systemd.get_pkgconfig_variable('systemdsystemunitdir', define_variable : [ 'prefix', prefix])

install_data(sources : 'pipewire.socket',
             install_dir : systemd_system_services_dir)

systemd_config = configuration_data()
systemd_config.set('PW_BINARY', pipewire_bindir / 'pipewire')
systemd_config.set('PW_MEDIA_SESSION_BINARY', pipewire_bindir / 'pipewire-media-session')

configure_file(input : 'pipewire.service.in',
               output : 'pipewire.service',
               configuration : systemd_config,
               install_dir : systemd_system_services_dir)

if not get_option('media-session').disabled()
  configure_file(input : 'pipewire-media-session.service.in',
               output : 'pipewire-media-session.service',
               configuration : systemd_config,
               install_dir : systemd_system_services_dir)
endif
