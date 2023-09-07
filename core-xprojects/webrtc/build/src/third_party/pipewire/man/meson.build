manpage_conf = configuration_data()
manpage_conf.set('PACKAGE_NAME', meson.project_name())
manpage_conf.set('PACKAGE_VERSION', meson.project_version())
manpage_conf.set('PACKAGE_URL', 'http://pipewire.org')
manpage_conf.set('PACKAGE_BUGREPORT', 'https://gitlab.freedesktop.org/pipewire/pipewire/issues')
manpage_conf.set('PIPEWIRE_CONFIG_DIR', pipewire_configdir)
manpage_conf.set('top_srcdir', meson.source_root())
manpage_conf.set('top_builddir', meson.build_root())

manpages = [
  'pipewire.1.xml.in',
  'pipewire.conf.5.xml.in',
  'pw-cat.1.xml.in',
  'pw-cli.1.xml.in',
  'pw-dot.1.xml.in',
  'pw-metadata.1.xml.in',
  'pw-mididump.1.xml.in',
  'pw-mon.1.xml.in',
  'pw-profiler.1.xml.in',
]

if not get_option('pipewire-jack').disabled()
  manpages += 'pw-jack.1.xml.in'
endif

foreach m : manpages
  file = m.split('.xml.in').get(0)
  xml = configure_file(input : m,
		       output : file + '.xml',
		       configuration : manpage_conf)
  section = file.split('.').get(-1)
  custom_target(file + '.target',
		output : file,
		input : xml,
		command : [xmltoman, '@INPUT@'],
		capture : true,
		install : true,
		install_dir : get_option('mandir') / 'man' + section)
endforeach
