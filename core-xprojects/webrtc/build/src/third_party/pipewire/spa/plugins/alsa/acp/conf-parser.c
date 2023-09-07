/***
  This file is part of PulseAudio.

  Copyright 2004-2006 Lennart Poettering

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

#ifdef HAVE_CONFIG_H
#include <config.h>
#endif

#include <dirent.h>
#include <string.h>
#include <stdio.h>
#include <errno.h>

#include "compat.h"

#include "conf-parser.h"

#define WHITESPACE " \t\n"
#define COMMENTS "#;\n"

/* Run the user supplied parser for an assignment */
static int normal_assignment(pa_config_parser_state *state) {
    const pa_config_item *item;

    pa_assert(state);

    for (item = state->item_table; item->parse; item++) {

        if (item->lvalue && !pa_streq(state->lvalue, item->lvalue))
            continue;

        if (item->section && !state->section)
            continue;

        if (item->section && !pa_streq(state->section, item->section))
            continue;

        state->data = item->data;

        return item->parse(state);
    }

    pa_log("[%s:%u] Unknown lvalue '%s' in section '%s'.", state->filename, state->lineno, state->lvalue, pa_strna(state->section));

    return -1;
}

/* Parse a proplist entry. */
static int proplist_assignment(pa_config_parser_state *state) {
    pa_assert(state);
    pa_assert(state->proplist);

    if (pa_proplist_sets(state->proplist, state->lvalue, state->rvalue) < 0) {
        pa_log("[%s:%u] Failed to parse a proplist entry: %s = %s", state->filename, state->lineno, state->lvalue, state->rvalue);
        return -1;
    }

    return 0;
}

/* Parse a variable assignment line */
static int parse_line(pa_config_parser_state *state) {
    char *c;

    state->lvalue = state->buf + strspn(state->buf, WHITESPACE);

    if ((c = strpbrk(state->lvalue, COMMENTS)))
        *c = 0;

    if (!*state->lvalue)
        return 0;

    if (pa_startswith(state->lvalue, ".include ")) {
        char *path = NULL, *fn;
        int r;

        fn = pa_strip(state->lvalue + 9);
        if (!pa_is_path_absolute(fn)) {
            const char *k;
            if ((k = strrchr(state->filename, '/'))) {
                char *dir = pa_xstrndup(state->filename, k - state->filename);
                fn = path = pa_sprintf_malloc("%s" PA_PATH_SEP "%s", dir, fn);
                pa_xfree(dir);
            }
        }

        r = pa_config_parse(fn, NULL, state->item_table, state->proplist, false, state->userdata);
        pa_xfree(path);
        return r;
    }

    if (*state->lvalue == '[') {
        size_t k;

        k = strlen(state->lvalue);
        pa_assert(k > 0);

        if (state->lvalue[k-1] != ']') {
            pa_log("[%s:%u] Invalid section header.", state->filename, state->lineno);
            return -1;
        }

        pa_xfree(state->section);
        state->section = pa_xstrndup(state->lvalue + 1, k-2);

        if (pa_streq(state->section, "Properties")) {
            if (!state->proplist) {
                pa_log("[%s:%u] \"Properties\" section is not allowed in this file.", state->filename, state->lineno);
                return -1;
            }

            state->in_proplist = true;
        } else
            state->in_proplist = false;

        return 0;
    }

    if (!(state->rvalue = strchr(state->lvalue, '='))) {
        pa_log("[%s:%u] Missing '='.", state->filename, state->lineno);
        return -1;
    }

    *state->rvalue = 0;
    state->rvalue++;

    state->lvalue = pa_strip(state->lvalue);
    state->rvalue = pa_strip(state->rvalue);

    if (state->in_proplist)
        return proplist_assignment(state);
    else
        return normal_assignment(state);
}

#ifndef OS_IS_WIN32
static int conf_filter(const struct dirent *entry) {
    return pa_endswith(entry->d_name, ".conf");
}
#endif

/* Go through the file and parse each line */
int pa_config_parse(const char *filename, FILE *f, const pa_config_item *t, pa_proplist *proplist, bool use_dot_d,
                    void *userdata) {
    int r = -1;
    bool do_close = !f;
    pa_config_parser_state state;

    pa_assert(filename);
    pa_assert(t);

    pa_zero(state);

    if (!f && !(f = pa_fopen_cloexec(filename, "r"))) {
        if (errno == ENOENT) {
            pa_log_debug("Failed to open configuration file '%s': %s", filename, pa_cstrerror(errno));
            r = 0;
            goto finish;
        }

        pa_log_warn("Failed to open configuration file '%s': %s", filename, pa_cstrerror(errno));
        goto finish;
    }
    pa_log_debug("Parsing configuration file '%s'", filename);

    state.filename = filename;
    state.item_table = t;
    state.userdata = userdata;

    if (proplist)
        state.proplist = pa_proplist_new();

    while (!feof(f)) {
        if (!fgets(state.buf, sizeof(state.buf), f)) {
            if (feof(f))
                break;

            pa_log_warn("Failed to read configuration file '%s': %s", filename, pa_cstrerror(errno));
            goto finish;
        }

        state.lineno++;

        if (parse_line(&state) < 0)
            goto finish;
    }

    if (proplist)
        pa_proplist_update(proplist, PA_UPDATE_REPLACE, state.proplist);

    r = 0;

finish:
    if (state.proplist)
        pa_proplist_free(state.proplist);

    pa_xfree(state.section);

    if (do_close && f)
        fclose(f);

    if (use_dot_d) {
#ifdef OS_IS_WIN32
        char *dir_name = pa_sprintf_malloc("%s.d", filename);
        char *pattern = pa_sprintf_malloc("%s\\*.conf", dir_name);
        HANDLE fh;
        WIN32_FIND_DATA wfd;

        fh = FindFirstFile(pattern, &wfd);
        if (fh != INVALID_HANDLE_VALUE) {
            do {
                if (!(wfd.dwFileAttributes & FILE_ATTRIBUTE_DIRECTORY)) {
                    char *filename2 = pa_sprintf_malloc("%s\\%s", dir_name, wfd.cFileName);
                    pa_config_parse(filename2, NULL, t, proplist, false, userdata);
                    pa_xfree(filename2);
                }
            } while (FindNextFile(fh, &wfd));
            FindClose(fh);
        } else {
            DWORD err = GetLastError();

            if (err == ERROR_PATH_NOT_FOUND) {
                pa_log_debug("Pattern %s did not match any files, ignoring.", pattern);
            } else {
                LPVOID msgbuf;
                DWORD fret = FormatMessage(FORMAT_MESSAGE_ALLOCATE_BUFFER | FORMAT_MESSAGE_FROM_SYSTEM | FORMAT_MESSAGE_IGNORE_INSERTS,
                                           NULL, err, MAKELANGID(LANG_NEUTRAL, SUBLANG_DEFAULT), (LPTSTR)&msgbuf, 0, NULL);

                if (fret != 0) {
                    pa_log_warn("FindFirstFile(%s) failed with error %ld (%s), ignoring.", pattern, err, (char*)msgbuf);
                    LocalFree(msgbuf);
                } else {
                    pa_log_warn("FindFirstFile(%s) failed with error %ld, ignoring.", pattern, err);
                    pa_log_warn("FormatMessage failed with error %ld", GetLastError());
                }
            }
        }

        pa_xfree(pattern);
        pa_xfree(dir_name);
#else
        char *dir_name;
        int n;
        struct dirent **entries = NULL;

        dir_name = pa_sprintf_malloc("%s.d", filename);

        n = scandir(dir_name, &entries, conf_filter, alphasort);
        if (n >= 0) {
            int i;

            for (i = 0; i < n; i++) {
                char *filename2;

                filename2 = pa_sprintf_malloc("%s" PA_PATH_SEP "%s", dir_name, entries[i]->d_name);
                pa_config_parse(filename2, NULL, t, proplist, false, userdata);
                pa_xfree(filename2);

                free(entries[i]);
            }

            free(entries);
        } else {
            if (errno == ENOENT)
                pa_log_debug("%s does not exist, ignoring.", dir_name);
            else
                pa_log_warn("scandir(\"%s\") failed: %s", dir_name, pa_cstrerror(errno));
        }

        pa_xfree(dir_name);
#endif
    }

    return r;
}

int pa_config_parse_int(pa_config_parser_state *state) {
    int *i;
    int32_t k;

    pa_assert(state);

    i = state->data;

    if (pa_atoi(state->rvalue, &k) < 0) {
        pa_log("[%s:%u] Failed to parse numeric value: %s", state->filename, state->lineno, state->rvalue);
        return -1;
    }

    *i = (int) k;
    return 0;
}

int pa_config_parse_unsigned(pa_config_parser_state *state) {
    unsigned *u;
    uint32_t k;

    pa_assert(state);

    u = state->data;

    if (pa_atou(state->rvalue, &k) < 0) {
        pa_log("[%s:%u] Failed to parse numeric value: %s", state->filename, state->lineno, state->rvalue);
        return -1;
    }

    *u = (unsigned) k;
    return 0;
}

int pa_config_parse_size(pa_config_parser_state *state) {
    size_t *i;
    uint32_t k;

    pa_assert(state);

    i = state->data;

    if (pa_atou(state->rvalue, &k) < 0) {
        pa_log("[%s:%u] Failed to parse numeric value: %s", state->filename, state->lineno, state->rvalue);
        return -1;
    }

    *i = (size_t) k;
    return 0;
}

int pa_config_parse_bool(pa_config_parser_state *state) {
    int k;
    bool *b;

    pa_assert(state);

    b = state->data;

    if ((k = pa_parse_boolean(state->rvalue)) < 0) {
        pa_log("[%s:%u] Failed to parse boolean value: %s", state->filename, state->lineno, state->rvalue);
        return -1;
    }

    *b = !!k;

    return 0;
}

int pa_config_parse_not_bool(pa_config_parser_state *state) {
    int k;
    bool *b;

    pa_assert(state);

    b = state->data;

    if ((k = pa_parse_boolean(state->rvalue)) < 0) {
        pa_log("[%s:%u] Failed to parse boolean value: %s", state->filename, state->lineno, state->rvalue);
        return -1;
    }

    *b = !k;

    return 0;
}

int pa_config_parse_string(pa_config_parser_state *state) {
    char **s;

    pa_assert(state);

    s = state->data;

    pa_xfree(*s);
    *s = *state->rvalue ? pa_xstrdup(state->rvalue) : NULL;
    return 0;
}
