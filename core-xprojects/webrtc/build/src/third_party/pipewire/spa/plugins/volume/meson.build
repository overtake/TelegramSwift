volume_sources = ['volume.c', 'plugin.c']

volumelib = shared_library('spa-volume',
                           volume_sources,
                           include_directories : [spa_inc],
                           install : true,
		           install_dir : spa_plugindir / 'volume')
