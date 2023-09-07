[[previous]](tutorial5.md) [[index]](tutorial-index.md) [[next]](tutorial7.md)

# Binding objects (Tutorial 6)

In this tutorial we show how to bind to an object so that we can
receive events and call methods on the object.

Let take a look at the following application to start.

```c
#include <pipewire/pipewire.h>

struct data {
	struct pw_main_loop *loop;
	struct pw_context *context;
	struct pw_core *core;

	struct pw_registry *registry;
	struct spa_hook registry_listener;

	struct pw_client *client;
	struct spa_hook client_listener;
};

static void client_info(void *object, const struct pw_client_info *info)
{
	struct data *data = object;
	const struct spa_dict_item *item;

	printf("client: id:%u\n", info->id);
	printf("\tprops:\n");
	spa_dict_for_each(item, info->props)
		printf("\t\t%s: \"%s\"\n", item->key, item->value);

	pw_main_loop_quit(data->loop);
}

static const struct pw_client_events client_events = {
	PW_VERSION_CLIENT_EVENTS,
	.info = client_info,
};

static void registry_event_global(void *_data, uint32_t id,
			uint32_t permissions, const char *type,
			uint32_t version, const struct spa_dict *props)
{
	struct data *data = _data;
	if (data->client != NULL)
		return;

	if (strcmp(type, PW_TYPE_INTERFACE_Client) == 0) {
		data->client = pw_registry_bind(data->registry,
				id, type, PW_VERSION_CLIENT, 0);
		pw_client_add_listener(data->client,
				&data->client_listener,
				&client_events, data);
	}
}

static const struct pw_registry_events registry_events = {
	PW_VERSION_REGISTRY_EVENTS,
	.global = registry_event_global,
};

int main(int argc, char *argv[])
{
	struct data data;

	spa_zero(data);

	pw_init(&argc, &argv);

	data.loop = pw_main_loop_new(NULL /* properties */ );
	data.context = pw_context_new(pw_main_loop_get_loop(data.loop),
				 NULL /* properties */ ,
				 0 /* user_data size */ );

	data.core = pw_context_connect(data.context, NULL /* properties */ ,
				  0 /* user_data size */ );

	data.registry = pw_core_get_registry(data.core, PW_VERSION_REGISTRY,
					0 /* user_data size */ );

	pw_registry_add_listener(data.registry, &data.registry_listener,
				 &registry_events, &data);

	pw_main_loop_run(data.loop);

	pw_proxy_destroy((struct pw_proxy *)data.client);
	pw_proxy_destroy((struct pw_proxy *)data.registry);
	pw_core_disconnect(data.core);
	pw_context_destroy(data.context);
	pw_main_loop_destroy(data.loop);

	return 0;
}
```

To compile the simple test application, copy it into a tutorial6.c file and
use:

```
gcc -Wall tutorial6.c -o tutorial6 $(pkg-config --cflags --libs libpipewire-0.3)
```

Most of this is the same as [tutorial 2](tutorial2.md) where we simply
enumerated all objects on the server. Instead of just printing the object
id and some other properties, in this example we also bind to the object.

We use the `pw_registry_bind()` method on our registry object like this:

```c
static void registry_event_global(void *_data, uint32_t id,
			uint32_t permissions, const char *type,
			uint32_t version, const struct spa_dict *props)
{
	struct data *data = _data;
	if (data->client != NULL)
		return;

	if (strcmp(type, PW_TYPE_INTERFACE_Client) == 0) {
		data->client = pw_registry_bind(data->registry,
				id, type, PW_VERSION_CLIENT, 0);
		/* ... */
	}
}
```

We bind to the first client object that we see. This gives us a pointer
to a `struct pw_proxy` that we can also cast to a `struct pw_client`.

On the proxy we can call methods and listen for events. PipeWire will
automatically serialize the method calls and events between client and
server for us.

We can now listen for events by adding a listener. We're going to
listen to the info event on the client object that is emitted right
after we bind to it or when it changes. This is not very different
from the registry listener we added before:

```c
static void client_info(void *object, const struct pw_client_info *info)
{
	struct data *data = object;
	const struct spa_dict_item *item;

	printf("client: id:%u\n", info->id);
	printf("\tprops:\n");
	spa_dict_for_each(item, info->props)
		printf("\t\t%s: \"%s\"\n", item->key, item->value);

	pw_main_loop_quit(data->loop);
}

static const struct pw_client_events client_events = {
	PW_VERSION_CLIENT_EVENTS,
	.info = client_info,
};

static void registry_event_global(void *_data, uint32_t id,
			uint32_t permissions, const char *type,
			uint32_t version, const struct spa_dict *props)
{
		/* ... */
		pw_client_add_listener(data->client,
				&data->client_listener,
				&client_events, data);
		/* ... */
}
```

We're also quitting the mainloop after we get the info to nicely stop
our tutorial application.

When we stop the application, don't forget to destroy all proxies that
you created. Otherwise, they will be leaked:

```c
	/* ... */
	pw_proxy_destroy((struct pw_proxy *)data.client);
	/* ... */

	return 0;
}
```

[[previous]](tutorial5.md) [[index]](tutorial-index.md) [[next]](tutorial7.md)
