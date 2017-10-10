
#import "CalendarUtils.h"

@implementation CalendarUtils


+ (BOOL) isSameDate:(NSDate*)d1 date:(NSDate*)d2 checkDay:(BOOL)checkDay {
    if(d1 && d2) {
        NSCalendar *cal = [NSCalendar currentCalendar];
        cal.timeZone = [NSTimeZone timeZoneWithAbbreviation:@"UTC"];
        unsigned unitFlags = NSCalendarUnitDay | NSCalendarUnitYear | NSCalendarUnitMonth;
        NSDateComponents *components = [cal components:unitFlags fromDate:d1];
        NSInteger ry = components.year;
        NSInteger rm = components.month;
        NSInteger rd = components.day;
        components = [cal components:unitFlags fromDate:d2];
        NSInteger ty = components.year;
        NSInteger tm = components.month;
        NSInteger td = components.day;
        return (ry == ty && rm == tm && (rd == td || !checkDay));
    } else {
        return NO;
    }
}


+ (NSDate*) monthDay:(NSInteger)day date:(NSDate *)date {
    NSCalendar *cal = [NSCalendar currentCalendar];
    cal.timeZone = [NSTimeZone timeZoneWithAbbreviation:@"UTC"];
    unsigned unitFlags = NSCalendarUnitDay| NSCalendarUnitYear | NSCalendarUnitMonth;
    NSDateComponents *components = [cal components:unitFlags fromDate:date];
    NSDateComponents *comps = [[NSDateComponents alloc] init];
    comps.day = day;
    comps.year = components.year;
    comps.month = components.month;
    return [cal dateFromComponents:comps];
}

+ (NSDate*) toUTC:(NSDate*)d {
    NSCalendar *cal = [NSCalendar currentCalendar];
    unsigned unitFlags = NSCalendarUnitDay| NSCalendarUnitYear | NSCalendarUnitMonth;
    NSDateComponents *components = [cal components:unitFlags fromDate:d];
    cal.timeZone = [NSTimeZone timeZoneWithAbbreviation:@"UTC"];
    return [cal dateFromComponents:components];
}

+(NSInteger)weekDay:(NSDate *)date {
    NSCalendar* cal = [NSCalendar currentCalendar];
    NSDateComponents* comp = [cal components:NSCalendarUnitWeekday fromDate:date];
    return [comp weekday];
}

+ (NSInteger) lastDayOfTheMonth:(NSDate *)date {
    NSCalendar *cal = [NSCalendar currentCalendar];
    cal.timeZone = [NSTimeZone timeZoneWithAbbreviation:@"UTC"];
    NSRange daysRange = [cal rangeOfUnit:NSCalendarUnitDay inUnit:NSCalendarUnitMonth forDate:date];
    return daysRange.length;
}

+ (NSInteger) colForDay:(NSInteger)day {
    NSCalendar *cal = [NSCalendar currentCalendar];
    cal.timeZone = [NSTimeZone timeZoneWithAbbreviation:@"UTC"];
    
    NSInteger idx = day - cal.firstWeekday;
    if(idx < 0) idx = 7 + idx;
    return idx;
}

+ (NSString*) dd:(NSDate*)d {
    NSCalendar *cal = [NSCalendar currentCalendar];
    cal.timeZone = [NSTimeZone timeZoneWithAbbreviation:@"UTC"];
    unsigned unitFlags = NSCalendarUnitDay | NSCalendarUnitYear | NSCalendarUnitMonth;
    NSDateComponents *cpt = [cal components:unitFlags fromDate:d];
    return [NSString stringWithFormat:@"%ld-%ld-%ld",cpt.year, cpt.month, cpt.day];
}

+ (NSDate *) stepMonth:(NSInteger)dm date:(NSDate *)date {
    NSCalendar *cal = [NSCalendar currentCalendar];
    cal.timeZone = [NSTimeZone timeZoneWithAbbreviation:@"UTC"];
    unsigned unitFlags = NSCalendarUnitDay| NSCalendarUnitYear | NSCalendarUnitMonth;
    NSDateComponents *components = [cal components:unitFlags fromDate:date];
    NSInteger month = components.month + dm;
    NSInteger year = components.year;
    if(month > 12) {
        month = 1;
        year++;
    };
    if(month < 1) {
        month = 12;
        year--;
    }
    components.year = year;
    components.month = month;
    return [cal dateFromComponents:components];
}

@end
