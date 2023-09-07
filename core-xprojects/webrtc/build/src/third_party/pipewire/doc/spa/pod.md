# POD

POD (plain old data) is a sort of data container. It is comparable to
DBus Variant or LV2 Atom.

A POD can express nested structures of Objects (with properties), Vectors,
Arrays, sequences and various primitives types. All information in the POD
is laid out sequentially in memory and can be written directly to
storage or exchanged between processes or threads without additional
marshalling.

Each POD is made of a 32 bits size followed by a 32 bits type field,
followed by the pod contents. This makes it possible to skip over unknown
POD type. The POD start is always aligned to 8 bytes.

PODs can be efficiently constructed and parsed in real-time threads without
requiring memory allocations. 

PODs use the SPA type system for the basic types and containers. See
the SPA types for more info.

## Types

PODs can contain a number of basic SPA types:

 * `SPA_TYPE_None`: no value or a NULL pointer.
 * `SPA_TYPE_Bool`: a boolean value
 * `SPA_TYPE_Id`: an enumerated value
 * `SPA_TYPE_Int`, `SPA_TYPE_Long`, `SPA_TYPE_Float`, `SPA_TYPE_Double`:
 		various numeral types, 32 and 64 bits.
 * `SPA_TYPE_String`: a string
 * `SPA_TYPE_Bytes`: a byte array
 * `SPA_TYPE_Rectangle`: a rectangle with width and height                                            
 * `SPA_TYPE_Fraction`: a fraction with numerator and denominator
 * `SPA_TYPE_Bitmap`: an array of bits                                                        

PODs can be grouped together in these container types:

 * `SPA_TYPE_Array`: an array of equal sized objects                                                         
 * `SPA_TYPE_Struct`: a collection of types and objects
 * `SPA_TYPE_Object`: an object with properties
 * `SPA_TYPE_Sequence`: a timed sequence of PODs                                                      

PODs can also contain some extra types:

 * `SPA_TYPE_Pointer`: a typed pointer in memory                                                       
 * `SPA_TYPE_Fd`: a file descriptor
 * `SPA_TYPE_Choice`: a choice of values                                                        
 * `SPA_TYPE_Pod`: a generic type for the POD itself         

# Constructing a POD

A POD is usually constructed with a `struct spa_pod_builder`. The builder
needs to be initialized with a memory region to write into. It is
also possible to dynamically grow the memory as needed.

The most common way to construct a POD is on the stack. This does
not require any memory allocations. The size of the POD can be
estimated pretty easily and if the buffer is not large enough, an
appropriate error will be generated.

The code fragment below initializes a pod builder to write into
the stack allocated buffer.

```c
uint8_t buffer[4096];
struct spa_pod_builder b;
spa_pod_builder_init(&b, buffer, sizeof(buffer));                       
```

Next we need to write some object into the builder. Let's write
a simple struct with an Int and Float in it. Structs are comparable
to JSON arrays.

```c
struct spa_pod_frame f;
spa_pod_builder_push_struct(&b, &f);
```

First we open the struct container, the `struct spa_pod_frame` keeps
track of the container context. Next we add some values to
the container like this:

```c
spa_pod_builder_int(&b, 5);
spa_pod_builder_float(&b, 3.1415f);
```

Then we close the container by popping the frame again:

```c
struct spa_pod *pod;
pod = spa_pod_builder_pop(&b, &f);
```

`spa_pod_builder_pop()` returns a reference to the object we completed
on the stack.

## Using varargs builder.

We can also use the following construct to make POD objects:

```c
spa_pod_builder_push_struct(&b, &f);
spa_pod_builder_add(&b,
	SPA_POD_Int(5),
	SPA_POD_Float(3.1415f));
pod = spa_pod_builder_pop(&b, &f);
```

Or even shorter:

```c
pod = spa_pod_builder_add_struct(&b,
	SPA_POD_Int(5),
	SPA_POD_Float(3.1415f));
```

It's not possible to use the varargs builder to make a Sequence or
Array, use the normal builder methods for that.

## Making objects

POD objects are containers for properties and are comparable to JSON
objects.

Start by pushing an object:

```c
spa_pod_builder_push_object(&b, &f, SPA_TYPE_OBJECT_Props, SPA_PARAM_Props);
```

An object requires an object type (`SPA_TYPE_OBJECT_Props`) and a context
id (`SPA_PARAM_Props`). The object type defines the properties that can be
added to the object and their meaning. The SPA type system allows you to
make this connection (See the type system).

Next we can push some properties in the object:

```c
spa_pod_builder_prop(&b, SPA_PROP_device, 0);
spa_pod_builder_string(&b, "hw:0");
spa_pod_builder_prop(&b, SPA_PROP_frequency, 0);
spa_pod_builder_float(&b, 440.0);
```

As can be seen, we always need to push a prop (with key and flags)
and then the associated value. For performance reasons it is a good
idea to always push (and parse) the object keys in ascending order.

Don't forget to pop the result when the object is finished:

```c
pod = spa_pod_builder_pop(&b, &f);
```

There is a shortcut for making objects:

```c
pod = spa_pod_builder_add_object(&b,
	SPA_TYPE_OBJECT_Props, SPA_PARAM_Props,
	SPA_PROP_device,    SPA_POD_String("hw:0"),
	SPA_PROP_frequency, SPA_POD_Float(440.0f));
```

## Choice values

It is possible to express ranges or enumerations of possible
values for properties (and to some extend structs). This is achieved
with Choice values.

Choice values are really just a choice type and an array of choice values
(of the same type). Depending on the choice type, the array values are
interpreted in different ways:

 * `SPA_CHOICE_None`:   no choice, first value is current
 * `SPA_CHOICE_Range`:  range: default, min, max
 * `SPA_CHOICE_Step`:   range with step: default, min, max, step
 * `SPA_CHOICE_Enum`:   enum: default, alternative,... 
 * `SPA_CHOICE_Flags`:  bitmask of flags

Let's illustrate this with a Props object that specifies a range of
possible values for the frequency:

```c
struct spa_pod_frame f2;

spa_pod_builder_push_object(&b, &f, SPA_TYPE_OBJECT_Props, SPA_PARAM_Props);
spa_pod_builder_prop(&b, SPA_PROP_frequency, 0);
spa_pod_builder_push_choice(&b, &f2, SPA_CHOICE_Range, 0);
spa_pod_builder_float(&b, 440.0);   /* default */
spa_pod_builder_float(&b, 110.0);   /* min */
spa_pod_builder_float(&b, 880.0);   /* min */
pod = spa_pod_builder_pop(&b, &f2);
pod = spa_pod_builder_pop(&b, &f);
```

As you can see, first push the choice as a Range, then the values. A Range
choice expects at least 3 values, the default value, minimum and maximum
values. There is a shortcut for this as well using varargs:

```c
pod = spa_pod_builder_add_object(&b,
	SPA_TYPE_OBJECT_Props, SPA_PARAM_Props,
	SPA_PROP_frequency, SPA_POD_CHOICE_RANGE_Float(440.0f, 110.0f, 880.0f));
```

## Choice examples

This is a description of a possible `SPA_TYPE_OBJECT_Format` as used when
enumerating allowed formats (`SPA_PARAM_EnumFormat`) in SPA objects:

```c
pod = spa_pod_builder_add_object(&b,
	SPA_TYPE_OBJECT_Format, SPA_PARAM_EnumFormat,
	/* specify the media type and subtype */
	SPA_FORMAT_mediaType,      SPA_POD_Id(SPA_MEDIA_TYPE_audio),
	SPA_FORMAT_mediaSubtype,   SPA_POD_Id(SPA_MEDIA_SUBTYPE_raw),
	/* audio/raw properties */
	SPA_FORMAT_AUDIO_format,   SPA_POD_CHOICE_ENUM_Id(
					SPA_AUDIO_FORMAT_S16, /* default */
					SPA_AUDIO_FORMAT_S16, /* alternative1 */
					SPA_AUDIO_FORMAT_S32, /* alternative2 */
					SPA_AUDIO_FORMAT_f32  /* alternative3 */
				   ),
	SPA_FORMAT_AUDIO_rate,     SPA_POD_CHOICE_RANGE_Int(
					44100,		/* default */
					8000,		/* min */
					192000		/* max */
				   ),
	SPA_FORMAT_AUDIO_channels, SPA_POD_Int(2));
```

## Fixate

We can remove all choice values from the object with the 
`spa_pod_object_fixate()` method. This modifies the pod in-place and sets all
choice properties to `SPA_CHOICE_None`, forcing the default value as the
only available value in the choice.

Running fixate on our previous example would result in an object equivalent
to:

```c
pod = spa_pod_builder_add_object(&b,
	SPA_TYPE_OBJECT_Format, SPA_PARAM_EnumFormat,
	/* specify the media type and subtype */
	SPA_FORMAT_mediaType,      SPA_POD_Id(SPA_MEDIA_TYPE_audio),
	SPA_FORMAT_mediaSubtype,   SPA_POD_Id(SPA_MEDIA_SUBTYPE_raw),
	/* audio/raw properties */
	SPA_FORMAT_AUDIO_format,   SPA_POD_Id(SPA_AUDIO_FORMAT_S16),
	SPA_FORMAT_AUDIO_rate,     SPA_POD_Int(44100),
	SPA_FORMAT_AUDIO_channels, SPA_POD_Int(2));
```

# Parsing a POD

Parsing a POD usually consists of

 * validating if raw bytes + size can contain a valid pod
 * inspecting the type of a pod
 * looping over the items in an object or struct
 * getting data out of PODs.

## Validating bytes

Use `spa_pod_from_data()` to check if maxsize of bytes in data contain
a POD at the size bytes starting at offset. This function checks that
the POD size will fit and not overflow.

```c
struct spa_pod *pod;
pod = spa_pod_from_data(data, maxsize, offset, size);
```

## Checking the type of POD

Use one of `spa_pod_is_bool()`, `spa_pod_is_int()`, etc to check
for the type of the pod. For simple (non-container) types,
`spa_pod_get_bool()`, `spa_pod_get_int()` etc can be used to
extract the value of the pod.

`spa_pod_is_object_type()` can be used to check if the POD contains
an object of the expected type.

## Struct fields

To iterate over the fields of a Struct use:

```c
struct spa_pod *pod, *obj;
SPA_POD_STRUCT_FOREACH(obj, pod) {
	printf("field type:%d\n", pod->type);
}
```

For parsing Structs it is usually much easier to use the parser
below.

## Object Properties

To iterate over the properties in an object you can do:

```c
struct spa_pod_prop *prop;
struct spa_pod_object *obj = (struct spa_pod_object*)pod;
SPA_POD_OBJECT_FOREACH(pod, prop) {
	printf("prop key:%d\n", prop->key);
}
```

There is a function to retrieve the property for a certain key
in the object. If the properties of the object are in ascending
order, you can start searching from the previous key.

```c
struct spa_pod_prop *prop;
prop = spa_pod_find_prop(obj, NULL, SPA_FORMAT_AUDIO_format);
  /* .. use first prop */
prop = spa_pod_find_prop(obj, prop, SPA_FORMAT_AUDIO_rate);
  /* .. use next prop */
```

## Parser

Similar to the builder, there is a parser object as well.

If the fields in a struct are known, it is much easier to use the
parser. Similarly, if the object type (and thus its keys) are known,
the parser is easier.

First initialize a `struct spa_pod_parser`:

```c
struct spa_pod_parser p;
spa_pod_parser_pod(&p, obj);
```

You can then enter containers such as objects or structs with a push
operation:

```c
struct spa_pod_frame f;
spa_pod_parser_push_struct(&p, &f);
```

You need to store the context in a `struct spa_pod_frame` to be able
to exit the container again later. 

You can then parse each field. The parser takes care of moving to the
next field.

```c
uint32_t id, val;
spa_pod_parser_get_id(&p, &id);
spa_pod_parser_get_int(&p, &val);
...
```

And finally exit the container again:

```c
spa_pod_parser_pop(&p, &f);
```

## Parser with variable arguments

In most cases, parsing objects is easier with the variable argument
functions. The parse function look like the mirror image of the builder
functions.

To parse a struct:

```c
spa_pod_parser_get_struct(&p,
	SPA_POD_Id(&id),
	SPA_POD_Int(&val));
```

To parse properties in an object:

```c
uint32_t type, subtype, format, rate, channels;
spa_pod_parser_get_object(&p,
	SPA_TYPE_OBJECT_Format, SPA_PARAM_EnumFormat,
	SPA_FORMAT_mediaType,      SPA_POD_Id(&type),
	SPA_FORMAT_mediaSubtype,   SPA_POD_Id(&subtype),
	SPA_FORMAT_AUDIO_format,   SPA_POD_Id(&format),
	SPA_FORMAT_AUDIO_rate,     SPA_POD_Int(&rate),
	SPA_FORMAT_AUDIO_channels, SPA_POD_Int(&channels));
```

When parsing objects it is possible to have optional fields. You can
make a field optional be parsing it with the `SPA_POD_OPT_` prefix
for the type.

In the next example, the rate and channels fields are optional
and when they are not present, the variables will not be changed.

```c
uint32_t type, subtype, format, rate = 0, channels = 0;
spa_pod_parser_get_object(&p,
	SPA_TYPE_OBJECT_Format, SPA_PARAM_EnumFormat,
	SPA_FORMAT_mediaType,      SPA_POD_Id(&type),
	SPA_FORMAT_mediaSubtype,   SPA_POD_Id(&subtype),
	SPA_FORMAT_AUDIO_format,   SPA_POD_Id(&format),
	SPA_FORMAT_AUDIO_rate,     SPA_POD_OPT_Int(&rate),
	SPA_FORMAT_AUDIO_channels, SPA_POD_OPT_Int(&channels));
```

It is not possible to parse a Sequence or Array with the parser.
Use the iterator for this.

## Choice values

The parser will handle Choice values as long as they are of type
None. It will then parse the single value from the choice. When
dealing with other choice values, it's possible to parse the 
property values into a `struct spa_pod` and then inspect the Choice
manually, if needed.

Here is an example of parsing the format values as a POD:

```c
uint32_t type, subtype;
struct spa_pod *format;
spa_pod_parser_get_object(&p,
	SPA_TYPE_OBJECT_Format, SPA_PARAM_EnumFormat,
	SPA_FORMAT_mediaType,      SPA_POD_Id(&type),
	SPA_FORMAT_mediaSubtype,   SPA_POD_Id(&subtype),
	SPA_FORMAT_AUDIO_format,   SPA_POD_Pod(&format));
```

`spa_pod_get_values()` is a useful function. It returns a
`struct spa_pod*` with and array of values. For normal PODs
and Choice None values, it simply returns the POD and 1 value.
For other Choice values it returns the Choice type and an array
of values:

```c
struct spa_pod *value;
uint32_t n_vals, choice;

value = spa_pod_get_values(pod, &n_vals, &choice);

switch (choice) {
case SPA_CHOICE_None:
        /* one single value */
	break;
case SPA_CHOICE_Range:
        /* array of values of type of pod, cast to right type
	 * to iterate. */
	uint32_t *v = SPA_POD_BODY(values);
	if (n_vals < 3)
		break;
	printf("default value: %u\n", v[0]);
	printf("min value: %u\n", v[1]);
	printf("max value: %u\n", v[2]);
	break;

	/* ... */
default:
	break;
}
```

# Filter

Given 2 pod objects of the same type (Object, Struct, ..) one can
run a filter and generate a new pod that only contains values that
are compatible with both input pods.

This is, for example, used to find a compatible format between two ports.

As an example we can run a filter on two simple PODs:

```c
pod = spa_pod_builder_add_object(&b,
	SPA_TYPE_OBJECT_Format, SPA_PARAM_EnumFormat,
	SPA_FORMAT_mediaType,      SPA_POD_Id(SPA_MEDIA_TYPE_audio),
	SPA_FORMAT_mediaSubtype,   SPA_POD_Id(SPA_MEDIA_SUBTYPE_raw),
	SPA_FORMAT_AUDIO_format,   SPA_POD_CHOICE_ENUM_Id(
					SPA_AUDIO_FORMAT_S16, /* default */
					SPA_AUDIO_FORMAT_S16, /* alternative1 */
					SPA_AUDIO_FORMAT_S32, /* alternative2 */
					SPA_AUDIO_FORMAT_f32  /* alternative3 */
				   ));

filter = spa_pod_builder_add_object(&b,
	SPA_TYPE_OBJECT_Format, SPA_PARAM_EnumFormat,
	SPA_FORMAT_mediaType,      SPA_POD_Id(SPA_MEDIA_TYPE_audio),
	SPA_FORMAT_mediaSubtype,   SPA_POD_Id(SPA_MEDIA_SUBTYPE_raw),
	SPA_FORMAT_AUDIO_format,   SPA_POD_CHOICE_ENUM_Id(
					SPA_AUDIO_FORMAT_S16, /* default */
					SPA_AUDIO_FORMAT_S16, /* alternative1 */
					SPA_AUDIO_FORMAT_f64  /* alternative2 */
				   ));

struct spa_pod *result;
if (spa_pod_filter(&b, &result, pod, filter) < 0)
	goto exit_error;
```

Filter will contain a POD equivalent to:

```c
result = spa_pod_builder_add_object(&b,
	SPA_TYPE_OBJECT_Format, SPA_PARAM_EnumFormat,
	SPA_FORMAT_mediaType,      SPA_POD_Id(SPA_MEDIA_TYPE_audio),
	SPA_FORMAT_mediaSubtype,   SPA_POD_Id(SPA_MEDIA_SUBTYPE_raw),
	SPA_FORMAT_AUDIO_format,   SPA_AUDIO_FORMAT_S16);
```

# POD layout

Each POD has a 32 bits size field, followed by a 32 bits type field. The size
field specifies the size following the type field.

Each POD is aligned to an 8 byte boundary.


