//
//  PresenceStrings.swift
//  Telegram-Mac
//
//  Created by keepcoder on 12/10/2016.
//  Copyright © 2016 Telegram. All rights reserved.
//

import Cocoa
import Postbox
import TelegramCore
import DateUtils
import TGUIKit
import MapKit
import CalendarUtils

func stringForTimestamp(day: Int32, month: Int32, year: Int32) -> String {
    return String(format: "%d.%02d.%02d", day, month, year - 100)
}

func stringForTime(hours: Int32, minutes: Int32) -> String {
    return String(format: "%d:%02d", hours, minutes)
}

enum UserPresenceDay {
    case today
    case yesterday
}

func stringForUserPresence(day: UserPresenceDay, hours: Int32, minutes: Int32) -> String {
    let dayString: String
    switch day {
    case .today:
        dayString = strings().peerStatusToday
    case .yesterday:
        dayString = strings().peerStatusYesterday
    }
    return strings().peerStatusLastSeenAt(dayString, stringForTime(hours: hours, minutes: minutes))
}

enum RelativeUserPresenceLastSeen {
    case justNow
    case minutesAgo(Int32)
    case hoursAgo(Int32)
    case todayAt(hours: Int32, minutes: Int32)
    case yesterdayAt(hours: Int32, minutes: Int32)
    case thisYear(month: Int32, day: Int32)
    case atDate(year: Int32, month: Int32)
}

enum RelativeUserPresenceStatus {
    case offline
    case online(at: Int32)
    case lastSeen(at: Int32)
    case recently
    case lastWeek
    case lastMonth
}

func relativeUserPresenceStatus(_ presence: TelegramUserPresence, timeDifference: TimeInterval, relativeTo timestamp: Int32) -> RelativeUserPresenceStatus {
    switch presence.status {
    case .none:
        return .offline
    case let .present(statusTimestamp):
        let statusTimestampInt: Int = Int(statusTimestamp)
        let statusTimestamp = Int32(min(statusTimestampInt - Int(timeDifference), Int(INT32_MAX)))
        if statusTimestamp >= timestamp {
            return .online(at: statusTimestamp)
        } else {
            return .lastSeen(at: statusTimestamp)
        }
        
    case .recently:
        let activeUntil = presence.lastActivity - Int32(timeDifference) + 30
        if activeUntil >= timestamp {
            return .online(at: activeUntil)
        } else {
            return .recently
        }
    case .lastWeek:
        return .lastWeek
    case .lastMonth:
        return .lastMonth
    }
}

func stringAndActivityForUserPresence(_ presence: TelegramUserPresence, timeDifference: TimeInterval, relativeTo timestamp: Int32, expanded: Bool = false, customTheme: GeneralRowItem.Theme? = nil) -> (String, Bool, NSColor) {
    
    switch presence.status {
    case .none:
        return (strings().peerStatusLongTimeAgo, false, customTheme?.grayTextColor ?? theme.colors.grayText)
    case let .present(statusTimestamp):
        let statusTimestampInt: Int = Int(statusTimestamp)
        let statusTimestamp = Int32(min(statusTimestampInt - Int(timeDifference), Int(INT32_MAX)))
        if statusTimestamp > timestamp {
            return (strings().peerStatusOnline, true, customTheme?.accentColor ?? theme.colors.accent)
        } else {
            let difference = timestamp - statusTimestamp
            if difference < 59 {
                return (strings().peerStatusJustNow, false, customTheme?.grayTextColor ?? theme.colors.grayText)
            } else if difference < 60 * 60 && !expanded {
                let minutes = max(difference / 60, 1)
                
                return (strings().peerStatusMinAgoCountable(Int(minutes)), false, customTheme?.grayTextColor ?? theme.colors.grayText)
            } else {
                var t: time_t = time_t(statusTimestamp)
                var timeinfo: tm = tm()
                localtime_r(&t, &timeinfo)
                
                var now: time_t = time_t(timestamp)
                var timeinfoNow: tm = tm()
                localtime_r(&now, &timeinfoNow)
                
                if timeinfo.tm_year != timeinfoNow.tm_year {
                    return ("\(strings().timeLastSeen) \(stringForTimestamp(day: timeinfo.tm_mday, month: timeinfo.tm_mon + 1, year: timeinfo.tm_year))", false, customTheme?.grayTextColor ?? theme.colors.grayText)
                }
                
                let dayDifference = timeinfo.tm_yday - timeinfoNow.tm_yday
                if dayDifference == 0 || dayDifference == -1 {
                    let day: UserPresenceDay
                    if dayDifference == 0 {
                        if expanded {
                            day = .today
                        } else {
                            let minutes = difference / (60 * 60)
                            
                            return (strings().lastSeenHoursAgoCountable(Int(minutes)), false, customTheme?.grayTextColor ?? theme.colors.grayText)
                        }
                    } else {
                        day = .yesterday
                    }
                    return (stringForUserPresence(day: day, hours: timeinfo.tm_hour, minutes: timeinfo.tm_min), false, customTheme?.grayTextColor ?? theme.colors.grayText)
                } else {
                    return ("\(strings().timeLastSeen) \(stringForTimestamp(day: timeinfo.tm_mday, month: timeinfo.tm_mon + 1, year: timeinfo.tm_year))", false, customTheme?.grayTextColor ?? theme.colors.grayText)
                }
            }
        }
    case .recently:
        let activeUntil = presence.lastActivity - Int32(timeDifference) + 30
        if activeUntil >= timestamp {
            return (strings().peerStatusOnline, true, customTheme?.accentColor ?? theme.colors.accent)
        } else {
            return (strings().peerStatusRecently, false, customTheme?.grayTextColor ?? theme.colors.grayText)
        }
    case .lastWeek:
        return (strings().peerStatusLastWeek, false, customTheme?.grayTextColor ?? theme.colors.grayText)
    case .lastMonth:
        return (strings().peerStatusLastMonth, false, customTheme?.grayTextColor ?? theme.colors.grayText)
    }
}

func userPresenceStringRefreshTimeout(_ presence: TelegramUserPresence, timeDifference: Int32, relativeTo timestamp: Int32) -> Double {
    switch presence.status {
    case let .present(statusTimestamp):
        
        let statusTimestampInt: Int = Int(statusTimestamp)
        let statusTimestamp = Int32(min(statusTimestampInt, Int(INT32_MAX)))
        
        if statusTimestamp > INT32_MAX - 1 {
            return Double.infinity
        }
        if statusTimestamp >= timestamp {
            return Double(statusTimestamp - timestamp)
        } else {
            let difference = timestamp - statusTimestamp
            if difference < 30 {
                return Double((30 - difference) + 1)
            } else if difference < 60 * 60 {
                return Double((difference % 60) + 1)
            } else {
                return Double.infinity
            }
        }
    case .recently:
        let activeUntil = presence.lastActivity - timeDifference + 30
        if activeUntil >= timestamp {
            return Double(activeUntil - timestamp + 1)
        } else {
            return Double.infinity
        }

    case .none, .lastWeek, .lastMonth:
        return Double.infinity
    }
}


func stringForRelativeSymbolicTimestamp(relativeTimestamp: Int32, relativeTo timestamp: Int32, medium: Bool = false) -> String {
    var t: time_t = time_t(relativeTimestamp)
    var timeinfo: tm = tm()
    localtime_r(&t, &timeinfo)
    
    var now: time_t = time_t(timestamp)
    var timeinfoNow: tm = tm()
    localtime_r(&now, &timeinfoNow)
    
    let dayDifference = timeinfo.tm_yday - timeinfoNow.tm_yday
    
    let hours = timeinfo.tm_hour
    let minutes = timeinfo.tm_min
    
    if dayDifference == 0 {
        return strings().timeTodayAt(stringForShortTimestamp(hours: hours, minutes: minutes))
    } else {
        if medium {
            return stringForMediumDate(timestamp: relativeTimestamp)
        } else {
            return stringForFullDate(timestamp: relativeTimestamp)
        }
    }
}



func stringForShortTimestamp(hours: Int32, minutes: Int32) -> String {
    
    
    
    var components = DateComponents()
    components.hour = Int(hours)
    components.minute = Int(minutes)

    // Use the current calendar to ensure the components are interpreted correctly
    let calendar = Calendar.current
    
    // Optional: you might want to ensure you're using the current time zone
    components.timeZone = TimeZone.current
    
    // Create a Date from components
    guard let date = calendar.date(from: components) else {
        print("Failed to create date from components.")
        return ""
    }
    
    // Create a DateFormatter and set its dateStyle to .none and timeStyle to .short
    // This will ensure that the time is formatted according to the user's locale
    let formatter = DateFormatter()
    formatter.dateStyle = .none
    formatter.timeStyle = .short
    
    // Format the date to a string
    let formattedTime = formatter.string(from: date)
    
    return formattedTime
//    
//    let hourString: String
//    if hours == 0 {
//        hourString = "12"
//    } else if hours > 12 {
//        hourString = "\(hours - 12)"
//    } else {
//        hourString = "\(hours)"
//    }
//    
//    let periodString: String
//    if hours >= 12 {
//        periodString = "PM"
//    } else {
//        periodString = "AM"
//    }
//    if minutes >= 10 {
//        return "\(hourString):\(minutes) \(periodString)"
//    } else {
//        return "\(hourString):0\(minutes) \(periodString)"
//    }
}

func stringForDuration(_ duration: Int32) -> String {
    return String.durationTransformed(elapsed: Int(duration))
}

func stringForFullDate(timestamp: Int32) -> String {
    var t: time_t = Int(timestamp)
    var timeinfo = tm()
    localtime_r(&t, &timeinfo);
    
    switch timeinfo.tm_mon + 1 {
    case 1:
        return strings().timePreciseDateM1("\(timeinfo.tm_mday)", "\(2000 + timeinfo.tm_year - 100)", stringForShortTimestamp(hours: Int32(timeinfo.tm_hour), minutes: Int32(timeinfo.tm_min)))
    case 2:
        return strings().timePreciseDateM2("\(timeinfo.tm_mday)", "\(2000 + timeinfo.tm_year - 100)", stringForShortTimestamp(hours: Int32(timeinfo.tm_hour), minutes: Int32(timeinfo.tm_min)))
    case 3:
        return strings().timePreciseDateM3("\(timeinfo.tm_mday)", "\(2000 + timeinfo.tm_year - 100)", stringForShortTimestamp(hours: Int32(timeinfo.tm_hour), minutes: Int32(timeinfo.tm_min)))
    case 4:
        return strings().timePreciseDateM4("\(timeinfo.tm_mday)", "\(2000 + timeinfo.tm_year - 100)", stringForShortTimestamp(hours: Int32(timeinfo.tm_hour), minutes: Int32(timeinfo.tm_min)))
    case 5:
        return strings().timePreciseDateM5("\(timeinfo.tm_mday)", "\(2000 + timeinfo.tm_year - 100)", stringForShortTimestamp(hours: Int32(timeinfo.tm_hour), minutes: Int32(timeinfo.tm_min)))
    case 6:
        return strings().timePreciseDateM6("\(timeinfo.tm_mday)", "\(2000 + timeinfo.tm_year - 100)", stringForShortTimestamp(hours: Int32(timeinfo.tm_hour), minutes: Int32(timeinfo.tm_min)))
    case 7:
        return strings().timePreciseDateM7("\(timeinfo.tm_mday)", "\(2000 + timeinfo.tm_year - 100)", stringForShortTimestamp(hours: Int32(timeinfo.tm_hour), minutes: Int32(timeinfo.tm_min)))
    case 8:
        return strings().timePreciseDateM8("\(timeinfo.tm_mday)", "\(2000 + timeinfo.tm_year - 100)", stringForShortTimestamp(hours: Int32(timeinfo.tm_hour), minutes: Int32(timeinfo.tm_min)))
    case 9:
        return strings().timePreciseDateM9("\(timeinfo.tm_mday)", "\(2000 + timeinfo.tm_year - 100)", stringForShortTimestamp(hours: Int32(timeinfo.tm_hour), minutes: Int32(timeinfo.tm_min)))
    case 10:
        return strings().timePreciseDateM10("\(timeinfo.tm_mday)", "\(2000 + timeinfo.tm_year - 100)", stringForShortTimestamp(hours: Int32(timeinfo.tm_hour), minutes: Int32(timeinfo.tm_min)))
    case 11:
        return strings().timePreciseDateM11("\(timeinfo.tm_mday)", "\(2000 + timeinfo.tm_year - 100)", stringForShortTimestamp(hours: Int32(timeinfo.tm_hour), minutes: Int32(timeinfo.tm_min)))
    case 12:
        return strings().timePreciseDateM12("\(timeinfo.tm_mday)", "\(2000 + timeinfo.tm_year - 100)", stringForShortTimestamp(hours: Int32(timeinfo.tm_hour), minutes: Int32(timeinfo.tm_min)))
    default:
        return ""
    }
}

func stringForDate(timestamp: Int32) -> String {
    var t: time_t = Int(timestamp)
    var timeinfo = tm()
    localtime_r(&t, &timeinfo);
    
    switch timeinfo.tm_mon + 1 {
    case 1:
        return strings().timePreciseDateM1("\(timeinfo.tm_mday)", "", stringForShortTimestamp(hours: Int32(timeinfo.tm_hour), minutes: Int32(timeinfo.tm_min)))
    case 2:
        return strings().timePreciseDateM2("\(timeinfo.tm_mday)", "", stringForShortTimestamp(hours: Int32(timeinfo.tm_hour), minutes: Int32(timeinfo.tm_min)))
    case 3:
        return strings().timePreciseDateM3("\(timeinfo.tm_mday)", "", stringForShortTimestamp(hours: Int32(timeinfo.tm_hour), minutes: Int32(timeinfo.tm_min)))
    case 4:
        return strings().timePreciseDateM4("\(timeinfo.tm_mday)", "", stringForShortTimestamp(hours: Int32(timeinfo.tm_hour), minutes: Int32(timeinfo.tm_min)))
    case 5:
        return strings().timePreciseDateM5("\(timeinfo.tm_mday)", "", stringForShortTimestamp(hours: Int32(timeinfo.tm_hour), minutes: Int32(timeinfo.tm_min)))
    case 6:
        return strings().timePreciseDateM6("\(timeinfo.tm_mday)", "", stringForShortTimestamp(hours: Int32(timeinfo.tm_hour), minutes: Int32(timeinfo.tm_min)))
    case 7:
        return strings().timePreciseDateM7("\(timeinfo.tm_mday)", "", stringForShortTimestamp(hours: Int32(timeinfo.tm_hour), minutes: Int32(timeinfo.tm_min)))
    case 8:
        return strings().timePreciseDateM8("\(timeinfo.tm_mday)", "", stringForShortTimestamp(hours: Int32(timeinfo.tm_hour), minutes: Int32(timeinfo.tm_min)))
    case 9:
        return strings().timePreciseDateM9("\(timeinfo.tm_mday)", "", stringForShortTimestamp(hours: Int32(timeinfo.tm_hour), minutes: Int32(timeinfo.tm_min)))
    case 10:
        return strings().timePreciseDateM10("\(timeinfo.tm_mday)", "", stringForShortTimestamp(hours: Int32(timeinfo.tm_hour), minutes: Int32(timeinfo.tm_min)))
    case 11:
        return strings().timePreciseDateM11("\(timeinfo.tm_mday)", "", stringForShortTimestamp(hours: Int32(timeinfo.tm_hour), minutes: Int32(timeinfo.tm_min)))
    case 12:
        return strings().timePreciseDateM12("\(timeinfo.tm_mday)", "", stringForShortTimestamp(hours: Int32(timeinfo.tm_hour), minutes: Int32(timeinfo.tm_min)))
    default:
        return ""
    }
}

extension Date {
    
    static var kernelBootTimeSecs:Int32 {
        var mib = [ CTL_KERN, KERN_BOOTTIME ]
        var bootTime = timeval()
        var bootTimeSize = MemoryLayout<timeval>.size
        
        if 0 != sysctl(&mib, UInt32(mib.count), &bootTime, &bootTimeSize, nil, 0) {
            fatalError("Could not get boot time, errno: \(errno)")
        }
        
        return Int32(bootTime.tv_sec)
    }
    var isToday: Bool {
        return CalendarUtils.isSameDate(self, date: Date(), checkDay: true)
    }
    var isTomorrow: Bool {
        return Calendar.current.isDateInTomorrow(self)
    }
}


func stringForMediumDate(timestamp: Int32) -> String {
    var t: time_t = Int(timestamp)
    var timeinfo = tm()
    localtime_r(&t, &timeinfo);
    let formatter = DateFormatter()
    formatter.timeStyle = .short

    let date = Date(timeIntervalSince1970: TimeInterval(timestamp))
    let time = formatter.string(from: date)

    if date.isToday || date.timeIntervalSince1970 < Date().timeIntervalSince1970 {
        return DateUtils.string(forLastSeen: timestamp)
    } else if date.isTomorrow {
        return strings().timeTomorrowAt(time)
    }
    
    
    
    switch timeinfo.tm_mon + 1 {
    case 1:
        return strings().timePreciseMediumDateM1("\(timeinfo.tm_mday)", time)
    case 2:
        return strings().timePreciseMediumDateM2("\(timeinfo.tm_mday)", time)
    case 3:
        return strings().timePreciseMediumDateM3("\(timeinfo.tm_mday)", time)
    case 4:
        return strings().timePreciseMediumDateM4("\(timeinfo.tm_mday)", time)
    case 5:
        return strings().timePreciseMediumDateM5("\(timeinfo.tm_mday)", time)
    case 6:
        return strings().timePreciseMediumDateM6("\(timeinfo.tm_mday)", time)
    case 7:
        return strings().timePreciseMediumDateM7("\(timeinfo.tm_mday)", time)
    case 8:
        return strings().timePreciseMediumDateM8("\(timeinfo.tm_mday)", time)
    case 9:
        return strings().timePreciseMediumDateM9("\(timeinfo.tm_mday)", time)
    case 10:
        return strings().timePreciseMediumDateM10("\(timeinfo.tm_mday)", time)
    case 11:
        return strings().timePreciseMediumDateM11("\(timeinfo.tm_mday)", time)
    case 12:
        return strings().timePreciseMediumDateM12("\(timeinfo.tm_mday)", time)
    default:
        return ""
    }
}

private var sharedDistanceFormatter: MKDistanceFormatter?
func stringForDistance(distance: CLLocationDistance) -> String {
    let distanceFormatter: MKDistanceFormatter
    if let currentDistanceFormatter = sharedDistanceFormatter {
        distanceFormatter = currentDistanceFormatter
    } else {
        distanceFormatter = MKDistanceFormatter()
        distanceFormatter.unitStyle = .full
        sharedDistanceFormatter = distanceFormatter
    }
    
    return distanceFormatter.string(fromDistance: distance)
}



public func formatBirthdayToString(day: Int, month: Int, year: Int?) -> String? {
    var dateComponents = DateComponents()
    dateComponents.year = year
    dateComponents.month = month
    dateComponents.day = day

    // Use the current calendar and adjust it according to the system's locale if necessary
    let calendar = Calendar.current

    guard let date = calendar.date(from: dateComponents) else {
        return nil
    }

    let dateFormatter = DateFormatter()
    if year == nil {
        dateFormatter.dateFormat = "MMM d"
    } else {
        dateFormatter.dateStyle = .medium
        dateFormatter.timeStyle = .none
    }

    // The locale and time zone adjustments are optional and can be tailored to specific needs
    dateFormatter.locale = Locale.current // Use the current system locale
    dateFormatter.timeZone = TimeZone.current // Use the current system time zone

    return dateFormatter.string(from: date)
}
