/* PipeWire
 *
 * Copyright © 2016 Wim Taymans <wim.taymans@gmail.com>
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

#ifndef PIPEWIRE_INTERFACES_V0_H
#define PIPEWIRE_INTERFACES_V0_H

#ifdef __cplusplus
extern "C" {
#endif

#include <spa/utils/defs.h>
#include <spa/param/param.h>
#include <spa/node/node.h>

#include <pipewire/pipewire.h>

/** Core */

#define PW_VERSION_CORE_V0			0

#define PW_CORE_V0_METHOD_HELLO		0
#define PW_CORE_V0_METHOD_UPDATE_TYPES	1
#define PW_CORE_V0_METHOD_SYNC		2
#define PW_CORE_V0_METHOD_GET_REGISTRY	3
#define PW_CORE_V0_METHOD_CLIENT_UPDATE	4
#define PW_CORE_V0_METHOD_PERMISSIONS	5
#define PW_CORE_V0_METHOD_CREATE_OBJECT	6
#define PW_CORE_V0_METHOD_DESTROY		7
#define PW_CORE_V0_METHOD_NUM		8

/**
 * Key to update default permissions of globals without specific
 * permissions. value is "[r][w][x]" */
#define PW_CORE_PERMISSIONS_DEFAULT	"permissions.default"

/**
 * Key to update specific permissions of a global. If the global
 * did not have specific permissions, it will first be assigned
 * the default permissions before it is updated.
 * Value is "<global-id>:[r][w][x]"*/
#define PW_CORE_PERMISSIONS_GLOBAL	"permissions.global"

/**
 * Key to update specific permissions of all existing globals.
 * This is equivalent to using \ref PW_CORE_PERMISSIONS_GLOBAL
 * on each global id individually that did not have specific
 * permissions.
 * Value is "[r][w][x]" */
#define PW_CORE_PERMISSIONS_EXISTING	"permissions.existing"

#define PW_LINK_OUTPUT_NODE_ID	"link.output_node.id"
#define PW_LINK_OUTPUT_PORT_ID	"link.output_port.id"
#define PW_LINK_INPUT_NODE_ID	"link.input_node.id"
#define PW_LINK_INPUT_PORT_ID	"link.input_port.id"

/**
 * \struct pw_core_v0_methods
 * \brief Core methods
 *
 * The core global object. This is a singleton object used for
 * creating new objects in the remote PipeWire instance. It is
 * also used for internal features.
 */
struct pw_core_v0_methods {
#define PW_VERSION_CORE_V0_METHODS	0
	uint32_t version;
	/**
	 * Start a conversation with the server. This will send
	 * the core info and server types.
	 *
	 * All the existing resources for the client (except the core
	 * resource) will be destroyed.
	 */
	void (*hello) (void *object);
	/**
	 * Update the type map
	 *
	 * Send a type map update to the PipeWire server. The server uses this
	 * information to keep a mapping between client types and the server types.
	 * \param first_id the id of the first type
	 * \param types the types as a string
	 * \param n_types the number of types
	 */
	void (*update_types) (void *object,
			      uint32_t first_id,
			      const char **types,
			      uint32_t n_types);
	/**
	 * Do server roundtrip
	 *
	 * Ask the server to emit the 'done' event with \a id.
	 * Since methods are handled in-order and events are delivered
	 * in-order, this can be used as a barrier to ensure all previous
	 * methods and the resulting events have been handled.
	 * \param seq the sequence number passed to the done event
	 */
	void (*sync) (void *object, uint32_t seq);
	/**
	 * Get the registry object
	 *
	 * Create a registry object that allows the client to list and bind
	 * the global objects available from the PipeWire server
	 * \param version the client proxy id
	 * \param id the client proxy id
	 */
	void (*get_registry) (void *object, uint32_t version, uint32_t new_id);
	/**
	 * Update the client properties
	 * \param props the new client properties
	 */
	void (*client_update) (void *object, const struct spa_dict *props);
	/**
	 * Manage the permissions of the global objects
	 *
	 * Update the permissions of the global objects using the
	 * dictionary with properties.
	 *
	 * Globals can use the default permissions or can have specific
	 * permissions assigned to them.
	 *
	 * \param id the global id to change
	 * \param props dictionary with permission properties
	 */
	void (*permissions) (void *object, const struct spa_dict *props);
	/**
	 * Create a new object on the PipeWire server from a factory.
	 * Use a \a factory_name of "client-node" to create a
	 * \ref pw_client_node.
	 *
	 * \param factory_name the factory name to use
	 * \param type the interface to bind to
	 * \param version the version of the interface
	 * \param props extra properties
	 * \param new_id the client proxy id
	 */
	void (*create_object) (void *object,
			       const char *factory_name,
			       uint32_t type,
			       uint32_t version,
			       const struct spa_dict *props,
			       uint32_t new_id);

	/**
	 * Destroy an object id
	 *
	 * \param id the object id to destroy
	 */
	void (*destroy) (void *object, uint32_t id);
};

#define PW_CORE_V0_EVENT_UPDATE_TYPES 0
#define PW_CORE_V0_EVENT_DONE         1
#define PW_CORE_V0_EVENT_ERROR        2
#define PW_CORE_V0_EVENT_REMOVE_ID    3
#define PW_CORE_V0_EVENT_INFO         4
#define PW_CORE_V0_EVENT_NUM          5

/** \struct pw_core_v0_events
 *  \brief Core events
 *  \ingroup pw_core_interface The pw_core interface
 */
struct pw_core_v0_events {
#define PW_VERSION_CORE_V0_EVENTS		0
	uint32_t version;
	/**
	 * Update the type map
	 *
	 * Send a type map update to the client. The client uses this
	 * information to keep a mapping between server types and the client types.
	 * \param first_id the id of the first type
	 * \param types the types as a string
	 * \param n_types the number of \a types
	 */
	void (*update_types) (void *object,
			      uint32_t first_id,
			      const char **types,
			      uint32_t n_types);
	/**
	 * Emit a done event
	 *
	 * The done event is emitted as a result of a sync method with the
	 * same sequence number.
	 * \param seq the sequence number passed to the sync method call
	 */
	void (*done) (void *object, uint32_t seq);
	/**
	 * Fatal error event
         *
         * The error event is sent out when a fatal (non-recoverable)
         * error has occurred. The id argument is the object where
         * the error occurred, most often in response to a request to that
         * object. The message is a brief description of the error,
         * for (debugging) convenience.
         * \param id object where the error occurred
         * \param res error code
         * \param error error description
	 */
	void (*error) (void *object, uint32_t id, int res, const char *error, ...);
	/**
	 * Remove an object ID
         *
         * This event is used internally by the object ID management
         * logic. When a client deletes an object, the server will send
         * this event to acknowledge that it has seen the delete request.
         * When the client receives this event, it will know that it can
         * safely reuse the object ID.
         * \param id deleted object ID
	 */
	void (*remove_id) (void *object, uint32_t id);
	/**
	 * Notify new core info
	 *
	 * \param info new core info
	 */
	void (*info) (void *object, struct pw_core_info *info);
};

#define pw_core_resource_v0_update_types(r,...) pw_resource_notify(r,struct pw_core_v0_events,update_types,__VA_ARGS__)
#define pw_core_resource_v0_done(r,...)         pw_resource_notify(r,struct pw_core_v0_events,done,__VA_ARGS__)
#define pw_core_resource_v0_error(r,...)        pw_resource_notify(r,struct pw_core_v0_events,error,__VA_ARGS__)
#define pw_core_resource_v0_remove_id(r,...)    pw_resource_notify(r,struct pw_core_v0_events,remove_id,__VA_ARGS__)
#define pw_core_resource_v0_info(r,...)         pw_resource_notify(r,struct pw_core_v0_events,info,__VA_ARGS__)


#define PW_VERSION_REGISTRY_V0			0

/** \page page_registry Registry
 *
 * \section page_registry_overview Overview
 *
 * The registry object is a singleton object that keeps track of
 * global objects on the PipeWire instance. See also \ref page_global.
 *
 * Global objects typically represent an actual object in PipeWire
 * (for example, a module or node) or they are singleton
 * objects such as the core.
 *
 * When a client creates a registry object, the registry object
 * will emit a global event for each global currently in the
 * registry.  Globals come and go as a result of device hotplugs or
 * reconfiguration or other events, and the registry will send out
 * global and global_remove events to keep the client up to date
 * with the changes.  To mark the end of the initial burst of
 * events, the client can use the pw_core.sync methosd immediately
 * after calling pw_core.get_registry.
 *
 * A client can bind to a global object by using the bind
 * request.  This creates a client-side proxy that lets the object
 * emit events to the client and lets the client invoke methods on
 * the object. See \ref page_proxy
 *
 * Clients can also change the permissions of the global objects that
 * it can see. This is interesting when you want to configure a
 * pipewire session before handing it to another application. You
 * can, for example, hide certain existing or new objects or limit
 * the access permissions on an object.
 */
#define PW_REGISTRY_V0_METHOD_BIND	0
#define PW_REGISTRY_V0_METHOD_NUM		1

/** Registry methods */
struct pw_registry_v0_methods {
#define PW_VERSION_REGISTRY_V0_METHODS	0
	uint32_t version;
	/**
	 * Bind to a global object
	 *
	 * Bind to the global object with \a id and use the client proxy
	 * with new_id as the proxy. After this call, methods can be
	 * send to the remote global object and events can be received
	 *
	 * \param id the global id to bind to
	 * \param type the interface type to bind to
	 * \param version the interface version to use
	 * \param new_id the client proxy to use
	 */
	void (*bind) (void *object, uint32_t id, uint32_t type, uint32_t version, uint32_t new_id);
};

#define PW_REGISTRY_V0_EVENT_GLOBAL             0
#define PW_REGISTRY_V0_EVENT_GLOBAL_REMOVE      1
#define PW_REGISTRY_V0_EVENT_NUM                2

/** Registry events */
struct pw_registry_v0_events {
#define PW_VERSION_REGISTRY_V0_EVENTS	0
	uint32_t version;
	/**
	 * Notify of a new global object
	 *
	 * The registry emits this event when a new global object is
	 * available.
	 *
	 * \param id the global object id
	 * \param parent_id the parent global id
	 * \param permissions the permissions of the object
	 * \param type the type of the interface
	 * \param version the version of the interface
	 * \param props extra properties of the global
	 */
	void (*global) (void *object, uint32_t id, uint32_t parent_id,
			uint32_t permissions, uint32_t type, uint32_t version,
			const struct spa_dict *props);
	/**
	 * Notify of a global object removal
	 *
	 * Emitted when a global object was removed from the registry.
	 * If the client has any bindings to the global, it should destroy
	 * those.
	 *
	 * \param id the id of the global that was removed
	 */
	void (*global_remove) (void *object, uint32_t id);
};

#define pw_registry_resource_v0_global(r,...)        pw_resource_notify(r,struct pw_registry_v0_events,global,__VA_ARGS__)
#define pw_registry_resource_v0_global_remove(r,...) pw_resource_notify(r,struct pw_registry_v0_events,global_remove,__VA_ARGS__)


#define PW_VERSION_MODULE_V0			0

#define PW_MODULE_V0_EVENT_INFO		0
#define PW_MODULE_V0_EVENT_NUM		1

/** Module events */
struct pw_module_v0_events {
#define PW_VERSION_MODULE_V0_EVENTS	0
	uint32_t version;
	/**
	 * Notify module info
	 *
	 * \param info info about the module
	 */
	void (*info) (void *object, struct pw_module_info *info);
};

#define pw_module_resource_v0_info(r,...)	pw_resource_notify(r,struct pw_module_v0_events,info,__VA_ARGS__)

#define PW_VERSION_NODE_V0		0

#define PW_NODE_V0_EVENT_INFO	0
#define PW_NODE_V0_EVENT_PARAM	1
#define PW_NODE_V0_EVENT_NUM	2

/** Node events */
struct pw_node_v0_events {
#define PW_VERSION_NODE_V0_EVENTS	0
	uint32_t version;
	/**
	 * Notify node info
	 *
	 * \param info info about the node
	 */
	void (*info) (void *object, struct pw_node_info *info);
	/**
	 * Notify a node param
	 *
	 * Event emitted as a result of the enum_params method.
	 *
	 * \param id the param id
	 * \param index the param index
	 * \param next the param index of the next param
	 * \param param the parameter
	 */
	void (*param) (void *object,
		       uint32_t id, uint32_t index, uint32_t next,
		       const struct spa_pod *param);
};

#define pw_node_resource_v0_info(r,...) pw_resource_notify(r,struct pw_node_v0_events,info,__VA_ARGS__)
#define pw_node_resource_v0_param(r,...) pw_resource_notify(r,struct pw_node_v0_events,param,__VA_ARGS__)

#define PW_NODE_V0_METHOD_ENUM_PARAMS	0
#define PW_NODE_V0_METHOD_NUM		1

/** Node methods */
struct pw_node_v0_methods {
#define PW_VERSION_NODE_V0_METHODS	0
	uint32_t version;
	/**
	 * Enumerate node parameters
	 *
	 * Start enumeration of node parameters. For each param, a
	 * param event will be emitted.
	 *
	 * \param id the parameter id to enum or PW_ID_ANY for all
	 * \param start the start index or 0 for the first param
	 * \param num the maximum number of params to retrieve
	 * \param filter a param filter or NULL
	 */
	void (*enum_params) (void *object, uint32_t id, uint32_t start, uint32_t num,
			const struct spa_pod *filter);
};

#define PW_VERSION_PORT_V0		0

#define PW_PORT_V0_EVENT_INFO	0
#define PW_PORT_V0_EVENT_PARAM	1
#define PW_PORT_V0_EVENT_NUM		2

/** Port events */
struct pw_port_v0_events {
#define PW_VERSION_PORT_V0_EVENTS	0
	uint32_t version;
	/**
	 * Notify port info
	 *
	 * \param info info about the port
	 */
	void (*info) (void *object, struct pw_port_info *info);
	/**
	 * Notify a port param
	 *
	 * Event emitted as a result of the enum_params method.
	 *
	 * \param id the param id
	 * \param index the param index
	 * \param next the param index of the next param
	 * \param param the parameter
	 */
	void (*param) (void *object,
		       uint32_t id, uint32_t index, uint32_t next,
		       const struct spa_pod *param);
};

#define pw_port_resource_v0_info(r,...) pw_resource_notify(r,struct pw_port_v0_events,info,__VA_ARGS__)
#define pw_port_resource_v0_param(r,...) pw_resource_notify(r,struct pw_port_v0_events,param,__VA_ARGS__)

#define PW_PORT_V0_METHOD_ENUM_PARAMS	0
#define PW_PORT_V0_METHOD_NUM		1

/** Port methods */
struct pw_port_v0_methods {
#define PW_VERSION_PORT_V0_METHODS	0
	uint32_t version;
	/**
	 * Enumerate port parameters
	 *
	 * Start enumeration of port parameters. For each param, a
	 * param event will be emitted.
	 *
	 * \param id the parameter id to enumerate
	 * \param start the start index or 0 for the first param
	 * \param num the maximum number of params to retrieve
	 * \param filter a param filter or NULL
	 */
	void (*enum_params) (void *object, uint32_t id, uint32_t start, uint32_t num,
			const struct spa_pod *filter);
};

#define PW_VERSION_FACTORY_V0		0

#define PW_FACTORY_V0_EVENT_INFO	0
#define PW_FACTORY_V0_EVENT_NUM		1

/** Factory events */
struct pw_factory_v0_events {
#define PW_VERSION_FACTORY_V0_EVENTS	0
	uint32_t version;
	/**
	 * Notify factory info
	 *
	 * \param info info about the factory
	 */
	void (*info) (void *object, struct pw_factory_info *info);
};

#define pw_factory_resource_v0_info(r,...) pw_resource_notify(r,struct pw_factory_v0_events,info,__VA_ARGS__)

#define PW_VERSION_CLIENT_V0		0

#define PW_CLIENT_V0_EVENT_INFO		0
#define PW_CLIENT_V0_EVENT_NUM		1

/** Client events */
struct pw_client_v0_events {
#define PW_VERSION_CLIENT_V0_EVENTS	0
	uint32_t version;
	/**
	 * Notify client info
	 *
	 * \param info info about the client
	 */
	void (*info) (void *object, struct pw_client_info *info);
};

#define pw_client_resource_v0_info(r,...) pw_resource_notify(r,struct pw_client_v0_events,info,__VA_ARGS__)


#define PW_VERSION_LINK_V0		0

#define PW_LINK_V0_EVENT_INFO	0
#define PW_LINK_V0_EVENT_NUM	1

/** Link events */
struct pw_link_v0_events {
#define PW_VERSION_LINK_V0_EVENTS	0
	uint32_t version;
	/**
	 * Notify link info
	 *
	 * \param info info about the link
	 */
	void (*info) (void *object, struct pw_link_info *info);
};

#define pw_link_resource_v0_info(r,...)      pw_resource_notify(r,struct pw_link_v0_events,info,__VA_ARGS__)

#ifdef __cplusplus
}  /* extern "C" */
#endif

#endif /* PIPEWIRE_INTERFACES_V0_H */
