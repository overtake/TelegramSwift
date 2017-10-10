//
//  TGCurrencyFormatter.m
//  Telegram
//
//  Created by keepcoder on 19/05/2017.
//  Copyright © 2017 Telegram. All rights reserved.
//

#import "TGCurrencyFormatter.h"

@implementation TGCurrencyFormatterEntry

- (instancetype)initWithSymbol:(NSString *)symbol thousandsSeparator:(NSString *)thousandsSeparator decimalSeparator:(NSString *)decimalSeparator symbolOnLeft:(bool)symbolOnLeft spaceBetweenAmountAndSymbol:(bool)spaceBetweenAmountAndSymbol decimalDigits:(int)decimalDigits {
    self = [super init];
    if (self != nil) {
        _symbol = symbol;
        _thousandsSeparator = thousandsSeparator;
        _decimalSeparator = decimalSeparator;
        _symbolOnLeft = symbolOnLeft;
        _spaceBetweenAmountAndSymbol = spaceBetweenAmountAndSymbol;
        _decimalDigits = decimalDigits;
    }
    return self;
}

@end

@interface TGCurrencyFormatter () {
    NSDictionary<NSString *, TGCurrencyFormatterEntry *> *_entries;
}

@end

@implementation TGCurrencyFormatter

+ (TGCurrencyFormatter *)shared {
    static TGCurrencyFormatter *instance = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        instance = [[TGCurrencyFormatter alloc] init];
    });
    return instance;
}

- (instancetype)init {
    self = [super init];
    if (self != nil) {
        NSMutableDictionary<NSString *, TGCurrencyFormatterEntry *> *entries = [[NSMutableDictionary alloc] init];
        NSString *filePath = [[NSBundle mainBundle] pathForResource:@"currencies" ofType:@"json"];
        NSData *data = [NSData dataWithContentsOfFile:filePath];
        if (data != nil) {
            NSDictionary *dict = [NSJSONSerialization JSONObjectWithData:data options:0 error:nil];
            [dict enumerateKeysAndObjectsUsingBlock:^(NSString *code, NSDictionary *contents, __unused BOOL *stop) {
                TGCurrencyFormatterEntry *entry = [[TGCurrencyFormatterEntry alloc] initWithSymbol:contents[@"symbol"] thousandsSeparator:contents[@"thousandsSeparator"] decimalSeparator:contents[@"decimalSeparator"] symbolOnLeft:[contents[@"symbolOnLeft"] boolValue] spaceBetweenAmountAndSymbol:[contents[@"spaceBetweenAmountAndSymbol"] boolValue] decimalDigits:[contents[@"decimalDigits"] intValue]];
                entries[code] = entry;
                entries[[code lowercaseString]] = entry;
            }];
        }
        _entries = entries;
    }
    return self;
}

- (NSString *)formatAmount:(int64_t)amount currency:(NSString *)currency {
    TGCurrencyFormatterEntry *entry = _entries[currency];
    if (entry != nil) {
        NSMutableString *result = [[NSMutableString alloc] init];
        if (amount < 0) {
            [result appendString:@"-"];
        }
        if (entry.symbolOnLeft) {
            [result appendString:entry.symbol];
            if (entry.spaceBetweenAmountAndSymbol) {
                [result appendString:@" "];
            }
        }
        
        int64_t integerPart = ABS(amount);
        char fractional[4];
        int fractionalCount = 0;
        for (int i = 0; i < entry.decimalDigits; i++) {
            fractional[fractionalCount++] = ((char)(integerPart % 10)) + '0';
            integerPart /= 10;
        }
        
        [result appendFormat:@"%d", (int)integerPart];
        [result appendString:entry.decimalSeparator];
        for (int i = 0; i < fractionalCount; i++) {
            [result appendFormat:@"%c", fractional[fractionalCount - i - 1]];
        }
        
        if (!entry.symbolOnLeft) {
            if (entry.spaceBetweenAmountAndSymbol) {
                [result appendString:@" "];
            }
            [result appendString:entry.symbol];
        }
        
        return result;
    } else {
        NSAssert(false, @"Unknown currency");
        NSNumberFormatter *_currencyFormatter = [[NSNumberFormatter alloc] init];
        [_currencyFormatter setNumberStyle:NSNumberFormatterCurrencyStyle];
        [_currencyFormatter setCurrencyCode:currency];
        [_currencyFormatter setNegativeFormat:@"-¤#,##0.00"];
        return [_currencyFormatter stringFromNumber:@(amount * 0.01)];
    }
}

@end
