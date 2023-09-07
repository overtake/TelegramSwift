test_apps = [
	'test-array',
	'test-client',
	'test-context',
	'test-endpoint',
	'test-interfaces',
	'test-properties',
	#	'test-remote',
	'test-stream',
	'test-utils'
]

foreach a : test_apps
  test('pw-' + a,
	executable('pw-' + a, a + '.c',
		dependencies : [pipewire_dep],
		c_args : [ '-D_GNU_SOURCE' ],
		install : installed_tests_enabled,
		install_dir : installed_tests_execdir),
	env : [
		'SPA_PLUGIN_DIR=@0@/spa/plugins/'.format(meson.build_root()),
		'PIPEWIRE_CONFIG_DIR=@0@/src/daemon/'.format(meson.build_root()),
		'PIPEWIRE_MODULE_DIR=@0@/src/modules/'.format(meson.build_root())
	])

  if installed_tests_enabled
    test_conf = configuration_data()
    test_conf.set('exec', installed_tests_execdir / 'pw-' + a)
    configure_file(
      input: installed_tests_template,
      output: 'pw-' + a + '.test',
      install_dir: installed_tests_metadir,
      configuration: test_conf
    )
  endif
endforeach


if have_cpp
test_cpp = executable('pw-test-cpp', 'test-cpp.cpp',
                        dependencies : [pipewire_dep],
                        install : installed_tests_enabled,
                        install_dir : installed_tests_execdir)
test('pw-test-cpp', test_cpp)

if installed_tests_enabled
  test_conf = configuration_data()
  test_conf.set('exec', installed_tests_execdir / 'pw-test-cpp')
  configure_file(
    input: installed_tests_template,
    output: 'pw-test-cpp.test',
    install_dir: installed_tests_metadir,
    configuration: test_conf
  )
endif
endif
