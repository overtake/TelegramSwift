> What is the array of spa_data in spa_buffer?

A buffer contains metadata and data. There can be many metadata items (headers, color info, cursor position, etc) in the buffer. The metadata items are stored in the metas array. In the same way, the buffer can contain multiple data blocks in the datas array. Each data block is, for example, a video plane or an audio channel. There are n_datas of those blocks.

> What is the void* data pointer in spa_data?

The data information either has a file descriptor or a data pointer. The type of the spa_data tells you what to expect. For a file descriptor, the data pointer can optionally be set when the fd is mapped into memory. Otherwise the user has to mmap the data herself.

Also associated with each spa_data is a chunk, which is read/write and contains the valid region in the spa_data (offset, size, stride and some flags).

The reason why is this set up like this is that the metadata memory, the data and chunks can be directly transported in shared memory while the buffer structure can be negotiated separately (describing the shared memory). This way buffers can be shared but no process can destroy the structure of the buffers.


	 * The buffer skeleton is placed in memory like below and can
	 * be accessed as a regular structure.
	 *
	 *      +==============================+
	 *      | struct spa_buffer            |
	 *      |   uint32_t n_metas           | number of metas
	 *      |   uint32_t n_datas           | number of datas
	 *    +-|   struct spa_meta *metas     | pointer to array of metas
	 *   +|-|   struct spa_data *datas     | pointer to array of datas
	 *   || +------------------------------+
	 *   |+>| struct spa_meta              |
	 *   |  |   uint32_t type              | metadata
	 *   |  |   uint32_t size              | size of metadata
	 *  +|--|   void *data                 | pointer to metadata
	 *  ||  | ... <n_metas>                | more spa_meta follow
	 *  ||  +------------------------------+
	 *  |+->| struct spa_data              |
	 *  |   |   uint32_t type              | memory type
	 *  |   |   uint32_t flags             |
	 *  |   |   int fd                     | fd of shared memory block
	 *  |   |   uint32_t mapoffset         | offset in shared memory of data
	 *  |   |   uint32_t maxsize           | size of data block
	 *  | +-|   void *data                 | pointer to data
	 *  |+|-|   struct spa_chunk *chunk    | pointer to chunk
	 *  ||| | ... <n_datas>                | more spa_data follow
	 *  ||| +==============================+
	 *  VVV
	 *
	 * metadata, chunk and memory can either be placed right
	 * after the skeleton (inlined) or in a separate piece of memory.
	 *
	 *  vvv
	 *  ||| +==============================+
	 *  +-->| meta data memory             | metadata memory, 8 byte aligned
	 *   || | ... <n_metas>                |
	 *   || +------------------------------+
	 *   +->| struct spa_chunk             | memory for n_datas chunks
	 *    | |   uint32_t offset            |
	 *    | |   uint32_t size              |
	 *    | |   int32_t stride             |
	 *    | |   int32_t dummy              |
	 *    | | ... <n_datas> chunks         |
	 *    | +------------------------------+
	 *    +>| data                         | memory for n_datas data, aligned
	 *      | ... <n_datas> blocks         | according to alignments
	 *      +==============================+
	 
Taken from [here](https://gitlab.freedesktop.org/pipewire/pipewire/-/blob/11f95fe11e07192cec19fddb4fafc708e023e49c/spa/include/spa/buffer/alloc.h).
