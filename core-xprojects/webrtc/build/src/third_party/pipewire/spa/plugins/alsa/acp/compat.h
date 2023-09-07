/***
  This file is part of PulseAudio.

  Copyright 2004-2006 Lennart Poettering
  Copyright 2006 Pierre Ossman <ossman@cendio.se> for Cendio AB

  PulseAudio is free software; you can redistribute it and/or modify
  it under the terms of the GNU Lesser General Public License as published
  by the Free Software Foundation; either version 2.1 of the License,
  or (at your option) any later version.

  PulseAudio is distributed in the hope that it will be useful, but
  WITHOUT ANY WARRANTY; without even the implied warranty of
  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the GNU
  General Public License for more details.

  You should have received a copy of the GNU Lesser General Public License
  along with PulseAudio; if not, see <http://www.gnu.org/licenses/>.
***/


#ifndef PULSE_COMPAT_H
#define PULSE_COMPAT_H

#ifdef __cplusplus
extern "C" {
#else
#include <stdbool.h>
#endif

#include <stdio.h>
#include <stdarg.h>
#include <stdint.h>
#include <inttypes.h>
#include <stdlib.h>
#include <unistd.h>

typedef struct pa_core pa_core;

typedef void *(*pa_copy_func_t)(const void *p);
typedef void (*pa_free_cb_t)(void *p);

#ifdef __GNUC__
#define PA_LIKELY(x) (__builtin_expect(!!(x),1))
#define PA_UNLIKELY(x) (__builtin_expect(!!(x),0))
#define PA_PRINTF_FUNC(fmt, arg1) __attribute__((format(printf, fmt, arg1)))
#else
#define PA_LIKELY(x) (x)
#define PA_UNLIKELY(x) (x)
#define PA_PRINTF_FUNC(fmt, arg1)
#endif

#define PA_MIN(a,b)                    \
({                                     \
        __typeof__(a) _a = (a);        \
        __typeof__(b) _b = (b);        \
        PA_LIKELY(_a < _b) ? _a : _b;  \
})
#define PA_MAX(a,b)                    \
({                                     \
        __typeof__(a) _a = (a);        \
        __typeof__(b) _b = (b);        \
        PA_LIKELY(_a > _b) ? _a : _b;  \
})
#define PA_CLAMP_UNLIKELY(v,low,high)                 \
({                                                    \
        __typeof__(v) _v = (v);                       \
        __typeof__(low) _low = (low);                 \
        __typeof__(high) _high = (high);              \
        PA_MIN(PA_MAX(_v, _low), _high);              \
})

#define PA_PTR_TO_UINT(p) ((unsigned int) ((uintptr_t) (p)))
#define PA_UINT_TO_PTR(u) ((void*) ((uintptr_t) (u)))

#include "array.h"
#include "llist.h"
#include "hashmap.h"
#include "dynarray.h"
#include "idxset.h"
#include "proplist.h"

typedef enum pa_direction {
	PA_DIRECTION_OUTPUT = 0x0001U,  /**< Output direction */
	PA_DIRECTION_INPUT = 0x0002U    /**< Input direction */
} pa_direction_t;

/* This enum replaces pa_port_available_t (defined in pulse/def.h) for
 * internal use, so make sure both enum types stay in sync. */
typedef enum pa_available {
	PA_AVAILABLE_UNKNOWN = 0,
	PA_AVAILABLE_NO = 1,
	PA_AVAILABLE_YES = 2,
} pa_available_t;

#define PA_RATE_MAX (48000U*8U)

typedef enum pa_sample_format {
	PA_SAMPLE_U8,		/**< Unsigned 8 Bit PCM */
	PA_SAMPLE_ALAW,		/**< 8 Bit a-Law */
	PA_SAMPLE_ULAW,		/**< 8 Bit mu-Law */
	PA_SAMPLE_S16LE,	/**< Signed 16 Bit PCM, little endian (PC) */
	PA_SAMPLE_S16BE,	/**< Signed 16 Bit PCM, big endian */
	PA_SAMPLE_FLOAT32LE,	/**< 32 Bit IEEE floating point, little endian (PC), range -1.0 to 1.0 */
	PA_SAMPLE_FLOAT32BE,	/**< 32 Bit IEEE floating point, big endian, range -1.0 to 1.0 */
	PA_SAMPLE_S32LE,	/**< Signed 32 Bit PCM, little endian (PC) */
	PA_SAMPLE_S32BE,	/**< Signed 32 Bit PCM, big endian */
	PA_SAMPLE_S24LE,	/**< Signed 24 Bit PCM packed, little endian (PC). \since 0.9.15 */
	PA_SAMPLE_S24BE,	/**< Signed 24 Bit PCM packed, big endian. \since 0.9.15 */
	PA_SAMPLE_S24_32LE,	/**< Signed 24 Bit PCM in LSB of 32 Bit words, little endian (PC). \since 0.9.15 */
	PA_SAMPLE_S24_32BE,	/**< Signed 24 Bit PCM in LSB of 32 Bit words, big endian. \since 0.9.15 */
	PA_SAMPLE_MAX,		/**< Upper limit of valid sample types */
	PA_SAMPLE_INVALID = -1	/**< An invalid value */
} pa_sample_format_t;

static inline int pa_sample_format_valid(unsigned format)
{
	return format < PA_SAMPLE_MAX;
}

#ifdef WORDS_BIGENDIAN
#define PA_SAMPLE_S16NE PA_SAMPLE_S16BE
#define PA_SAMPLE_FLOAT32NE PA_SAMPLE_FLOAT32BE
#define PA_SAMPLE_S32NE PA_SAMPLE_S32BE
#define PA_SAMPLE_S24NE PA_SAMPLE_S24BE
#define PA_SAMPLE_S24_32NE PA_SAMPLE_S24_32BE
#define PA_SAMPLE_S16RE PA_SAMPLE_S16LE
#define PA_SAMPLE_FLOAT32RE PA_SAMPLE_FLOAT32LE
#define PA_SAMPLE_S32RE PA_SAMPLE_S32LE
#define PA_SAMPLE_S24RE PA_SAMPLE_S24LE
#define PA_SAMPLE_S24_32RE PA_SAMPLE_S24_32LE
#else
#define PA_SAMPLE_S16NE PA_SAMPLE_S16LE
#define PA_SAMPLE_FLOAT32NE PA_SAMPLE_FLOAT32LE
#define PA_SAMPLE_S32NE PA_SAMPLE_S32LE
#define PA_SAMPLE_S24NE PA_SAMPLE_S24LE
#define PA_SAMPLE_S24_32NE PA_SAMPLE_S24_32LE
#define PA_SAMPLE_S16RE PA_SAMPLE_S16BE
#define PA_SAMPLE_FLOAT32RE PA_SAMPLE_FLOAT32BE
#define PA_SAMPLE_S32RE PA_SAMPLE_S32BE
#define PA_SAMPLE_S24RE PA_SAMPLE_S24BE
#define PA_SAMPLE_S24_32RE PA_SAMPLE_S24_32BE
#endif

static const size_t pa_sample_size_table[] = {
    [PA_SAMPLE_U8] = 1,
    [PA_SAMPLE_ULAW] = 1,
    [PA_SAMPLE_ALAW] = 1,
    [PA_SAMPLE_S16LE] = 2,
    [PA_SAMPLE_S16BE] = 2,
    [PA_SAMPLE_FLOAT32LE] = 4,
    [PA_SAMPLE_FLOAT32BE] = 4,
    [PA_SAMPLE_S32LE] = 4,
    [PA_SAMPLE_S32BE] = 4,
    [PA_SAMPLE_S24LE] = 3,
    [PA_SAMPLE_S24BE] = 3,
    [PA_SAMPLE_S24_32LE] = 4,
    [PA_SAMPLE_S24_32BE] = 4
};

static inline const char *pa_sample_format_to_string(pa_sample_format_t f)
{
	static const char* const table[]= {
		[PA_SAMPLE_U8] = "u8",
		[PA_SAMPLE_ALAW] = "aLaw",
		[PA_SAMPLE_ULAW] = "uLaw",
		[PA_SAMPLE_S16LE] = "s16le",
		[PA_SAMPLE_S16BE] = "s16be",
		[PA_SAMPLE_FLOAT32LE] = "float32le",
		[PA_SAMPLE_FLOAT32BE] = "float32be",
		[PA_SAMPLE_S32LE] = "s32le",
		[PA_SAMPLE_S32BE] = "s32be",
		[PA_SAMPLE_S24LE] = "s24le",
		[PA_SAMPLE_S24BE] = "s24be",
		[PA_SAMPLE_S24_32LE] = "s24-32le",
		[PA_SAMPLE_S24_32BE] = "s24-32be",
	};

	if (!pa_sample_format_valid(f))
	        return NULL;
	return table[f];
}

typedef struct pa_sample_spec {
	pa_sample_format_t format;
	uint32_t rate;
	uint8_t channels;
} pa_sample_spec;

typedef uint64_t pa_usec_t;
#define PA_MSEC_PER_SEC ((pa_usec_t) 1000ULL)
#define PA_USEC_PER_SEC ((pa_usec_t) 1000000ULL)
#define PA_USEC_PER_MSEC ((pa_usec_t) 1000ULL)

static inline size_t pa_usec_to_bytes(pa_usec_t t, const pa_sample_spec *spec) {
    return (size_t) (((t * spec->rate) / PA_USEC_PER_SEC)) *
	    (pa_sample_size_table[spec->format] * spec->channels);
}

static inline int pa_sample_rate_valid(uint32_t rate) {
    return rate > 0 && rate <= PA_RATE_MAX * 101 / 100;
}

static inline size_t pa_frame_size(const pa_sample_spec *spec) {
    return pa_sample_size_table[spec->format] * spec->channels;
}

typedef enum pa_log_level {
	PA_LOG_ERROR  = 0,    /* Error messages */
	PA_LOG_WARN   = 1,    /* Warning messages */
	PA_LOG_NOTICE = 2,    /* Notice messages */
	PA_LOG_INFO   = 3,    /* Info messages */
	PA_LOG_DEBUG  = 4,    /* Debug messages */
	PA_LOG_LEVEL_MAX
} pa_log_level_t;

extern int _acp_log_level;
extern acp_log_func _acp_log_func;
extern void * _acp_log_data;

#define pa_log_level_enabled(lev) (_acp_log_level >= (int)(lev))

#define pa_log_levelv_meta(lev,f,l,func,fmt,ap)                         \
({                                                                      \
        if (pa_log_level_enabled (lev) && _acp_log_func)                \
                _acp_log_func(_acp_log_data,lev,f,l,func,fmt,ap);			\
})

static inline PA_PRINTF_FUNC(5, 6) void pa_log_level_meta(enum pa_log_level level,
           const char *file, int line, const char *func,
           const char *fmt, ...)
{
	va_list args;
	va_start(args,fmt);
	pa_log_levelv_meta(level,file,line,func,fmt,args);
	va_end(args);
}

#define pa_logl(lev,fmt,...)	pa_log_level_meta(lev,__FILE__, __LINE__, __func__, fmt, ##__VA_ARGS__)
#define pa_log_error(fmt,...)	pa_logl(PA_LOG_ERROR, fmt, ##__VA_ARGS__)
#define pa_log_warn(fmt,...)	pa_logl(PA_LOG_WARN, fmt, ##__VA_ARGS__)
#define pa_log_notice(fmt,...)	pa_logl(PA_LOG_NOTICE, fmt, ##__VA_ARGS__)
#define pa_log_info(fmt,...)	pa_logl(PA_LOG_INFO, fmt, ##__VA_ARGS__)
#define pa_log_debug(fmt,...)	pa_logl(PA_LOG_DEBUG, fmt, ##__VA_ARGS__)
#define pa_log			pa_log_error

#define pa_assert_se(expr)                                              \
        do {                                                            \
                if (PA_UNLIKELY(!(expr))) {                             \
                        fprintf(stderr, "'%s' failed at %s:%u %s()\n",  \
                                #expr , __FILE__, __LINE__, __func__);  \
                        abort();                                        \
                }                                                       \
        } while (false)

#define pa_assert(expr)                                                 \
        do {                                                            \
                if (PA_UNLIKELY(!(expr))) {                             \
                        fprintf(stderr, "'%s' failed at %s:%u %s()\n",  \
                                #expr , __FILE__, __LINE__, __func__);  \
                        abort();                                        \
                }                                                       \
        } while (false)

#define pa_assert_not_reached()                                                \
        do {                                                                    \
                fprintf(stderr, "Code should not be reached at %s:%u %s()\n",   \
                                __FILE__, __LINE__, __func__);                  \
                abort();                                                        \
        } while (false)


#define pa_memzero(x,l) (memset((x), 0, (l)))
#define pa_zero(x)      (pa_memzero(&(x), sizeof(x)))

#define PA_ELEMENTSOF(x) (sizeof(x)/sizeof((x)[0]))

#define pa_streq(a,b) (!strcmp((a),(b)))
#define pa_strneq(a,b,n) (!strncmp((a),(b),(n)))
#define pa_strnull(s)	((s) ? (s) : "null")
#define pa_startswith(s,pfx)	(strstr(s, pfx) == s)

#define pa_snprintf	snprintf

#define pa_xstrdup(s)		((s) != NULL ? strdup(s) : NULL)
#define pa_xstrndup(s,n)	((s) != NULL ? strndup(s,n) : NULL)
#define pa_xfree		free
#define pa_xmalloc		malloc
#define pa_xnew0(t,n)		calloc(n, sizeof(t))
#define pa_xnew(t,n)		pa_xnew0(t,n)
#define pa_xrealloc		realloc
#define pa_xrenew(t,p,n)	((t*) realloc(p, (n)*sizeof(t)))

static inline void* pa_xmemdup(const void *p, size_t l) {
	return memcpy(malloc(l), p, l);

}
#define pa_xnewdup(t,p,n) ((t*) pa_xmemdup((p), (n)*sizeof(t)))

static inline void pa_xfreev(void**a)
{
	int i;
	for (i = 0; a && a[i]; i++)
                free(a[i]);
        free(a);
}
static inline void pa_xstrfreev(char **a) {
    pa_xfreev((void**)a);
}


#define pa_cstrerror	strerror

#define PA_PATH_SEP		"/"
#define PA_PATH_SEP_CHAR	'/'

#define PA_WHITESPACE "\n\r \t"

static PA_PRINTF_FUNC(1,2) inline char *pa_sprintf_malloc(const char *fmt, ...)
{
	char *res;
	va_list args;
	va_start(args, fmt);
	if (vasprintf(&res, fmt, args) < 0)
		res = NULL;
	va_end(args);
	return res;
}

#define pa_fopen_cloexec(f,m)	fopen(f,m"e")

static inline char *pa_path_get_filename(const char *p)
{
    char *fn;
    if (!p)
        return NULL;
    if ((fn = strrchr(p, PA_PATH_SEP_CHAR)))
        return fn+1;
    return (char*) p;
}

static inline bool pa_is_path_absolute(const char *fn)
{
    return *fn == PA_PATH_SEP_CHAR;
}

static inline char* pa_maybe_prefix_path(const char *path, const char *prefix)
{
    if (pa_is_path_absolute(path))
        return pa_xstrdup(path);
    return pa_sprintf_malloc("%s" PA_PATH_SEP "%s", prefix, path);
}

static inline bool pa_endswith(const char *s, const char *sfx)
{
	size_t l1, l2;
	l1 = strlen(s);
	l2 = strlen(sfx);
	return l1 >= l2 && pa_streq(s + l1 - l2, sfx);
}

static inline char *pa_replace(const char*s, const char*a, const char *b)
{
	struct pa_array res;
	size_t an, bn;

	an = strlen(a);
	bn = strlen(b);
	pa_array_init(&res, an);

	for (;;) {
		const char *p;

		if (!(p = strstr(s, a)))
			break;

		pa_array_add_data(&res, s, p-s);
		pa_array_add_data(&res, b, bn);
		s = p + an;
	}
	pa_array_add_data(&res, s, strlen(s) + 1);
	return res.data;
}

static inline char *pa_split(const char *c, const char *delimiter, const char**state)
{
    const char *current = *state ? *state : c;
    size_t l;
    if (!*current)
        return NULL;
    l = strcspn(current, delimiter);
    *state = current+l;
    if (**state)
        (*state)++;
    return pa_xstrndup(current, l);
}

static inline char *pa_split_spaces(const char *c, const char **state)
{
    const char *current = *state ? *state : c;
    size_t l;
    if (!*current || *c == 0)
        return NULL;
    current += strspn(current, PA_WHITESPACE);
    l = strcspn(current, PA_WHITESPACE);
    *state = current+l;
    return pa_xstrndup(current, l);
}

static inline char **pa_split_spaces_strv(const char *s)
{
    char **t, *e;
    unsigned i = 0, n = 8;
    const char *state = NULL;

    t = pa_xnew(char*, n);
    while ((e = pa_split_spaces(s, &state))) {
        t[i++] = e;
        if (i >= n) {
            n *= 2;
            t = pa_xrenew(char*, t, n);
        }
    }
    if (i <= 0) {
        pa_xfree(t);
        return NULL;
    }
    t[i] = NULL;
    return t;
}

static inline char* pa_str_strip_suffix(const char *str, const char *suffix)
{
    size_t str_l, suf_l, prefix;
    char *ret;

    str_l = strlen(str);
    suf_l = strlen(suffix);

    if (str_l < suf_l)
        return NULL;
    prefix = str_l - suf_l;
    if (!pa_streq(&str[prefix], suffix))
        return NULL;
    ret = pa_xmalloc(prefix + 1);
    memcpy(ret, str, prefix);
    ret[prefix] = '\0';
    return ret;
}

static inline const char *pa_split_in_place(const char *c, const char *delimiter, size_t *n, const char**state)
{
    const char *current = *state ? *state : c;
    size_t l;
    if (!*current)
        return NULL;
    l = strcspn(current, delimiter);
    *state = current+l;
    if (**state)
        (*state)++;
    *n = l;
    return current;
}

static inline const char *pa_split_spaces_in_place(const char *c, size_t *n, const char **state)
{
    const char *current = *state ? *state : c;
    size_t l;
    if (!*current || *c == 0)
        return NULL;
    current += strspn(current, PA_WHITESPACE);
    l = strcspn(current, PA_WHITESPACE);
    *state = current+l;
    *n = l;
    return current;
}

static inline bool pa_str_in_list_spaces(const char *haystack, const char *needle)
{
    const char *s;
    size_t n;
    const char *state = NULL;

    if (!haystack || !needle)
        return false;

    while ((s = pa_split_spaces_in_place(haystack, &n, &state))) {
        if (pa_strneq(needle, s, n))
            return true;
    }

    return false;
}

static inline char *pa_strip(char *s)
{
    char *e, *l = NULL;
    s += strspn(s, PA_WHITESPACE);
    for (e = s; *e; e++)
        if (!strchr(PA_WHITESPACE, *e))
            l = e;
    if (l)
        *(l+1) = 0;
    else
        *s = 0;
    return s;
}

static inline int pa_atod(const char *s, double *ret_d)
{
	char *x;
	*ret_d = strtod(s, &x);
	return 0;
}
static inline int pa_atoi(const char *s, int32_t *ret_i)
{
	*ret_i = (int32_t) atoi(s);
	return 0;
}
static inline int pa_atou(const char *s, uint32_t *ret_u)
{
	*ret_u = (uint32_t) atoi(s);
	return 0;
}
static inline int pa_atol(const char *s, long *ret_l)
{
	char *x;
	*ret_l = strtol(s, &x, 0);
	return 0;
}

static inline int pa_parse_boolean(const char *v)
{
	if (pa_streq(v, "1") || !strcasecmp(v, "y") || !strcasecmp(v, "t")
	    || !strcasecmp(v, "yes") || !strcasecmp(v, "true") || !strcasecmp(v, "on"))
		return 1;
	else if (pa_streq(v, "0") || !strcasecmp(v, "n") || !strcasecmp(v, "f")
	    || !strcasecmp(v, "no") || !strcasecmp(v, "false") || !strcasecmp(v, "off"))
		return 0;
	errno = EINVAL;
	return -1;
}

static inline const char *pa_yes_no(bool b) {
    return b ? "yes" : "no";
}

static inline const char *pa_strna(const char *x) {
    return x ? x : "n/a";
}

static inline pa_sample_spec* pa_sample_spec_init(pa_sample_spec *spec)
{
    spec->format = PA_SAMPLE_INVALID;
    spec->rate = 0;
    spec->channels = 0;
    return spec;
}

static inline char *pa_readlink(const char *p) {
#ifdef HAVE_READLINK
    size_t l = 100;

    for (;;) {
        char *c;
        ssize_t n;

        c = pa_xmalloc(l);

        if ((n = readlink(p, c, l-1)) < 0) {
            pa_xfree(c);
            return NULL;
        }

        if ((size_t) n < l-1) {
            c[n] = 0;
            return c;
        }

        pa_xfree(c);
        l *= 2;
    }
#else
    return NULL;
#endif
}

#include <spa/support/i18n.h>

extern struct spa_i18n *acp_i18n;

#define _(String)  spa_i18n_text(acp_i18n, String)
#ifdef gettext_noop
#define N_(String) gettext_noop(String)
#else
#define N_(String) (String)
#endif

#include "channelmap.h"
#include "volume.h"

#ifdef __cplusplus
}
#endif

#endif /* PULSE_COMPAT_H */
