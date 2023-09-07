test_apps = [
	'test-buffer',
	'test-node',
	'test-pod',
	'test-utils',
	'test-json',
]

foreach a : test_apps
  test('spa-' + a,
	executable('spa-' + a, a + '.c',
		dependencies : [dl_lib, pthread_lib, mathlib ],
		include_directories : [spa_inc ],
		c_args : [ '-D_GNU_SOURCE' ],
		install : installed_tests_enabled,
		install_dir : installed_tests_execdir),
	env : [
		'SPA_PLUGIN_DIR=@0@/spa/plugins/'.format(meson.build_root()),
	])

  if installed_tests_enabled
    test_conf = configuration_data()
    test_conf.set('exec', installed_tests_execdir / 'spa-' + a)
    configure_file(
      input: installed_tests_template,
      output: 'spa-' + a + '.test',
      install_dir: installed_tests_metadir,
      configuration: test_conf
    )
  endif
endforeach

if have_cpp
test_cpp = executable('spa-test-cpp', 'test-cpp.cpp',
                        include_directories : [spa_inc ],
                        dependencies : [],
                        install : installed_tests_enabled,
                        install_dir : installed_tests_execdir)
test('spa-test-cpp', test_cpp)
if installed_tests_enabled
  test_conf = configuration_data()
  test_conf.set('exec', installed_tests_execdir / 'spa-test-cpp')
  configure_file(
    input: installed_tests_template,
    output: 'spa-test-cpp.test',
    install_dir: installed_tests_metadir,
    configuration: test_conf
  )
endif
endif

benchmark_apps = [
	'stress-ringbuffer',
	'benchmark-pod',
	'benchmark-dict',
]

foreach a : benchmark_apps
  benchmark('spa-' + a,
	executable('spa-' + a, a + '.c',
		dependencies : [dl_lib, pthread_lib, mathlib ],
		include_directories : [spa_inc ],
		c_args : [ '-D_GNU_SOURCE' ],
		install : installed_tests_enabled,
		install_dir : installed_tests_execdir),
	env : [
		'SPA_PLUGIN_DIR=@0@/spa/plugins/'.format(meson.build_root()),
	])

  if installed_tests_enabled
    test_conf = configuration_data()
    test_conf.set('exec', installed_tests_execdir / 'spa-' + a)
    configure_file(
      input: installed_tests_template,
      output: 'spa-' + a + '.test',
      install_dir: installed_tests_metadir,
      configuration: test_conf
    )
  endif
endforeach
