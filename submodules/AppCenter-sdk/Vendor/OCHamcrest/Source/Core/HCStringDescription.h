//  OCHamcrest by Jon Reid, https://qualitycoding.org/
//  Copyright 2020 hamcrest. See LICENSE.txt

#import <OCHamcrest/HCBaseDescription.h>

@protocol HCSelfDescribing;


NS_ASSUME_NONNULL_BEGIN

/*!
 * @abstract An HCDescription that is stored as a string.
 */
@interface HCStringDescription : HCBaseDescription


/*!
 * @abstract Returns the description of an HCSelfDescribing object as a string.
 * @param selfDescribing The object to be described.
 * @return The description of the object.
 */
+ (NSString *)stringFrom:(id <HCSelfDescribing>)selfDescribing;

/*!
 * @abstract Creates and returns an empty description.
 */
+ (instancetype)stringDescription;

/*!
 * @abstract Initializes a newly allocated HCStringDescription that is initially empty.
 */
- (instancetype)init NS_DESIGNATED_INITIALIZER;

@end

NS_ASSUME_NONNULL_END
