spa_support_sources = ['cpu.c',
		       'logger.c',
		       'loop.c',
		       'node-driver.c',
		       'null-audio-sink.c',
		       'plugin.c',
		       'system.c']

spa_support_lib = shared_library('spa-support',
			spa_support_sources,
			c_args : [ '-D_GNU_SOURCE' ],
			include_directories : [ spa_inc ],
			dependencies : [ pthread_lib, epoll_shim_dep ],
			install : true,
		        install_dir : spa_plugindir / 'support')


if not get_option('evl').disabled()
  evl_inc = include_directories('/usr/evl/include')
  evl_lib = cc.find_library('evl',
		dirs: ['/usr/evl/lib/'], required: get_option('evl'))

  spa_evl_sources = ['evl-system.c',
		   'evl-plugin.c']

  spa_evl_lib = shared_library('spa-evl',
			spa_evl_sources,
			c_args : [ '-D_GNU_SOURCE' ],
			include_directories : [ spa_inc, evl_inc],
			dependencies : [ pthread_lib, evl_lib],
			install : true,
		        install_dir : spa_plugindir / 'support')
endif

spa_dbus_sources = ['dbus.c']

spa_dbus_lib = shared_library('spa-dbus',
			spa_dbus_sources,
			include_directories : [ spa_inc],
			dependencies : [dbus_dep, ],
			install : true,
		        install_dir : spa_plugindir / 'support')


if systemd_dep.found()
  spa_journal_sources = ['journal.c']

  spa_journal_lib = shared_library('spa-journal',
			  spa_journal_sources,
			  include_directories : spa_inc,
			  dependencies : systemd_dep,
			  install : true,
		          install_dir : spa_plugindir / 'support')
endif
