[[index]](tutorial-index.md) [[next]](tutorial2.md)

# Getting started (Tutorial 1)

In this tutorial we show the basics of a simple PipeWire application.
Use this tutorial to get started and help you set up your development
environment.

## Initialization

Let get started with the simplest application.

```c
#include <pipewire/pipewire.h>                                                  

int main(int argc, char *argv[])
{
	pw_init(&argc, &argv);

	fprintf(stdout, "Compiled with libpipewire %s\n"
                        "Linked with libpipewire %s\n",
                                pw_get_headers_version(),
                                pw_get_library_version());
	return 0;
}
```

Before you can use any PipeWire functions, you need to call `pw_init()`.

## Compilation

To compile the simple test application, copy it into a test1.c file and
use:

```
gcc -Wall test1.c -o test1 $(pkg-config --cflags --libs libpipewire-0.3)
```

then run it with:

```
# ./test1
Compiled with libpipewire 0.3.5
Linked with libpipewire 0.3.5
#
```

[[index]](tutorial-index.md) [[next]](tutorial2.md)
