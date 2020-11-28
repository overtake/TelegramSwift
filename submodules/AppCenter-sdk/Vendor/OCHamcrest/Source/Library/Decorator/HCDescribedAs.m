//  OCHamcrest by Jon Reid, https://qualitycoding.org/
//  Copyright 2020 hamcrest. See LICENSE.txt

#import "HCDescribedAs.h"


@interface NSString (OCHamcrest)
@end

@implementation NSString (OCHamcrest)

// Parse decimal number (-1 if not found) and return remaining string.
- (NSString *)och_getDecimalNumber:(int *)number
{
    int decimal = 0;
    BOOL readDigit = NO;

    NSUInteger length = self.length;
    NSUInteger index;
    for (index = 0; index < length; ++index)
    {
        unichar character = [self characterAtIndex:index];
        if (!isdigit(character))
            break;
        decimal = decimal * 10 + character - '0';
        readDigit = YES;
    }

    if (!readDigit)
    {
        *number = -1;
        return self;
    }
    *number = decimal;
    return [self substringFromIndex:index];
}

@end


@interface HCDescribedAs ()
@property (nonatomic, copy, readonly) NSString *descriptionTemplate;
@property (nonatomic, strong, readonly) id <HCMatcher> matcher;
@property (nonatomic, copy, readonly) NSArray *values;
@end

@implementation HCDescribedAs

- (instancetype)initWithDescription:(NSString *)description
                         forMatcher:(id <HCMatcher>)matcher
                         overValues:(NSArray *)templateValues
{
    self = [super init];
    if (self)
    {
        _descriptionTemplate = [description copy];
        _matcher = matcher;
        _values = [templateValues copy];
    }
    return self;
}

- (BOOL)matches:(nullable id)item
{
    return [self.matcher matches:item];
}

- (void)describeMismatchOf:(nullable id)item to:(nullable id <HCDescription>)mismatchDescription
{
    [self.matcher describeMismatchOf:item to:mismatchDescription];
}

- (void)describeTo:(id <HCDescription>)description
{
    NSArray<NSString *> *components = [self.descriptionTemplate componentsSeparatedByString:@"%"];
    BOOL firstComponent = YES;
    for (NSString *component in components)
    {
        if (firstComponent)
        {
            firstComponent = NO;
            [description appendText:component];
        }
        else
        {
            [self appendTemplateForComponent:component toDescription:description];
        }
    }
}

- (void)appendTemplateForComponent:(NSString *)component toDescription:(id <HCDescription>)description
{
    int index;
    NSString *remainder = [component och_getDecimalNumber:&index];
    if (index < 0)
        [[description appendText:@"%"] appendText:component];
    else
        [[description appendDescriptionOf:self.values[(NSUInteger)index]] appendText:remainder];
}

@end


id HC_describedAs(NSString *description, id <HCMatcher> matcher, ...)
{
    NSMutableArray *valueList = [NSMutableArray array];

    va_list args;
    va_start(args, matcher);
    id value = va_arg(args, id);
    while (value != nil)
    {
        [valueList addObject:value];
        value = va_arg(args, id);
    }
    va_end(args);

    return [[HCDescribedAs alloc] initWithDescription:description
                                           forMatcher:matcher
                                           overValues:valueList];
}
