//  OCHamcrest by Jon Reid, https://qualitycoding.org/
//  Copyright 2020 hamcrest. See LICENSE.txt

#import "HCStringContainsInOrder.h"

#import "HCCollect.h"


static void requireElementsToBeStrings(NSArray *array)
{
    for (id element in array)
    {
        if (![element isKindOfClass:[NSString class]])
        {
            @throw [NSException exceptionWithName:@"NotAString"
                                           reason:@"Arguments must be strings"
                                         userInfo:nil];
        }
    }
}


@interface HCStringContainsInOrder ()
@property (nonatomic, copy, readonly) NSArray<NSString *> *substrings;
@end

@implementation HCStringContainsInOrder

- (instancetype)initWithSubstrings:(NSArray<NSString *> *)substrings
{
    self = [super init];
    if (self)
    {
        requireElementsToBeStrings(substrings);
        _substrings = [substrings copy];
    }
    return self;
}

- (BOOL)matches:(nullable id)item
{
    if (![item isKindOfClass:[NSString class]])
        return NO;

    NSRange searchRange = NSMakeRange(0, [item length]);
    for (NSString *substring in self.substrings)
    {
        NSRange substringRange = [item rangeOfString:substring options:0 range:searchRange];
        if (substringRange.location == NSNotFound)
            return NO;
        searchRange.location = substringRange.location + substringRange.length;
        searchRange.length = [item length] - searchRange.location;
    }
    return YES;
}

- (void)describeTo:(id <HCDescription>)description
{
    [description appendList:self.substrings start:@"a string containing " separator:@", " end:@" in order"];
}

@end


id HC_stringContainsInOrderIn(NSArray<NSString *> *substrings)
{
    return [[HCStringContainsInOrder alloc] initWithSubstrings:substrings];
}

id HC_stringContainsInOrder(NSString *substrings, ...)
{
    va_list args;
    va_start(args, substrings);
    NSArray *array = HCCollectItems(substrings, args);
    va_end(args);

    return HC_stringContainsInOrderIn(array);
}
