/*
    Copyright (C) 2013 Paul Davis
    
    This program is free software; you can redistribute it and/or modify
    it under the terms of the GNU Lesser General Public License as published by
    the Free Software Foundation; either version 2.1 of the License, or
    (at your option) any later version.
    
    This program is distributed in the hope that it will be useful,
    but WITHOUT ANY WARRANTY; without even the implied warranty of
    MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
    GNU Lesser General Public License for more details.
    
    You should have received a copy of the GNU Lesser General Public License
    along with this program; if not, write to the Free Software 
    Foundation, Inc., 59 Temple Place - Suite 330, Boston, MA 02111-1307, USA.

*/

#ifndef __jack_uuid_h__
#define __jack_uuid_h__

#include <jack/types.h>

#ifdef __cplusplus
extern "C" {
#endif

#define JACK_UUID_SIZE 36
#define JACK_UUID_STRING_SIZE (JACK_UUID_SIZE+1) /* includes trailing null */
#define JACK_UUID_EMPTY_INITIALIZER 0

extern jack_uuid_t jack_client_uuid_generate ();
extern jack_uuid_t jack_port_uuid_generate (uint32_t port_id);

extern uint32_t jack_uuid_to_index (jack_uuid_t);

extern int  jack_uuid_compare (jack_uuid_t, jack_uuid_t);
extern void jack_uuid_copy (jack_uuid_t* dst, jack_uuid_t src);
extern void jack_uuid_clear (jack_uuid_t*);
extern int  jack_uuid_parse (const char *buf, jack_uuid_t*);
extern void jack_uuid_unparse (jack_uuid_t, char buf[JACK_UUID_STRING_SIZE]);
extern int  jack_uuid_empty (jack_uuid_t);

#ifdef __cplusplus
} /* namespace */
#endif

#endif /* __jack_uuid_h__ */

