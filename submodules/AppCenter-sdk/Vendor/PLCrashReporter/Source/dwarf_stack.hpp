/*
 * Copyright (c) 2013 Plausible Labs Cooperative, Inc.
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

#ifndef PLCRASH_ASYNC_DWARF_STACK_H
#define PLCRASH_ASYNC_DWARF_STACK_H 1

#include <cstddef>

#include "PLCrashFeatureConfig.h"
#include "PLCrashMacros.h"

#if PLCRASH_FEATURE_UNWIND_DWARF

/**
 * @internal
 * @ingroup plcrash_async_dwarf_private_stack
 * @{
 */

PLCR_CPP_BEGIN_NS
namespace async {

/**
 * @internal
 *
 * A simple machine pointer stack for use with DWARF opcode/CFA evaluation.
 */
template <typename T, size_t S> class dwarf_stack {
    T mem[S];
    T *sp = mem;
    
public:
    inline bool push (T value);
    inline bool peek (T *value);
    inline bool pop (T *value);
    inline bool pick (size_t index);
    inline bool drop (void);

    inline bool dup (void);
    inline bool swap (void);
    inline bool rotate (void);
};

/**
 * Push a single value onto the stack.
 *
 * @param value The value to push.
 * @return Returns true on success, or false if the stack is full.
 */
template <typename T, size_t S> inline bool dwarf_stack<T,S>::push (T value) {
    /* Refuse to exceed the allocated stack size */
    if (sp == &mem[S])
        return false;
    
    *sp = value;
    sp++;
    
    return true;
}

/**
 * Pop a single value from the stack.
 *
 * @param value An address to which the popped value will be written.
 * @return Returns true on success, or false if the stack is empty.
 */
template <typename T, size_t S> inline bool dwarf_stack<T,S>::pop (T *value) {
    /* Refuse to pop the final value */
    if (sp == mem)
        return false;

    sp--;
    *value = *sp;
    return true;
}

/**
 * Peek at the top of the stack.
 *
 * @param value An address to which the peeked value will be written.
 * @return Returns true on success, or false if the stack is empty.
 */
template <typename T, size_t S> inline bool dwarf_stack<T,S>::peek (T *value) {
    /* Refuse to peek an empty stack */
    if (sp == mem)
        return false;
    
    *value = *(sp-1);
    return true;
}

/**
 * Pop and discard an element from the stack.
 *
 * @return Returns true on success, or false if the stack is empty.
 */
template <typename T, size_t S> inline bool dwarf_stack<T,S>::drop (void) {
    /* Refuse to pop the final value */
    if (sp == mem)
        return false;

    sp--;
    return true;
}

/**
 * Duplicate the value at the top of the stack.
 *
 * @return Returns true on success, or false if the stack is full.
 */
template <class T, size_t S> inline bool dwarf_stack<T,S>::dup (void) {
    /* Refuse to exceed the allocated stack size */
    if (sp == &mem[S])
        return false;

    /* Peek and push the current value */
    T val;
    if (!peek(&val))
        return false;
    
    return push(val);
}
    
/**
 * Pick the stack entry with the specified index, and push its value on
 * the top of the stack.
 *
 * @param index The index of the entry to be picked
 * @return Returns true on success, or false if the index is outside the stack bounds.
 */
template <typename T, size_t S> inline bool dwarf_stack<T,S>::pick (size_t index) {
    /* Validate the index range */
    if (sp - mem <= index)
        return false;

    push(*(sp-1-index));
    return true;
}
    
/**
 * Swap the top two stack entries.
 *
 * @return Returns true on success, or false if less than two values are available on
 * the stack.
 */
template <typename T, size_t S> inline bool dwarf_stack<T,S>::swap (void) {
    T v1;
    T v2;

    /* Fetch the current values */
    if (!pop(&v1))
        return false;
    
    if (!pop(&v2))
        return false;

    /* Pushing two just-popped values should never fail */
    if (!push(v1))
        return false;
    
    if (!push(v2))
        return false;

    return true;
}
    
/**
 * Rotate the top three stack entries. The entry at the top of the stack
 * is becomes the third stack entry, the second entry becomes the top of the stack,
 * and the third entry becomes the second entry.
 *
 * @return Returns true on success, or false if less than three values are available on
 * the stack.
 */
template <typename T, size_t S> inline bool dwarf_stack<T,S>::rotate (void) {
    T v1;
    T v2;
    T v3;
    
    /* Fetch the current values */
    if (!pop(&v1))
        return false;
    
    if (!pop(&v2))
        return false;

    if (!pop(&v3))
        return false;
    
    /* Pushing three just-popped values should never fail */
    if (!push(v1))
        return false;

    if (!push(v3))
        return false;

    if (!push(v2))
        return false;
    
    return true;
}

PLCR_CPP_END_NS
}

/*
 * @}
 */

#endif /* PLCRASH_FEATURE_UNWIND_DWARF */
#endif /* PLCRASH_ASYNC_DWARF_STACK_H */
