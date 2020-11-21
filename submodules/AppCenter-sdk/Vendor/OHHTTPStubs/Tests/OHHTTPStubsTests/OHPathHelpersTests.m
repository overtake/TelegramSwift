#import <XCTest/XCTest.h>

#if OHHTTPSTUBS_USE_STATIC_LIBRARY || SWIFT_PACKAGE
#import "HTTPStubs.h"
#import "HTTPStubsPathHelpers.h"
#else
@import OHHTTPStubs;
#endif

@interface HTTPStubsPathHelpersTests : XCTestCase
@end

@implementation HTTPStubsPathHelpersTests

- (void)testOHResourceBundle {
    NSBundle *classBundle = [NSBundle bundleForClass:self.class];
    NSBundle *expectedBundle = [NSBundle bundleWithPath:[classBundle pathForResource:@"empty"
                                                                              ofType:@"bundle"]];

    XCTAssertEqual(OHResourceBundle(@"empty", self.class), expectedBundle);
}

@end
