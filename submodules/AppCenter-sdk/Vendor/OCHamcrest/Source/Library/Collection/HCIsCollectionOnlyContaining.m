//  OCHamcrest by Jon Reid, https://qualitycoding.org/
//  Copyright 2020 hamcrest. See LICENSE.txt

#import "HCIsCollectionOnlyContaining.h"

#import "HCAnyOf.h"
#import "HCCollect.h"


@implementation HCIsCollectionOnlyContaining

- (void)describeTo:(id <HCDescription>)description
{
    [[description appendText:@"a collection containing items matching "]
                  appendDescriptionOf:self.matcher];
}

@end


id HC_onlyContainsIn(NSArray *itemMatchers)
{
    return [[HCIsCollectionOnlyContaining alloc] initWithMatcher:HC_anyOfIn(itemMatchers)];
}

id HC_onlyContains(id itemMatchers, ...)
{
    va_list args;
    va_start(args, itemMatchers);
    NSArray *array = HCCollectItems(itemMatchers, args);
    va_end(args);

    return HC_onlyContainsIn(array);
}
