doxyfile_conf = configuration_data()
doxyfile_conf.set('PACKAGE_NAME', meson.project_name())
doxyfile_conf.set('PACKAGE_VERSION', meson.project_version())
doxyfile_conf.set('top_srcdir', meson.source_root())
doxyfile_conf.set('top_builddir', meson.build_root())

if find_program('dot', required: false).found()
  doxyfile_conf.set('HAVE_DOT', 'YES')
else
  doxyfile_conf.set('HAVE_DOT', 'NO')
endif

inputs = ''
foreach h : pipewire_headers
  inputs += ' ' + meson.source_root() / 'src' / 'pipewire' / h
endforeach
foreach h : pipewire_sources
  inputs += ' ' + meson.source_root() / 'src' / 'pipewire' / h
endforeach

doxyfile_conf.set('inputs', inputs)

doxyfile = configure_file(input: 'Doxyfile.in',
                          output: 'Doxyfile',
                          configuration: doxyfile_conf)

docdir = get_option('docdir')
if docdir == ''
  docdir = pipewire_datadir / 'doc' / meson.project_name()
endif

html_target = custom_target('pipewire-docs',
                            input: [ doxyfile ],
                            output: [ 'html' ],
                            command: [ doxygen, doxyfile ],
                            install: true,
                            install_dir: docdir)
