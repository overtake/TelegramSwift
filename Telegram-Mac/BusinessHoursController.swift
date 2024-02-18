//
//  BusinessHoursController.swift
//  Telegram
//
//  Created by Mikhail Filimonov on 12.02.2024.
//  Copyright © 2024 Telegram. All rights reserved.
//

import Foundation
import TelegramCore
import Postbox
import Cocoa
import TGUIKit
import SwiftSignalKit

#if DEBUG

private struct GMTZone : Equatable, Comparable {
    static func < (lhs: GMTZone, rhs: GMTZone) -> Bool {
        return lhs.hoursFromGMT < rhs.hoursFromGMT
    }
    let timeZone: TimeZone

    init(timeZone: TimeZone, abbreviation: String) {
        self.timeZone = timeZone
        self.hoursFromGMT = TimeInterval(timeZone.secondsFromGMT()) / 60.0 / 60.0
        self.abbreviation = abbreviation.replacingOccurrences(of: "_", with: " ")
    }
    let hoursFromGMT: TimeInterval
    let abbreviation: String
    
    var text: String {
        let gmtText = "\(hoursFromGMT)"
            .replacingOccurrences(of: ".5", with: ":30")
            .replacingOccurrences(of: ".0", with: "")

        if hoursFromGMT >= 0 {
            return "GMT+\(gmtText), \(abbreviation)"
        } else {
            return "GMT\(gmtText), \(abbreviation)"
        }
    }
}

private func getAllGMTTimeZones() -> [GMTZone] {
    // Fetch all known timezone identifiers
    let allTimeZoneIdentifiers = TimeZone.abbreviationDictionary.map { $0.value }
    
    let gmtTimeZones = allTimeZoneIdentifiers
    
    // Optionally, sort the array if you need the time zones in a specific order
    let sortedGMTTimeZones = gmtTimeZones.uniqueElements
    
    return sortedGMTTimeZones.map {
        GMTZone(timeZone: TimeZone(identifier: $0)!, abbreviation: $0)
    }.sorted(by: <)
}

private func formatHourToLocaleTime(hour: Int) -> String {
    // Create a DateComponents object with the hour set to the provided value
    var components = DateComponents()
    components.hour = Int(Float(hour) / 60)
    components.minute = hour % 60

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
}

private let formattedMinutes: [Int: String] = {
    var values: [Int: String] = [:]
    for i in 0 ..< 60 {
        values[i] = formatMinutesToLocaleTime(minutes: i)
    }
    return values
}()

private func formatMinutesToLocaleTime(minutes: Int) -> String {
    
    // Create a DateComponents object with the hour set to the provided value
    var components = DateComponents()
    components.minute = minutes
    
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
}

private final class Arguments {
    let context: AccountContext
    let toggleEnabled:()->Void
    let toggleDay:(State.Day)->Void
    let enableDay:(State.Day)->Void
    let addSpecific:(State.Day)->Void
    let editSpefic:(State.Day, State.Hours.MinutesInDay)->Void
    let removeSpefic:(State.Day, State.Hours.MinutesInDay)->Void
    let selectTimezone:(GMTZone)->Void
    init(context: AccountContext, toggleEnabled:@escaping()->Void, toggleDay:@escaping(State.Day)->Void, enableDay:@escaping(State.Day)->Void, addSpecific:@escaping(State.Day)->Void, removeSpefic:@escaping(State.Day, State.Hours.MinutesInDay)->Void, editSpefic:@escaping(State.Day, State.Hours.MinutesInDay)->Void, selectTimezone:@escaping(GMTZone)->Void) {
        self.context = context
        self.toggleEnabled = toggleEnabled
        self.toggleDay = toggleDay
        self.enableDay = enableDay
        self.addSpecific = addSpecific
        self.removeSpefic = removeSpefic
        self.editSpefic = editSpefic
        self.selectTimezone = selectTimezone
    }
}

private struct State : Equatable {
    enum Day : Int32 {
        case monday
        case tuesday
        case wednesday
        case thrusday
        case friday
        case saturday
        case sunday
        
        var title: String {
            switch self {
            case .monday:
                return "Monday"
            case .tuesday:
                return "Tuesday"
            case .wednesday:
                return "Wednesday"
            case .thrusday:
                return "Thrusday"
            case .friday:
                return "Friday"
            case .saturday:
                return "Saturday"
            case .sunday:
                return "Sunday"
            }
        }
        
        static var all: [Day] {
            return [.monday, .tuesday, .wednesday, .thrusday, .friday, .saturday, .sunday]
        }
    }
    struct Hours: Equatable {
        struct MinutesInDay : Equatable {
            var from: Int
            var to: Int
            var uniqueId: Int64
        }
        var list:[MinutesInDay] = []
    }
    
    var enabled: Bool = false
    
    var data:[Day: Hours] = [:]
    
    var timezone: GMTZone
    
    func openingHours(_ day: Day) -> String {
        if let hours = data[day] {
            if hours.list.isEmpty {
                return "24 hours"
            } else {
                var text: String = ""
                for (i, hour) in hours.list.enumerated() {
                    text += "\(formatHourToLocaleTime(hour: hour.from)) - \(formatHourToLocaleTime(hour: hour.to))"
                    if i < hours.list.count - 1 {
                        text += ", "
                    }
                }
                return text
            }
        } else {
            return "Closed"
        }
    }
}

private let _id_header = InputDataIdentifier("_id_header")
private let _id_enabled = InputDataIdentifier("_id_enabled")

private func _id_day(_ day: State.Day) -> InputDataIdentifier {
    return InputDataIdentifier("_id_day_\(day.rawValue)")
}
private let _id_timezone = InputDataIdentifier("_id_timezone")

private let _id_add_specific = InputDataIdentifier("_id_add_specific")

private func _id_opening_time(_ day: State.Hours.MinutesInDay) -> InputDataIdentifier {
    return InputDataIdentifier("_id_opening_time\(day.uniqueId)")
}
private func _id_closing_time(_ day: State.Hours.MinutesInDay) -> InputDataIdentifier {
    return InputDataIdentifier("_id_closing_time\(day.uniqueId)")
}
private func _id_remove_opening(_ day: State.Hours.MinutesInDay) -> InputDataIdentifier {
    return InputDataIdentifier("_id_remove_opening\(day.uniqueId)")
}

private func entries(_ state: State, arguments: Arguments) -> [InputDataEntry] {
    var entries:[InputDataEntry] = []
    
    var sectionId:Int32 = 0
    var index: Int32 = 0
    
    entries.append(.sectionId(sectionId, type: .normal))
    sectionId += 1
  
    
    entries.append(.custom(sectionId: sectionId, index: index, value: .none, identifier: _id_header, equatable: nil, comparable: nil, item: { initialSize, stableId in
        return AnimatedStickerHeaderItem(initialSize, stableId: stableId, context: arguments.context, sticker: LocalAnimatedSticker.fly_dollar, text: .initialize(string: "Turn this on to show your opening hours schedule to your customers.", color: theme.colors.listGrayText, font: .normal(.text)))
    }))
    
    entries.append(.sectionId(sectionId, type: .normal))
    sectionId += 1
    
    entries.append(.general(sectionId: sectionId, index: index, value: .none, error: nil, identifier: _id_enabled, data: .init(name: "Show Business Hours", color: theme.colors.text, type: .switchable(state.enabled), viewType: .singleItem, action: arguments.toggleEnabled)))
    
    // entries
    
    
    
    if state.enabled {
        entries.append(.sectionId(sectionId, type: .normal))
        sectionId += 1
        
        entries.append(.desc(sectionId: sectionId, index: index, text: .plain("BUSINESS HOURS"), data: .init(color: theme.colors.listGrayText, viewType: .textTopItem)))
        index += 1
        
        for (i, day) in State.Day.all.enumerated() {
            entries.append(.general(sectionId: sectionId, index: index, value: .none, error: nil, identifier: _id_day(day), data: .init(name: day.title, color: theme.colors.text, type: .switchable(state.data[day] != nil), viewType: bestGeneralViewType(State.Day.all, for: i), description: state.openingHours(day), descTextColor: theme.colors.accent, action: {
                arguments.toggleDay(day)
            }, switchAction: {
                arguments.enableDay(day)
            })))
        }
        
        entries.append(.sectionId(sectionId, type: .normal))
        sectionId += 1
        
        let zones: [ContextMenuItem] = getAllGMTTimeZones().map { zone in
            return ContextMenuItem(zone.text, handler: {
                arguments.selectTimezone(zone)
            }, state: zone.abbreviation == state.timezone.abbreviation ? .on : nil)
        }
        
        entries.append(.general(sectionId: sectionId, index: index, value: .none, error: nil, identifier: _id_timezone, data: .init(name: "Timezone", color: theme.colors.text, type: .contextSelector(state.timezone.text, zones), viewType: .singleItem)))

        
    }
    
    
    
    entries.append(.sectionId(sectionId, type: .normal))
    sectionId += 1
    
    return entries
}


private func dayEntries(_ state: State, day: State.Day, arguments: Arguments) -> [InputDataEntry] {
    var entries:[InputDataEntry] = []
    
    var sectionId:Int32 = 0
    var index: Int32 = 0
    
    
    
    entries.append(.sectionId(sectionId, type: .normal))
    sectionId += 1
  
    entries.append(.general(sectionId: sectionId, index: index, value: .none, error: nil, identifier: _id_enabled, data: .init(name: "Open On This Day", color: theme.colors.text, type: .switchable(state.data[day] != nil), viewType: .singleItem, action: {
        arguments.enableDay(day)
    })))
    
    // entries
    
    if let hours = state.data[day] {
        let getHoursMenu:(State.Hours.MinutesInDay, Bool)->[ContextMenuItem] = { hour, from in
            var items:[ContextMenuItem] = []
            
            var start: Int = 0
            var end: Int = 24 * 60
            
            if from {
                start = 0
                end = hour.to
            } else {
                start = hour.from
                end = 23 * 60
            }
            
         
            
            let s = Int(Float(start) / 60.0)
            let e = Int(Float(end) / 60.0)

            let from_hours = Int(Float(hour.from) / 60)
            let to_hours = Int(Float(hour.to) / 60)

            for i in s ... e {
                let state: NSControl.StateValue? = i == (from ? from_hours : to_hours) ? .on : nil
                let item = ContextMenuItem(formatHourToLocaleTime(hour: i * 60), handler: {
                    arguments.editSpefic(day, .init(from: from ? i * 60 : hour.from, to: !from ? i * 60 : hour.to, uniqueId: hour.uniqueId))
                }, state: state)
                
                let minutes = ContextMenu()
                var minuteItems:[ContextMenuItem] = []
                for j in 0 ..< 60 {
                    let item = ContextMenuItem(formattedMinutes[j]!, handler: {
                        arguments.editSpefic(day, .init(from: from ? i * 60 + j : hour.from, to: !from ? i * 60 + j : hour.to, uniqueId: hour.uniqueId))
                    }, state: state == .on && j == (from ? hour.from % 60 : hour.to % 60) ? .on : nil)
                    
                    minuteItems.append(item)
                }
                minutes.items = minuteItems
                
                item.submenu = minutes
                items.append(item)
            }
            return items
        }
                
        for hour in hours.list {
            
            entries.append(.sectionId(sectionId, type: .normal))
            sectionId += 1

            entries.append(.general(sectionId: sectionId, index: index, value: .none, error: nil, identifier: _id_opening_time(hour), data: .init(name: "Opening Time", color: theme.colors.text, type: .contextSelector(formatHourToLocaleTime(hour: hour.from), getHoursMenu(hour, true)), viewType: .firstItem)))
            
            entries.append(.general(sectionId: sectionId, index: index, value: .none, error: nil, identifier: _id_closing_time(hour), data: .init(name: "Closing Time", color: theme.colors.text, type: .contextSelector(formatHourToLocaleTime(hour: hour.to), getHoursMenu(hour, false)), viewType: .innerItem)))
            
            entries.append(.general(sectionId: sectionId, index: index, value: .none, error: nil, identifier: _id_remove_opening(hour), data: .init(name: "Remove", color: theme.colors.redUI, type: .none, viewType: .lastItem, action: {
                arguments.removeSpefic(day, hour)
            })))

        }
    }
    

    let count = state.data[day]?.list.count ?? 0
        
    sectionId = 1000
    
    entries.append(.sectionId(sectionId, type: .normal))
    sectionId += 1

    entries.append(.general(sectionId: sectionId, index: index, value: .none, error: nil, identifier: _id_add_specific, data: .init(name: "Add a Set of Hours", color: theme.colors.accent, type: .none, viewType: .singleItem, action: {
        arguments.addSpecific(day)
    })))
    
    entries.append(.desc(sectionId: sectionId, index: index, text: .plain("Specify your working hours during the day."), data: .init(color: theme.colors.listGrayText, viewType: .textBottomItem)))
    
    
    entries.append(.sectionId(sectionId, type: .normal))
    sectionId += 1
    
    return entries
}


func BusinessHoursController(context: AccountContext) -> InputDataController {

    let actionsDisposable = DisposableSet()
    
    let timezone = GMTZone(timeZone: TimeZone.current, abbreviation: "")
    
    let effectiveTimezone = getAllGMTTimeZones().first(where: { $0.hoursFromGMT == timezone.hoursFromGMT })!

    let initialState = State(timezone: effectiveTimezone)
    
    let statePromise = ValuePromise(initialState, ignoreRepeated: true)
    let stateValue = Atomic(value: initialState)
    let updateState: ((State) -> State) -> Void = { f in
        statePromise.set(stateValue.modify (f))
    }
    
    var getArguments:(()->Arguments?)? = nil

    let arguments = Arguments(context: context, toggleEnabled: {
        updateState { current in
            var current = current
            current.enabled = !current.enabled
            return current
        }
    }, toggleDay: { day in
        if let arguments = getArguments?() {
            context.bindings.rootNavigation().push(BusinessdayHoursController(context: context, stateSignal: statePromise.get(), arguments: arguments, day: day))
        }
    }, enableDay: { day in
        updateState { current in
            var current = current
            if current.data[day] != nil {
                current.data.removeValue(forKey: day)
            } else {
                current.data[day] = .init(list: [])
            }
            return current
        }
    }, addSpecific: { day in
        updateState { current in
            var current = current
            var hours = current.data[day] ?? .init()
            hours.list.append(.init(from: 9 * 60, to: 23 * 60, uniqueId: arc4random64()))
            current.data[day] = hours
            return current
        }
    }, removeSpefic: { day, hour in
        updateState { current in
            var current = current
            var hours = current.data[day] ?? .init()
            hours.list.removeAll(where: { $0.uniqueId == hour.uniqueId })
            current.data[day] = hours
            return current
        }
    }, editSpefic: { day, hour in
        updateState { current in
            var current = current
            var hours = current.data[day] ?? .init()
            if let hourIndex = hours.list.firstIndex(where: { $0.uniqueId == hour.uniqueId }) {
                hours.list[hourIndex] = hour
            }
            current.data[day] = hours
            return current
        }
    }, selectTimezone: { timezone in
        updateState { current in
            var current = current
            current.timezone = timezone
            return current
        }
    })
    
    getArguments = { [weak arguments] in
        return arguments
    }
    
    
    let signal = statePromise.get() |> deliverOnPrepareQueue |> map { state in
        return InputDataSignalValue(entries: entries(state, arguments: arguments), grouping: false)
    }
    
    let controller = InputDataController(dataSignal: signal, title: "Business Hours", removeAfterDisappear: false, hasDone: false)
    
    controller.onDeinit = {
        actionsDisposable.dispose()
    }

    return controller
    
}






private func BusinessdayHoursController(context: AccountContext, stateSignal: Signal<State, NoError>, arguments: Arguments, day: State.Day) -> InputDataController {
    
    let signal = stateSignal |> deliverOnPrepareQueue |> map { state in
        return InputDataSignalValue(entries: dayEntries(state, day: day, arguments: arguments), grouping: false)
    }
    
    let controller = InputDataController(dataSignal: signal, title: day.title, removeAfterDisappear: false, hasDone: false)
    
    return controller
    
}


#endif
