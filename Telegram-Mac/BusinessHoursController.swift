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

private func wrappedMinuteRange(range: Range<Int>, dayIndexOffset: Int = 0) -> IndexSet {
    let mappedRange = (range.lowerBound + dayIndexOffset * 24 * 60) ..< (range.upperBound + dayIndexOffset * 24 * 60)
    
    var result = IndexSet()
    if mappedRange.upperBound > 7 * 24 * 60 {
        if mappedRange.lowerBound < 7 * 24 * 60 {
            result.insert(integersIn: mappedRange.lowerBound ..< 7 * 24 * 60)
        }
        result.insert(integersIn: 0 ..< (mappedRange.upperBound - 7 * 24 * 60))
    } else {
        result.insert(integersIn: mappedRange)
    }
    return result
}


extension TimeZoneList.Item {
    
    var gmtText: String {
        let hoursFromGMT = TimeInterval(self.utcOffset) / 60.0 / 60.0
        let gmtText = "\(hoursFromGMT)"
            .replacingOccurrences(of: ".5", with: ":30")
            .replacingOccurrences(of: ".0", with: "")
        if hoursFromGMT >= 0 {
            return "\(strings().businessHoursUTC)+\(gmtText)"
        } else {
            return "\(strings().businessHoursUTC)\(gmtText)"
        }
    }
    var text: String {
        let hoursFromGMT = TimeInterval(self.utcOffset) / 60.0 / 60.0
        let gmtText = "\(hoursFromGMT)"
            .replacingOccurrences(of: ".5", with: ":30")
            .replacingOccurrences(of: ".0", with: "")

        if hoursFromGMT >= 0 {
            return "\(title), \(strings().businessHoursUTC)+\(gmtText)"
        } else {
            return "\(title), \(strings().businessHoursUTC)\(gmtText)"
        }
    }
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
    let selectTimezone:(TimeZoneList.Item)->Void
    let selectSpecific:(State.Day, State.Hours.MinutesInDay, Bool)->Void
    let openTimezones:()->Void
    init(context: AccountContext, toggleEnabled:@escaping()->Void, toggleDay:@escaping(State.Day)->Void, enableDay:@escaping(State.Day)->Void, addSpecific:@escaping(State.Day)->Void, removeSpefic:@escaping(State.Day, State.Hours.MinutesInDay)->Void, editSpefic:@escaping(State.Day, State.Hours.MinutesInDay)->Void, selectTimezone:@escaping(TimeZoneList.Item)->Void, selectSpecific:@escaping(State.Day, State.Hours.MinutesInDay, Bool)->Void, openTimezones:@escaping()->Void) {
        self.context = context
        self.toggleEnabled = toggleEnabled
        self.toggleDay = toggleDay
        self.enableDay = enableDay
        self.addSpecific = addSpecific
        self.removeSpefic = removeSpefic
        self.editSpefic = editSpefic
        self.selectTimezone = selectTimezone
        self.selectSpecific = selectSpecific
        self.openTimezones = openTimezones
    }
}

private struct State : Equatable {
    
    enum ValidationError: Error {
        case intersectingRanges
    }

    
    enum Day : Int {
        case monday = 0
        case tuesday = 1
        case wednesday = 2
        case thursday = 3
        case friday = 4
        case saturday = 5
        case sunday = 6
        
        var title: String {
            switch self {
            case .monday:
                return strings().weekdayMonday
            case .tuesday:
                return strings().weekdayTuesday
            case .wednesday:
                return strings().weekdayWednesday
            case .thursday:
                return strings().weekdayThursday
            case .friday:
                return strings().weekdayFriday
            case .saturday:
                return strings().weekdaySaturday
            case .sunday:
                return strings().weekdaySunday
            }
        }
        
        static var all: [Day] {
            return [.monday, .tuesday, .wednesday, .thursday, .friday, .saturday, .sunday]
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
    
    var timezone: TimeZoneList.Item?
    
    var initial: TelegramBusinessHours?
    
    var timeZones: TimeZoneList?
    
    func openingHours(_ day: Day) -> String {
        if let hours = data[day] {
            if hours.list.isEmpty || hours.list[0].from == 0 && hours.list[0].to == 60 * 24 {
                return strings().businessHours24Hours
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
            return strings().businessHoursClosed
        }
    }
    
    
    func mapped() throws -> TelegramBusinessHours? {
        
        if !enabled {
            return nil
        }
        guard let timezone = self.timezone else {
            return nil
        }
        var mappedIntervals: [TelegramBusinessHours.WorkingTimeInterval] = []
        
        var filledMinutes = IndexSet()
        for i in 0 ..< 7 {
            guard let today: State.Day = .init(rawValue: i) else {
                return nil
            }
            
            let dayStartMinute = i * 24 * 60
            guard let effectiveRanges = self.data[today]?.list else {
                continue
            }
        

            for range in effectiveRanges {
                let minuteRange: Range<Int> = (dayStartMinute + range.from) ..< (dayStartMinute + range.to)
                
                let wrappedMinutes = wrappedMinuteRange(range: minuteRange)
                
                if !filledMinutes.intersection(wrappedMinutes).isEmpty {
                    throw ValidationError.intersectingRanges
                }
                filledMinutes.formUnion(wrappedMinutes)
                mappedIntervals.append(TelegramBusinessHours.WorkingTimeInterval(startMinute: minuteRange.lowerBound, endMinute: minuteRange.upperBound))
            }
            if effectiveRanges.isEmpty {
                let minuteRange: Range<Int> = (dayStartMinute + 0) ..< (dayStartMinute + 24 * 60)
                mappedIntervals.append(TelegramBusinessHours.WorkingTimeInterval(startMinute: minuteRange.lowerBound, endMinute: minuteRange.upperBound))
            }
        }
        
        var mergedIntervals: [TelegramBusinessHours.WorkingTimeInterval] = []
        for interval in mappedIntervals {
            if mergedIntervals.isEmpty {
                mergedIntervals.append(interval)
            } else {
                let index = mergedIntervals.count - 1
                if mergedIntervals[index].endMinute >= interval.startMinute {
                    mergedIntervals[index] = TelegramBusinessHours.WorkingTimeInterval(startMinute: mergedIntervals[index].startMinute, endMinute: interval.endMinute)
                } else {
                    mergedIntervals.append(interval)
                }
            }
        }

        
        return TelegramBusinessHours(timezoneId: timezone.id, weeklyTimeIntervals: mergedIntervals)
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
        return AnimatedStickerHeaderItem(initialSize, stableId: stableId, context: arguments.context, sticker: LocalAnimatedSticker.business_hours, text: .initialize(string: strings().businessHoursHeader, color: theme.colors.listGrayText, font: .normal(.text)))
    }))
    
    entries.append(.sectionId(sectionId, type: .normal))
    sectionId += 1
    
    entries.append(.general(sectionId: sectionId, index: index, value: .none, error: nil, identifier: _id_enabled, data: .init(name: strings().businessHoursShowHours, color: theme.colors.text, type: .switchable(state.enabled), viewType: .singleItem, action: arguments.toggleEnabled)))
    
    // entries
    
    
    
    if state.enabled {
        entries.append(.sectionId(sectionId, type: .normal))
        sectionId += 1
        
        entries.append(.desc(sectionId: sectionId, index: index, text: .plain(strings().businessHoursBusinessHours), data: .init(color: theme.colors.listGrayText, viewType: .textTopItem)))
        index += 1
        
        for (i, day) in State.Day.all.enumerated() {
            entries.append(.general(sectionId: sectionId, index: index, value: .none, error: nil, identifier: _id_day(day), data: .init(name: day.title, color: theme.colors.text, type: .switchable(state.data[day] != nil), viewType: bestGeneralViewType(State.Day.all, for: i), description: state.openingHours(day), descTextColor: state.data[day] != nil ? theme.colors.accent : theme.colors.grayText, action: {
                arguments.toggleDay(day)
            }, switchAction: {
                arguments.enableDay(day)
            })))
        }
        
        if let zones = state.timeZones, let timezone = state.timezone {
            entries.append(.sectionId(sectionId, type: .normal))
            sectionId += 1
            
            
            let zones: [ContextMenuItem] = zones.items.map { zone in
                return ContextMenuItem(zone.text, handler: {
                    arguments.selectTimezone(zone)
                }, state: nil)
            }
            
            entries.append(.general(sectionId: sectionId, index: index, value: .none, error: nil, identifier: _id_timezone, data: .init(name: strings().businessHoursTimezone, color: theme.colors.text, type: .nextContext(timezone.text), viewType: .singleItem, action: arguments.openTimezones)))
        }
        

        
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
  
    entries.append(.general(sectionId: sectionId, index: index, value: .none, error: nil, identifier: _id_enabled, data: .init(name: strings().businessHoursSetTitle, color: theme.colors.text, type: .switchable(state.data[day] != nil), viewType: .singleItem, action: {
        arguments.enableDay(day)
    })))
    
    // entries
    
    if let hours = state.data[day] {
        
        let startMinute = hours.list.min(by: { $0.from < $1.from })?.from
        let endMinute = hours.list.max(by: { $0.to < $1.to })?.to

        
        
//        let getHoursMenu:(State.Hours.MinutesInDay, Bool)->[ContextMenuItem] = { hour, from in
//            var items:[ContextMenuItem] = []
//            
//            var start: Int = 0
//            var end: Int = 24 * 60
//            
//            if from {
//                start = 0
//                end = hour.to
//            } else {
//                start = hour.from
//                end = 24 * 60
//            }
//            
//         
//            
//            let s = Int(Float(start) / 60.0)
//            let e = Int(Float(end) / 60.0)
//
//            let from_hours = Int(Float(hour.from) / 60)
//            let to_hours = Int(Float(hour.to) / 60)
//            
//           
//
//            for i in s ... e {
//                let minuteRange = i * 60
//
//                var intersected = false
//                let hourRange = NSMakeRange(minuteRange, minuteRange + 60)
//                if let startMinute, let endMinute {
//                    let range = NSMakeRange(startMinute, endMinute - startMinute)
//                    intersected = range.intersection(hourRange) == hourRange
//                }
//                
//                if !intersected {
//                    let state: NSControl.StateValue? = i == (from ? from_hours : to_hours) ? .on : nil
//                    let item = ContextMenuItem(formatHourToLocaleTime(hour: minuteRange), handler: {
//                        arguments.editSpefic(day, .init(from: from ? minuteRange : hour.from, to: !from ? minuteRange : hour.to, uniqueId: hour.uniqueId))
//                    }, state: state)
//                    
//                    let minutes = ContextMenu()
//                    var minuteItems:[ContextMenuItem] = []
//                    for j in 0 ..< 60 {
//                        let hourRange = NSMakeRange(minuteRange, minuteRange + i)
//                        if let startMinute, let endMinute {
//                            let range = NSMakeRange(startMinute, endMinute - startMinute)
//                            intersected = range.intersection(hourRange) == hourRange
//                        }
//                        if !intersected {
//                            let item = ContextMenuItem(formattedMinutes[j]!, handler: {
//                                arguments.editSpefic(day, .init(from: from ? minuteRange + j : hour.from, to: !from ? minuteRange + j : hour.to, uniqueId: hour.uniqueId))
//                            }, state: state == .on && j == (from ? hour.from % 60 : hour.to % 60) ? .on : nil)
//                            
//                            minuteItems.append(item)
//                        }
//                    }
//                    minutes.items = minuteItems
//                    
//                    item.submenu = minutes
//                    items.append(item)
//                }
//             
//            }
//            return items
//        }
                
        for hour in hours.list {
            
            entries.append(.sectionId(sectionId, type: .normal))
            sectionId += 1

            entries.append(.general(sectionId: sectionId, index: index, value: .none, error: nil, identifier: _id_opening_time(hour), data: .init(name: strings().businessHoursSetOpeningTime, color: theme.colors.text, type: .nextContext(formatHourToLocaleTime(hour: hour.from)), viewType: .firstItem, action: {
                arguments.selectSpecific(day, hour, true)
            })))
            
            
            entries.append(.general(sectionId: sectionId, index: index, value: .none, error: nil, identifier: _id_closing_time(hour), data: .init(name: strings().businessHoursSetClosingTime, color: theme.colors.text, type: .nextContext(formatHourToLocaleTime(hour: hour.to)), viewType: .innerItem, action: {
                arguments.selectSpecific(day, hour, false)
            })))
            
            entries.append(.general(sectionId: sectionId, index: index, value: .none, error: nil, identifier: _id_remove_opening(hour), data: .init(name: strings().businessHoursSetRemove, color: theme.colors.redUI, type: .none, viewType: .lastItem, action: {
                arguments.removeSpefic(day, hour)
            })))

        }
    }
    

    let count = state.data[day]?.list.count ?? 0
        
    sectionId = 1000
    
    
    let hours = state.data[day]
    var filled: Bool = false
    if let lastHour = hours?.list.max(by: { $0.to < $1.to }) {
        if lastHour.to == 24 * 60 {
            filled = true
        }
    }

    if !filled {
        entries.append(.sectionId(sectionId, type: .normal))
        sectionId += 1

        entries.append(.general(sectionId: sectionId, index: index, value: .none, error: nil, identifier: _id_add_specific, data: .init(name: strings().businessHoursAddSet, color: theme.colors.accent, type: .none, viewType: .singleItem, action: {
            arguments.addSpecific(day)
        })))
        
        entries.append(.desc(sectionId: sectionId, index: index, text: .plain(strings().businessHoursAddSetInfo), data: .init(color: theme.colors.listGrayText, viewType: .textBottomItem)))
        
    }

    
    entries.append(.sectionId(sectionId, type: .normal))
    sectionId += 1
    
    return entries
}


func BusinessHoursController(context: AccountContext) -> InputDataController {

    let actionsDisposable = DisposableSet()
        

    let initialState = State()
    
    let statePromise = ValuePromise<State>(ignoreRepeated: true)
    let stateValue = Atomic(value: initialState)
    let updateState: ((State) -> State) -> Void = { f in
        statePromise.set(stateValue.modify (f))
    }
    
    let businessHours = context.engine.data.get(TelegramEngine.EngineData.Item.Peer.BusinessHours(id: context.peerId)) |> deliverOnMainQueue

    
    actionsDisposable.add(context.engine.accountData.keepCachedTimeZoneListUpdated().start())
    


    actionsDisposable.add(combineLatest(businessHours, context.engine.accountData.cachedTimeZoneList()).start(next: { hours, timezones in
        updateState { current in
            var current = current
            current.initial = hours
            current.enabled = hours != nil
            current.timeZones = timezones

            if current.timezone == nil {
                if let hours = hours {
                    current.timezone = timezones?.items.first(where: { $0.id == hours.timezoneId })
                } else {
                    current.timezone = timezones?.items.first { $0.utcOffset == TimeZone.current.secondsFromGMT() }
                }
            }
            
            if let hours = hours {
                let weekDays = hours.splitIntoWeekDays()
                for (i, day) in weekDays.enumerated() {
                    if let today = State.Day(rawValue: i) {
                        switch day {
                        case let .intervals(intervals):
                            current.data[today] = .init(list: intervals.map { .init(from: $0.startMinute, to: $0.endMinute, uniqueId: arc4random64()) })
                        case .closed:
                            current.data.removeValue(forKey: today)
                        case .open:
                            current.data[today] = .init()
                        }
                    }
                }
            } else {
                current.enabled = false
            }
            return current
        }
    }))
    
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
            
            
            var rangeStart = 9 * 60
            if let lastRange = hours.list.last {
                rangeStart = lastRange.to + 1
            }
            if rangeStart >= 24 * 60 - 1 {
                return current
            }
            
            let rangeEnd = min(rangeStart + 9 * 60, 24 * 60)
            
            hours.list.append(.init(from: rangeStart, to: rangeEnd, uniqueId: arc4random64()))
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
    }, selectSpecific: { day, hour, isFrom in
        let from: TimePickerOption = TimePickerOption(hours: Int32(Float(hour.from) / 60), minutes: Int32(hour.from % 60))
        let to: TimePickerOption = TimePickerOption(hours: Int32(Float(hour.to) / 60), minutes: Int32(hour.to % 60))

        showModal(with: TimeRangeSelectorController(context: context, from: from, to: to, title: day.title, ok: strings().modalSave, fromString: strings().businessHoursSetOpeningTime, toString: strings().businessHoursSetClosingTime, endIsResponder: !isFrom, updatedValue: { updatedFrom, updatedTo in
            
            let updated = State.Hours.MinutesInDay(from: Int(updatedFrom.hours * 60 + updatedFrom.minutes), to: Int(updatedTo.hours * 60 + updatedTo.minutes), uniqueId: hour.uniqueId)
            updateState { current in
                var current = current
                var hours = current.data[day] ?? .init()
                if let hourIndex = hours.list.firstIndex(where: { $0.uniqueId == updated.uniqueId }) {
                    hours.list[hourIndex] = updated
                }
                current.data[day] = hours
                return current
            }
            
        }), for: context.window)
    }, openTimezones: {
        let state = stateValue.with { $0 }
        if let list = state.timeZones?.items, let timezone = state.timezone {
            showModal(with: BusinessTimezonesController(context: context, timezones: list, selected: timezone, complete: { updated in
                updateState { current in
                    var current = current
                    current.timezone = updated
                    return current
                }
            }), for: context.window)
        }
    })
    
    getArguments = { [weak arguments] in
        return arguments
    }
    
    
    let signal = statePromise.get() |> deliverOnPrepareQueue |> map { state in
        return InputDataSignalValue(entries: entries(state, arguments: arguments), grouping: false)
    }
    
    let controller = InputDataController(dataSignal: signal, title: strings().businessHoursTitle, removeAfterDisappear: false, hasDone: true)
    
    controller.validateData = { _ in
        let state = stateValue.with { $0 }
        do {
            let hours = try state.mapped()
            _ = context.engine.accountData.updateAccountBusinessHours(businessHours: hours).start()
            showModalText(for: context.window, text: strings().businessUpdated)
            return .success(.navigationBack)
        } catch {
            return .fail(.alert("Intersection Error"))
        }
        
    }
    
    controller.updateDoneValue = { data in
        return { f in
            let mapped = stateValue.with { try? $0.mapped() }
            let isEnabled = stateValue.with { $0.initial != mapped }
            if isEnabled {
                f(.enabled(strings().navigationDone))
            } else {
                f(.disabled(strings().navigationDone))
            }
        }
    }

    
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

