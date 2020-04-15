#include "DateUtils.h"
//#include <time.h>

static time_t midnightOnDay(time_t t)
{
    struct tm theday;
    localtime_r(&t, &theday);
    theday.tm_hour = 0;
    theday.tm_min = 0;
    theday.tm_sec = 0;
    return mktime(&theday);
}

static NSString* (^localizationFunc)(NSString *key);

void setDateLocalizationFunc(NSString* (^localizationF)(NSString *key)) {
    localizationFunc = localizationF;
}

NSString * NSLocalized(NSString * key, NSString *comment) {
    if (localizationFunc != nil) {
        return localizationFunc(key);
    } else {
        return NSLocalizedString(key, comment);
    }
}

static time_t todayMidnight()
{
    return midnightOnDay(time(0));
}

static bool areSameDay(time_t t1, time_t t2)
{
    struct tm tm1, tm2;
    localtime_r(&t1, &tm1);
    localtime_r(&t2, &tm2);
    return ((tm1.tm_mday == tm2.tm_mday) && (tm1.tm_mon == tm2.tm_mon) && (tm1.tm_year == tm2.tm_year));
}

static int daysBetween(time_t t1, time_t t2)
{
    // we'll be rounding down fractional days, so set t1 to midnight and then do division
    time_t newt1 = midnightOnDay(t1);
    return (int) ((t2 - newt1) / (60 * 60 * 24));
}

static bool value_dateHas12hFormat = false;


static bool value_dialogTimeMonthNameFirst() {
    return [NSLocalized(@"Date.DialogDateFormat", @"") hasPrefix:@"{month}"];
};
static NSString *value_dialogTimeFormat() {
    return [[NSLocalized(@"Date.DialogDateFormat", @"") stringByReplacingOccurrencesOfString:@"{month}" withString:@"%@"] stringByReplacingOccurrencesOfString:@"{day}" withString:@"%d"];
};

static NSString *value_today() {
    return NSLocalized(@"Time.today", @"");
};
static NSString *value_yesterday() {
    return NSLocalized(@"Time.yesterday", @"");
};
static NSString *value_tomorrow() {
    return NSLocalized(@"Time.tomorrow", @"");
};
static NSString *value_at() {
    return NSLocalized(@"Time.at", @"");
};

static char value_date_separator = '.';
static bool value_monthFirst = false;

static bool DateUtilsInitialized = false;
static void initializeDateUtils()
{
    NSDateFormatter *dateFormatter = [[NSDateFormatter alloc] init];
    [dateFormatter setLocale:[NSLocale currentLocale]];
    [dateFormatter setDateStyle:NSDateFormatterNoStyle];
    [dateFormatter setTimeStyle:NSDateFormatterMediumStyle];
    NSTimeZone *timeZone = [NSTimeZone localTimeZone];
    [dateFormatter setTimeZone:timeZone];
    NSString *dateString = [dateFormatter stringFromDate:[NSDate date]];
    NSRange amRange = [dateString rangeOfString:[dateFormatter AMSymbol]];
    NSRange pmRange = [dateString rangeOfString:[dateFormatter PMSymbol]];
    value_dateHas12hFormat = !(amRange.location == NSNotFound && pmRange.location == NSNotFound);
    
    dateString = [NSDateFormatter dateFormatFromTemplate:@"MdY" options:0 locale:[NSLocale currentLocale]];
    if ([dateString rangeOfString:@"."].location != NSNotFound)
    {
        value_date_separator = '.';
    }
    else if ([dateString rangeOfString:@"/"].location != NSNotFound)
    {
        value_date_separator = '/';
    }
    else if ([dateString rangeOfString:@"-"].location != NSNotFound)
    {
        value_date_separator = '-';
    }
    
    if ([dateString rangeOfString:[NSString stringWithFormat:@"M%cd", value_date_separator]].location != NSNotFound)
    {
        value_monthFirst = true;
    }
    

    
    DateUtilsInitialized = true;
}

static inline bool dateHas12hFormat()
{
    if (!DateUtilsInitialized)
        initializeDateUtils();
    
    return value_dateHas12hFormat;
}

bool TGUse12hDateFormat()
{
    if (!DateUtilsInitialized)
        initializeDateUtils();
    
    return value_dateHas12hFormat;
}

static inline NSString *weekdayNameShort(int number)
{
    if (!DateUtilsInitialized)
        initializeDateUtils();
    
    if (number < 0)
        number = 0;
    if (number > 6)
        number = 6;
    
    if (number == 0)
        number = 6;
    else
        number--;
    
    switch (number) {
        case 0:
            return NSLocalized(@"Weekday.ShortMonday", @"");
        case 1:
            return NSLocalized(@"Weekday.ShortTuesday", @"");
        case 2:
            return NSLocalized(@"Weekday.ShortWednesday", @"");
        case 3:
            return NSLocalized(@"Weekday.ShortThursday", @"");
        case 4:
            return NSLocalized(@"Weekday.ShortFriday", @"");
        case 5:
            return NSLocalized(@"Weekday.ShortSaturday", @"");
        case 6:
            return NSLocalized(@"Weekday.ShortSunday", @"");
    }
    return @"";
}

static inline NSString *weekdayNameFull(int number)
{
    if (!DateUtilsInitialized)
        initializeDateUtils();
    
    if (number < 0)
        number = 0;
    if (number > 6)
        number = 6;
    
    if (number == 0)
        number = 6;
    else
        number--;
    
    switch (number) {
        case 0:
            return NSLocalized(@"Weekday.Monday", @"");
        case 1:
            return NSLocalized(@"Weekday.Tuesday", @"");
        case 2:
            return NSLocalized(@"Weekday.Wednesday", @"");
        case 3:
            return NSLocalized(@"Weekday.Thursday", @"");
        case 4:
            return NSLocalized(@"Weekday.Friday", @"");
        case 5:
            return NSLocalized(@"Weekday.Saturday", @"");
        case 6:
            return NSLocalized(@"Weekday.Sunday", @"");
    }
    return @"";
}

static inline NSString *monthNameGenShort(int number)
{
    if (!DateUtilsInitialized)
        initializeDateUtils();
    
    if (number < 0)
        number = 0;
    if (number > 11)
        number = 11;
    
    switch (number) {
        case 0:
            return NSLocalized(@"Month.ShortJanuary", @"");
        case 1:
            return NSLocalized(@"Month.ShortFebruary", @"");
        case 2:
            return NSLocalized(@"Month.ShortMarch", @"");
        case 3:
            return NSLocalized(@"Month.ShortApril", @"");
        case 4:
            return NSLocalized(@"Month.ShortMay", @"");
        case 5:
            return NSLocalized(@"Month.ShortJune", @"");
        case 6:
            return NSLocalized(@"Month.ShortJuly", @"");
        case 7:
            return NSLocalized(@"Month.ShortAugust", @"");
        case 8:
            return NSLocalized(@"Month.ShortSeptember", @"");
        case 9:
            return NSLocalized(@"Month.ShortOctober", @"");
        case 10:
            return NSLocalized(@"Month.ShortNovember", @"");
        case 11:
            return NSLocalized(@"Month.ShortDecember", @"");
    }
    return @"";
}

static inline NSString *monthNameGenFull(int number)
{
    if (!DateUtilsInitialized)
        initializeDateUtils();
    
    if (number < 0)
        number = 0;
    if (number > 11)
        number = 11;
    
    switch (number) {
        case 0:
            return NSLocalized(@"Month.GenJanuary", @"");
        case 1:
            return NSLocalized(@"Month.GenFebruary", @"");
        case 2:
            return NSLocalized(@"Month.GenMarch", @"");
        case 3:
            return NSLocalized(@"Month.GenApril", @"");
        case 4:
            return NSLocalized(@"Month.GenMay", @"");
        case 5:
            return NSLocalized(@"Month.GenJune", @"");
        case 6:
            return NSLocalized(@"Month.GenJuly", @"");
        case 7:
            return NSLocalized(@"Month.GenAugust", @"");
        case 8:
            return NSLocalized(@"Month.GenSeptember", @"");
        case 9:
            return NSLocalized(@"Month.GenOctober", @"");
        case 10:
            return NSLocalized(@"Month.GenNovember", @"");
        case 11:
            return NSLocalized(@"Month.GenDecember", @"");
    }
    return @"";
    
}

static inline bool dialogTimeMonthNameFirst()
{
    if (!DateUtilsInitialized)
        initializeDateUtils();
    
    return value_dialogTimeMonthNameFirst();
}

static inline NSString *dialogTimeFormat()
{
    if (!DateUtilsInitialized)
        initializeDateUtils();
    
    return value_dialogTimeFormat();
}

@implementation DateUtils

+ (NSString *)stringForShortTime:(int)time
{
    time_t t = time;
    struct tm timeinfo;
    localtime_r(&t, &timeinfo);
    
    if (dateHas12hFormat())
    {
        if (timeinfo.tm_hour < 12)
            return [[NSString alloc] initWithFormat:@"%d:%02d AM", timeinfo.tm_hour == 0 ? 12 : timeinfo.tm_hour, timeinfo.tm_min];
        else
            return [[NSString alloc] initWithFormat:@"%d:%02d PM", (timeinfo.tm_hour - 12 == 0) ? 12 : (timeinfo.tm_hour - 12), timeinfo.tm_min];
    }
    else
        return [[NSString alloc] initWithFormat:@"%02d:%02d", timeinfo.tm_hour, timeinfo.tm_min];
}

+ (NSString *)stringForDialogTime:(int)time
{
    time_t t = time;
    struct tm timeinfo;
    localtime_r(&t, &timeinfo);
    
    if (dialogTimeMonthNameFirst())
        return [[NSString alloc] initWithFormat:dialogTimeFormat(), monthNameGenFull(timeinfo.tm_mon), timeinfo.tm_mday];
    else
        return [[NSString alloc] initWithFormat:dialogTimeFormat(), timeinfo.tm_mday, monthNameGenFull(timeinfo.tm_mon)];
}

+ (NSString *)stringForDayOfMonth:(int)date dayOfMonth:(int *)dayOfMonth
{
    time_t t = date;
    struct tm timeinfo;
    localtime_r(&t, &timeinfo);
    
    if (dayOfMonth != NULL)
        *dayOfMonth = timeinfo.tm_mday;
    
    if (dialogTimeMonthNameFirst())
        return [[NSString alloc] initWithFormat:@"%@ %d", monthNameGenShort(timeinfo.tm_mon), timeinfo.tm_mday];
    else
        return [[NSString alloc] initWithFormat:@"%d %@", timeinfo.tm_mday, monthNameGenShort(timeinfo.tm_mon)];
}

+ (void)setDateLocalizationFunc:(NSString* (^)(NSString *key))localizationF {
    setDateLocalizationFunc(localizationF);
}

+ (NSString *)stringForDayOfMonthFull:(int)date dayOfMonth:(int *)dayOfMonth
{
    time_t t = date;
    struct tm timeinfo;
    localtime_r(&t, &timeinfo);
    
    if (dayOfMonth != NULL)
        *dayOfMonth = timeinfo.tm_mday;
    
    if (dialogTimeMonthNameFirst())
        return [[NSString alloc] initWithFormat:@"%@ %d", monthNameGenFull(timeinfo.tm_mon), timeinfo.tm_mday];
    else
        return [[NSString alloc] initWithFormat:@"%d %@", timeinfo.tm_mday, monthNameGenFull(timeinfo.tm_mon)];
}

+ (NSString *)stringForDayOfWeek:(int)date
{
    time_t t = date;
    struct tm timeinfo;
    localtime_r(&t, &timeinfo);
    
    return weekdayNameFull(timeinfo.tm_wday);
}

+ (NSString *)stringForMessageListDate:(int)date
{   
    time_t t = date;
    struct tm timeinfo;
    localtime_r(&t, &timeinfo);
    
    time_t t_now;
    time(&t_now);
    struct tm timeinfo_now;
    localtime_r(&t_now, &timeinfo_now);
    
    if (timeinfo.tm_year != timeinfo_now.tm_year)
    {
        if (value_monthFirst)
            return [[NSString alloc] initWithFormat:@"%d%c%d%c%02d", timeinfo.tm_mon + 1, value_date_separator, timeinfo.tm_mday, value_date_separator, timeinfo.tm_year - 100];
        else
            return [[NSString alloc] initWithFormat:@"%d%c%02d%c%02d", timeinfo.tm_mday, value_date_separator, timeinfo.tm_mon + 1, value_date_separator, timeinfo.tm_year - 100];
    }
    else
    {   
        int dayDiff = timeinfo.tm_yday - timeinfo_now.tm_yday;// daysBetween(t_now, t);
        
        if(dayDiff == 0)
        {
            if (dateHas12hFormat())
            {
                if (timeinfo.tm_hour < 12)
                    return [[NSString alloc] initWithFormat:@"%d:%02d AM", timeinfo.tm_hour == 0 ? 12 : timeinfo.tm_hour, timeinfo.tm_min];
                else
                    return [[NSString alloc] initWithFormat:@"%d:%02d PM", (timeinfo.tm_hour - 12 == 0) ? 12 : (timeinfo.tm_hour - 12), timeinfo.tm_min];
            }
            else
                return [[NSString alloc] initWithFormat:@"%02d:%02d", timeinfo.tm_hour, timeinfo.tm_min];
        }
        else if(dayDiff == -1)
            return weekdayNameShort(timeinfo.tm_wday);
        else if(dayDiff == -2) 
            return weekdayNameShort(timeinfo.tm_wday);
        else if(dayDiff > -7 && dayDiff <= -2) 
            return weekdayNameShort(timeinfo.tm_wday);
        /*else if (true || (dayDiff > -180 && dayDiff <= -7))
        {
            if (dialogTimeMonthNameFirst())
                return [[NSString alloc] initWithFormat:@"%@ %d", monthNameGenShort(timeinfo.tm_mon), timeinfo.tm_mday];
            else
                return [[NSString alloc] initWithFormat:@"%d %@", timeinfo.tm_mday, monthNameGenShort(timeinfo.tm_mon)];
        }*/
        else
        {
            if (value_monthFirst)
                return [[NSString alloc] initWithFormat:@"%d%c%d%c%02d", timeinfo.tm_mon + 1, value_date_separator, timeinfo.tm_mday, value_date_separator, timeinfo.tm_year - 100];
            else
                return [[NSString alloc] initWithFormat:@"%d%c%02d%c%02d", timeinfo.tm_mday, value_date_separator, timeinfo.tm_mon + 1, value_date_separator, timeinfo.tm_year - 100];
        }
    }
    
    return nil;
}

+ (NSString *)stringForLastSeen:(int)date
{
    time_t t = date;
    struct tm timeinfo;
    localtime_r(&t, &timeinfo);
    
    time_t t_now;
    time(&t_now);
    struct tm timeinfo_now;
    localtime_r(&t_now, &timeinfo_now);
    
    if (timeinfo.tm_year != timeinfo_now.tm_year)
    {
        if (value_monthFirst)
            return [[NSString alloc] initWithFormat:@"%d%c%d%c%02d", timeinfo.tm_mon + 1, value_date_separator, timeinfo.tm_mday, value_date_separator, timeinfo.tm_year - 100];
        else
            return [[NSString alloc] initWithFormat:@"%d%c%02d%c%02d", timeinfo.tm_mday, value_date_separator, timeinfo.tm_mon + 1, value_date_separator, timeinfo.tm_year - 100];
    }
    else
    {
        int dayDiff = timeinfo.tm_yday - timeinfo_now.tm_yday;
        
        if(dayDiff == 0 || dayDiff == -1)
        {
            if (dateHas12hFormat())
            {
                if (timeinfo.tm_hour < 12)
                    return [[NSString alloc] initWithFormat:@"%@ %@ %d:%02d AM", dayDiff == 0 ? value_today() : value_yesterday(), value_at(), timeinfo.tm_hour == 0 ? 12 : timeinfo.tm_hour, timeinfo.tm_min];
                else
                    return [[NSString alloc] initWithFormat:@"%@ %@ %d:%02d PM", dayDiff == 0 ? value_today() : value_yesterday(), value_at(), (timeinfo.tm_hour - 12 == 0) ? 12 : (timeinfo.tm_hour - 12), timeinfo.tm_min];
            }
            else
                return [[NSString alloc] initWithFormat:@"%@ %@ %02d:%02d", dayDiff == 0 ? value_today() : value_yesterday(), value_at(), timeinfo.tm_hour, timeinfo.tm_min];
        }
        else if (false && dayDiff > -7 && dayDiff <= -2)
        {
            return weekdayNameShort(timeinfo.tm_wday);
        }
        else
        {
            if (value_monthFirst)
                return [[NSString alloc] initWithFormat:@"%d%c%d%c%02d", timeinfo.tm_mon + 1, value_date_separator, timeinfo.tm_mday, value_date_separator, timeinfo.tm_year - 100];
            else
                return [[NSString alloc] initWithFormat:@"%d%c%02d%c%02d", timeinfo.tm_mday, value_date_separator, timeinfo.tm_mon + 1, value_date_separator, timeinfo.tm_year - 100];
        }
    }
    
    return nil;
}

+ (NSString *)stringForLastSeenShort:(int)date
{
    time_t t = date;
    struct tm timeinfo;
    localtime_r(&t, &timeinfo);
    
    time_t t_now;
    time(&t_now);
    struct tm timeinfo_now;
    localtime_r(&t_now, &timeinfo_now);
    
    if (timeinfo.tm_year != timeinfo_now.tm_year)
    {
        if (value_monthFirst)
            return [[NSString alloc] initWithFormat:@"%d%c%d%c%02d", timeinfo.tm_mon + 1, value_date_separator, timeinfo.tm_mday, value_date_separator, timeinfo.tm_year - 100];
        else
            return [[NSString alloc] initWithFormat:@"%d%c%02d%c%02d", timeinfo.tm_mday, value_date_separator, timeinfo.tm_mon + 1, value_date_separator, timeinfo.tm_year - 100];
    }
    else
    {
        int dayDiff = timeinfo.tm_yday - timeinfo_now.tm_yday;
        
        if(dayDiff == 0 || dayDiff == -1)
        {
            if (dateHas12hFormat())
            {
                if (timeinfo.tm_hour < 12)
                    return [[NSString alloc] initWithFormat:@"%@%s%@ %d:%02d AM", dayDiff == 0 ? @"" : value_yesterday(), dayDiff == 0 ? "" : " ", value_at(), timeinfo.tm_hour == 0 ? 12 : timeinfo.tm_hour, timeinfo.tm_min];
                else
                    return [[NSString alloc] initWithFormat:@"%@%s%@ %d:%02d PM", dayDiff == 0 ? @"" : value_yesterday(), dayDiff == 0 ? "" : " ", value_at(), (timeinfo.tm_hour - 12 == 0) ? 12 : (timeinfo.tm_hour - 12), timeinfo.tm_min];
            }
            else
            {
                return [[NSString alloc] initWithFormat:@"%@%s%@ %02d:%02d", dayDiff == 0 ? @"" : value_yesterday(), dayDiff == 0 ? "" : " ", value_at(), timeinfo.tm_hour, timeinfo.tm_min];
            }
        }
        else if (false && dayDiff > -7 && dayDiff <= -2)
        {
            return weekdayNameShort(timeinfo.tm_wday);
        }
        else
        {
            if (value_monthFirst)
                return [[NSString alloc] initWithFormat:@"%d%c%d%c%02d", timeinfo.tm_mon + 1, value_date_separator, timeinfo.tm_mday, value_date_separator, timeinfo.tm_year - 100];
            else
                return [[NSString alloc] initWithFormat:@"%d%c%02d%c%02d", timeinfo.tm_mday, value_date_separator, timeinfo.tm_mon + 1, value_date_separator, timeinfo.tm_year - 100];
        }
    }
    
    return nil;
}

+ (NSString *)stringForRelativeLastSeen:(int)date
{
    time_t t = date;
    struct tm timeinfo;
    localtime_r(&t, &timeinfo);
    
    time_t t_now;
    time(&t_now);
    struct tm timeinfo_now;
    localtime_r(&t_now, &timeinfo_now);
    
    if (timeinfo.tm_year != timeinfo_now.tm_year)
    {
        if (value_monthFirst)
            return [[NSString alloc] initWithFormat:@"%d%c%d%c%02d", timeinfo.tm_mon + 1, value_date_separator, timeinfo.tm_mday, value_date_separator, timeinfo.tm_year - 100];
        else
            return [[NSString alloc] initWithFormat:@"%d%c%02d%c%02d", timeinfo.tm_mday, value_date_separator, timeinfo.tm_mon + 1, value_date_separator, timeinfo.tm_year - 100];
    }
    else
    {
        int dayDiff = timeinfo.tm_yday - timeinfo_now.tm_yday;
        
        int minutesDiff = (int) (t_now - date) / 60;
        int hoursDiff = (int) (t_now - date) / (60 * 60);
        
        if (dayDiff == 0 && hoursDiff <= 23)
        {
            if (minutesDiff < 1)
            {
                return NSLocalized(@"Time.justnow", nil);
            }
            else if (minutesDiff < 60)
            {
                return [[NSString alloc] initWithFormat:minutesDiff == 1 ? NSLocalized(@"Time.agoMinute",nil) : NSLocalized(@"Time.agoMinutes", nil), minutesDiff];
            }
            else
            {
                return [[NSString alloc] initWithFormat:hoursDiff == 1 ? NSLocalized(@"Time.agoHour",nil) : NSLocalized(@"Time.agoHours",nil), hoursDiff];
            }
        }
        else if (dayDiff == 0 || dayDiff == -1)
        {
            if (dateHas12hFormat())
            {
                if (timeinfo.tm_hour < 12)
                    return [[NSString alloc] initWithFormat:@"%@%s%@ %d:%02d AM", dayDiff == 0 ? @"" : value_yesterday(), dayDiff == 0 ? "" : " ", value_at(), timeinfo.tm_hour == 0 ? 12 : timeinfo.tm_hour, timeinfo.tm_min];
                else
                    return [[NSString alloc] initWithFormat:@"%@%s%@ %d:%02d PM", dayDiff == 0 ? @"" : value_yesterday(), dayDiff == 0 ? "" : " ", value_at(), (timeinfo.tm_hour - 12 == 0) ? 12 : (timeinfo.tm_hour - 12), timeinfo.tm_min];
            }
            else
            {
                return [[NSString alloc] initWithFormat:@"%@%s%@ %02d:%02d", dayDiff == 0 ? @"" : value_yesterday(), dayDiff == 0 ? "" : " ", value_at(), timeinfo.tm_hour, timeinfo.tm_min];
            }
        }
        else
        {
            if (value_monthFirst)
                return [[NSString alloc] initWithFormat:@"%d%c%d%c%02d", timeinfo.tm_mon + 1, value_date_separator, timeinfo.tm_mday, value_date_separator, timeinfo.tm_year - 100];
            else
                return [[NSString alloc] initWithFormat:@"%d%c%02d%c%02d", timeinfo.tm_mday, value_date_separator, timeinfo.tm_mon + 1, value_date_separator, timeinfo.tm_year - 100];
        }
    }
    
    return nil;
}

+ (NSString *)stringForUntil:(int)date
{
    time_t t = date;
    struct tm timeinfo;
    localtime_r(&t, &timeinfo);
    
    time_t t_now;
    time(&t_now);
    struct tm timeinfo_now;
    localtime_r(&t_now, &timeinfo_now);
    
    if (timeinfo.tm_year != timeinfo_now.tm_year)
    {
        if (value_monthFirst)
            return [[NSString alloc] initWithFormat:@"%d%c%d%c%02d", timeinfo.tm_mon + 1, value_date_separator, timeinfo.tm_mday, value_date_separator, timeinfo.tm_year - 100];
        else
            return [[NSString alloc] initWithFormat:@"%d%c%02d%c%02d", timeinfo.tm_mday, value_date_separator, timeinfo.tm_mon + 1, value_date_separator, timeinfo.tm_year - 100];
    }
    else
    {
        int dayDiff = timeinfo.tm_yday - timeinfo_now.tm_yday; //daysBetween(t_now, t);
        
        if(dayDiff == 0 || dayDiff == 1)
        {
            if (dateHas12hFormat())
            {
                if (timeinfo.tm_hour < 12)
                    return [[NSString alloc] initWithFormat:@"%@, %d:%02d AM", dayDiff == 0 ? value_today : value_tomorrow, timeinfo.tm_hour == 0 ? 12 : timeinfo.tm_hour, timeinfo.tm_min];
                else
                    return [[NSString alloc] initWithFormat:@"%@, %d:%02d PM", dayDiff == 0 ? value_today : value_tomorrow, (timeinfo.tm_hour - 12 == 0) ? 12 : (timeinfo.tm_hour - 12), timeinfo.tm_min];
            }
            else
                return [[NSString alloc] initWithFormat:@"%@, %02d:%02d", dayDiff == 0 ? value_today : value_tomorrow, timeinfo.tm_hour, timeinfo.tm_min];
        }
        else
        {
            if (value_monthFirst)
                return [[NSString alloc] initWithFormat:@"%d%c%d%c%02d", timeinfo.tm_mon + 1, value_date_separator, timeinfo.tm_mday, value_date_separator, timeinfo.tm_year - 100];
            else
                return [[NSString alloc] initWithFormat:@"%d%c%02d%c%02d", timeinfo.tm_mday, value_date_separator, timeinfo.tm_mon + 1, value_date_separator, timeinfo.tm_year - 100];
        }
    }
    
    return nil;
}

@end
