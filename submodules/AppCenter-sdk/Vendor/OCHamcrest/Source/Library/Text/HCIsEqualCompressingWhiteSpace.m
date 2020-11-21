//  OCHamcrest by Jon Reid, https://qualitycoding.org/
//  Copyright 2020 hamcrest. See LICENSE.txt

#import "HCIsEqualCompressingWhiteSpace.h"

#import "HCRequireNonNilObject.h"


static NSString *stripSpaces(NSString *string)
{
    NSRegularExpression *regex = [NSRegularExpression regularExpressionWithPattern:@"\\s+"
                                                                           options:0
                                                                             error:NULL];
    NSString *modifiedString = [regex stringByReplacingMatchesInString:string
                                                               options:0
                                                                 range:NSMakeRange(0, string.length)
                                                          withTemplate:@" "];
    return [modifiedString stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceCharacterSet]];
}


@interface HCIsEqualCompressingWhiteSpace ()
@property (nonatomic, copy, readonly) NSString *originalString;
@property (nonatomic, copy, readonly) NSString *strippedString;
@end

@implementation HCIsEqualCompressingWhiteSpace

- (instancetype)initWithString:(NSString *)string
{
    HCRequireNonNilObject(string);

    self = [super init];
    if (self)
    {
        _originalString = [string copy];
        _strippedString = [stripSpaces(string) copy];
    }
    return self;
}

- (BOOL)matches:(nullable id)item
{
    if (![item isKindOfClass:[NSString class]])
        return NO;

    return [self.strippedString isEqualToString:stripSpaces(item)];
}

- (void)describeTo:(id <HCDescription>)description
{
    [[description appendDescriptionOf:self.originalString]
                  appendText:@" ignoring whitespace"];
}

@end


id HC_equalToCompressingWhiteSpace(NSString *expectedString)
{
    return [[HCIsEqualCompressingWhiteSpace alloc] initWithString:expectedString];
}
