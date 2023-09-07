
subdir('pipewire')
subdir('extensions')
subdir('daemon')
subdir('tools')
subdir('modules')
if not get_option('examples').disabled()
  subdir('examples')
endif
if not get_option('tests').disabled()
  subdir('tests')
endif

if gst_dep.length() != 0
  subdir('gst')
endif
