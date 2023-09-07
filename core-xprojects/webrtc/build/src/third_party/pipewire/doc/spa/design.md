# SPA Design

SPA (Simple Plugin API) is an extensible API to implement all kinds of plugins.
It is inspired by many other plugin APIs, mostly LV2 and GStreamer.

Plugins are dynamically loadable objects that contain objects and interfaces that
can be introspected and used at runtime in any application.

SPA provides the following functionality:

 * enumeration of object factories and the interfaces provided by the objects
 * creation of objects (AKA a handle)
 * retrieve interfaces to perform actions on the objects

SPA was designed with the following goals in mind:

 * No dependencies, SPA is shipped as a set of header files that have no dependencies
   except for the standard c library.
 * Very efficient both in space and in time.
 * Very configurable and usable in many different environments. All aspects of
   the plugin environment can be configured and changed, like logging, poll loops,
   system calls etc.
 * Consistent API
 * Extensible, new API can be added with minimal effort, existing API can be
   updated and versioned.

The original user of SPA is PipeWire, which uses SPA to implement the low-level
multimedia processing plugins, device detection, mainloops, CPU detection and
logging, among other things. SPA however can be used outside of PipeWire with
minimal problems.

This document introduces the basic concepts of SPA plugins. It first covers using
the API and then talks about implementing new Plugins.

# Conventions

## Types

Types are generally divided into two categories:

* String types: They identify interfaces and highlevel object types.
* integer types: These are enumerations used in the parts where high
                 performance/ease of use/low space overhead is needed.

The SPA type is system is statis and very simple but still allows you
to make and introspect complex object type hierarchies.

See the type system docs for more info.

## Error codes

SPA uses negative integers as errno style error codes. Functions that return an
int result code generated an error when < 0. `spa_strerror()` can be used to
get a string representation of the error code.

SPA also has a way to encode asynchronous results. This is done by setting a
high bit (bit 30, the `ASYNC_BIT`) in the result code and a sequence number
in the lower bits. This result is normally identified as a positive success
result code and the sequence number can later be matched to the completion
event.

## Useful macros

SPA comes with some useful macros defined in `<spa/utils/defs.h>`.


# SPA Plugin

The SPA plugin is the starting point for the API. A plugin is an OS specific
shared object that needs to be loaded/opened in an OS specific way. SPA does
not specify where plugins need to live, although plugins are normally installed
in `/usr/lib64/spa-0.2/` or equivalent. Plugins and API are versioned and many
versions can live on the same system.

## Open a plugin

A plugin is opened with a platform specific API. In this example we use dlopen()
as the method used on Linux.

A plugin always consists of 2 parts, the vendor path and then the .so file.

As an example we will load the "support/libspa-support.so" plugin. You will
usually use some mapping between functionality and plugin path, as we'll see
later, instead of hardcoding the plugin name.

To dlopen a plugin we then need to prefix the plugin path like this:

```c
#define SPA_PLUGIN_PATH	/usr/lib64/spa-0.2/"
void *hnd = dlopen(SPA_PLUGIN_PATH"/support/libspa-support.so", RTLD_NOW);
```

The environment variable `SPA_PLUGIN_PATH` is usually used to find the
location of the plugins. You will have to do some more work to construct the
shared object path.

The plugin has (should have) exactly one public symbol, called
`spa_handle_factory_enum`, which is defined with the macro
`SPA_HANDLE_FACTORY_ENUM_FUNC_NAME` to get some compile time checks and avoid
typos in the symbol name. We can get the symbol like so:

```c
spa_handle_factory_enum_func_t enum_func;
enum_func = dlsym(hnd, SPA_HANDLE_FACTORY_ENUM_FUNC_NAME));
```

If this symbol is not available, this is not a valid SPA plugin.

## Enumerating factories

With the `enum_func` we can now enumerate all the factories in the plugin:

```c
uint32_t i;
const struct spa_handle_factory *factory = NULL;
for (i = 0;;) {
	if (enum_func(&factory, &i) <= 0)
		break;
	/* check name and version, introspect interfaces,
	 * do something with the factory. */
}
```

A factory has a version, a name, some properties and a couple of functions
that we can check and use. The main use of a factory is to create an
actual new object from it.

We can enumerate the interfaces that we will find on this new object with
the `spa_handle_factory_enum_interface_info()` method. Interface types
are simple strings that uniquely define the interface (See also the type
system).

The name of the factory is a well-known name that describes the functionality
of the objects created from the factory. `<spa/utils/names.h>` contains
definitions for common functionality, for example:

```c
#define SPA_NAME_SUPPORT_CPU            "support.cpu"                   /**< A CPU interface */
#define SPA_NAME_SUPPORT_LOG            "support.log"                   /**< A Log interface */
#define SPA_NAME_SUPPORT_DBUS           "support.dbus"                  /**< A DBUS interface */
```

Usually the name will be mapped to a specific plugin. This way an
alternative compatible implementation can be made in a different library.

## Making a handle

Once we have a suitable factory, we need to allocate memory for the object
it can create. SPA usually does not allocate memory itself but relies on
the application and the stack for storage.

First get the size of the required memory:

```c
size_t size = spa_handle_factory_get_size(factory, NULL /* extra params */);
```

Sometimes the memory can depend on the extra parameters given in
`_get_size()`. Next we need to allocate the memory and initialize the object
in it:

```c
handle = calloc(1, size);
spa_handle_factory_init(factory, handle,
			NULL, /* info */
			NULL, /* support */
			0     /* n_support */);
```

The info parameter should contain the same extra properties given in
`spa_handle_factory_get_size()`.

The support parameter is an array of `struct spa_support` items. They
contain a string type and a pointer to extra support objects. This can
be a logging API or a main loop API, for example. Some plugins require
certain support libraries to function.

## Retrieving an interface

When a SPA handle is made, you can retrieve any of the interfaces that
it provides:

```c
void *iface;
spa_handle_get_interface(handle, SPA_NAME_SUPPORT_LOG, &iface);
```

If this method succeeds, you can cast the `iface` variable to
`struct spa_log *` and start using the log interface methods.

```c
struct spa_log *log = iface;
spa_log_warn(log, "Hello World!\n");
```


## Clearing an object

After you are done with a handle you can clear it with
`spa_handle_clear()` and you can unload the library with `dlclose()`.


# SPA Interfaces

We briefly talked about retrieving an interface from a plugin in the
previous section. Now we will explore what an interface actually is
and how to use it.

When you retrieve an interface from a handle, you get a reference to
a small structure that contains the type (string) of the interface,
a version and a structure with a set of methods (and data) that are
the implementation of the interface. Calling a method on the interface
will just call the appropriate method in the implementation.

Interfaces are defined in a header file (for example see
`<spa/support/log.h>` for the logger API). It is a self contained
definition that you can just use in your application after you dlopen()
the plugin.

Some interfaces also provide extra fields in the interface, like the
log interface above that has the log level as a read/write parameter.

## SPA Events

Some interfaces will also allow you to register a callback (a hook or
listener) to be notified of events. This is usually when something
changed internally in the interface and it wants to notify the registered
listeners about this.

For example, the `struct spa_node` interface has a method to register such
an event handler like this:

```c
static void node_info(void *data, const struct spa_node_info *info)
{
	printf("got node info!\n");
}

static struct spa_node_events node_events = {
	SPA_VERSION_NODE_EVENTS,
        .info = node_info,
};

struct spa_hook listener;
spa_zero(listener);
spa_node_add_listener(node, &listener, &node_event, my_data);
```

You make a structure with pointers to the events you are interested in
and then use `spa_node_add_listener()` to register a listener. The
`struct spa_hook` is used by the interface to keep track of registered
event listeners.

Whenever the node information is changed, your `node_info` method will
be called with `my_data` as the first data field. The events are usually
also triggered when the listener is added, to enumerate the current
state of the object.

Events have a `version` field, set to `SPA_VERSION_NODE_EVENTS` in the
above example. It should contain the version of the event structure
you compiled with. When new events are added later, the version field
will be checked and the new signal will be ignored for older versions.

You can remove your listener with:

```c
spa_hook_remove(&listener);
```

## API results

Some interfaces provide API that gives you a list or enumeration of
objects/values. To avoid allocation overhead and ownership problems,
SPA uses events to push results to the application. This makes it
possible for the plugin to temporarily create complex objects on the
stack and push this to the application without allocation or ownership
problems. The application can look at the pushed result and keep/copy
only what it wants to keep.


### Synchronous results

Here is an example of enumerating parameters on a node interface.

First install a listener for the result:

```c
static void node_result(void *data, int seq, int res,
		uint32_t type, const void *result)
{
        const struct spa_result_node_params *r =
                (const struct spa_result_node_params *) result;
	printf("got param:\n");
	spa_debug_pod(0, NULL, r->param);
}

struct spa_hook listener = { 0 };
static const struct spa_node_events node_events = {
	SPA_VERSION_NODE_EVENTS,
	.result = node_result,
};

spa_node_add_listener(node, &listener, &node_events, node);
```

Then perform the `enum_param` method:

```c
int res = spa_node_enum_params(node, 0, SPA_PARAM_EnumFormat, 0, MAXINT, NULL);
```

This triggers the result event handler with a 0 sequence number for each
supported format. After this completes, remove the listener again:

```c
spa_hook_remove(&listener);
```


### Asynchronous results

Asynchronous results are pushed to the application in the same way as
synchronous results, they are just pushed later. You can check that
a result is asynchronous by the return value of the enum function:

```c
int res = spa_node_enum_params(node, 0, SPA_PARAM_EnumFormat, 0, MAXINT, NULL);

if (SPA_RESULT_IS_ASYNC(res)) {
	/* result will be received later */
	...
}
```

In the case of async results, the result callback will be called with the
sequence number of the async result code, which can be obtained with:

```c
expected_seq = SPA_RESULT_ASYNC_SEQ(res);
```

# Implementing a new plugin
