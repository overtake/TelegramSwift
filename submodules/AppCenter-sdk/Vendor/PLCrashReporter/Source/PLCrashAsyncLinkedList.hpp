/*
 * Author: Landon Fuller <landonf@plausible.coop>
 *
 * Copyright (c) 2008-2013 Plausible Labs Cooperative, Inc.
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

#ifndef PLCRASH_ASYNC_LINKED_LIST_H
#define PLCRASH_ASYNC_LINKED_LIST_H 1

#include "PLCrashAsync.h"
#include "PLCrashMacros.h"
#include "PLCrashCompatConstants.h"
#include <atomic>

PLCR_CPP_BEGIN_NS

namespace async {
    
    
/**
 * @internal
 * @ingroup plcrash_async
 *
 * An async-safe linked list implementation.
 *
 * Maintains a linked list with support for async-safe iteration. Writing may occur concurrently with
 * async-safe reading, but is not async-safe.
 *
 * Atomic compare and swap is used to ensure a consistent view of the list for readers. To simplify implementation, a
 * write mutex is held for all updates; the implementation is not designed for efficiency in the face of contention
 * between readers and writers, and it's assumed that no contention should realistically occur.
 *
 * @tparam V The list element type. 
 */
template <typename V>
class async_list {
public:
    /**
     * Async-safe image list element.
     */
    class node {
    public:
        friend class async_list<V>;
        
        // Custom new/delete that do not rely on the stdlib
        void *operator new (size_t size) {
            void *ptr = malloc(size);
            PLCF_ASSERT(ptr != NULL);
            return ptr;
        }
        void operator delete (void *ptr) {
            free(ptr);
        }
        
        /**
         * Return the list item value.
         */
        V value (void) {
            return _value;
        }

    private:
        
        /**
         * Construct a new node with @a value.
         *
         * @param value The value for this node.
         */
        node (V value) {
            _value = value;
            _prev = NULL;
            _next = NULL;
        }
        
        /**
         * Reset a node for re-use.
         *
         * @param value The new value for this node.
         */
        void reset (V value) {
            _value = value;
            _prev = NULL;
            _next = NULL;
        }
    
        /** The list entry value. */
        V _value;
        
        /** The previous item in the list, or NULL */
        node *_prev;
        
        /** The next image in the list, or NULL. */
        std::atomic<node *> _next;
    };

    async_list (void);
    ~async_list (void);
    
    void nasync_prepend (V value);
    void nasync_append (V value);
    void nasync_remove_first_value (V value);
    void nasync_remove_node (node *deleted_node);
    void set_reading (bool enable);
    node *next (node *current);
    
    // Custom new/delete that do not rely on the stdlib
    void *operator new (size_t size) {
        void *ptr = malloc(size);
        PLCF_ASSERT(ptr != NULL);
        return ptr;
    }
    void operator delete (void *ptr) { free(ptr); }
    
    /**
     * Sanity check list validity. Intended to be used from the unit tests; will fire
     * an assertion if the list structure is invalid.
     *
     * This method acquires no locks and is not thread-safe. It should not be used
     * when making concurrent changes to the list, or otherwise outside of a test environment.
     */
    inline void assert_list_valid (void) {
        /* Verify list linkage in both directions. */
        node *prev = NULL;
        for (node *cur = _head; cur != NULL; cur = cur->_next) {
            PLCF_ASSERT(cur->_prev == prev);
            prev = cur;
        }
        
        PLCF_ASSERT(prev == _tail);
    }

private:
    void free_list (node *next);

    /** The lock used by writers. No lock is required for readers. */
    PLCR_COMPAT_LOCK_TYPE _write_lock;
    
    /** The head of the list, or NULL if the list is empty. Must only be used to iterate or delete entries. */
    std::atomic<node *> _head;
    
    /** The tail of the list, or NULL if the list is empty. Must only be used to append new entries. */
    node *_tail;
    
    /** The list reference count. No nodes will be deallocated while the count is greater than 0. If the count
     * reaches 0, all nodes in the free list will be deallocated. */
    std::atomic_int32_t _refcount;
    
    /** The node free list. */
    node *_free;
};

/** Construct a new, empty linked list */
template <typename V> async_list<V>::async_list (void) {
    _head = NULL;
    _tail = NULL;
    _free = NULL;
    _refcount = 0;
    _write_lock = PLCR_COMPAT_LOCK_INIT;
}
    
template <typename V> async_list<V>::~async_list (void) {
    /* Free all nodes */
    if (_head != NULL)
        free_list(_head);
    
    if (_free != NULL)
        free_list(_free);
}

/**
 * Prepend a new entry value to the list
 *
 * @param value The value to be prepended.
 *
 * @warning This method is not async safe.
 */
template <typename V> void async_list<V>::nasync_prepend (V value) {
    /* Lock the list from other writers. */
    PLCR_COMPAT_LOCK_LOCK(&_write_lock); {
        /* Construct the new entry, or recycle an existing one. */
        node *new_node;
        if (_free != NULL) {
            /* Fetch a node from the free list */
            new_node = _free;
            new_node->reset(value);
            
            /* Update the free list */
            _free = _free->_next;
        } else {
            new_node = new node(value);
        }
        
        /* Issue a memory barrier to ensure a consistent view of the value. */
        std::atomic_thread_fence(std::memory_order_seq_cst);
        
        /* If this is the first entry, initialize the list. */
        if (_tail == NULL) {
            
            /* Update the list tail. This need not be done atomically, as tail is never accessed by a lockless reader. */
            _tail = new_node;
            
            /* Atomically update the list head; this will be iterated upon by lockless readers. */
            node *expected = NULL;
            if (!_head.compare_exchange_strong(expected, new_node)) {
                /* Should never occur */
                PLCF_DEBUG("An async image head was set with tail == NULL despite holding lock.");
            }
        }
        
        /* Otherwise, prepend to the head of the list */
        else {
            new_node->_next = (node *)_head;
            new_node->_prev = NULL;
            
            /* Update the prev pointers. This is never accessed without a lock, so no additional synchronization
             * is required here. */
            ((node *)_head)->_prev = new_node;

            /* Issue a memory barrier to ensure a consistent view of the nodes. */
            std::atomic_thread_fence(std::memory_order_seq_cst);

            /* Atomically slot the new record into place; this may be iterated on by a lockless reader. */
            node *expected = new_node->_next;
            if (!_head.compare_exchange_strong(expected, new_node)) {
                PLCF_DEBUG("Failed to prepend to image list despite holding lock");
            }
        }
    } PLCR_COMPAT_LOCK_UNLOCK(&_write_lock);
}


/**
 * Append a new entry value to the list
 *
 * @param value The value to be appended.
 *
 * @warning This method is not async safe.
 */
template <typename V> void async_list<V>::nasync_append (V value) {
    
    /* Lock the list from other writers. */
    PLCR_COMPAT_LOCK_LOCK(&_write_lock); {
        /* Construct the new entry, or recycle an existing one. */
        node *new_node;
        if (_free != NULL) {
            /* Fetch a node from the free list */
            new_node = _free;
            new_node->reset(value);
            
            /* Update the free list */
            _free = _free->_next;
        } else {
            new_node = new node(value);
        }
        
        /* Issue a memory barrier to ensure a consistent view of the value. */
        std::atomic_thread_fence(std::memory_order_seq_cst);
        
        /* If this is the first entry, initialize the list. */
        if (_tail == NULL) {
            
            /* Update the list tail. This need not be done atomically, as tail is never accessed by a lockless reader. */
            _tail = new_node;
            
            /* Atomically update the list head; this will be iterated upon by lockless readers. */
            node *expected = NULL;
            if (!_head.compare_exchange_strong(expected, new_node)) {
                /* Should never occur */
                PLCF_DEBUG("An async image head was set with tail == NULL despite holding lock.");
            }
        }
        
        /* Otherwise, append to the end of the list */
        else {
            /* Atomically slot the new record into place; this may be iterated on by a lockless reader. */
            node *expected = NULL;
            if (!_tail->_next.compare_exchange_strong(expected, new_node)) {
                PLCF_DEBUG("Failed to append to image list despite holding lock");
            }
            
            /* Update the prev and tail pointers. This is never accessed without a lock, so no additional barrier
             * is required here. */
            new_node->_prev = _tail;
            _tail = new_node;
        }
    } PLCR_COMPAT_LOCK_UNLOCK(&_write_lock);
}

/**
 * Find and remove the first entry node with @a value. Direct '==' equality checking
 * is performed.
 *
 * @param value The value to search for.
 *
 * @warning This method is not async safe.
 */
template <typename V> void async_list<V>::nasync_remove_first_value (V value) {
    set_reading(true);
    node *n = NULL;
    while ((n = next(n)) != NULL) {
        if (n->value() == value) {
            nasync_remove_node(n);
            break;
        }
    }
    set_reading(false);
}

/**
 * Remove a specific entry node from the list.
 *
 * @param deleted_node The node to be removed.
 *
 * @warning This method is not async safe.
 */
template <typename V> void async_list<V>::nasync_remove_node (node *deleted_node) {
    /* Lock the list from other writers. */
    PLCR_COMPAT_LOCK_LOCK(&_write_lock); {
        /* Find the record. */
        node *item = _head;
        while (item != NULL) {
            if (item == deleted_node)
                break;
            
            item = item->_next;
        }
        
        /* If not found, nothing to do */
        if (item == NULL) {
            PLCR_COMPAT_LOCK_UNLOCK(&_write_lock);
            return;
        }
        
        /*
         * Atomically make the item unreachable by readers.
         *
         * This serves as a synchronization point -- after the CAS, the item is no longer reachable via the list.
         */
        if (item == _head) {
            if (!_head.compare_exchange_strong(item, item->_next)) {
                PLCF_DEBUG("Failed to remove image list head despite holding lock");
            }
        } else {
            /* There MUST be a non-NULL prev pointer, as this is not HEAD. */
            if (!item->_prev->_next.compare_exchange_strong(item, item->_next)) {
                PLCF_DEBUG("Failed to remove image list item despite holding lock");
            }
        }
        
        /* Now that the item is unreachable, update the prev/tail pointers. These are never accessed without a lock,
         * and need not be updated atomically. */
        if (item->_next != NULL) {
            /* Item is not the tail (otherwise next would be NULL), so simply update the next item's prev pointer. */
            ((node *)item->_next)->_prev = item->_prev;
        } else {
            /* Item is the tail (next is NULL). Simply update the tail record. */
            _tail = item->_prev;
        }
        
        /* If a reader is active, place the node on the free list. The item is unreachable here when readers
         * aren't active, so if we have a 0 refcount, we can safely delete the item, and be sure that no
         * reader holds a reference to it. */
        if (_refcount > 0) {
            item->_prev = NULL;
            item->_next = _free;
            
            if (_free != NULL)
                _free->_prev = item;
            _free = item;
        } else {
            delete item;
        }
    } PLCR_COMPAT_LOCK_UNLOCK(&_write_lock);
}

/**
 * Retain or release the list for reading. This method is async-safe.
 *
 * This must be issued prior to attempting to iterate the list, and must called again once reads have completed.
 *
 * @param enable If true, the list will be retained. If false, released.
 */
template <typename V> void async_list<V>::set_reading (bool enable) {
    if (enable) {
        /* Increment and issue a barrier. Once issued, no items will be deallocated while a reference is held. */
        _refcount++;
    } else {
        /* Increment and issue a barrier. Once issued, items may again be deallocated. */
        _refcount--;
    }
}

/**
 * Iterate over list nodes. This method is async-safe. If no additional nodes are available, will return NULL.
 *
 * The list must be marked for reading before iteration is performed.
 *
 * @param current The current list node, or NULL to start iteration.
 */
template <typename V> typename async_list<V>::node *async_list<V>::next (node *current) {
    PLCF_ASSERT(_refcount > 0);
    
    if (current != NULL)
        return current->_next;
    
    return _head;
}

/*
 * @internal
 *
 * Free all items in @a next list.
 *
 * @param next The head of the list to deallocate.
 *
 * @warning This method is not async-safe, and must only be called with the write lock held, or
 * from the deconstructor.
 */
template <typename V> void async_list<V>::free_list (node *next) {
    while (next != NULL) {
        /* Save the current pointer and fetch the next pointer. */
        node *cur = next;
        next = cur->_next;
        
        /* Deallocate the current item. */
        delete cur;
    }
}

PLCR_CPP_END_NS
}

#endif /* PLCRASH_ASYNC_LINKED_LIST_H */
