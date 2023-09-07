/* PipeWire
 *
 * Copyright © 2018 Wim Taymans
 *
 * Permission is hereby granted, free of charge, to any person obtaining a
 * copy of this software and associated documentation files (the "Software"),
 * to deal in the Software without restriction, including without limitation
 * the rights to use, copy, modify, merge, publish, distribute, sublicense,
 * and/or sell copies of the Software, and to permit persons to whom the
 * Software is furnished to do so, subject to the following conditions:
 *
 * The above copyright notice and this permission notice (including the next
 * paragraph) shall be included in all copies or substantial portions of the
 * Software.
 *
 * THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
 * IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
 * FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT.  IN NO EVENT SHALL
 * THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
 * LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING
 * FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER
 * DEALINGS IN THE SOFTWARE.
 */

#include <spa/support/log-impl.h>

#include <spa/pod/pod.h>
#include <spa/debug/types.h>
#include <spa/pod/iter.h>

#include <pipewire/log.h>
#include <pipewire/private.h>

SPA_LOG_IMPL(default_log);

#define DEFAULT_LOG_LEVEL SPA_LOG_LEVEL_WARN

SPA_EXPORT
enum spa_log_level pw_log_level = DEFAULT_LOG_LEVEL;

static struct spa_log *global_log = &default_log.log;

/** Set the global log interface
 * \param log the global log to set
 * \memberof pw_log
 */
SPA_EXPORT
void pw_log_set(struct spa_log *log)
{
	global_log = log ? log : &default_log.log;
	global_log->level = pw_log_level;
}

bool pw_log_is_default(void)
{
	return global_log == &default_log.log;
}

/** Get the global log interface
 * \return the global log
 * \memberof pw_log
 */
SPA_EXPORT
struct spa_log *pw_log_get(void)
{
	return global_log;
}

/** Set the global log level
 * \param level the new log level
 * \memberof pw_log
 */
SPA_EXPORT
void pw_log_set_level(enum spa_log_level level)
{
	pw_log_level = level;
	global_log->level = level;
}

/** Log a message
 * \param level the log level
 * \param file the file this message originated from
 * \param line the line number
 * \param func the function
 * \param fmt the printf style format
 * \param ... printf style arguments to log
 *
 * \memberof pw_log
 */
SPA_EXPORT
void
pw_log_log(enum spa_log_level level,
	   const char *file,
	   int line,
	   const char *func,
	   const char *fmt, ...)
{
	if (SPA_UNLIKELY(pw_log_level_enabled(level))) {
		va_list args;
		va_start(args, fmt);
		spa_interface_call(&global_log->iface,
			struct spa_log_methods, logv, 0, level, file, line,
			func, fmt, args);
		va_end(args);
	}
}

/** Log a message with va_list
 * \param level the log level
 * \param file the file this message originated from
 * \param line the line number
 * \param func the function
 * \param fmt the printf style format
 * \param args a va_list of arguments
 *
 * \memberof pw_log
 */
SPA_EXPORT
void
pw_log_logv(enum spa_log_level level,
	    const char *file,
	    int line,
	    const char *func,
	    const char *fmt,
	    va_list args)
{
	if (SPA_UNLIKELY(pw_log_level_enabled(level))) {
		spa_interface_call(&global_log->iface,
			struct spa_log_methods, logv, 0, level, file, line,
			func, fmt, args);
	}
}

/** \fn void pw_log_error (const char *format, ...)
 * Log an error message
 * \param format a printf style format
 * \param ... printf style arguments
 * \memberof pw_log
 */
/** \fn void pw_log_warn (const char *format, ...)
 * Log a warning message
 * \param format a printf style format
 * \param ... printf style arguments
 * \memberof pw_log
 */
/** \fn void pw_log_info (const char *format, ...)
 * Log an info message
 * \param format a printf style format
 * \param ... printf style arguments
 * \memberof pw_log
 */
/** \fn void pw_log_debug (const char *format, ...)
 * Log a debug message
 * \param format a printf style format
 * \param ... printf style arguments
 * \memberof pw_log
 */
/** \fn void pw_log_trace (const char *format, ...)
 * Log a trace message. Trace messages may be generated from
 * \param format a printf style format
 * \param ... printf style arguments
 * realtime threads
 * \memberof pw_log
 */

struct log_ctx {
	enum spa_log_level level;
	const char *file;
	int line;
	const char *func;
};

#define _log(_c,fmt,...) pw_log_log(_c->level, _c->file, _c->line, _c->func,   \
		"%*s" fmt, indent, "", ## __VA_ARGS__)

static inline int
log_pod_value(struct log_ctx *ctx, int indent, const struct spa_type_info *info,
		uint32_t type, void *body, uint32_t size)
{
	switch (type) {
	case SPA_TYPE_Bool:
		_log(ctx, "Bool %s", (*(int32_t *) body) ? "true" : "false");
		break;
	case SPA_TYPE_Id:
		_log(ctx, "Id %-8d (%s)", *(int32_t *) body,
		       spa_debug_type_find_name(info, *(int32_t *) body));
		break;
	case SPA_TYPE_Int:
		_log(ctx, "Int %d", *(int32_t *) body);
		break;
	case SPA_TYPE_Long:
		_log(ctx, "Long %" PRIi64 "", *(int64_t *) body);
		break;
	case SPA_TYPE_Float:
		_log(ctx, "Float %f", *(float *) body);
		break;
	case SPA_TYPE_Double:
		_log(ctx, "Double %f", *(double *) body);
		break;
	case SPA_TYPE_String:
		_log(ctx, "String \"%s\"", (char *) body);
		break;
	case SPA_TYPE_Fd:
		_log(ctx, "Fd %d", *(int *) body);
		break;
	case SPA_TYPE_Pointer:
	{
		struct spa_pod_pointer_body *b = (struct spa_pod_pointer_body *)body;
		_log(ctx, "Pointer %s %p",
		       spa_debug_type_find_name(SPA_TYPE_ROOT, b->type), b->value);
		break;
	}
	case SPA_TYPE_Rectangle:
	{
		struct spa_rectangle *r = (struct spa_rectangle *)body;
		_log(ctx, "Rectangle %dx%d", r->width, r->height);
		break;
	}
	case SPA_TYPE_Fraction:
	{
		struct spa_fraction *f = (struct spa_fraction *)body;
		_log(ctx, "Fraction %d/%d", f->num, f->denom);
		break;
	}
	case SPA_TYPE_Bitmap:
		_log(ctx, "Bitmap");
		break;
	case SPA_TYPE_Array:
	{
		struct spa_pod_array_body *b = (struct spa_pod_array_body *)body;
		void *p;
		const struct spa_type_info *ti = spa_debug_type_find(SPA_TYPE_ROOT, b->child.type);

		_log(ctx, "Array: child.size %d, child.type %s", b->child.size,
				ti ? ti->name : "unknown");

		SPA_POD_ARRAY_BODY_FOREACH(b, size, p)
			log_pod_value(ctx, indent + 2, info, b->child.type, p, b->child.size);
		break;
	}
	case SPA_TYPE_Choice:
	{
		struct spa_pod_choice_body *b = (struct spa_pod_choice_body *)body;
		void *p;
		const struct spa_type_info *ti = spa_debug_type_find(spa_type_choice, b->type);

		_log(ctx, "Choice: type %s, flags %08x %d %d",
		       ti ? ti->name : "unknown", b->flags, size, b->child.size);

		SPA_POD_CHOICE_BODY_FOREACH(b, size, p)
			log_pod_value(ctx, indent + 2, info, b->child.type, p, b->child.size);
		break;
	}
	case SPA_TYPE_Struct:
	{
		struct spa_pod *b = (struct spa_pod *)body, *p;
		_log(ctx, "Struct: size %d", size);
		SPA_POD_FOREACH(b, size, p)
			log_pod_value(ctx, indent + 2, info, p->type, SPA_POD_BODY(p), p->size);
		break;
	}
	case SPA_TYPE_Object:
	{
		struct spa_pod_object_body *b = (struct spa_pod_object_body *)body;
		struct spa_pod_prop *p;
		const struct spa_type_info *ti, *ii;

		ti = spa_debug_type_find(info, b->type);
		ii = ti ? spa_debug_type_find(ti->values, 0) : NULL;
		ii = ii ? spa_debug_type_find(ii->values, b->id) : NULL;

		_log(ctx, "Object: size %d, type %s (%d), id %s (%d)", size,
		       ti ? ti->name : "unknown", b->type, ii ? ii->name : "unknown", b->id);

		info = ti ? ti->values : info;

		indent += 2;
		SPA_POD_OBJECT_BODY_FOREACH(b, size, p) {
			ii = spa_debug_type_find(info, p->key);

			_log(ctx, "Prop: key %s (%d), flags %08x",
					ii ? ii->name : "unknown", p->key, p->flags);

			log_pod_value(ctx, indent + 2, ii ? ii->values : NULL,
					p->value.type,
					SPA_POD_CONTENTS(struct spa_pod_prop, p),
					p->value.size);
		}
		indent -= 2;
		break;
	}
	case SPA_TYPE_Sequence:
	{
		struct spa_pod_sequence_body *b = (struct spa_pod_sequence_body *)body;
		const struct spa_type_info *ti, *ii;
		struct spa_pod_control *c;

		ti = spa_debug_type_find(info, b->unit);

		_log(ctx, "%*s" "Sequence: size %d, unit %s", indent, "", size,
		       ti ? ti->name : "unknown");

		indent +=2;
		SPA_POD_SEQUENCE_BODY_FOREACH(b, size, c) {
			ii = spa_debug_type_find(spa_type_control, c->type);

			_log(ctx, "Control: offset %d, type %s",
					c->offset, ii ? ii->name : "unknown");

			log_pod_value(ctx, indent + 2, ii ? ii->values : NULL,
					c->value.type,
					SPA_POD_CONTENTS(struct spa_pod_control, c),
					c->value.size);
		}
		indent -=2;
		break;
	}
	case SPA_TYPE_Bytes:
		_log(ctx, "Bytes");
		break;
	case SPA_TYPE_None:
		_log(ctx, "None");
		break;
	default:
		_log(ctx, "unhandled POD type %d", type);
		break;
	}
	return 0;
}

void pw_log_log_object(enum spa_log_level level,
	   const char *file,
	   int line,
	   const char *func,
	   uint32_t flags, const void *object)
{
	struct log_ctx ctx = { level, file, 0, func, };
	if (flags & PW_LOG_OBJECT_POD) {
		const struct spa_pod *pod = object;
		if (pod == NULL) {
			pw_log_log(level, file, line, func, "NULL");
		} else {
			log_pod_value(&ctx, 0, SPA_TYPE_ROOT,
				SPA_POD_TYPE(pod),
				SPA_POD_BODY(pod),
				SPA_POD_BODY_SIZE(pod));
		}
	}
}
