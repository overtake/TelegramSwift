/* PipeWire
 *
 * Copyright © 2021 Pauli Virtanen
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

/*
 * Instruct policy-node to move streams when the default sink/sources (either explicitly set
 * via metadata, or determined from priority) changes, and the stream does not have an
 * explicitly specified target node.
 *
 * This is done by just setting a session property flag, and policy-node does the rest.
 */

#include "config.h"

#include "pipewire/pipewire.h"
#include "extensions/metadata.h"

#include "media-session.h"

#define KEY_NAME	"policy-node.streams-follow-default"

int sm_streams_follow_default_start(struct sm_media_session *session)
{
	pw_properties_set(session->props, KEY_NAME, "true");
	return 0;
}
