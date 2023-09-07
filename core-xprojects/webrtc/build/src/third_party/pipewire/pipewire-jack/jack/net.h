/*
  Copyright (C) 2009-2010 Grame

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

#ifndef __net_h__
#define __net_h__

#ifdef __cplusplus
extern "C"
{
#endif

#include <jack/systemdeps.h>
#include <jack/types.h>
#include <jack/weakmacros.h>

#define DEFAULT_MULTICAST_IP    "225.3.19.154"
#define DEFAULT_PORT            19000
#define DEFAULT_MTU             1500
#define MASTER_NAME_SIZE        256

// Possible error codes

#define NO_ERROR             0
#define SOCKET_ERROR        -1
#define SYNC_PACKET_ERROR   -2
#define DATA_PACKET_ERROR   -3

#define RESTART_CB_API 1

enum JackNetEncoder {

    JackFloatEncoder = 0,   // samples are transmitted as float
    JackIntEncoder = 1,     // samples are transmitted as 16 bits integer
    JackCeltEncoder = 2,    // samples are transmitted using CELT codec (http://www.celt-codec.org/)
    JackOpusEncoder = 3,    // samples are transmitted using OPUS codec (http://www.opus-codec.org/)
};

typedef struct {

    int audio_input;    // from master or to slave (-1 to take master audio physical inputs)
    int audio_output;   // to master or from slave (-1 to take master audio physical outputs)
    int midi_input;     // from master or to slave (-1 to take master MIDI physical inputs)
    int midi_output;    // to master or from slave (-1 to take master MIDI physical outputs)
    int mtu;            // network Maximum Transmission Unit
    int time_out;       // in second, -1 means infinite
    int encoder;        // encoder type (one of JackNetEncoder)
    int kbps;           // KB per second for CELT or OPUS codec
    int latency;        // network latency in number of buffers

} jack_slave_t;

typedef struct {

    int audio_input;                    // master audio physical outputs (-1 to take slave wanted audio inputs)
    int audio_output;                   // master audio physical inputs (-1 to take slave wanted audio outputs)
    int midi_input;                     // master MIDI physical outputs (-1 to take slave wanted MIDI inputs)
    int midi_output;                    // master MIDI physical inputs (-1 to take slave wanted MIDI outputs)
    jack_nframes_t buffer_size;         // master buffer size
    jack_nframes_t sample_rate;         // master sample rate
    char master_name[MASTER_NAME_SIZE]; // master machine name
    int time_out;                       // in second, -1 means infinite
    int partial_cycle;                  // if 'true', partial buffers will be used 

} jack_master_t;

/**
 *  jack_net_slave_t is an opaque type. You may only access it using the
 *  API provided.
 */
typedef struct _jack_net_slave jack_net_slave_t;

 /**
 * Open a network connection with the master machine.
 *
 * @param ip the multicast address of the master
 * @param port the connection port
 * @param name the JACK client name
 * @param request a connection request structure
 * @param result a connection result structure
 *
 * @return Opaque net handle if successful or NULL in case of error.
 */
jack_net_slave_t* jack_net_slave_open(const char* ip, int port, const char* name, jack_slave_t* request, jack_master_t* result);

/**
 * Close the network connection with the master machine.
 *
 * @param net the network connection to be closed
 *
 * @return 0 on success, otherwise a non-zero error code
 */
int jack_net_slave_close(jack_net_slave_t* net);

/**
 * Prototype for Process callback.
 *
 * @param nframes buffer size
 * @param audio_input number of audio inputs
 * @param audio_input_buffer an array of audio input buffers (from master)
 * @param midi_input number of MIDI inputs
 * @param midi_input_buffer an array of MIDI input buffers (from master)
 * @param audio_output number of audio outputs
 * @param audio_output_buffer an array of audio output buffers (to master)
 * @param midi_output number of MIDI outputs
 * @param midi_output_buffer an array of MIDI output buffers (to master)
 * @param arg pointer to a client supplied structure supplied by jack_set_net_process_callback()
 *
 * @return zero on success, non-zero on error
 */
typedef int (* JackNetSlaveProcessCallback) (jack_nframes_t buffer_size,
                                            int audio_input,
                                            float** audio_input_buffer,
                                            int midi_input,
                                            void** midi_input_buffer,
                                            int audio_output,
                                            float** audio_output_buffer,
                                            int midi_output,
                                            void** midi_output_buffer,
                                            void* data);

/**
 * Set network process callback.
 *
 * @param net the network connection
 * @param net_callback the process callback
 * @param arg pointer to a client supplied structure
 *
 * @return 0 on success, otherwise a non-zero error code
 */
int jack_set_net_slave_process_callback(jack_net_slave_t * net, JackNetSlaveProcessCallback net_callback, void *arg);

/**
 * Start processing thread, the net_callback will start to be called.
 *
 * @param net the network connection
 *
 * @return 0 on success, otherwise a non-zero error code
 */
int jack_net_slave_activate(jack_net_slave_t* net);

/**
 * Stop processing thread.
 *
 * @param net the network connection
 *
 * @return 0 on success, otherwise a non-zero error code
 */
int jack_net_slave_deactivate(jack_net_slave_t* net);

/**
 * Test if slave is still active.
 *
 * @param net the network connection
 *
 * @return a boolean 
 */
int jack_net_slave_is_active(jack_net_slave_t* net);

/**
 * Prototype for BufferSize callback.
 *
 * @param nframes buffer size
 * @param arg pointer to a client supplied structure supplied by jack_set_net_buffer_size_callback()
 *
 * @return zero on success, non-zero on error
 */
typedef int (*JackNetSlaveBufferSizeCallback)(jack_nframes_t nframes, void *arg);

/**
 * Set network buffer size callback.
 *
 * @param net the network connection
 * @param bufsize_callback the buffer size callback
 * @param arg pointer to a client supplied structure
 *
 * @return 0 on success, otherwise a non-zero error code
 */
int jack_set_net_slave_buffer_size_callback(jack_net_slave_t *net, JackNetSlaveBufferSizeCallback bufsize_callback, void *arg);

/**
 * Prototype for SampleRate callback.
 *
 * @param nframes sample rate
 * @param arg pointer to a client supplied structure supplied by jack_set_net_sample_rate_callback()
 *
 * @return zero on success, non-zero on error
 */
typedef int (*JackNetSlaveSampleRateCallback)(jack_nframes_t nframes, void *arg);

/**
 * Set network sample rate callback.
 *
 * @param net the network connection
 * @param samplerate_callback the sample rate callback
 * @param arg pointer to a client supplied structure
 *
 * @return 0 on success, otherwise a non-zero error code
 */
int jack_set_net_slave_sample_rate_callback(jack_net_slave_t *net, JackNetSlaveSampleRateCallback samplerate_callback, void *arg);

/**
 * Prototype for server Shutdown callback (if not set, the client will just restart, waiting for an available master again).
 *
 * @param arg pointer to a client supplied structure supplied by jack_set_net_shutdown_callback()
 */
typedef void (*JackNetSlaveShutdownCallback)(void* arg);

/**
 * Set network shutdown callback.
 *
 * @param net the network connection
 * @param shutdown_callback the shutdown callback
 * @param arg pointer to a client supplied structure
 *
 * @return 0 on success, otherwise a non-zero error code
 */
int jack_set_net_slave_shutdown_callback(jack_net_slave_t *net, JackNetSlaveShutdownCallback shutdown_callback, void *arg) JACK_OPTIONAL_WEAK_DEPRECATED_EXPORT;

/**
 * Prototype for server Restart callback : this is the new preferable way to be notified when the master has disappeared. 
 * The client may want to retry connecting a certain number of time (which will be done using the time_out value given in jack_net_slave_open) 
 * by returning 0. Otherwise returning a non-zero error code will definitively close the connection 
 * (and jack_net_slave_is_active will later on return false).
 * If both Shutdown and Restart are supplied, Restart callback will be used.
 *
 * @param arg pointer to a client supplied structure supplied by jack_set_net_restart_callback()
 *
 * @return 0 on success, otherwise a non-zero error code
 */
typedef int (*JackNetSlaveRestartCallback)(void* arg);

/**
 * Set network restart callback.
 *
 * @param net the network connection
 * @param restart_callback the shutdown callback
 * @param arg pointer to a client supplied structure
 *
 * @return 0 on success, otherwise a non-zero error code
 */
int jack_set_net_slave_restart_callback(jack_net_slave_t *net, JackNetSlaveRestartCallback restart_callback, void *arg) JACK_OPTIONAL_WEAK_EXPORT;

/**
 * Prototype for server Error callback.
 *
 * @param error_code an error code (see "Possible error codes")
 * @param arg pointer to a client supplied structure supplied by jack_set_net_error_callback()
 */
typedef void (*JackNetSlaveErrorCallback) (int error_code, void* arg);

/**
 * Set error restart callback.
 *
 * @param net the network connection
 * @param error_callback the error callback
 * @param arg pointer to a client supplied structure
 *
 * @return 0 on success, otherwise a non-zero error code
 */
int jack_set_net_slave_error_callback(jack_net_slave_t *net, JackNetSlaveErrorCallback error_callback, void *arg) JACK_OPTIONAL_WEAK_EXPORT;

/**
 *  jack_net_master_t is an opaque type, you may only access it using the API provided.
 */
typedef struct _jack_net_master jack_net_master_t;

 /**
 * Open a network connection with the slave machine.
 *
 * @param ip the multicast address of the master
 * @param port the connection port
 * @param request a connection request structure
 * @param result a connection result structure
 *
 * @return Opaque net handle if successful or NULL in case of error.
 */
jack_net_master_t* jack_net_master_open(const char* ip, int port, jack_master_t* request, jack_slave_t* result);

/**
 * Close the network connection with the slave machine.
 *
 * @param net the network connection to be closed
 *
 * @return 0 on success, otherwise a non-zero error code
 */
int jack_net_master_close(jack_net_master_t* net);

/**
 * Receive sync and data from the network (complete buffer).
 *
 * @param net the network connection
 * @param audio_input number of audio inputs
 * @param audio_input_buffer an array of audio input buffers
 * @param midi_input number of MIDI inputs
 * @param midi_input_buffer an array of MIDI input buffers
 *
 * @return zero on success, non-zero on error
 */
int jack_net_master_recv(jack_net_master_t* net, int audio_input, float** audio_input_buffer, int midi_input, void** midi_input_buffer);

/**
 * Receive sync and data from the network (incomplete buffer).
 *
 * @param net the network connection
 * @param audio_input number of audio inputs
 * @param audio_input_buffer an array of audio input buffers
 * @param midi_input number of MIDI inputs
 * @param midi_input_buffer an array of MIDI input buffers
 * @param frames the number of frames to receive
 *
 * @return zero on success, non-zero on error
 */
int jack_net_master_recv_slice(jack_net_master_t* net, int audio_input, float** audio_input_buffer, int midi_input, void** midi_input_buffer, int frames);

/**
 * Send sync and data to the network (complete buffer).
 *
 * @param net the network connection
 * @param audio_output number of audio outputs
 * @param audio_output_buffer an array of audio output buffers
 * @param midi_output number of MIDI outputs
 * @param midi_output_buffer an array of MIDI output buffers
 *
 * @return zero on success, non-zero on error
 */
int jack_net_master_send(jack_net_master_t* net, int audio_output, float** audio_output_buffer, int midi_output, void** midi_output_buffer);

/**
 * Send sync and data to the network (incomplete buffer).
 *
 * @param net the network connection
 * @param audio_output number of audio outputs
 * @param audio_output_buffer an array of audio output buffers
 * @param midi_output number of MIDI outputs
 * @param midi_output_buffer an array of MIDI output buffers
 * @param frames the number of frames to send
 *
 * @return zero on success, non-zero on error
 */
int jack_net_master_send_slice(jack_net_master_t* net, int audio_output, float** audio_output_buffer, int midi_output, void** midi_output_buffer, int frames);

// Experimental Adapter API

/**
 *  jack_adapter_t is an opaque type, you may only access it using the API provided.
 */
typedef struct _jack_adapter jack_adapter_t;

/**
 * Create an adapter.
 *
 * @param input number of audio inputs
 * @param output of audio outputs
 * @param host_buffer_size the host buffer size in frames
 * @param host_sample_rate the host buffer sample rate
 * @param adapted_buffer_size the adapted buffer size in frames
 * @param adapted_sample_rate the adapted buffer sample rate
 *
 * @return 0 on success, otherwise a non-zero error code
 */
jack_adapter_t* jack_create_adapter(int input, int output,
                                    jack_nframes_t host_buffer_size,
                                    jack_nframes_t host_sample_rate,
                                    jack_nframes_t adapted_buffer_size,
                                    jack_nframes_t adapted_sample_rate);

/**
 * Destroy an adapter.
 *
 * @param adapter the adapter to be destroyed
 *
 * @return 0 on success, otherwise a non-zero error code
 */
int jack_destroy_adapter(jack_adapter_t* adapter);

/**
 * Flush internal state of an adapter.
 *
 * @param adapter the adapter to be flushed
 *
 * @return 0 on success, otherwise a non-zero error code
 */
void jack_flush_adapter(jack_adapter_t* adapter);

/**
 * Push input to and pull output from adapter ringbuffer.
 *
 * @param adapter the adapter
 * @param input an array of audio input buffers
 * @param output an array of audio output buffers
 * @param frames number of frames
 *
 * @return 0 on success, otherwise a non-zero error code
 */
int jack_adapter_push_and_pull(jack_adapter_t* adapter, float** input, float** output, unsigned int frames);

/**
 * Pull input from and push output to adapter ringbuffer.
 *
 * @param adapter the adapter
 * @param input an array of audio input buffers
 * @param output an array of audio output buffers
 * @param frames number of frames
 *
 * @return 0 on success, otherwise a non-zero error code
 */
int jack_adapter_pull_and_push(jack_adapter_t* adapter, float** input, float** output, unsigned int frames);

#ifdef __cplusplus
}
#endif

#endif /* __net_h__ */
