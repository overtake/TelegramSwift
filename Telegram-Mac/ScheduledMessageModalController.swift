//
//  ScheduledMessageModalController.swift
//  Telegram
//
//  Created by Mikhail Filimonov on 07/08/2019.
//  Copyright © 2019 Telegram. All rights reserved.
//

import TGUIKit

import SyncCore

private var timeIntervals:[TimeInterval?]  {
    var intervals:[TimeInterval?] = []
    for i in 0 ... 23 {
        let current = Double(i) * 60.0 * 60
        intervals.append(current)
//        #if DEBUG
        for i in 1 ... 59 {
            intervals.append(current + Double(i) * 60.0)
        }
        if i < 23 {
            intervals.append(nil)
        }

    }
    return intervals
}

private var dayFormatter: DateFormatter {
    let dateFormatter = DateFormatter()
    dateFormatter.locale = Locale(identifier: appAppearance.language.languageCode)
    //dateFormatter.timeZone = TimeZone(abbreviation: "UTC")!
    dateFormatter.dateFormat = "MMM d, yyyy"
    return dateFormatter
}

private var dayFormatterRelative: DateFormatter {
    let dateFormatter = DateFormatter()
    dateFormatter.locale = Locale(identifier: appAppearance.language.languageCode)
   // dateFormatter.timeZone = TimeZone(abbreviation: "UTC")!

    dateFormatter.dateStyle = .short
    dateFormatter.doesRelativeDateFormatting = true
    return dateFormatter
}

private func formatDay(_ date: Date) -> String {
    if CalendarUtils.isSameDate(date, date: Date(), checkDay: true) {
        return dayFormatterRelative.string(from: date)
    } else {
        return dayFormatter.string(from: date)
    }
}

private func formatTime(_ date: Date) -> String {
    let timeFormatter = DateFormatter()
    timeFormatter.timeStyle = .medium
   // timeFormatter.timeZone = TimeZone(abbreviation: "UTC")!
    return timeFormatter.string(from: date)
}

final class ScheduledMessageModalView : View {
    fileprivate let dayPicker: DatePicker<Date>
    private let atView = TextView()
    fileprivate let timePicker: TimePicker
    private let containerView = View()
    fileprivate let sendOn = TitleButton()
    fileprivate let sendWhenOnline = TitleButton()
    required init(frame frameRect: NSRect) {
        
        self.dayPicker = DatePicker<Date>(selected: DatePickerOption<Date>(name: formatDay(Date()), value: Date()))
        self.timePicker = TimePicker(selected: TimePickerOption(hours: 0, minutes: 0, seconds: 0))
        super.init(frame: frameRect)
        containerView.addSubview(self.dayPicker)
        containerView.addSubview(self.atView)
        containerView.addSubview(self.timePicker)
        self.addSubview(self.containerView)
        self.addSubview(sendOn)
        self.atView.userInteractionEnabled = false
        self.atView.isSelectable = false
        self.sendOn.layer?.cornerRadius = .cornerRadius
        self.sendOn.disableActions()
        self.addSubview(self.sendWhenOnline)
        self.updateLocalizationAndTheme(theme: theme)
    }
    
    override func updateLocalizationAndTheme(theme: PresentationTheme) {
        super.updateLocalizationAndTheme(theme: theme)
        
        self.sendOn.set(font: .medium(.text), for: .Normal)
        self.sendOn.set(color: .white, for: .Normal)
        self.sendOn.set(background: theme.colors.accent, for: .Normal)
        self.sendOn.set(background: theme.colors.accent.withAlphaComponent(0.8), for: .Highlight)

        self.sendWhenOnline.set(font: .normal(.text), for: .Normal)
        self.sendWhenOnline.set(color: theme.colors.accent, for: .Normal)
        self.sendWhenOnline.set(text: L10n.scheduleSendWhenOnline, for: .Normal)
        _ = self.sendWhenOnline.sizeToFit()
        
        let atLayout = TextViewLayout(.initialize(string: L10n.scheduleControllerAt, color: theme.colors.text, font: .normal(.title)), alwaysStaticItems: true)
        atLayout.measure(width: .greatestFiniteMagnitude)
        atView.update(atLayout)
        
        needsLayout = true
    }
    
    func possibleSendWhenOnline(_ sendWhenOnline: Bool) {
        self.sendWhenOnline.isHidden = !sendWhenOnline
    }
    
    override func layout() {
        super.layout()
        self.dayPicker.setFrameSize(NSMakeSize(115, 30))
        self.timePicker.setFrameSize(NSMakeSize(115, 30))

        let fullWidth = dayPicker.frame.width + 15 + atView.frame.width + 15 + timePicker.frame.width
        self.containerView.setFrameSize(NSMakeSize(fullWidth, max(dayPicker.frame.height, timePicker.frame.height)))

        self.dayPicker.centerY(x: 0)
        self.atView.centerY(x: self.dayPicker.frame.maxX + 15)
        self.timePicker.centerY(x: self.atView.frame.maxX + 15)
        
        self.containerView.centerX(y: 30)
        
        _ = self.sendOn.sizeToFit(NSZeroSize, NSMakeSize(fullWidth, 30), thatFit: true)
        
        self.sendOn.centerX(y: containerView.frame.maxY + 30)
        
        self.sendWhenOnline.centerX(y: self.sendOn.frame.maxY + 15)
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}


private extension TimePickerOption {
    var interval: TimeInterval {
        let hours = Double(self.hours) * 60.0 * 60
        let minutes = Double(self.minutes) * 60.0
        let seconds = Double(self.seconds)
        return hours + minutes + seconds
    }
}
class ScheduledMessageModalController: ModalViewController {
    private let context: AccountContext
    private let scheduleAt: (Date)->Void
    private let defaultDate: Date?
    private let sendWhenOnline: Bool
    init(context: AccountContext, defaultDate: Date? = nil, sendWhenOnline: Bool = true, scheduleAt:@escaping(Date)->Void) {
        self.context = context
        self.defaultDate = defaultDate
        self.scheduleAt = scheduleAt
        self.sendWhenOnline = sendWhenOnline
        super.init(frame: NSMakeRect(0, 0, 350, 200))
        self.bar = .init(height: 0)
    }
    
    override func viewClass() -> AnyClass {
        return ScheduledMessageModalView.self
    }
    
    override var modalHeader: (left: ModalHeaderData?, center: ModalHeaderData?, right: ModalHeaderData?)? {
        return (left: ModalHeaderData(title: nil, image: theme.icons.modalClose, handler: { [weak self] in
            self?.close()
        }), center: ModalHeaderData(title: L10n.scheduleControllerTitle, handler: {
            
        }), right: nil)
    }
    
    
    
    override open func measure(size: NSSize) {
        self.modal?.resize(with:NSMakeSize(frame.width, sendWhenOnline ? 170 : 150), animated: false)
    }
    
    override var dynamicSize: Bool {
        return true
    }
    
    var genericView: ScheduledMessageModalView {
        return self.view as! ScheduledMessageModalView
    }
    
    private func applyDay(_ date: Date) {
        genericView.dayPicker.selected = DatePickerOption(name: formatDay(date), value: date)
        let current = date.addingTimeInterval(self.genericView.timePicker.selected.interval)

        if CalendarUtils.isSameDate(Date(), date: date, checkDay: true) {
            
             if current < Date() {
                for interval in timeIntervals.compactMap ({$0}) {
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
        
        genericView.timePicker.selected = TimePickerOption(hours: timeinfo.tm_hour, minutes: timeinfo.tm_min, seconds: timeinfo.tm_sec)

        if CalendarUtils.isSameDate(Date(), date: date, checkDay: true) {
            genericView.sendOn.set(text: L10n.scheduleSendToday(formatTime(date)), for: .Normal)
        } else {
            genericView.sendOn.set(text: L10n.scheduleSendDate(formatDay(date), formatTime(date)), for: .Normal)
        }
    }
    
    override var handleAllEvents: Bool {
        return true
    }
    
    private func schedule() {
        let day = self.genericView.dayPicker.selected.value
        let date = day.startOfDay.addingTimeInterval(self.genericView.timePicker.selected.interval)
        if CalendarUtils.isSameDate(Date(), date: day, checkDay: true) {
            if Date() > date {
                genericView.timePicker.shake()
                return
            }
        }
        self.scheduleAt(date)
        self.close()
    }
    
    override func returnKeyAction() -> KeyHandlerResult {
        self.schedule()
        return .invoked
    }
    
    override func firstResponder() -> NSResponder? {
        return genericView.timePicker.firstResponder
    }
    
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        window?.set(handler: { () -> KeyHandlerResult in
            
            return .invokeNext
        }, with: self, for: .Tab, priority: .modal)
        window?.set(handler: { () -> KeyHandlerResult in
            
            return .invokeNext
        }, with: self, for: .LeftArrow, priority: .modal)
        window?.set(handler: { () -> KeyHandlerResult in
            
            return .invokeNext
        }, with: self, for: .RightArrow, priority: .modal)
    }
    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        window?.removeAllHandlers(for: self)
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        
        
        let date = self.defaultDate ?? Date()
        
        var t: time_t = time_t(date.timeIntervalSince1970)
        var timeinfo: tm = tm()
        localtime_r(&t, &timeinfo)
        
        self.genericView.dayPicker.selected = DatePickerOption<Date>(name: formatDay(date), value: date)
        self.genericView.timePicker.selected = TimePickerOption(hours: 0, minutes: 0, seconds: 0)
        
        self.genericView.possibleSendWhenOnline(self.sendWhenOnline)
        
        self.applyDay(date)
        
        self.genericView.timePicker.update = { [weak self] updated in
            guard let `self` = self else {
                return false
            }
            
            let day = self.genericView.dayPicker.selected.value
            
            let date = day.startOfDay.addingTimeInterval(updated.interval)

            self.applyTime(date)
            return true
        }
        
        self.genericView.sendOn.set(handler: { [weak self] _ in
            self?.schedule()
        }, for: .Click)
        
        self.genericView.sendWhenOnline.set(handler: { [weak self] _ in
            self?.scheduleAt(Date(timeIntervalSince1970: TimeInterval(scheduleWhenOnlineTimestamp)))
            self?.close()
        }, for: .Click)
        
        self.readyOnce()
        
        self.genericView.dayPicker.set(handler: { [weak self] control in
            if let control = control as? DatePicker<Date>, let window = self?.window, !hasPopover(window) {
                let calendar = CalendarController(NSMakeRect(0, 0, 250, 250), window, current: control.selected.value, onlyFuture: true, selectHandler: { [weak self] date in
                    self?.applyDay(date)
                })
                showPopover(for: control, with: calendar, edge: .maxY, inset: NSMakePoint(-8, -50))
            }
            
        }, for: .Down)
        
        self.genericView.timePicker.set(handler: { [weak self] control in
            if let control = control as? DatePicker<Date>, let `self` = self, let window = self.window, !hasPopover(window) {
                var items:[SPopoverItem] = []
                
                let day = self.genericView.dayPicker.selected.value
                
                for interval in timeIntervals {
                    if let interval = interval {
                        let date = day.startOfDay.addingTimeInterval(interval)
                        if CalendarUtils.isSameDate(Date(), date: day, checkDay: true) {
                            if Date() > date {
                                continue
                            }
                        }
                        items.append(SPopoverItem(formatTime(date), { [weak self] in
                            self?.applyTime(date)
                        }, height: 30))
                    } else if !items.isEmpty {
                        items.append(SPopoverItem())
                    }
                }
                showPopover(for: control, with: SPopoverViewController(items: items, visibility: 6), edge: .maxY, inset: NSMakePoint(0, -50))
            }
            
        }, for: .Down)
        
    }
}
