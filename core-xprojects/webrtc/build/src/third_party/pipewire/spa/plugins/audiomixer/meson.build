audiomixer_sources = [
	'audiomixer.c',
	'mix-ops.c',
	'mixer-dsp.c',
	'plugin.c']

simd_cargs = []
simd_dependencies = []

audiomixer_c = static_library('audiomixer_c',
	['mix-ops-c.c' ],
	c_args : ['-O3'],
	include_directories : [spa_inc],
	install : false
)
simd_dependencies += audiomixer_c

if have_sse
	audiomixer_sse = static_library('audiomixer_sse',
		['mix-ops-sse.c' ],
		c_args : [sse_args, '-O3', '-DHAVE_SSE'],
		include_directories : [spa_inc],
		install : false
	)
	simd_cargs += ['-DHAVE_SSE']
	simd_dependencies += audiomixer_sse
endif
if have_sse2
	audiomixer_sse2 = static_library('audiomixer_sse2',
		['mix-ops-sse2.c' ],
		c_args : [sse2_args, '-O3', '-DHAVE_SSE2'],
		include_directories : [spa_inc],
		install : false
	)
	simd_cargs += ['-DHAVE_SSE2']
	simd_dependencies += audiomixer_sse2
endif
if have_avx and have_fma
	audiomixer_avx = static_library('audiomixer_avx',
		['mix-ops-avx.c'],
		c_args : [avx_args, fma_args, '-O3', '-DHAVE_AVX', '-DHAVE_FMA'],
		include_directories : [spa_inc],
		install : false
	)
	simd_cargs += ['-DHAVE_AVX', '-DHAVE_FMA']
	simd_dependencies += audiomixer_avx
endif

audiomixerlib = shared_library('spa-audiomixer',
                          audiomixer_sources,
			  c_args : simd_cargs,
			  link_with : simd_dependencies,
                          include_directories : [spa_inc],
                          dependencies : [ mathlib ],
                          install : true,
                          install_dir : spa_plugindir / 'audiomixer')
