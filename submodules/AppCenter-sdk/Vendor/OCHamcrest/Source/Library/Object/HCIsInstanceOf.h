//  OCHamcrest by Jon Reid, https://qualitycoding.org/
//  Copyright 2020 hamcrest. See LICENSE.txt

#import <OCHamcrest/HCClassMatcher.h>


NS_ASSUME_NONNULL_BEGIN

/*!
 * @abstract Matches objects that are of a given class or any subclass.
 */
@interface HCIsInstanceOf : HCClassMatcher
@end


FOUNDATION_EXPORT id HC_instanceOf(Class expectedClass);

#ifndef HC_DISABLE_SHORT_SYNTAX
/*!
 * @abstract Creates a matcher that matches when the examined object is an instance of, or inherits
 * from, the specified class.
 * @param expectedClass The class to compare against as the expected class.
 * @discussion
 * <b>Example</b><br />
 * <pre>assertThat(canoe, instanceOf([Canoe class]))</pre>
 *
 * <b>Name Clash</b><br />
 * In the event of a name clash, <code>#define HC_DISABLE_SHORT_SYNTAX</code> and use the synonym
 * HC_instanceOf instead.
 */
static inline id instanceOf(Class expectedClass)
{
    return HC_instanceOf(expectedClass);
}
#endif

NS_ASSUME_NONNULL_END
