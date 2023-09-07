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

#include <jack/statistics.h>

SPA_EXPORT
float jack_get_max_delayed_usecs (jack_client_t *client)
{
	struct client *c = (struct client *) client;
	float res = 0.0f;

	spa_return_val_if_fail(c != NULL, 0.0);

	if (c->driver_activation)
		res = (float)c->driver_activation->max_delay / SPA_USEC_PER_SEC;

	pw_log_trace(NAME" %p: max delay %f", client, res);
	return res;
}

SPA_EXPORT
float jack_get_xrun_delayed_usecs (jack_client_t *client)
{
	struct client *c = (struct client *) client;
	float res = 0.0f;

	spa_return_val_if_fail(c != NULL, 0.0);

	if (c->driver_activation)
		res = (float)c->driver_activation->xrun_delay / SPA_USEC_PER_SEC;

	pw_log_trace(NAME" %p: xrun delay %f", client, res);
	return res;
}

SPA_EXPORT
void jack_reset_max_delayed_usecs (jack_client_t *client)
{
	struct client *c = (struct client *) client;

	spa_return_if_fail(c != NULL);

	if (c->driver_activation)
		c->driver_activation->max_delay = 0;
}
