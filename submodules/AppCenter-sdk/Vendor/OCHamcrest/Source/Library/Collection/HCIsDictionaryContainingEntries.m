//  OCHamcrest by Jon Reid, https://qualitycoding.org/
//  Copyright 2020 hamcrest. See LICENSE.txt

#import "HCIsDictionaryContainingEntries.h"

#import "HCWrapInMatcher.h"


@interface HCIsDictionaryContainingEntries ()
@property (nonatomic, copy, readonly) NSArray *keys;
@property (nonatomic, copy, readonly) NSArray<id <HCMatcher>> *valueMatchers;
@end

@implementation HCIsDictionaryContainingEntries

- (instancetype)initWithKeys:(NSArray *)keys
               valueMatchers:(NSArray<id <HCMatcher>> *)valueMatchers
{
    self = [super init];
    if (self)
    {
        _keys = [keys copy];
        _valueMatchers = [valueMatchers copy];
    }
    return self;
}

- (BOOL)matches:(id)dict describingMismatchTo:(id <HCDescription>)mismatchDescription
{
    if (![dict isKindOfClass:[NSDictionary class]])
    {
        [[mismatchDescription appendText:@"was non-dictionary "] appendDescriptionOf:dict];
        return NO;
    }

    NSUInteger count = self.keys.count;
    for (NSUInteger index = 0; index < count; ++index)
    {
        id key = self.keys[index];
        if (dict[key] == nil)
        {
            [[[[mismatchDescription appendText:@"no "]
                                    appendDescriptionOf:key]
                                    appendText:@" key in "]
                                    appendDescriptionOf:dict];
            return NO;
        }

        id valueMatcher = self.valueMatchers[index];
        id actualValue = dict[key];

        if (![valueMatcher matches:actualValue])
        {
            [[[[mismatchDescription appendText:@"value for "]
                                    appendDescriptionOf:key]
                                    appendText:@" was "]
                                    appendDescriptionOf:actualValue];
            return NO;
        }
    }

    return YES;
}

- (void)describeKeyValueAtIndex:(NSUInteger)index to:(id <HCDescription>)description
{
    [[[[description appendDescriptionOf:self.keys[index]]
                    appendText:@" = "]
                    appendDescriptionOf:self.valueMatchers[index]]
                    appendText:@"; "];
}

- (void)describeTo:(id <HCDescription>)description
{
    [description appendText:@"a dictionary containing { "];
    NSUInteger count = [self.keys count];
    NSUInteger index = 0;
    for (; index < count - 1; ++index)
        [self describeKeyValueAtIndex:index to:description];
    [self describeKeyValueAtIndex:index to:description];
    [description appendText:@"}"];
}

@end


static void requirePairedObject(id obj)
{
    if (obj == nil)
    {
        @throw [NSException exceptionWithName:@"NilObject"
                                       reason:@"HC_hasEntries keys and value matchers must be paired"
                                     userInfo:nil];
    }
}


id HC_hasEntriesIn(NSDictionary *valueMatchersForKeys)
{
    NSArray *keys = valueMatchersForKeys.allKeys;
    NSMutableArray<id <HCMatcher>> *valueMatchers = [[NSMutableArray alloc] init];
    for (id key in keys)
        [valueMatchers addObject:HCWrapInMatcher(valueMatchersForKeys[key])];

    return [[HCIsDictionaryContainingEntries alloc] initWithKeys:keys
                                                   valueMatchers:valueMatchers];
}

id HC_hasEntries(id keysAndValueMatchers, ...)
{
    va_list args;
    va_start(args, keysAndValueMatchers);

    id key = keysAndValueMatchers;
    id valueMatcher = va_arg(args, id);
    requirePairedObject(valueMatcher);
    NSMutableArray *keys = [NSMutableArray arrayWithObject:key];
    NSMutableArray<id <HCMatcher>> *valueMatchers = [NSMutableArray arrayWithObject:HCWrapInMatcher(valueMatcher)];

    key = va_arg(args, id);
    while (key != nil)
    {
        [keys addObject:key];
        valueMatcher = va_arg(args, id);
        requirePairedObject(valueMatcher);
        [valueMatchers addObject:HCWrapInMatcher(valueMatcher)];
        key = va_arg(args, id);
    }

    return [[HCIsDictionaryContainingEntries alloc] initWithKeys:keys
                                                   valueMatchers:valueMatchers];
}
