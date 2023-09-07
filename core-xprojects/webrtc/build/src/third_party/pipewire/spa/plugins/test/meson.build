test_sources = ['fakesrc.c', 'fakesink.c', 'plugin.c']

testlib = shared_library('spa-test',
                          test_sources,
                          include_directories : [ spa_inc],
                          dependencies : [pthread_lib, ],
                          install : true,
		          install_dir : spa_plugindir / 'test')
