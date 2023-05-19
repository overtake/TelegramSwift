//
//  DatePickerRowItem.swift
//  Telegram
//
//  Created by Mikhail Filimonov on 06.04.2021.
//  Copyright © 2021 Telegram. All rights reserved.
//

import Foundation
import TGUIKit
import CalendarUtils


private final class DateSelectorView : View {
    fileprivate let dayPicker: DatePicker<Date>
    private let atView = TextView()
    fileprivate let timePicker: TimePicker
    fileprivate let containerView = View()
    
    var update:((Date)->Void)?
    
    required init(frame frameRect: NSRect) {
        self.dayPicker = DatePicker<Date>(selected: DatePickerOption<Date>(name: DateSelectorUtil.formatDay(Date()), value: Date()))
        self.timePicker = TimePicker(selected: TimePickerOption(hours: 0, minutes: 0, seconds: 0))
        super.init(frame: frameRect)
        containerView.addSubview(dayPicker)
        containerView.addSubview(timePicker)
        containerView.addSubview(atView)
        addSubview(containerView)
        
        let atLayout = TextViewLayout(.initialize(string: strings().scheduleControllerAt, color: GroupCallTheme.customTheme.textColor, font: .normal(.title)), alwaysStaticItems: true)
        atLayout.measure(width: .greatestFiniteMagnitude)
        atView.update(atLayout)
        
        self.dayPicker.set(handler: { [weak self] control in
            if let control = control as? DatePicker<Date>, let window = self?.kitWindow, !hasPopover(window) {
                let calendar = CalendarController(NSMakeRect(0, 0, 300, 300), window, current: control.selected.value, onlyFuture: true, limitedBy: Date(timeIntervalSinceNow: 7 * 24 * 60 * 60), selectHandler: { [weak self] date in
                    self?.applyDay(date)
                    if let date = self?.select() {
                        self?.update?(date)
                    }
                })
                showPopover(for: control, with: calendar, edge: .maxY, inset: NSMakePoint(-8, -60))
            }
        }, for: .Down)
        
       
        let date = Date()
        
        var t: time_t = time_t(date.timeIntervalSince1970)
        var timeinfo: tm = tm()
        localtime_r(&t, &timeinfo)
        
        
        
        self.timePicker.update = { [weak self] updated in
            guard let `self` = self else {
                return false
            }
            
            let day = self.dayPicker.selected.value
            
            let date = day.startOfDay.addingTimeInterval(updated.interval)
            
            self.applyTime(date)
            self.update?(self.select())
            return true
        }
        
    }
    
    private func applyDay(_ date: Date) {
        self.dayPicker.selected = DatePickerOption(name: DateSelectorUtil.formatDay(date), value: date)
        let current = date.addingTimeInterval(self.timePicker.selected.interval)

        if CalendarUtils.isSameDate(Date(), date: date, checkDay: true) {
             if current < Date() {
                for interval in DateSelectorUtil.timeIntervals.compactMap ({$0}) {
                    let new = date.startOfDay.addingTimeInterval(interval)
                    if new > Date() {
                        applyTime(new)
                        break
                    }
                }
             } else {
                if date != current {
                    applyTime(date.addingTimeInterval(current.timeIntervalSince1970 - current.startOfDay.timeIntervalSince1970))
                } else {
                    applyTime(date)
                }
            }
        } else {
            if date != current {
                applyTime(date.addingTimeInterval(current.timeIntervalSince1970 - current.startOfDay.timeIntervalSince1970))
            } else {
                applyTime(date)
            }
        }
    }
    
    private func applyTime(_ date: Date) {
        
        var t: time_t = time_t(date.timeIntervalSince1970)
        var timeinfo: tm = tm()
        localtime_r(&t, &timeinfo)
        
        timePicker.selected = TimePickerOption(hours: timeinfo.tm_hour, minutes: timeinfo.tm_min, seconds: timeinfo.tm_sec)
    }

    func updateDate(_ date: Date) {
        self.dayPicker.selected = DatePickerOption<Date>(name: DateSelectorUtil.formatDay(date), value: date)
        self.timePicker.selected = TimePickerOption(hours: 0, minutes: 0, seconds: 0)
        self.applyDay(date)
    }
    
    override func layout() {
        super.layout()
        
        self.dayPicker.setFrameSize(NSMakeSize(124, 30))
        self.timePicker.setFrameSize(NSMakeSize(124, 30))
        let fullWidth = dayPicker.frame.width + 15 + atView.frame.width + 15 + timePicker.frame.width
        self.containerView.setFrameSize(NSMakeSize(fullWidth, max(dayPicker.frame.height, timePicker.frame.height)))
        self.dayPicker.centerY(x: 0)
        self.atView.centerY(x: self.dayPicker.frame.maxX + 15)
        self.timePicker.centerY(x: self.atView.frame.maxX + 15)
        self.containerView.center()
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    private func select() -> Date {
        let day = self.dayPicker.selected.value
        let date = day.startOfDay.addingTimeInterval(self.timePicker.selected.interval)
        return date
    }
}


final class DatePickerRowItem : GeneralRowItem {
    fileprivate let initialDate: Date?
    fileprivate let update:(Date)->Void
    init(_ initialSize: NSSize, stableId: AnyHashable, viewType: GeneralViewType, initialDate: Date?, update:@escaping(Date)->Void) {
        self.initialDate = initialDate
        self.update = update
        super.init(initialSize, height: 48, stableId: stableId, viewType: viewType)
    }
    
    
    
    override func viewClass() -> AnyClass {
        return DatePickerRowView.self
    }
}


private final class DatePickerRowView : GeneralContainableRowView {
    private let view = DateSelectorView(frame: .zero)
    required init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        addSubview(view)
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override func shakeView() {
        super.shakeView()
        self.view.shake()
    }
    
    
    override func layout() {
        super.layout()
        
        view.frame = containerView.focus(NSMakeSize(containerView.frame.width, 30))
    }
    
    override func set(item: TableRowItem, animated: Bool = false) {
        super.set(item: item, animated: animated)
        
        guard let item = item as? DatePickerRowItem else {
            return
        }
        view.updateDate(item.initialDate ?? Date(timeIntervalSinceNow: 1 * 60 * 60))
        view.update = item.update
    }
}
