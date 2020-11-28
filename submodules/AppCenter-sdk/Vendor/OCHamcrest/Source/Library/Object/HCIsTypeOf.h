//  OCHamcrest by Jon Reid, https://qualitycoding.org/
//  Copyright 2020 hamcrest. See LICENSE.txt

#import <OCHamcrest/HCClassMatcher.h>


NS_ASSUME_NONNULL_BEGIN

/*!
 * @abstract Matches objects that are of a given class.
 */
@interface HCIsTypeOf : HCClassMatcher
@end


FOUNDATION_EXPORT id HC_isA(Class expectedClass);

#ifndef HC_DISABLE_SHORT_SYNTAX
/*!
 * @abstract Creates a matcher that matches when the examined object is an instance of the specified
 * class, but not of any subclass.
 * @param expectedClass The class to compare against as the expected class.
 * @discussion
 * <b>Example</b><br />
 * <pre>assertThat(canoe, isA([Canoe class]))</pre>
 *
 * <b>Name Clash</b><br />
 * In the event of a name clash, <code>#define HC_DISABLE_SHORT_SYNTAX</code> and use the synonym
 * HC_isA instead.
 */
static inline id isA(Class expectedClass)
{
    return HC_isA(expectedClass);
}
#endif

NS_ASSUME_NONNULL_END
