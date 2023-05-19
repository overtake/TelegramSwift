//
//  EmojiSuggestionBridge.h
//  Telegram
//
//  Created by keepcoder on 24/07/2017.
//  Copyright © 2017 Telegram. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface CEmojiSuggestion : NSObject
@property(nonatomic, strong) NSString * emoji;
@property(nonatomic, strong) NSString * label;
@property(nonatomic, strong) NSString * replacement;
@end

@interface EmojiSuggestionBridge : NSObject
+(NSArray<CEmojiSuggestion *> *)getSuggestions:(NSString *)q;
@end
