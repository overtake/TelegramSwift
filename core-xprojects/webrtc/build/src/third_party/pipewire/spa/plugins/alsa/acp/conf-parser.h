#ifndef fooconfparserhfoo
#define fooconfparserhfoo

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

#include <stdio.h>
#include <stdbool.h>

#include "compat.h"

/* An abstract parser for simple, line based, shallow configuration
 * files consisting of variable assignments only. */

typedef struct pa_config_parser_state pa_config_parser_state;

typedef int (*pa_config_parser_cb_t)(pa_config_parser_state *state);

/* Wraps info for parsing a specific configuration variable */
typedef struct pa_config_item {
    const char *lvalue; /* name of the variable */
    pa_config_parser_cb_t parse; /* Function that is called to parse the variable's value */
    void *data; /* Where to store the variable's data */
    const char *section;
} pa_config_item;

struct pa_config_parser_state {
    const char *filename;
    unsigned lineno;
    char *section;
    char *lvalue;
    char *rvalue;
    void *data; /* The data pointer of the current pa_config_item. */
    void *userdata; /* The pointer that was given to pa_config_parse(). */

    /* Private data to be used only by conf-parser.c. */
    const pa_config_item *item_table;
    char buf[4096];
    pa_proplist *proplist;
    bool in_proplist;
};

/* The configuration file parsing routine. Expects a table of
 * pa_config_items in *t that is terminated by an item where lvalue is
 * NULL.
 *
 * If use_dot_d is true, then after parsing the file named by the filename
 * argument, the function will parse all files ending with ".conf" in
 * alphabetical order from a directory whose name is filename + ".d", if such
 * directory exists.
 *
 * Some configuration files may contain a Properties section, which
 * is a bit special. Normally all accepted lvalues must be predefined
 * in the pa_config_item table, but in the Properties section the
 * pa_config_item table is ignored, and all lvalues are accepted (as
 * long as they are valid proplist keys). If the proplist pointer is
 * non-NULL, the parser will parse any section named "Properties" as
 * properties, and those properties will be merged into the given
 * proplist. If proplist is NULL, then sections named "Properties"
 * are not allowed at all in the configuration file. */
int pa_config_parse(const char *filename, FILE *f, const pa_config_item *t, pa_proplist *proplist, bool use_dot_d,
                    void *userdata);

/* Generic parsers for integers, size_t, booleans and strings */
int pa_config_parse_int(pa_config_parser_state *state);
int pa_config_parse_unsigned(pa_config_parser_state *state);
int pa_config_parse_size(pa_config_parser_state *state);
int pa_config_parse_bool(pa_config_parser_state *state);
int pa_config_parse_not_bool(pa_config_parser_state *state);
int pa_config_parse_string(pa_config_parser_state *state);

#endif
