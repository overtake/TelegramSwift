//
//  ScheduledMessageModalController.swift
//  Telegram
//
//  Created by Mikhail Filimonov on 07/08/2019.
//  Copyright © 2019 Telegram. All rights reserved.
//

import TGUIKit



private var timeIntervals:[TimeInterval]  {
    var intervals:[TimeInterval] = []
    for i in 0 ... 23 {
        let current = Double(i) * 60.0 * 60
        intervals.append(current)
        intervals.append(current + 15.0 * 60.0)
        intervals.append(current + 30.0 * 60.0)
        intervals.append(current + 45.0 * 60.0)
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
    timeFormatter.timeStyle = .short
   // timeFormatter.timeZone = TimeZone(abbreviation: "UTC")!
    return timeFormatter.string(from: date)
}

final class ScheduledMessageModalView : View {
    fileprivate let dayPicker: DatePicker<Date>
    private let atView = TextView()
    fileprivate let timePicker: DatePicker<Date>
    private let containerView = View()
    fileprivate let sendOn = TitleButton()
    required init(frame frameRect: NSRect) {
        
        self.dayPicker = DatePicker<Date>(selected: DatePickerOption<Date>(name: formatDay(Date()), value: Date()))
        self.timePicker = DatePicker<Date>(selected: DatePickerOption<Date>(name: "22:00", value: Date()))
        super.init(frame: frameRect)
        containerView.addSubview(self.dayPicker)
        containerView.addSubview(self.atView)
        containerView.addSubview(self.timePicker)
        self.addSubview(self.containerView)
        self.addSubview(sendOn)
        self.atView.userInteractionEnabled = false
        self.atView.isSelectable = false
        self.sendOn.layer?.cornerRadius = .cornerRadius
        self.updateLocalizationAndTheme()
    }
    
    override func updateLocalizationAndTheme() {
        super.updateLocalizationAndTheme()
        
        self.sendOn.set(font: .medium(.text), for: .Normal)
        self.sendOn.set(color: .white, for: .Normal)
        self.sendOn.set(background: theme.colors.blueUI, for: .Normal)
        self.sendOn.set(background: theme.colors.blueUI.withAlphaComponent(0.8), for: .Highlight)

        
        let atLayout = TextViewLayout(.initialize(string: "At", color: theme.colors.text, font: .normal(.title)), alwaysStaticItems: true)
        atLayout.measure(width: .greatestFiniteMagnitude)
        atView.update(atLayout)
        
        needsLayout = true
    }
    
    override func layout() {
        super.layout()
        self.dayPicker.setFrameSize(NSMakeSize(90, 30))
        self.timePicker.setFrameSize(NSMakeSize(90, 30))

        let fullWidth = dayPicker.frame.width + 15 + atView.frame.width + 15 + timePicker.frame.width
        self.containerView.setFrameSize(NSMakeSize(fullWidth, max(dayPicker.frame.height, timePicker.frame.height)))

        self.dayPicker.centerY(x: 0)
        self.atView.centerY(x: self.dayPicker.frame.maxX + 15)
        self.timePicker.centerY(x: self.atView.frame.maxX + 15)
        
        self.containerView.centerX(y: 30)
        
        _ = self.sendOn.sizeToFit(NSZeroSize, NSMakeSize(fullWidth, 30), thatFit: true)
        
        self.sendOn.centerX(y: frame.height - self.sendOn.frame.height - 30)
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}

class ScheduledMessageModalController: ModalViewController {
    private let context: AccountContext
    init(context: AccountContext) {
        self.context = context
        super.init(frame: NSMakeRect(0, 0, 300, 120))
        self.bar = .init(height: 0)
    }
    
    override func viewClass() -> AnyClass {
        return ScheduledMessageModalView.self
    }
    
    override var modalHeader: (left: ModalHeaderData?, center: ModalHeaderData?, right: ModalHeaderData?)? {
        return (left: nil, center: ModalHeaderData(title: "Schedule Message", handler: {
            
        }), right: ModalHeaderData(title: nil, image: theme.icons.modalClose, handler: {
            
        }))
    }
    
//    override var modalInteractions: ModalInteractions? {
//        return ModalInteractions(acceptTitle: "Schedule", accept: {
//
//        }, cancelTitle: L10n.modalCancel)
//    }
    
    
    override open func measure(size: NSSize) {
        self.modal?.resize(with:NSMakeSize(frame.width, 150), animated: false)
    }
    
    override var dynamicSize: Bool {
        return true
    }
    
    var genericView: ScheduledMessageModalView {
        return self.view as! ScheduledMessageModalView
    }
    
    private func applyDay(_ date: Date) {
        genericView.dayPicker.selected = DatePickerOption(name: formatDay(date), value: date)
        let current = self.genericView.timePicker.selected.value

        if CalendarUtils.isSameDate(Date(), date: date, checkDay: true) {
            
             if current < Date() {
                for interval in timeIntervals {
                    let new = date.startOfDay.addingTimeInterval(interval)
                    if new > Date() {
                        applyTime(new)
                        break
                    }
                }
             } else {
                applyTime(date.addingTimeInterval(current.timeIntervalSince1970 - current.startOfDayUTC.timeIntervalSince1970))
            }
        } else {
            applyTime(date.addingTimeInterval(current.timeIntervalSince1970 - current.startOfDayUTC.timeIntervalSince1970))
        }
    }
    
    private func applyTime(_ date: Date) {
        genericView.timePicker.selected = DatePickerOption(name: formatTime(date), value: date)
        
        if CalendarUtils.isSameDate(Date(), date: date, checkDay: true) {
            genericView.sendOn.set(text: L10n.scheduleSendToday(formatTime(date)), for: .Normal)
        } else {
            genericView.sendOn.set(text: L10n.scheduleSendDate(formatDay(date), formatTime(date)), for: .Normal)
        }
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        self.applyDay(Date())
        
        self.readyOnce()
        
        self.genericView.dayPicker.set(handler: { [weak self] control in
            if let control = control as? DatePicker<Date>, let window = self?.window {
                let calendar = CalendarController(NSMakeRect(0, 0, 250, 250), window, current: control.selected.value, onlyFuture: true, selectHandler: { [weak self] date in
                    self?.applyDay(date)
                })
                showPopover(for: control, with: calendar, edge: .maxY, inset: NSMakePoint(-8, -50))
            }
            
        }, for: .Down)
        
        self.genericView.timePicker.set(handler: { [weak self] control in
            if let control = control as? DatePicker<Date>, let `self` = self {
                var items:[SPopoverItem] = []
                
                let day = self.genericView.dayPicker.selected.value
                
                for interval in timeIntervals {
                    let date = Date().startOfDay.addingTimeInterval(interval)
                    if CalendarUtils.isSameDate(Date(), date: day, checkDay: true) {
                        if Date() > date {
                            continue
                        }
                    }
                    items.append(SPopoverItem(formatTime(date), { [weak self] in
                        self?.applyTime(date)
                    }, height: 30))
                }
                
                showPopover(for: control, with: SPopoverViewController(items: items, visibility: 6), edge: .maxY, inset: NSMakePoint(-12, -50))
            }
            
        }, for: .Down)
        
    }
}
