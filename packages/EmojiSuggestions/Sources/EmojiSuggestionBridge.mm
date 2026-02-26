//
//  EmojiSuggestionBridge.m
//  Telegram
//
//  Created by keepcoder on 24/07/2017.
//  Copyright © 2017 Telegram. All rights reserved.
//

#import "EmojiSuggestionBridge.h"
#import "emoji_suggestions.h"

@implementation CEmojiSuggestion
-(__nonnull id)initWithEmoji:(NSString *)emoji label:(NSString *)label replacement:(NSString *)replacement {
    if (self = [super init]) {
        _emoji = emoji;
        _label = label;
        _replacement = replacement;
    }
    return self;
}
@end

@implementation EmojiSuggestionBridge


std::vector<Ui::Emoji::utf16char> convertToUtf16(NSString *string) {
    auto cf = (__bridge CFStringRef)string;
    auto range = CFRangeMake(0, CFStringGetLength(cf));
    auto bufferLength = CFIndex(0);
    CFStringGetBytes(cf, range, kCFStringEncodingUTF16LE, 0, FALSE, nullptr, 0, &bufferLength);
    if (!bufferLength) {
        return std::vector<Ui::Emoji::utf16char>();
    }
    auto result = std::vector<Ui::Emoji::utf16char>(bufferLength / 2 + 1, 0);
    CFStringGetBytes(cf, range, kCFStringEncodingUTF16LE, 0, FALSE, reinterpret_cast<UInt8*>(result.data()), result.size() * 2, &bufferLength);
    result.resize(bufferLength / 2);
    return result;
}

NSString *convertFromUtf16(Ui::Emoji::utf16string string) {
    auto result = CFStringCreateWithBytes(nullptr, reinterpret_cast<const UInt8*>(string.data()), string.size() * 2, kCFStringEncodingUTF16LE, false);
    return (__bridge NSString*)result;
}
+(NSArray<CEmojiSuggestion *> *)getSuggestions:(NSString *)q {
    
    NSString *c = [q substringToIndex:MIN(Ui::Emoji::GetSuggestionMaxLength(), q.length)];
    
    auto query = convertToUtf16(c);
    auto values = Ui::Emoji::GetSuggestions(Ui::Emoji::utf16string(query.data(), query.size()));
    
    NSMutableArray *list = [[NSMutableArray alloc] init];
    
    for (auto &item : values) {
        NSString *emoji = convertFromUtf16(item.emoji());
        NSString *label = convertFromUtf16(item.label());
        NSString *replacement = convertFromUtf16(item.replacement());
        
        CEmojiSuggestion *suggestion = [[CEmojiSuggestion alloc] initWithEmoji: emoji label: label replacement: replacement];
        
        [list addObject:suggestion];
    }
    return list;
}


@end

