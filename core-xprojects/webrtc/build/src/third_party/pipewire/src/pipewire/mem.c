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

#include "config.h"

#include <string.h>
#include <stddef.h>
#include <stdio.h>
#include <errno.h>
#include <sys/mman.h>
#include <fcntl.h>
#include <unistd.h>
#include <stdlib.h>
#include <sys/syscall.h>

#include <spa/utils/list.h>
#include <spa/buffer/buffer.h>

#include <pipewire/log.h>
#include <pipewire/map.h>
#include <pipewire/mem.h>

#define NAME "mempool"

#if !defined(__FreeBSD__) && !defined(HAVE_MEMFD_CREATE)
/*
 * No glibc wrappers exist for memfd_create(2), so provide our own.
 *
 * Also define memfd fcntl sealing macros. While they are already
 * defined in the kernel header file <linux/fcntl.h>, that file as
 * a whole conflicts with the original glibc header <fnctl.h>.
 */

static inline int memfd_create(const char *name, unsigned int flags)
{
	return syscall(SYS_memfd_create, name, flags);
}

#define HAVE_MEMFD_CREATE 1
#endif

#ifdef __FreeBSD__
#define MAP_LOCKED 0
#endif

/* memfd_create(2) flags */

#ifndef MFD_CLOEXEC
#define MFD_CLOEXEC       0x0001U
#endif

#ifndef MFD_ALLOW_SEALING
#define MFD_ALLOW_SEALING 0x0002U
#endif

/* fcntl() seals-related flags */

#ifndef F_LINUX_SPECIFIC_BASE
#define F_LINUX_SPECIFIC_BASE 1024
#endif

#ifndef F_ADD_SEALS
#define F_ADD_SEALS (F_LINUX_SPECIFIC_BASE + 9)
#define F_GET_SEALS (F_LINUX_SPECIFIC_BASE + 10)

#define F_SEAL_SEAL     0x0001	/* prevent further seals from being set */
#define F_SEAL_SHRINK   0x0002	/* prevent file from shrinking */
#define F_SEAL_GROW     0x0004	/* prevent file from growing */
#define F_SEAL_WRITE    0x0008	/* prevent writes */
#endif

static struct spa_list _mempools = SPA_LIST_INIT(&_mempools);

#define pw_mempool_emit(p,m,v,...) spa_hook_list_call(&p->listener_list, struct pw_mempool_events, m, v, ##__VA_ARGS__)
#define pw_mempool_emit_destroy(p)	pw_mempool_emit(p, destroy, 0)
#define pw_mempool_emit_added(p,b)	pw_mempool_emit(p, added, 0, b)
#define pw_mempool_emit_removed(p,b)	pw_mempool_emit(p, removed, 0, b)

struct mempool {
	struct pw_mempool this;

	struct spa_list link;		/* link in global _mempools */

	struct spa_hook_list listener_list;

	struct pw_map map;		/* map memblock to id */
	struct spa_list blocks;		/* list of memblock */
	uint32_t pagesize;
};

struct memblock {
	struct pw_memblock this;
	struct spa_list link;		/* link in mempool */
	struct spa_list mappings;	/* list of struct mapping */
	struct spa_list memmaps;	/* list of struct memmap */
};

/* a mapped region of a block */
struct mapping {
	struct memblock *block;
	int ref;
	uint32_t offset;
	uint32_t size;
	unsigned int do_unmap:1;
	struct spa_list link;
	void *ptr;
};

/* a reference to a (part of a) mapped region */
struct memmap {
	struct pw_memmap this;
	struct mapping *mapping;
	struct spa_list link;
};

struct pw_mempool *pw_mempool_new(struct pw_properties *props)
{
	struct mempool *impl;
	struct pw_mempool *this;

	impl = calloc(1, sizeof(struct mempool));
	if (impl == NULL)
		return NULL;

	this = &impl->this;
	this->props = props;

	impl->pagesize = sysconf(_SC_PAGESIZE);

	pw_log_debug(NAME" %p: new", this);

	spa_hook_list_init(&impl->listener_list);
	pw_map_init(&impl->map, 64, 64);
	spa_list_init(&impl->blocks);

	spa_list_append(&_mempools, &impl->link);

	return this;
}

void pw_mempool_clear(struct pw_mempool *pool)
{
	struct mempool *impl = SPA_CONTAINER_OF(pool, struct mempool, this);
	struct memblock *b;

	pw_log_debug(NAME" %p: clear", pool);

	spa_list_consume(b, &impl->blocks, link)
		pw_memblock_free(&b->this);
	pw_map_reset(&impl->map);
}

void pw_mempool_destroy(struct pw_mempool *pool)
{
	struct mempool *impl = SPA_CONTAINER_OF(pool, struct mempool, this);

	pw_log_debug(NAME" %p: destroy", pool);

	pw_mempool_emit_destroy(impl);

	pw_mempool_clear(pool);

	spa_list_remove(&impl->link);

	spa_hook_list_clean(&impl->listener_list);

	pw_map_clear(&impl->map);
	if (pool->props)
		pw_properties_free(pool->props);
	free(impl);
}


void pw_mempool_add_listener(struct pw_mempool *pool,
			     struct spa_hook *listener,
			     const struct pw_mempool_events *events,
			     void *data)
{
	struct mempool *impl = SPA_CONTAINER_OF(pool, struct mempool, this);
	spa_hook_list_append(&impl->listener_list, listener, events, data);
}

#if 0
/** Map a memblock
 * \param mem a memblock
 * \return 0 on success, < 0 on error
 * \memberof pw_memblock
 */
SPA_EXPORT
int pw_memblock_map_old(struct pw_memblock *mem)
{
	if (mem->ptr != NULL)
		return 0;

	if (mem->flags & PW_MEMBLOCK_FLAG_MAP_READWRITE) {
		int prot = 0;

		if (mem->flags & PW_MEMBLOCK_FLAG_MAP_READ)
			prot |= PROT_READ;
		if (mem->flags & PW_MEMBLOCK_FLAG_MAP_WRITE)
			prot |= PROT_WRITE;

		if (mem->flags & PW_MEMBLOCK_FLAG_MAP_TWICE) {
			void *ptr, *wrap;

			mem->ptr =
			    mmap(NULL, mem->size << 1, PROT_NONE, MAP_ANONYMOUS | MAP_PRIVATE, -1,
				 0);
			if (mem->ptr == MAP_FAILED)
				return -errno;

			ptr =
			    mmap(mem->ptr, mem->size, prot, MAP_FIXED | MAP_SHARED, mem->fd,
				 mem->offset);
			if (ptr != mem->ptr) {
				munmap(mem->ptr, mem->size << 1);
				return -ENOMEM;
			}

			wrap = SPA_MEMBER(mem->ptr, mem->size, void);

			ptr =
			    mmap(wrap, mem->size, prot, MAP_FIXED | MAP_SHARED,
				 mem->fd, mem->offset);
			if (ptr != wrap) {
				munmap(mem->ptr, mem->size << 1);
				return -ENOMEM;
			}
		} else {
			mem->ptr = mmap(NULL, mem->size, prot, MAP_SHARED, mem->fd, 0);
			if (mem->ptr == MAP_FAILED)
				return -errno;
		}
	} else {
		mem->ptr = NULL;
	}

	pw_log_debug(NAME" %p: map to %p", mem, mem->ptr);

	return 0;
}
#endif

static struct mapping * memblock_find_mapping(struct memblock *b,
		uint32_t flags, uint32_t offset, uint32_t size)
{
	struct mapping *m;
	struct pw_mempool *pool = b->this.pool;

	spa_list_for_each(m, &b->mappings, link) {
		pw_log_debug(NAME" %p: check %p offset:(%d <= %d) end:(%d >= %d)",
				pool, m, m->offset, offset, m->offset + m->size,
				offset + size);
		if (m->offset <= offset && (m->offset + m->size) >= (offset + size)) {
			pw_log_debug(NAME" %p: found %p id:%d fd:%d offs:%d size:%d ref:%d",
					pool, &b->this, b->this.id, b->this.fd,
					offset, size, b->this.ref);
			return m;
		}
	}
	return NULL;
}

static struct mapping * memblock_map(struct memblock *b,
		enum pw_memmap_flags flags, uint32_t offset, uint32_t size)
{
	struct mempool *p = SPA_CONTAINER_OF(b->this.pool, struct mempool, this);
	struct mapping *m;
	void *ptr;
	int prot = 0, fl = 0;

	if (flags & PW_MEMMAP_FLAG_READ)
		prot |= PROT_READ;
	if (flags & PW_MEMMAP_FLAG_WRITE)
		prot |= PROT_WRITE;

	if (flags & PW_MEMMAP_FLAG_PRIVATE)
		fl |= MAP_PRIVATE;
	else
		fl |= MAP_SHARED;

	if (flags & PW_MEMMAP_FLAG_LOCKED)
		fl |= MAP_LOCKED;

	if (flags & PW_MEMMAP_FLAG_TWICE) {
		pw_log_error(NAME" %p: implement me PW_MEMMAP_FLAG_TWICE", p);
		errno = ENOTSUP;
		return NULL;
	}


	ptr = mmap(NULL, size, prot, fl, b->this.fd, offset);
	if (ptr == MAP_FAILED) {
		pw_log_error(NAME" %p: Failed to mmap memory fd:%d offset:%u size:%u: %m",
				p, b->this.fd, offset, size);
		return NULL;
	}

	m = calloc(1, sizeof(struct mapping));
	if (m == NULL) {
		munmap(ptr, size);
		return NULL;
	}
	m->ptr = ptr;
	m->do_unmap = true;
	m->block = b;
	m->offset = offset;
	m->size = size;
	b->this.ref++;
	spa_list_append(&b->mappings, &m->link);

        pw_log_debug(NAME" %p: block:%p fd:%d map:%p ptr:%p (%d %d) block-ref:%d", p, &b->this,
			b->this.fd, m, m->ptr, offset, size, b->this.ref);

	return m;
}

static void mapping_free(struct mapping *m)
{
	struct memblock *b = m->block;
	struct mempool *p = SPA_CONTAINER_OF(b->this.pool, struct mempool, this);

        pw_log_debug(NAME" %p: mapping:%p block:%p fd:%d ptr:%p size:%d block-ref:%d",
			p, m, b, b->this.fd, m->ptr, m->size, b->this.ref);

	if (m->do_unmap)
		munmap(m->ptr, m->size);
	spa_list_remove(&m->link);
	free(m);
}

static void mapping_unmap(struct mapping *m)
{
	struct memblock *b = m->block;
	struct mempool *p = SPA_CONTAINER_OF(b->this.pool, struct mempool, this);
        pw_log_debug(NAME" %p: mapping:%p block:%p fd:%d ptr:%p size:%d block-ref:%d",
			p, m, b, b->this.fd, m->ptr, m->size, b->this.ref);
	mapping_free(m);
	pw_memblock_unref(&b->this);
}

SPA_EXPORT
struct pw_memmap * pw_memblock_map(struct pw_memblock *block,
		enum pw_memmap_flags flags, uint32_t offset, uint32_t size, uint32_t tag[5])
{
	struct memblock *b = SPA_CONTAINER_OF(block, struct memblock, this);
	struct mempool *p = SPA_CONTAINER_OF(block->pool, struct mempool, this);
	struct mapping *m;
	struct memmap *mm;
	struct pw_map_range range;

	pw_map_range_init(&range, offset, size, p->pagesize);

	m = memblock_find_mapping(b, flags, offset, size);
	if (m == NULL)
		m = memblock_map(b, flags, range.offset, range.size);
	if (m == NULL)
		return NULL;

	mm = calloc(1, sizeof(struct memmap));
	if (mm == NULL) {
		if (m->ref == 0)
			mapping_unmap(m);
		return NULL;
	}

	m->ref++;
	mm->mapping = m;
	mm->this.block = block;
	mm->this.flags = flags;
	mm->this.offset = offset;
	mm->this.size = size;
	mm->this.ptr = SPA_MEMBER(m->ptr, range.start, void);

        pw_log_debug(NAME" %p: map:%p block:%p fd:%d ptr:%p (%d %d) mapping:%p ref:%d", p,
			&mm->this, b, b->this.fd, mm->this.ptr, offset, size, m, m->ref);

	if (tag) {
		memcpy(mm->this.tag, tag, sizeof(mm->this.tag));
		pw_log_debug(NAME" %p: tag:%d:%d:%d:%d:%d", p,
			tag[0], tag[1], tag[2], tag[3], tag[4]);
	}

	spa_list_append(&b->memmaps, &mm->link);

	return &mm->this;
}

SPA_EXPORT
struct pw_memmap * pw_mempool_map_id(struct pw_mempool *pool,
		uint32_t id, enum pw_memmap_flags flags, uint32_t offset, uint32_t size, uint32_t tag[5])
{
	struct mempool *impl = SPA_CONTAINER_OF(pool, struct mempool, this);
	struct memblock *b;

	b = pw_map_lookup(&impl->map, id);
	if (b == NULL) {
		errno = ENOENT;
		return NULL;
	}
	return pw_memblock_map(&b->this, flags, offset, size, tag);
}

SPA_EXPORT
int pw_memmap_free(struct pw_memmap *map)
{
	struct memmap *mm = SPA_CONTAINER_OF(map, struct memmap, this);
	struct mapping *m = mm->mapping;
	struct memblock *b = m->block;
	struct mempool *p = SPA_CONTAINER_OF(b->this.pool, struct mempool, this);

        pw_log_debug(NAME" %p: map:%p block:%p fd:%d ptr:%p mapping:%p ref:%d", p,
			&mm->this, b, b->this.fd, mm->this.ptr, m, m->ref);

	spa_list_remove(&mm->link);

	if (--m->ref == 0)
		mapping_unmap(m);

	free(mm);

	return 0;
}

static inline enum pw_memmap_flags block_flags_to_mem(enum pw_memblock_flags flags)
{
	enum pw_memmap_flags fl = 0;

	if (flags & PW_MEMBLOCK_FLAG_READABLE)
		fl |= PW_MEMMAP_FLAG_READ;
	if (flags & PW_MEMBLOCK_FLAG_WRITABLE)
		fl |= PW_MEMMAP_FLAG_WRITE;

	return fl;
}

/** Create a new memblock
 * \param pool the pool to use
 * \param flags memblock flags
 * \param type the requested memory type one of enum spa_data_type
 * \param size size to allocate
 * \return a memblock structure or NULL with errno on error
 * \memberof pw_memblock
 */
SPA_EXPORT
struct pw_memblock * pw_mempool_alloc(struct pw_mempool *pool, enum pw_memblock_flags flags,
		uint32_t type, size_t size)
{
	struct mempool *impl = SPA_CONTAINER_OF(pool, struct mempool, this);
	struct memblock *b;
	int res;

	b = calloc(1, sizeof(struct memblock));
	if (b == NULL)
		return NULL;

	b->this.ref = 1;
	b->this.pool = pool;
	b->this.flags = flags;
	b->this.type = type;
	b->this.size = size;
	spa_list_init(&b->mappings);
	spa_list_init(&b->memmaps);

#ifdef HAVE_MEMFD_CREATE
	b->this.fd = memfd_create("pipewire-memfd", MFD_CLOEXEC | MFD_ALLOW_SEALING);
	if (b->this.fd == -1) {
		res = -errno;
		pw_log_error(NAME" %p: Failed to create memfd: %m", pool);
		goto error_free;
	}
#elif defined(__FreeBSD__)
	b->this.fd = shm_open(SHM_ANON, O_CREAT | O_RDWR | O_CLOEXEC, 0);
	if (b->this.fd == -1) {
		res = -errno;
		pw_log_error(NAME" %p: Failed to create SHM_ANON fd: %m", pool);
		goto error_free;
	}
#else
	char filename[] = "/dev/shm/pipewire-tmpfile.XXXXXX";
	b->this.fd = mkostemp(filename, O_CLOEXEC);
	if (b->this.fd == -1) {
		res = -errno;
		pw_log_error(NAME" %p: Failed to create temporary file: %m", pool);
		goto error_free;
	}
	unlink(filename);
#endif

	if (ftruncate(b->this.fd, size) < 0) {
		res = -errno;
		pw_log_warn(NAME" %p: Failed to truncate temporary file: %m", pool);
		goto error_close;
	}
#ifdef HAVE_MEMFD_CREATE
	if (flags & PW_MEMBLOCK_FLAG_SEAL) {
		unsigned int seals = F_SEAL_GROW | F_SEAL_SHRINK | F_SEAL_SEAL;
		if (fcntl(b->this.fd, F_ADD_SEALS, seals) == -1) {
			pw_log_warn(NAME" %p: Failed to add seals: %m", pool);
		}
	}
#endif
	if (flags & PW_MEMBLOCK_FLAG_MAP && size > 0) {
		b->this.map = pw_memblock_map(&b->this,
				block_flags_to_mem(flags), 0, size, NULL);
		if (b->this.map == NULL) {
			res = -errno;
			pw_log_warn(NAME" %p: Failed to map: %m", pool);
			goto error_close;
		}
		b->this.ref--;
	}

	b->this.id = pw_map_insert_new(&impl->map, b);
	spa_list_append(&impl->blocks, &b->link);
	pw_log_debug(NAME" %p: block:%p id:%d type:%u size:%zd", pool, &b->this, b->this.id, type, size);

	if (!SPA_FLAG_IS_SET(flags, PW_MEMBLOCK_FLAG_DONT_NOTIFY))
		pw_mempool_emit_added(impl, &b->this);

	return &b->this;

error_close:
	close(b->this.fd);
error_free:
	free(b);
	errno = -res;
	return NULL;
}

static struct memblock * mempool_find_fd(struct pw_mempool *pool, int fd)
{
	struct mempool *impl = SPA_CONTAINER_OF(pool, struct mempool, this);
	struct memblock *b;

	spa_list_for_each(b, &impl->blocks, link) {
		if (fd == b->this.fd) {
			pw_log_debug(NAME" %p: found %p id:%d fd:%d ref:%d",
					pool, &b->this, b->this.id, fd, b->this.ref);
			return b;
		}
	}
	return NULL;
}

SPA_EXPORT
struct pw_memblock * pw_mempool_import(struct pw_mempool *pool,
		enum pw_memblock_flags flags, uint32_t type, int fd)
{
	struct mempool *impl = SPA_CONTAINER_OF(pool, struct mempool, this);
	struct memblock *b;

	b = mempool_find_fd(pool, fd);
	if (b != NULL) {
		b->this.ref++;
		return &b->this;
	}

	b = calloc(1, sizeof(struct memblock));
	if (b == NULL)
		return NULL;

	spa_list_init(&b->memmaps);
	spa_list_init(&b->mappings);

	b->this.ref = 1;
	b->this.pool = pool;
	b->this.type = type;
	b->this.fd = fd;
	b->this.flags = flags;
	b->this.id = pw_map_insert_new(&impl->map, b);
	spa_list_append(&impl->blocks, &b->link);

	pw_log_debug(NAME" %p: block:%p id:%u flags:%08x type:%u fd:%d",
			pool, b, b->this.id, flags, type, fd);

	if (!SPA_FLAG_IS_SET(flags, PW_MEMBLOCK_FLAG_DONT_NOTIFY))
		pw_mempool_emit_added(impl, &b->this);

	return &b->this;
}

SPA_EXPORT
struct pw_memblock * pw_mempool_import_block(struct pw_mempool *pool,
		struct pw_memblock *mem)
{
	pw_log_debug(NAME" %p: import block:%p type:%d fd:%d", pool,
			mem, mem->type, mem->fd);
	return pw_mempool_import(pool,
			mem->flags | PW_MEMBLOCK_FLAG_DONT_CLOSE,
			mem->type, mem->fd);
}

SPA_EXPORT
struct pw_memmap * pw_mempool_import_map(struct pw_mempool *pool,
		struct pw_mempool *other, void *data, uint32_t size, uint32_t tag[5])
{
	struct pw_memblock *old, *block;
	struct memblock *b;
	struct pw_memmap *map;
	uint32_t offset;

	old = pw_mempool_find_ptr(other, data);
	if (old == NULL || old->map == NULL) {
		errno = EFAULT;
		return NULL;
	}

	block = pw_mempool_import_block(pool, old);
	if (block == NULL)
		return NULL;

	if (block->ref == 1) {
		struct mapping *m;

		b = SPA_CONTAINER_OF(block, struct memblock, this);

		m = calloc(1, sizeof(struct mapping));
		if (m == NULL) {
			pw_memblock_unref(block);
			return NULL;
		}
		m->ptr = old->map->ptr;
		m->block = b;
		m->offset = old->map->offset;
		m->size = old->map->size;
		spa_list_append(&b->mappings, &m->link);
		pw_log_debug(NAME" %p: mapping:%p block:%p offset:%u size:%u ref:%u",
				pool, m, block, m->offset, m->size, block->ref);
	} else {
		block->ref--;
	}

	offset = SPA_PTRDIFF(data, old->map->ptr);

	map = pw_memblock_map(block,
			block_flags_to_mem(block->flags), offset, size, tag);
	if (map == NULL)
		return NULL;

	pw_log_debug(NAME" %p: from pool:%p block:%p id:%u data:%p size:%u ref:%d",
			pool, other, block, block->id, data, size, block->ref);

	return map;
}

int pw_mempool_remove_id(struct pw_mempool *pool, uint32_t id)
{
	struct mempool *impl = SPA_CONTAINER_OF(pool, struct mempool, this);
	struct memblock *b;

	b = pw_map_lookup(&impl->map, id);
	if (b == NULL)
		return -ENOENT;

	pw_log_debug(NAME" %p: block:%p id:%d fd:%d ref:%d",
			pool, b, id, b->this.fd, b->this.ref);

	b->this.id = SPA_ID_INVALID;
	pw_map_remove(&impl->map, id);
	pw_memblock_unref(&b->this);

	return 0;
}

/** Free a memblock
 * \param mem a memblock
 * \memberof pw_memblock
 */
SPA_EXPORT
void pw_memblock_free(struct pw_memblock *block)
{
	struct memblock *b = SPA_CONTAINER_OF(block, struct memblock, this);
	struct pw_mempool *pool = block->pool;
	struct mempool *impl = SPA_CONTAINER_OF(pool, struct mempool, this);
	struct memmap *mm;
	struct mapping *m;

	spa_return_if_fail(block != NULL);

	pw_log_debug(NAME" %p: block:%p id:%d fd:%d ref:%d",
			pool, block, block->id, block->fd, block->ref);

	block->ref++;
	if (block->map)
		block->ref++;

	if (block->id != SPA_ID_INVALID)
		pw_map_remove(&impl->map, block->id);
	spa_list_remove(&b->link);

	if (!SPA_FLAG_IS_SET(block->flags, PW_MEMBLOCK_FLAG_DONT_NOTIFY))
		pw_mempool_emit_removed(impl, block);

	spa_list_consume(mm, &b->memmaps, link)
		pw_memmap_free(&mm->this);

	spa_list_consume(m, &b->mappings, link) {
		pw_log_warn(NAME" %p: stray mapping:%p", pool, m);
		mapping_free(m);
	}

	if (block->fd != -1 && !(block->flags & PW_MEMBLOCK_FLAG_DONT_CLOSE)) {
		pw_log_debug(NAME" %p: close fd:%d", pool, block->fd);
		close(block->fd);
	}
	free(b);
}

SPA_EXPORT
struct pw_memblock * pw_mempool_find_ptr(struct pw_mempool *pool, const void *ptr)
{
	struct mempool *impl = SPA_CONTAINER_OF(pool, struct mempool, this);
	struct memblock *b;
	struct mapping *m;

	spa_list_for_each(b, &impl->blocks, link) {
		spa_list_for_each(m, &b->mappings, link) {
			if (ptr >= m->ptr && ptr < SPA_MEMBER(m->ptr, m->size, void)) {
				pw_log_debug(NAME" %p: block:%p id:%d for %p", pool,
						b, b->this.id, ptr);
				return &b->this;
			}
		}
	}
	return NULL;
}

SPA_EXPORT
struct pw_memblock * pw_mempool_find_id(struct pw_mempool *pool, uint32_t id)
{
	struct mempool *impl = SPA_CONTAINER_OF(pool, struct mempool, this);
	struct memblock *b;

	b = pw_map_lookup(&impl->map, id);
	pw_log_debug(NAME" %p: block:%p for %d", pool, b, id);
	if (b == NULL)
		return NULL;

	return &b->this;
}

SPA_EXPORT
struct pw_memblock * pw_mempool_find_fd(struct pw_mempool *pool, int fd)
{
	struct memblock *b;

	b = mempool_find_fd(pool, fd);
	if (b == NULL)
		return NULL;

	return &b->this;
}

SPA_EXPORT
struct pw_memmap * pw_mempool_find_tag(struct pw_mempool *pool, uint32_t tag[5], size_t size)
{
	struct mempool *impl = SPA_CONTAINER_OF(pool, struct mempool, this);
	struct memblock *b;
	struct memmap *mm;

	pw_log_debug(NAME" %p: find tag %d:%d:%d:%d:%d size:%zd", pool,
			tag[0], tag[1], tag[2], tag[3], tag[4], size);

	spa_list_for_each(b, &impl->blocks, link) {
		spa_list_for_each(mm, &b->memmaps, link) {
			if (memcmp(tag, mm->this.tag, size) == 0) {
				pw_log_debug(NAME" %p: found %p", pool, mm);
				return &mm->this;
			}
		}
	}
	return NULL;
}
