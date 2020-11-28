/***********************************************************************************
 *
 * Copyright (c) 2012 Olivier Halligon, 2016 Sebastian Hagedorn
 *
 * Permission is hereby granted, free of charge, to any person obtaining a copy
 * of this software and associated documentation files (the "Software"), to deal
 * in the Software without restriction, including without limitation the rights
 * to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
 * copies of the Software, and to permit persons to whom the Software is
 * furnished to do so, subject to the following conditions:
 *
 * The above copyright notice and this permission notice shall be included in
 * all copies or substantial portions of the Software.
 *
 * THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
 * IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
 * FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
 * AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
 * LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
 * OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
 * THE SOFTWARE.
 *
 ***********************************************************************************/

////////////////////////////////////////////////////////////////////////////////
#pragma mark - Imports

#import <objc/runtime.h>

////////////////////////////////////////////////////////////////////////////////
#pragma mark - Method Swizzling Helpers

/**
 *  Replaces the selector's associated method implementation with the
 *  given implementation (or adds it, if there was no existing one).
 *
 *  @param selector      The selector entry in the dispatch table.
 *  @param newImpl       The implementation that will be associated with
 *                       the given selector.
 *  @param affectedClass The class whose dispatch table will be altered.
 *  @param isClassMethod Set to YES if the selector denotes a class
 *                       method, or NO if it is an instance method.
 *  @return              The previous implementation associated with
 *                       the swizzled selector. You should store the
 *                       implementation and call it when overwriting
 *                       the selector.
 */
__attribute__((warn_unused_result)) IMP HTTPStubsReplaceMethod(SEL selector,
                                                               IMP newImpl,
                                                               Class affectedClass,
                                                               BOOL isClassMethod);
