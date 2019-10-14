//
//  PresenceStrings.swift
//  Telegram-Mac
//
//  Created by keepcoder on 12/10/2016.
//  Copyright © 2016 Telegram. All rights reserved.
//

import Cocoa
import PostboxMac
import TelegramCoreMac
import TGUIKit
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
        dayString = tr(L10n.peerStatusToday)
    case .yesterday:
        dayString = tr(L10n.peerStatusYesterday)
    }
    return tr(L10n.peerStatusLastSeenAt(dayString, stringForTime(hours: hours, minutes: minutes)))
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

func stringAndActivityForUserPresence(_ presence: TelegramUserPresence, timeDifference: TimeInterval, relativeTo timestamp: Int32, expanded: Bool = false) -> (String, Bool, NSColor) {
    switch presence.status {
    case .none:
        return (L10n.peerStatusLongTimeAgo, false, theme.colors.grayText)
    case let .present(statusTimestamp):
        let statusTimestampInt: Int = Int(statusTimestamp)
        let statusTimestamp = Int32(min(statusTimestampInt - Int(timeDifference), Int(INT32_MAX)))
        if statusTimestamp >= timestamp {
            return (L10n.peerStatusOnline, true, theme.colors.accent)
        } else {
            let difference = timestamp - statusTimestamp
            if difference < 59 {
                return (tr(L10n.peerStatusJustNow), false, theme.colors.grayText)
            } else if difference < 60 * 60 && !expanded {
                let minutes = max(difference / 60, 1)
                
                return (L10n.peerStatusMinAgoCountable(Int(minutes)), false, theme.colors.grayText)
            } else {
                var t: time_t = time_t(statusTimestamp)
                var timeinfo: tm = tm()
                localtime_r(&t, &timeinfo)
                
                var now: time_t = time_t(timestamp)
                var timeinfoNow: tm = tm()
                localtime_r(&now, &timeinfoNow)
                
                if timeinfo.tm_year != timeinfoNow.tm_year {
                    return ("\(L10n.timeLastSeen) \(stringForTimestamp(day: timeinfo.tm_mday, month: timeinfo.tm_mon + 1, year: timeinfo.tm_year))", false, theme.colors.grayText)
                }
                
                let dayDifference = timeinfo.tm_yday - timeinfoNow.tm_yday
                if dayDifference == 0 || dayDifference == -1 {
                    let day: UserPresenceDay
                    if dayDifference == 0 {
                        if expanded {
                            day = .today
                        } else {
                            let minutes = difference / (60 * 60)
                            
                            return (L10n.lastSeenHoursAgoCountable(Int(minutes)), false, theme.colors.grayText)
                        }
                    } else {
                        day = .yesterday
                    }
                    return (stringForUserPresence(day: day, hours: timeinfo.tm_hour, minutes: timeinfo.tm_min), false, theme.colors.grayText)
                } else {
                    return ("\(L10n.timeLastSeen) \(stringForTimestamp(day: timeinfo.tm_mday, month: timeinfo.tm_mon + 1, year: timeinfo.tm_year))", false, theme.colors.grayText)
                }
            }
        }
    case .recently:
        let activeUntil = presence.lastActivity - Int32(timeDifference) + 30
        if activeUntil >= timestamp {
            return (L10n.peerStatusOnline, true, theme.colors.accent)
        } else {
            return (L10n.peerStatusRecently, false, theme.colors.grayText)
        }
    case .lastWeek:
        return (L10n.peerStatusLastWeek, false, theme.colors.grayText)
    case .lastMonth:
        return (L10n.peerStatusLastMonth, false, theme.colors.grayText)
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


func stringForRelativeSymbolicTimestamp(relativeTimestamp: Int32, relativeTo timestamp: Int32) -> String {
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
        return L10n.timeTodayAt(stringForShortTimestamp(hours: hours, minutes: minutes))
    } else {
        return stringForFullDate(timestamp: relativeTimestamp)
    }
}



func stringForShortTimestamp(hours: Int32, minutes: Int32) -> String {
    let hourString: String
    if hours == 0 {
        hourString = "12"
    } else if hours > 12 {
        hourString = "\(hours - 12)"
    } else {
        hourString = "\(hours)"
    }
    
    let periodString: String
    if hours >= 12 {
        periodString = "PM"
    } else {
        periodString = "AM"
    }
    if minutes >= 10 {
        return "\(hourString):\(minutes) \(periodString)"
    } else {
        return "\(hourString):0\(minutes) \(periodString)"
    }
}



func stringForFullDate(timestamp: Int32) -> String {
    var t: time_t = Int(timestamp)
    var timeinfo = tm()
    localtime_r(&t, &timeinfo);
    
    switch timeinfo.tm_mon + 1 {
    case 1:
        return L10n.timePreciseDateM1("\(timeinfo.tm_mday)", "\(2000 + timeinfo.tm_year - 100)", stringForShortTimestamp(hours: Int32(timeinfo.tm_hour), minutes: Int32(timeinfo.tm_min)))
    case 2:
        return L10n.timePreciseDateM2("\(timeinfo.tm_mday)", "\(2000 + timeinfo.tm_year - 100)", stringForShortTimestamp(hours: Int32(timeinfo.tm_hour), minutes: Int32(timeinfo.tm_min)))
    case 3:
        return L10n.timePreciseDateM3("\(timeinfo.tm_mday)", "\(2000 + timeinfo.tm_year - 100)", stringForShortTimestamp(hours: Int32(timeinfo.tm_hour), minutes: Int32(timeinfo.tm_min)))
    case 4:
        return L10n.timePreciseDateM4("\(timeinfo.tm_mday)", "\(2000 + timeinfo.tm_year - 100)", stringForShortTimestamp(hours: Int32(timeinfo.tm_hour), minutes: Int32(timeinfo.tm_min)))
    case 5:
        return L10n.timePreciseDateM5("\(timeinfo.tm_mday)", "\(2000 + timeinfo.tm_year - 100)", stringForShortTimestamp(hours: Int32(timeinfo.tm_hour), minutes: Int32(timeinfo.tm_min)))
    case 6:
        return L10n.timePreciseDateM6("\(timeinfo.tm_mday)", "\(2000 + timeinfo.tm_year - 100)", stringForShortTimestamp(hours: Int32(timeinfo.tm_hour), minutes: Int32(timeinfo.tm_min)))
    case 7:
        return L10n.timePreciseDateM7("\(timeinfo.tm_mday)", "\(2000 + timeinfo.tm_year - 100)", stringForShortTimestamp(hours: Int32(timeinfo.tm_hour), minutes: Int32(timeinfo.tm_min)))
    case 8:
        return L10n.timePreciseDateM8("\(timeinfo.tm_mday)", "\(2000 + timeinfo.tm_year - 100)", stringForShortTimestamp(hours: Int32(timeinfo.tm_hour), minutes: Int32(timeinfo.tm_min)))
    case 9:
        return L10n.timePreciseDateM9("\(timeinfo.tm_mday)", "\(2000 + timeinfo.tm_year - 100)", stringForShortTimestamp(hours: Int32(timeinfo.tm_hour), minutes: Int32(timeinfo.tm_min)))
    case 10:
        return L10n.timePreciseDateM10("\(timeinfo.tm_mday)", "\(2000 + timeinfo.tm_year - 100)", stringForShortTimestamp(hours: Int32(timeinfo.tm_hour), minutes: Int32(timeinfo.tm_min)))
    case 11:
        return L10n.timePreciseDateM11("\(timeinfo.tm_mday)", "\(2000 + timeinfo.tm_year - 100)", stringForShortTimestamp(hours: Int32(timeinfo.tm_hour), minutes: Int32(timeinfo.tm_min)))
    case 12:
        return L10n.timePreciseDateM12("\(timeinfo.tm_mday)", "\(2000 + timeinfo.tm_year - 100)", stringForShortTimestamp(hours: Int32(timeinfo.tm_hour), minutes: Int32(timeinfo.tm_min)))
    default:
        return ""
    }
}
