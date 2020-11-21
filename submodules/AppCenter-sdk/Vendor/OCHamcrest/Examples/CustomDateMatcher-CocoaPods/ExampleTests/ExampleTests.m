#import "IsGivenDayOfWeek.h"
@import OCHamcrest;
@import XCTest;


@interface ExampleTests : XCTestCase
@end

@implementation ExampleTests

- (void)testDateIsOnASaturday
{
    // Example of a successful match.
    NSDateComponents *dateComponents = [[NSDateComponents alloc] init];
    dateComponents.day = 26;
    dateComponents.month = 4;
    dateComponents.year = 2008;
    NSCalendar *gregorianCalendar = [[NSCalendar alloc] initWithCalendarIdentifier:NSCalendarIdentifierGregorian];
    NSDate *date = [gregorianCalendar dateFromComponents:dateComponents];

    assertThat(date, is(onASaturday()));
}

- (void)testFailsWithMismatchedDate
{
    // Example of what happens with date that doesn't match.
    NSDateComponents *dateComponents = [[NSDateComponents alloc] init];
    dateComponents.day = 6;
    dateComponents.month = 4;
    dateComponents.year = 2008;
    NSCalendar *gregorianCalendar = [[NSCalendar alloc] initWithCalendarIdentifier:NSCalendarIdentifierGregorian];
    NSDate *date = [gregorianCalendar dateFromComponents:dateComponents];

    assertThat(date, is(onASaturday()));
}

- (void)testFailsWithNonDate
{
    // Example of what happens with object that isn't a date.
    NSString* nonDate = @"oops";
    assertThat(nonDate, is(onASaturday()));
}

@end
