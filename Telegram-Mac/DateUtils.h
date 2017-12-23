/*
 * This is the source code of Telegram for iOS v. 1.1
 * It is licensed under GNU GPL v. 2 or later.
 * You should have received a copy of the license in this archive (see LICENSE).
 *
 * Copyright Peter Iakovlev, 2013.
 */

#import <Foundation/Foundation.h>


@interface DateUtils : NSObject

+ (NSString *)stringForShortTime:(int)time;
+ (NSString *)stringForDialogTime:(int)time;
+ (NSString *)stringForDayOfMonth:(int)date dayOfMonth:(int *)dayOfMonth;
+ (NSString *)stringForDayOfWeek:(int)date;
+ (NSString *)stringForMessageListDate:(int)date;
+ (NSString *)stringForLastSeen:(int)date;
+ (NSString *)stringForLastSeenShort:(int)date;
+ (NSString *)stringForRelativeLastSeen:(int)date;
+ (NSString *)stringForUntil:(int)date;
+ (NSString *)stringForDayOfMonthFull:(int)date dayOfMonth:(int *)dayOfMonth;
+ (void)setDateLocalizationFunc:(NSString* (^)(NSString *key))localizationF;
@end

NSString * NSLocalized(NSString * key, NSString *comment);


#ifdef __cplusplus
extern "C" {
#endif

bool TGUse12hDateFormat();
    
#ifdef __cplusplus
}
#endif
