//  OCHamcrest by Jon Reid, https://qualitycoding.org/
//  Copyright 2020 hamcrest. See LICENSE.txt

#import <Foundation/Foundation.h>

FOUNDATION_EXPORT double OCHamcrestVersionNumber;
FOUNDATION_EXPORT const unsigned char OCHamcrestVersionString[];

#import <OCHamcrest/HCAllOf.h>
#import <OCHamcrest/HCAnyOf.h>
#import <OCHamcrest/HCArgumentCaptor.h>
#import <OCHamcrest/HCAssertThat.h>
#import <OCHamcrest/HCConformsToProtocol.h>
#import <OCHamcrest/HCDescribedAs.h>
#import <OCHamcrest/HCEvery.h>
#import <OCHamcrest/HCHasCount.h>
#import <OCHamcrest/HCHasDescription.h>
#import <OCHamcrest/HCHasProperty.h>
#import <OCHamcrest/HCIs.h>
#import <OCHamcrest/HCIsAnything.h>
#import <OCHamcrest/HCIsCloseTo.h>
#import <OCHamcrest/HCIsCollectionContaining.h>
#import <OCHamcrest/HCIsCollectionContainingInAnyOrder.h>
#import <OCHamcrest/HCIsCollectionContainingInOrder.h>
#import <OCHamcrest/HCIsCollectionContainingInRelativeOrder.h>
#import <OCHamcrest/HCIsCollectionOnlyContaining.h>
#import <OCHamcrest/HCIsDictionaryContaining.h>
#import <OCHamcrest/HCIsDictionaryContainingEntries.h>
#import <OCHamcrest/HCIsDictionaryContainingKey.h>
#import <OCHamcrest/HCIsDictionaryContainingValue.h>
#import <OCHamcrest/HCIsEmptyCollection.h>
#import <OCHamcrest/HCIsEqual.h>
#import <OCHamcrest/HCIsEqualIgnoringCase.h>
#import <OCHamcrest/HCIsEqualCompressingWhiteSpace.h>
#import <OCHamcrest/HCIsEqualToNumber.h>
#import <OCHamcrest/HCIsIn.h>
#import <OCHamcrest/HCIsInstanceOf.h>
#import <OCHamcrest/HCIsNil.h>
#import <OCHamcrest/HCIsNot.h>
#import <OCHamcrest/HCIsSame.h>
#import <OCHamcrest/HCIsTrueFalse.h>
#import <OCHamcrest/HCIsTypeOf.h>
#import <OCHamcrest/HCNumberAssert.h>
#import <OCHamcrest/HCOrderingComparison.h>
#import <OCHamcrest/HCStringContains.h>
#import <OCHamcrest/HCStringContainsInOrder.h>
#import <OCHamcrest/HCStringEndsWith.h>
#import <OCHamcrest/HCStringStartsWith.h>
#import <OCHamcrest/HCTestFailure.h>
#import <OCHamcrest/HCTestFailureReporter.h>
#import <OCHamcrest/HCTestFailureReporterChain.h>
#import <OCHamcrest/HCThrowsException.h>

// Carthage workaround: Include transitive public headers
#import <OCHamcrest/HCBaseDescription.h>
#import <OCHamcrest/HCCollect.h>
#import <OCHamcrest/HCRequireNonNilObject.h>
#import <OCHamcrest/HCStringDescription.h>
#import <OCHamcrest/HCWrapInMatcher.h>
