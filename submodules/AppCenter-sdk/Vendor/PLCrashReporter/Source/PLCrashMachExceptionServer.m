/*
 * Author: Landon Fuller <landonf@bikemonkey.org>
 *
 * Copyright (c) 2012-2013 Plausible Labs Cooperative, Inc.
 * All rights reserved.
 *
 * Permission is hereby granted, free of charge, to any person
 * obtaining a copy of this software and associated documentation
 * files (the "Software"), to deal in the Software without
 * restriction, including without limitation the rights to use,
 * copy, modify, merge, publish, distribute, sublicense, and/or sell
 * copies of the Software, and to permit persons to whom the
 * Software is furnished to do so, subject to the following
 * conditions:
 *
 * The above copyright notice and this permission notice shall be
 * included in all copies or substantial portions of the Software.
 *
 * THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND,
 * EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES
 * OF MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND
 * NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT
 * HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY,
 * WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING
 * FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR
 * OTHER DEALINGS IN THE SOFTWARE.
 */

#include "PLCrashFeatureConfig.h"
#import "PLCrashMachExceptionPort.h"

#if PLCRASH_FEATURE_MACH_EXCEPTIONS

/*
 * WARNING:
 *
 * I've held off from implementing Mach exception handling due to the fact that the APIs required for a complete
 * implementation are not public on iOS. However, a commercial crash reporter is now shipping with support for Mach
 * exceptions, which implies that either they've received special dispensation to use private APIs / private structures,
 * they've found another way to do it, or they're just using undocumented functionality and hoping for the best.
 *
 * After filing a request with Apple DTS to clarify the issue, they provided the following guidance:
 *    Our engineers have reviewed your request and have determined that this would be best handled as a bug report,
 *    which you have already filed. _There is no documented way of accomplishing this, nor is there a workaround
 *    possible._
 *
 * Emphasis mine. As such, I don't believe it is be possible to support the use of Mach exceptions on iOS
 * without the use of undocumented functionality.
 *
 * Unfortunately, sigaltstack() is broken in later iOS releases, necessitating an alternative fix. Even if it wasn't
 * broken, it only ever supported handling stack overflow on the main thread, and mach exceptions would be a preferrable
 * solution.
 *
 * As such, this file provides a proof-of-concept implementation of Mach exception handling, intended to
 * provide support for Mac OS X using public API, and to ferret out what cannot be implemented on iOS
 * without the use of private API on iOS. Some developers have requested that Mach exceptions be provided as
 * option on iOS, which we may provide in the future.
 *
 * The following issues exist in the iOS implementation:
 *  - The msgh_id values required for an exception reply message are not available from the available
 *    headers and must be hard-coded. This prevents one from safely replying to exception messages, which
 *    means that it is impossible to (correctly) inform the server that an exception has *not* been
 *    handled.
 *
 *    Impact:
 *      This can lead to the process locking up and not dispatching to the host exception handler (eg, Apple's 
 *      crash reporter), depending on the behavior of the kernel exception code.
 *
 *  - The mach_* structure/type variants required by MACH_EXCEPTION_CODES are not publicly defined (on Mac OS X,
 *    these are provided by mach_exc.defs). This prevents one from forwarding exception messages to an existing
 *    handler that was registered with a MACH_EXCEPTION_CODES behavior.
 *    
 *    Impact:
 *      This can break forwarding to any task exception handler that registers itself with MACH_EXCEPTION_CODES.
 *      This is the case with LLDB; it will register a task exception handler with MACH_EXCEPTION_CODES set. Failure
 *      to correctly forward these exceptions will result in the debugger breaking in interesting ways; for example,
 *      changes to the set of dyld-loaded images are detected by setting a breakpoint on the dyld image registration
 *      funtions, and this functionality will break if the exception is not correctly forwarded.
 *
 * Since Mach exception handling is important for a fully functional crash reporter, I've also filed a radar
 * to request that the API be made public:
 *  Radar: rdar://12939497 RFE: Provide mach_exc.defs for iOS
 */

#import "PLCrashMachExceptionServer.h"
#import "PLCrashReporterNSError.h"
#import "PLCrashHostInfo.h"
#import "PLCrashAsync.h"

#import <pthread.h>
#import <stdatomic.h>

#import <mach/mach.h>
#import <mach/exc.h>

/* The msgh_id to use for thread termination messages. This value most not conflict with the MACH_NOTIFY_NO_SENDERS msgh_id, which
 * is the only other value currently sent on the server notify port */
#define PLCRASH_TERMINATE_MSGH_ID 0xDEADBEEF

#if PLCRASH_TERMINATE_MSGH_ID == MACH_NOTIFY_NO_SENDERS
#error The allocated message identifiers conflict.
#endif

#if PL_MACH64_EXC_API
#  import "mach_exc.h"
typedef __Request__mach_exception_raise_t PLRequest_exception_raise_t;
typedef __Reply__mach_exception_raise_t PLReply_exception_raise_t;
#else
typedef __Request__exception_raise_t PLRequest_exception_raise_t;
typedef __Reply__exception_raise_t PLReply_exception_raise_t;
#endif

#ifdef PL_MACH64_EXC_CODES
#  define PLCRASH_DEFAULT_BEHAVIOR (EXCEPTION_DEFAULT | MACH_EXCEPTION_CODES)
#else
#  define PLCRASH_DEFAULT_BEHAVIOR EXCEPTION_DEFAULT
#endif

/**
 * @internal
 * Map an exception type to its corresponding mask value.
 *
 * @note This needs to handle all exception types for which the exception server will be registered.
 */
static exception_mask_t exception_to_mask (exception_type_t exception) {
#define EXM(n) case EXC_ ## n: return EXC_MASK_ ## n;
    switch (exception) {
        EXM(BAD_ACCESS);
        EXM(BAD_INSTRUCTION);
        EXM(ARITHMETIC);
        EXM(EMULATION);
        EXM(BREAKPOINT);
        EXM(SOFTWARE);
        EXM(SYSCALL);
        EXM(MACH_SYSCALL);
        EXM(RPC_ALERT);
        EXM(CRASH);
#ifdef EXC_GUARD
        EXM(GUARD);
#endif
    }
#undef EXM

    /* This is very loosely gauranteed in exception_types.h; it's possible, though unlikely, that
     * a future exception type could diverge from the standard mask flag assignment. */
    PLCF_DEBUG("Unhandled exception type %d; exception_to_mask() should be updated", exception);

#ifdef PLCF_DEBUG_BUILD
    abort();
#else
    return (1 << exception);
#endif
}

/**
 * @internal
 *
 * Exception handler context.
 */
struct plcrash_exception_server_context {
    /** The server's mach thread. */
    thread_t server_thread;

    /** Registered exception port. */
    mach_port_t server_port;
    
    /** Notification port */
    mach_port_t notify_port;
    
    /** Listen port set */
    mach_port_t port_set;

    /** User callback. */
    PLCrashMachExceptionHandlerCallback callback;

    /** User callback context. */
    void *callback_context;

    /** Lock used to signal waiting initialization thread. */
    pthread_mutex_t lock;
    
    /** Condition used to signal waiting initialization thread. */
    pthread_cond_t server_cond;
    
    /**
     * Intended to be set by a controlling termination thread. Informs the mach exception
     * thread that it should de-register itself and then signal completion.
     *
     * This value must be updated atomically and with a memory barrier, as it will be accessed
     * without locking.
     */
    atomic_bool server_should_stop;

    /** Intended to be observed by the waiting initialization thread. Informs
     * the waiting thread that shutdown has completed . */
    bool server_stop_done;
};

/***
 * @internal
 *
 * Mach Exception Server.
 *
 * Implements monitoring of Mach exceptions on tasks and threads.
 *
 * @TODO We need to be able to determine if an exception can be/will/was handled by a signal handler. Failure
 * to detect such a case will result in spurious reports written for otherwise handled signals. See also:
 * https://bugzilla.xamarin.com/show_bug.cgi?id=4120
 *
 * @par Double Faults
 *
 * It may be valuable to be able to detect that your crash reporter itself crashed,
 * and if possible, provide debugging information that can be reported.
 *
 * How this is handled depends on whether you are running in-process, or out-of-process.
 *
 * @par Out-of-process
 *
 * In the case that the reporter is running out-of-process, it is recommended that you use a
 * crash reporter *on your crash reporter* to report the crash.
 *
 * It is less likely that a bug triggered by analyzing the target process will <em>also</em>
 * be triggered when analyzing the crash reporter itself.
 *
 * @par In-process
 *
 * When running in-process, it is far more likely that re-running the crash reporter
 * will trigger the same crash again. Thus, it is recommended that an implementor handle double
 * faults in a "safe mode" less likely to trigger an additional crash, and gauranteed to record
 * (at a minimum) that the crash report itself crashed, even if no additional crash data can be
 * recorded.
 *
 * This may be done by targeting the Mach exception server's thread with a thread-specific
 * crash handler. All callbacks will be issued on this thread, and it may be reliably targeted
 * to observe any crashes that occur within those callbacks.
 *
 * An example implementation might do the following:
 * - Before performing any other operations, create a cookie file on-disk that can be checked on
 *   startup to determine whether the crash reporter itself crashed. This at the very least will
 *   let API clients know that a problem exists (eg, a failure occured while generating the report).
 * - Re-run the crash report writer, disabling any risky code paths that are not strictly necessary, e.g.:
 *     - Disable local symbolication if it has been enabled by the user. This will avoid
 *       a great deal if binary parsing.
 *     - Disable reporting on any threads other than the crashed thread. This will avoid
 *       any bugs that may have occured in the stack unwinding code for existing threads.
 */
@implementation PLCrashMachExceptionServer

/**
 * Initialize a new Mach exception server.
 *
 * @param callback Callback called upon receipt of an exception. The callback will execute
 * on the exception server's thread, distinctly from the crashed thread.
 * @param context Context to be passed to the callback. May be NULL.
 * @param outError A pointer to an NSError object variable. If an error occurs initializing the exception server,
 * this pointer will contain an error object in the NSMachErrorDomain or NSPOSIXErrorDomain indicating why the
 * exception handler could not be registered. If no error occurs, this parameter will be left unmodified.
 * You may specify NULL for this parameter, and no error information will be provided.
 */
- (id) initWithCallBack: (PLCrashMachExceptionHandlerCallback) callback
                context: (void *) context
                  error: (NSError **) outError
{
    pthread_attr_t attr;
    pthread_t thr;
    kern_return_t kr;

    if ((self = [super init]) == nil)
        return nil;

    
    /* Initialize the bare context. */
    _serverContext = (struct plcrash_exception_server_context *) calloc(1, sizeof(*_serverContext));
    _serverContext->server_port = MACH_PORT_NULL;
    _serverContext->notify_port = MACH_PORT_NULL;
    _serverContext->port_set = MACH_PORT_NULL;
    _serverContext->server_thread = MACH_PORT_NULL;
    _serverContext->callback = callback;
    _serverContext->callback_context = context;
    
    if (pthread_mutex_init(&_serverContext->lock, NULL) != 0) {
        plcrash_populate_posix_error(outError, errno, @"Mutex initialization failed");
        
        free(_serverContext);
        _serverContext = NULL;
        return nil;
    }
    
    if (pthread_cond_init(&_serverContext->server_cond, NULL) != 0) {
        plcrash_populate_posix_error(outError, errno, @"Condition initialization failed");

        pthread_mutex_destroy(&_serverContext->lock);
        free(_serverContext);
        _serverContext = NULL;
        return nil;
    }
    
    /*
     * Initalize our server's port
     */
    kr = mach_port_allocate(mach_task_self(), MACH_PORT_RIGHT_RECEIVE, &_serverContext->server_port);
    if (kr != KERN_SUCCESS) {
        plcrash_populate_mach_error(outError, kr, @"Failed to allocate exception server's port");
        return nil;
    }
    
    /*
     * Initialize our notification port
     */
    kr = mach_port_allocate(mach_task_self(), MACH_PORT_RIGHT_RECEIVE, &_serverContext->notify_port);
    if (kr != KERN_SUCCESS) {
        plcrash_populate_mach_error(outError, kr, @"Failed to allocate exception server's port");
        return nil;
    }

    kr = mach_port_insert_right(mach_task_self(), _serverContext->notify_port, _serverContext->notify_port, MACH_MSG_TYPE_MAKE_SEND);
    if (kr != KERN_SUCCESS) {
        plcrash_populate_mach_error(outError, kr, @"Failed to add send right to exception server's port");
        return nil;
    }
    
    mach_port_t prev_notify_port;
    kr = mach_port_request_notification(mach_task_self(), _serverContext->server_port, MACH_NOTIFY_NO_SENDERS, 1, _serverContext->notify_port, MACH_MSG_TYPE_MAKE_SEND_ONCE, &prev_notify_port);
    if (kr != KERN_SUCCESS) {
        plcrash_populate_mach_error(outError, kr, @"Failed to request MACH_NOTIFY_NO_SENDERS on the exception server's port");
        return nil;
    }
    
    /*
     * Initialize our port set.
     */
    kr = mach_port_allocate(mach_task_self(), MACH_PORT_RIGHT_PORT_SET, &_serverContext->port_set);
    if (kr != KERN_SUCCESS) {
        plcrash_populate_mach_error(outError, kr, @"Failed to allocate exception server's port set");

        return nil;
    }

    /* Add the service port to the port set */
    kr = mach_port_move_member(mach_task_self(), _serverContext->server_port, _serverContext->port_set);
    if (kr != KERN_SUCCESS) {
        plcrash_populate_mach_error(outError, kr, @"Failed to add exception server port to port set");

        return nil;
    }

    /* Add the notify port to the port set */
    kr = mach_port_move_member(mach_task_self(), _serverContext->notify_port, _serverContext->port_set);
    if (kr != KERN_SUCCESS) {
        plcrash_populate_mach_error(outError, kr, @"Failed to add exception server notify port to port set");

        return nil;
    }

    /* Spawn the server thread. */
    {
        if (pthread_attr_init(&attr) != 0) {
            plcrash_populate_posix_error(outError, errno, @"Failed to initialize pthread_attr");

            return nil;
        }
        
        pthread_attr_setdetachstate(&attr, PTHREAD_CREATE_DETACHED);
        // TODO - A custom stack should be specified, using high/low guard pages to help prevent overwriting the stack
        // by crashing code.
        // pthread_attr_setstack(&attr, sp, stacksize);
        
        if (pthread_create(&thr, &attr, &exception_server_thread, _serverContext) != 0) {
            plcrash_populate_posix_error(outError, errno, @"Failed to create exception server thread");
            pthread_attr_destroy(&attr);

            return nil;
        }
        
        pthread_attr_destroy(&attr);
        
        /* Save the thread reference */
        _serverContext->server_thread = pthread_mach_thread_np(thr);
    }
    
    return self;
}

/**
 * Return the Mach thread on which the exception server is running.
 *
 * @warning The behavior of this method is undefined if the receiver
 * has not been registered as a mach exception server, or has been deregistered.
 */
- (thread_t) serverThread {
    NSAssert(_serverContext != NULL, @"No handler registered!");

    thread_t result;
    pthread_mutex_lock(&_serverContext->lock); {
        result = _serverContext->server_thread;
    } pthread_mutex_unlock(&_serverContext->lock);
    
    return result;
}

/**
 * Create and return a new send right for the receiver's Mach exception server. The callee is responsible
 * for deallocating the send right via mach_port_deallocate or similar.
 *
 * @param outError A pointer to an NSError object variable. If an error occurs, this pointer
 * will contain an error object indicating why the Mach send right could not be created. If no error
 * occurs, this parameter will be left unmodified. You may specify nil for this parameter, and no error information
 * will be provided.
 * @return Returns a valid mach send right on success; on error, MACH_PORT_NULL will be returned.
 *
 * @warning The exception server must be registered with a specific thread state type and behavior; these may be
 * fetched via the preferred PLCrashMachExceptionServer::exceptionPortWithMask:error:.
 */
- (mach_port_t) copySendRightForServerAndReturningError: (NSError **) outError {
    mach_port_t result;
    kern_return_t kr;

    pthread_mutex_lock(&_serverContext->lock); {
        /* Insert a send right; this will either create the right, or bump the reference count. */
        kr = mach_port_insert_right(mach_task_self(), _serverContext->server_port, _serverContext->server_port, MACH_MSG_TYPE_MAKE_SEND);
        if (kr != KERN_SUCCESS) {
            plcrash_populate_mach_error(outError, kr, @"Failed to insert Mach send right");
            
            pthread_mutex_unlock(&_serverContext->lock);
            return MACH_PORT_NULL;
        }
        
        result = _serverContext->server_port;
    }; pthread_mutex_unlock(&_serverContext->lock);

    return result;
}

/**
 * Create and return a new exception port instance for the receiver's Mach exception server. The returned instance
 * defines the behavior and flavor required by the Mach exception server, as well as providing a valid Mach
 * send right for the exception server.
 *
 * @param outError A pointer to an NSError object variable. If an error occurs, this pointer
 * will contain an error object in the NSMachErrorDomain indicating why the Mach send right could not be created. If no error
 * occurs, this parameter will be left unmodified. You may specify nil for this parameter, and no error information
 * will be provided.
 * @return Returns a valid Mach port instance on success; on error, nil will be returned.
 *
 * @note The newly allocated send right will be owned by the PLCrashMachExceptionPort instance; to ensure that the send
 * right survives for the lifetime of any exception server registration, the PLCrashMachExceptionPort must either be preserved,
 * or the underlying mach port's reference count should be incremented, eg, via mach_port_mod_refs() or mach_port_insert_right().
 */
- (PLCrashMachExceptionPort *) exceptionPortWithMask: (exception_mask_t) mask error: (NSError **) outError {
    /* Fetch a send right. Unless misconfigured, this should never fail */
    mach_port_t port = [self copySendRightForServerAndReturningError: outError];
    if (!MACH_PORT_VALID(port))
        return nil;

    /* Create the port oject */
    PLCrashMachExceptionPort *result;
    result = [[PLCrashMachExceptionPort alloc] initWithServerPort: port
                                                              mask: mask
                                                          behavior: PLCRASH_DEFAULT_BEHAVIOR
                                                            flavor: MACHINE_THREAD_STATE];

    /* Drop our send right */
    mach_port_deallocate(mach_task_self(), port);
    
    return result;
}


/**
 * Send a Mach exception reply for the given @a request and return the result.
 *
 * @param request The request to which a reply should be sent.
 * @param retcode The reply return code to supply.
 */
static mach_msg_return_t exception_server_reply (PLRequest_exception_raise_t *request, kern_return_t retcode) {
    PLReply_exception_raise_t reply;
    
    /* Initialize the reply */
    memset(&reply, 0, sizeof(reply));
    reply.Head.msgh_bits = MACH_MSGH_BITS(MACH_MSGH_BITS_REMOTE(request->Head.msgh_bits), 0);
    reply.Head.msgh_local_port = MACH_PORT_NULL;
    reply.Head.msgh_remote_port = request->Head.msgh_remote_port;
    reply.Head.msgh_size = sizeof(reply);
    reply.NDR = NDR_record;
    reply.RetCode = retcode;
    
    /*
     * Mach uses reply id offsets of 100. This is rather arbitrary, and in theory could be changed
     * in a future iOS release (although, it has stayed constant for nearly 24 years, so it seems unlikely
     * to change now). See the top-level file warning regarding use on iOS.
     *
     * On Mac OS X, the reply_id offset may be considered implicitly defined due to mach_exc.defs and
     * exc.defs being public.
     */
    reply.Head.msgh_id = request->Head.msgh_id + 100;
    
    /* Dispatch the reply */
    return mach_msg(&reply.Head, MACH_SEND_MSG, reply.Head.msgh_size, 0, MACH_PORT_NULL, MACH_MSG_TIMEOUT_NONE, MACH_PORT_NULL);
}


/**
 * Forward a Mach exception to the given exception to the first matching handler in @a state, if any.
 *
 * @param task The task in which the exception occured.
 * @param thread The thread on which the exception occured. The thread will be suspended when the callback is issued, and may be resumed
 * by the callback using thread_resume().
 * @param exception_type Mach exception type.
 * @param code Mach exception codes.
 * @param code_count The number of codes provided.
 * @param port_state The set of exception handlers to which the message should be forwarded.
 *
 * @return Returns KERN_SUCCESS if the exception was handled by a registered exception server, or an error
 * if the exception was not handled, or forwarding failed.
 *
 * @par In-Process Operation
 *
 * When operating in-process, handling the exception replies internally breaks external debuggers,
 * as they assume it is safe to leave our thread suspended. This results in the target thread never resuming,
 * as our thread never wakes up to reply to the message, or to handle future messages.
 *
 * The recommended solution is to simply not register a Mach exception handler in the case where a debugger
 * is already attached.
 *
 * @note This function may be called at crash-time.
 */
kern_return_t PLCrashMachExceptionForward (task_t task,
                                           thread_t thread,
                                           exception_type_t exception_type,
                                           mach_exception_data_t code,
                                           mach_msg_type_number_t code_count,
                                           plcrash_mach_exception_port_set_t *port_state)
{
    exception_behavior_t behavior;
    thread_state_flavor_t flavor;
    mach_port_t port;
    
    /* Find a matching handler */
    exception_mask_t fwd_mask = exception_to_mask(exception_type);
    bool found = false;
    for (mach_msg_type_number_t i = 0; i < port_state->count; i++) {
        if (!MACH_PORT_VALID(port_state->ports[i]))
            continue;
        
        if ((port_state->masks[i] & fwd_mask) == 0)
            continue;
        
        found = true;
        port = port_state->ports[i];
        behavior = port_state->behaviors[i];
        flavor = port_state->flavors[i];
        break;
    }
    
    /* No handler found */
    if (!found) {
        return KERN_FAILURE;
    }
    
    thread_state_data_t thread_state;
    mach_msg_type_number_t thread_state_count;
    kern_return_t kr;
    
    /* We prefer 64-bit codes; if the user requests 32-bit codes, we need to map them */
    exception_data_type_t code32[code_count];
    for (mach_msg_type_number_t i = 0; i < code_count; i++) {
        code32[i] = (exception_data_type_t)code[i];
    }
    
    /* Strip the MACH_EXCEPTION_CODES modifier from the behavior flags */
    bool mach_exc_codes = false;
    if (behavior & MACH_EXCEPTION_CODES) {
        mach_exc_codes = true;
        behavior &= ~MACH_EXCEPTION_CODES;
    }
    
    /*
     * Fetch thread state if required. When not required, 'flavor' will be invalid (eg, THREAD_STATE_NONE or similar), and
     * fetching the thread state will simply fail.
     */
    if (behavior != EXCEPTION_DEFAULT) {
        thread_state_count = THREAD_STATE_MAX;
        kr = thread_get_state (thread, flavor, thread_state, &thread_state_count);
        if (kr != KERN_SUCCESS) {
            PLCF_DEBUG("Failed to fetch thread state for thread=0x%x, flavor=0x%x, kr=0x%x", thread, flavor, kr);
            return kr;
        }
    }
    
    /* Handle the supported behaviors */
    switch (behavior) {
        case EXCEPTION_DEFAULT:
            if (mach_exc_codes) {
#if PL_MACH64_EXC_API
                return mach_exception_raise(port, thread, task, exception_type, code, code_count);
#endif
            } else {
                return exception_raise(port, thread, task, exception_type, code32, code_count);
            }
            break;
            
        case EXCEPTION_STATE:
            if (mach_exc_codes) {
#if PL_MACH64_EXC_API
                return mach_exception_raise_state(port, exception_type, code, code_count, &flavor, thread_state,
                                                  thread_state_count, thread_state, &thread_state_count);
#endif
            } else {
                return exception_raise_state(port, exception_type, code32, code_count, &flavor, thread_state,
                                             thread_state_count, thread_state, &thread_state_count);
            }
            break;
            
        case EXCEPTION_STATE_IDENTITY:
            if (mach_exc_codes) {
#if PL_MACH64_EXC_API
                return mach_exception_raise_state_identity(port, thread, task, exception_type, code,
                                                           code_count, &flavor, thread_state, thread_state_count, thread_state, &thread_state_count);
#endif
            } else {
                return exception_raise_state_identity(port, thread, task, exception_type, code32,
                                                      code_count, &flavor, thread_state, thread_state_count, thread_state, &thread_state_count);
            }
            break;
            
        default:
            /* Handled below */
            break;
    }
    
    PLCF_DEBUG("Unsupported exception behavior: 0x%x (MACH_EXCEPTION_CODES=%s)", behavior, mach_exc_codes ? "true" : "false");
    return KERN_FAILURE;
}


/**
 * Background exception server. Handles incoming exception messages and dispatches
 * them to the registered callback.
 *
 * This code must be written to be async-safe once a Mach exception message
 * has been returned, as the state of the process' threads is entirely unknown.
 */
static void *exception_server_thread (void *arg) {
    struct plcrash_exception_server_context *exc_context = (struct plcrash_exception_server_context *) arg;
    PLRequest_exception_raise_t *request = NULL;
    size_t request_size;
    kern_return_t kr;
    mach_msg_return_t mr;
    
    /* Initialize the received message with a default size */
    request_size = round_page(sizeof(*request));
    kr = vm_allocate(mach_task_self(), (vm_address_t *) &request, request_size, VM_FLAGS_ANYWHERE);
    if (kr != KERN_SUCCESS) {
        /* Shouldn't happen ... */
        fprintf(stderr, "Unexpected error in vm_allocate(): %x\n", kr);
        return NULL;
    }
    
    /* Wait for an exception message */
    while (true) {
        /* Initialize our request message */
        request->Head.msgh_local_port = exc_context->port_set;
        request->Head.msgh_size = (mach_msg_size_t)request_size;
        mr = mach_msg(&request->Head,
                      MACH_RCV_MSG | MACH_RCV_LARGE,
                      0,
                      request->Head.msgh_size,
                      exc_context->port_set,
                      MACH_MSG_TIMEOUT_NONE,
                      MACH_PORT_NULL);
        
        /* Handle recoverable errors */
        if (mr != MACH_MSG_SUCCESS && mr == MACH_RCV_TOO_LARGE) {
            /* Determine the new size (before dropping the buffer) */
            request_size = round_page(request->Head.msgh_size);
            
            /* Drop the old receive buffer */
            vm_deallocate(mach_task_self(), (vm_address_t) request, request_size);
            
            /* Re-allocate a larger receive buffer */
            kr = vm_allocate(mach_task_self(), (vm_address_t *) &request, request_size, VM_FLAGS_ANYWHERE);
            if (kr != KERN_SUCCESS) {
                /* Shouldn't happen ... */
                fprintf(stderr, "Unexpected error in vm_allocate(): 0x%x\n", kr);
                return NULL;
            }
            
            continue;
            
            /* Handle fatal errors */
        } else if (mr != MACH_MSG_SUCCESS) {
            /* Shouldn't happen ... */
            PLCF_DEBUG("Unexpected error in mach_msg(): 0x%x", mr);
            
            // TODO - Should we inform observers?
            
            continue;
            
            /* Success! */
        } else {
            /* Notify port handling */
            if (request->Head.msgh_local_port == exc_context->notify_port) {
                /* Handle no sender notifications */
                if (request->Head.msgh_id == MACH_NOTIFY_NO_SENDERS) {
                    /* TODO: This will be used to dispatch 'no sender' delegate messages, which can be used to track whether
                     * all mach exception clients have terminated. This is primarily useful in determining whether the exception
                     * server can shut down when running out-of-process and potentially servicing exception messages from
                     * multiple tasks. */
                    continue;
                }
            
                /* Detect termination messages. */
                if (request->Head.msgh_id == PLCRASH_TERMINATE_MSGH_ID) {
                    /* We intentionally do not acquire a lock here. It is possible that we've been woken
                     * spuriously with the process in an unknown state, in which case we must not call
                     * out to non-async-safe functions */
                    if (exc_context->server_should_stop) {
                        /* Inform the requesting thread of completion */
                        pthread_mutex_lock(&exc_context->lock); {
                            exc_context->server_stop_done = true;
                            pthread_cond_signal(&exc_context->server_cond);
                        } pthread_mutex_unlock(&exc_context->lock);
                        
                        /* Ensure a quick death if we access exc_context after termination  */
                        exc_context = NULL;
                        
                        /* Trigger cleanup */
                        break;
                    }
                }
            }

            /* Sanity check the message size */
            if (request->Head.msgh_size < sizeof(*request)) {
                PLCF_DEBUG("Unexpected message size of %" PRIu64, (uint64_t) request->Head.msgh_size);

                /* Provide a negative reply */
                mr = exception_server_reply(request, KERN_FAILURE);
                if (mr != MACH_MSG_SUCCESS)
                    PLCF_DEBUG("Unexpected failure replying to Mach exception message: 0x%x", mr);
                
                continue;
            }
            
            /* Map 32-bit codes to 64-bit types. */
#if !PL_MACH64_EXC_CODES
            mach_exception_data_type_t code64[request->codeCnt];
            for (mach_msg_type_number_t i = 0; i < request->codeCnt; i++) {
                code64[i] = (uint32_t) request->code[i];
            }
#elif PL_MACH64_EXC_API
            mach_exception_data_type_t *code64 = request->code;
#else
            /* XXX: When the mach_exc* types are unavailable (eg, iOS), we're forced to cast the 32-bit values to
             * 64-bit values. Our check below verifies that we won't crash here, but this is arguably inappropriate
             * use of the API. A request for access to the mach_* APIs has been filed as rdar://12939497 */
    
            /* We round up our allocation to a full page, and reallocate if the allocation isn't large enough;
             * this verifies that the returned request is large enough to contain 64-bit mach exception code data,
             * even when using the 32-bit types. */
            if (request_size - sizeof(*request) < (sizeof(mach_exception_data_type_t) * request->codeCnt)) {
                PLCF_DEBUG("Request is too small to contain 64-bit mach exception codes (0x%zu", request_size);
                continue;
            }
            mach_exception_data_type_t *code64 = (mach_exception_data_type_t *) request->code;
#endif
            
            /* Call our handler. */
            kern_return_t exc_result;
            exc_result = exc_context->callback(request->task.name,
                                               request->thread.name,
                                               request->exception,
                                               code64,
                                               request->codeCnt,
                                               exc_context->callback_context);
            
            /*
             * Reply to the message.
             */
            mr = exception_server_reply(request, exc_result);
            if (mr != MACH_MSG_SUCCESS)
                PLCF_DEBUG("Unexpected failure replying to Mach exception message: 0x%x", mr);
        }
    }
    
    /* Drop the receive buffer */
    if (request != NULL)
        vm_deallocate(mach_task_self(), (vm_address_t) request, request_size);
    
    return NULL;
}


/* We automatically stop the server on dealloc */
- (void) dealloc {
    mach_msg_return_t mr;
    
    if (_serverContext == NULL) {
        return;
    }

    /* Mark the server for termination */
    bool expected = false;
    atomic_compare_exchange_strong(&_serverContext->server_should_stop, &expected, true);

    /* Wake up the waiting server */
    mach_msg_header_t msg;
    memset(&msg, 0, sizeof(msg));
    msg.msgh_bits = MACH_MSGH_BITS(MACH_MSG_TYPE_COPY_SEND, MACH_MSG_TYPE_MAKE_SEND_ONCE);
    msg.msgh_local_port = MACH_PORT_NULL;
    msg.msgh_remote_port = _serverContext->notify_port;
    msg.msgh_size = sizeof(msg);
    msg.msgh_id = PLCRASH_TERMINATE_MSGH_ID;

    mr = mach_msg(&msg, MACH_SEND_MSG, msg.msgh_size, 0, MACH_PORT_NULL, MACH_MSG_TIMEOUT_NONE, MACH_PORT_NULL);

    if (mr != MACH_MSG_SUCCESS) {
        PLCR_LOG("Unexpected error sending termination message to background thread: %d", mr);
        return;
    }

    /* Wait for completion */
    pthread_mutex_lock(&_serverContext->lock);
    while (!_serverContext->server_stop_done) {
        pthread_cond_wait(&_serverContext->server_cond, &_serverContext->lock);
    }
    pthread_mutex_unlock(&_serverContext->lock);

    /* Server is now dead, can clean up all resources */
    if (_serverContext->server_port != MACH_PORT_NULL)
        mach_port_deallocate(mach_task_self(), _serverContext->server_port);
    
    if (_serverContext->notify_port != MACH_PORT_NULL)
        mach_port_deallocate(mach_task_self(), _serverContext->notify_port);
    
    if (_serverContext->port_set != MACH_PORT_NULL)
        mach_port_deallocate(mach_task_self(), _serverContext->port_set);

    pthread_cond_destroy(&_serverContext->server_cond);
    pthread_mutex_destroy(&_serverContext->lock);

    /* Once we've been signaled by the background thread, it will no longer access exc_context */
    free(_serverContext);
}

@end

#endif /* PLCRASH_FEATURE_MACH_EXCEPTIONS */
