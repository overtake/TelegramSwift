#import "IsGivenDayOfWeek.h"

static NSString* const dayAsString[] =
        { @"ZERO", @"Sunday", @"Monday", @"Tuesday", @"Wednesday", @"Thursday", @"Friday", @"Saturday" };


@implementation IsGivenDayOfWeek

- (instancetype)initWithDayOfWeek:(NSInteger)dayOfWeek
{
    self = [super init];
    if (self)
        _dayOfWeek = dayOfWeek;
    return self;
}

// Test whether item matches.
- (BOOL)matches:(id)item
{
    if (![item isKindOfClass:[NSDate class]])
        return NO;

    NSCalendar *gregorianCalendar = [[NSCalendar alloc] initWithCalendarIdentifier:NSCalendarIdentifierGregorian];
    return [gregorianCalendar component:NSCalendarUnitWeekday fromDate:item] == self.dayOfWeek;
}

// Describe the matcher.
- (void)describeTo:(id <HCDescription>)description
{
    [[description appendText:@"date falling on "] appendText:dayAsString[self.dayOfWeek]];
}

@end


id onASaturday()
{
    return [[IsGivenDayOfWeek alloc] initWithDayOfWeek:7];
}
