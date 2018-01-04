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

func relativeUserPresenceStatus(_ presence: TelegramUserPresence, relativeTo timestamp: Int32) -> RelativeUserPresenceStatus {
    switch presence.status {
    case .none:
        return .offline
    case let .present(statusTimestamp):
        if statusTimestamp >= timestamp {
            return .online(at: statusTimestamp)
        } else {
            return .lastSeen(at: statusTimestamp)
        }
    case .recently:
        return .recently
    case .lastWeek:
        return .lastWeek
    case .lastMonth:
        return .lastMonth
    }
}

func stringAndActivityForUserPresence(_ presence: TelegramUserPresence, relativeTo timestamp: Int32) -> (String, Bool, NSColor) {
    switch presence.status {
    case .none:
        return (tr(L10n.peerStatusRecently), false, theme.colors.grayText)
    case let .present(statusTimestamp):
        if statusTimestamp >= timestamp {
            return (tr(L10n.peerStatusOnline), true, theme.colors.blueText)
        } else {
            let difference = timestamp - statusTimestamp
            if difference < 59 {
                return (tr(L10n.peerStatusJustNow), false, theme.colors.grayText)
            } else if difference < 60 * 60 {
                let minutes = max(difference / 60, 1)
                
                return (tr(L10n.peerStatusMinAgoCountable(Int(minutes))), false, theme.colors.grayText)
            } else {
                var t: time_t = time_t(statusTimestamp)
                var timeinfo: tm = tm()
                localtime_r(&t, &timeinfo)
                
                var now: time_t = time_t(timestamp)
                var timeinfoNow: tm = tm()
                localtime_r(&now, &timeinfoNow)
                
                if timeinfo.tm_year != timeinfoNow.tm_year {
                    return ("\(tr(L10n.timeLastSeen)) \(stringForTimestamp(day: timeinfo.tm_mday, month: timeinfo.tm_mon + 1, year: timeinfo.tm_year))", false, theme.colors.grayText)
                }
                
                let dayDifference = timeinfo.tm_yday - timeinfoNow.tm_yday
                if dayDifference == 0 || dayDifference == -1 {
                    let day: UserPresenceDay
                    if dayDifference == 0 {
                        day = .today
                    } else {
                        day = .yesterday
                    }
                    return (stringForUserPresence(day: day, hours: timeinfo.tm_hour, minutes: timeinfo.tm_min), false, theme.colors.grayText)
                } else {
                    return ("\(tr(L10n.timeLastSeen)) \(stringForTimestamp(day: timeinfo.tm_mday, month: timeinfo.tm_mon + 1, year: timeinfo.tm_year))", false, theme.colors.grayText)
                }
            }
        }
    case .recently:
        return (tr(L10n.peerStatusRecently), false, theme.colors.grayText)
    case .lastWeek:
        return (tr(L10n.peerStatusLastWeek), false, theme.colors.grayText)
    case .lastMonth:
        return (tr(L10n.peerStatusLastMonth), false, theme.colors.grayText)
    }
}

func userPresenceStringRefreshTimeout(_ presence: TelegramUserPresence, relativeTo timestamp: Int32) -> Double {
    switch presence.status {
    case let .present(statusTimestamp):
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
    case .recently, .none, .lastWeek, .lastMonth:
        return Double.infinity
    }
}
