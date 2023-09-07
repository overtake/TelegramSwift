[[previous]](tutorial1.md) [[index]](tutorial-index.md) [[next]](tutorial3.md)

# Enumerating objects (Tutorial 2)

In this tutorial we show how to connect to a PipeWire daemon and 
enumerate the objects that it has.

Let take a look at the following application to start.

```c
#include <pipewire/pipewire.h>

static void registry_event_global(void *data, uint32_t id,
		uint32_t permissions, const char *type, uint32_t version,
		const struct spa_dict *props)
{
	printf("object: id:%u type:%s/%d\n", id, type, version);
}

static const struct pw_registry_events registry_events = {
	PW_VERSION_REGISTRY_EVENTS,
	.global = registry_event_global,
};

int main(int argc, char *argv[])                                                
{                                                                               
        struct pw_main_loop *loop;                                              
        struct pw_context *context;                                             
        struct pw_core *core;                                                   
        struct pw_registry *registry;                                           
        struct spa_hook registry_listener;                                      
                                                                                
        pw_init(&argc, &argv);                                                  
                                                                                
        loop = pw_main_loop_new(NULL /* properties */);                         
        context = pw_context_new(pw_main_loop_get_loop(loop),                   
                        NULL /* properties */,                                  
                        0 /* user_data size */);                                
                                                                                
        core = pw_context_connect(context,                                      
                        NULL /* properties */,                                  
                        0 /* user_data size */);                                
                                                                                
        registry = pw_core_get_registry(core, PW_VERSION_REGISTRY,              
                        0 /* user_data size */);                                
                                                                                
        spa_zero(registry_listener);                                            
        pw_registry_add_listener(registry, &registry_listener,                  
                                       &registry_events, NULL);                 
                                                                                
        pw_main_loop_run(loop);                                                 
                                                                                
        pw_proxy_destroy((struct pw_proxy*)registry);                           
        pw_core_disconnect(core);                                               
        pw_context_destroy(context);                                            
        pw_main_loop_destroy(loop);                                             
                                                                                
        return 0;                                                               
}                                  
```

To compile the simple test application, copy it into a tutorial2.c file and
use:

```
gcc -Wall tutorial2.c -o tutorial2 $(pkg-config --cflags --libs libpipewire-0.3)
```

Let's break this down:

First we need to initialize the PipeWire library with `pw_init()` as we
saw in the previous tutorial. This will load and configure the right
modules and setup logging and other tasks.

```c
	...
        pw_init(&argc, &argv);
	...
```

Next we need to create one of the `struct pw_loop` wrappers. PipeWire
ships with 2 types of mainloop implementations. We will use the
`struct pw_main_loop` implementation, we will see later how we can
use the `struct pw_thread_loop` implementation as well.

The mainloop is an abstraction of a big poll loop, waiting for events
to occur and things to do. Most of the PipeWire work will actually
be performed in the context of this loop and so we need to make one
first.

We then need to make a new context object with the loop. This context
object will manage the resources for us and will make it possible for
us to connect to a PipeWire daemon:

```c
        struct pw_main_loop *loop;
        struct pw_context *context;

        loop = pw_main_loop_new(NULL /* properties */);
        context = pw_context_new(pw_main_loop_get_loop(loop),
                        NULL /* properties */,
                        0 /* user_data size */);
```

It is possible to give extra properties when making the mainloop or
context to tweak its features and functionality. It is also possible
to add extra data to the allocated objects for your user data. It will
stay alive for as long as the object is alive. We will use this
feature later.

A real implementation would also need to check if the allocation
succeeded and do some error handling, but we leave that out to make
the code easier to read.

With the context we can now connect to the PipeWire daemon:

```c
        struct pw_core *core;
        core = pw_context_connect(context,
                        NULL /* properties */,
                        0 /* user_data size */);
```

This creates a socket between the client and the server and makes
a proxy object (with ID 0) for the core. Don't forget to check the
result here, a NULL value means that the connection failed.

At this point we can send messages to the server and receive events.
For now we're not going to handle events on this core proxy but
we're going to handle them on the registry object.


```c
        struct pw_registry *registry;
        struct spa_hook registry_listener;

        registry = pw_core_get_registry(core, PW_VERSION_REGISTRY,
                        0 /* user_data size */);

        spa_zero(registry_listener);
        pw_registry_add_listener(registry, &registry_listener,
                                       &registry_events, NULL);
```

From the core we get the registry proxy object and when we use
`pw_registry_add_listener()` to listen for events. We need a
small `struct spa_hook` to keep track of the listener and a
reference to the `struct pw_registry_events` that contains the
events we want to listen to.

This is how we define the event handler and the function to
handle the events:

```c
static const struct pw_registry_events registry_events = {
	PW_VERSION_REGISTRY_EVENTS,
	.global = registry_event_global,
};

static void registry_event_global(void *data, uint32_t id,
		uint32_t permissions, const char *type, uint32_t version,
		const struct spa_dict *props)
{
	printf("object: id:%u type:%s/%d\n", id, type, version);
}
```

Now that everything is set up we can start the mainloop and let
the communication between client and server continue:

```c
        pw_main_loop_run(loop);
```

Since we don't call `pw_main_loop_quit()` anywhere, this loop will
continue forever. In the next tutorial we'll see how we can nicely
exit our application after we received all server objects.


[[previous]](tutorial1.md) [[index]](tutorial-index.md) [[next]](tutorial3.md)
