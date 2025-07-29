//
//  DateSelectorModalController.swift
//  Telegram
//
//  Created by Mikhail Filimonov on 07/08/2019.
//  Copyright © 2019 Telegram. All rights reserved.
//

import TGUIKit
import TelegramCore
import SwiftSignalKit
import CalendarUtils
import Postbox


final class DateSelectorModalView : View {
    fileprivate let dayPicker: DatePicker<Date>
    private let atView = TextView()
    fileprivate let timePicker: TimePicker
    private let containerView = View()
    fileprivate let sendOn = TextButton()
    fileprivate let sendWhenOnline = TextButton()
    fileprivate var actionView: TextView?
    
    fileprivate var infoText: TextView?
    
    var dismiss: (()->Void)? = nil
    
    required init(frame frameRect: NSRect, hasSeconds: Bool) {
        
        self.dayPicker = DatePicker<Date>(selected: DatePickerOption<Date>(name: DateSelectorUtil.formatDay(Date()), value: Date()))
        self.timePicker = TimePicker(selected: TimePickerOption(hours: 0, minutes: 0, seconds: hasSeconds ? 0 : nil))
        super.init(frame: frameRect)
        containerView.addSubview(self.dayPicker)
        containerView.addSubview(self.atView)
        containerView.addSubview(self.timePicker)
        self.addSubview(self.containerView)
        self.addSubview(sendOn)
        self.atView.userInteractionEnabled = false
        self.atView.isSelectable = false
        self.sendOn.layer?.cornerRadius = 10
        self.sendOn.disableActions()
        self.addSubview(self.sendWhenOnline)
        self.updateLocalizationAndTheme(theme: theme)
    }
    
    override func updateLocalizationAndTheme(theme: PresentationTheme) {
        super.updateLocalizationAndTheme(theme: theme)
        
        self.backgroundColor = theme.colors.listBackground
        
        self.sendOn.set(font: .medium(.text), for: .Normal)
        self.sendOn.set(color: theme.colors.underSelectedColor, for: .Normal)
        self.sendOn.set(background: theme.colors.accent, for: .Normal)
        self.sendOn.set(background: theme.colors.accent.highlighted, for: .Highlight)

        self.sendWhenOnline.set(font: .normal(.text), for: .Normal)
        self.sendWhenOnline.set(color: theme.colors.accent, for: .Normal)
        self.sendWhenOnline.set(text: strings().scheduleSendWhenOnline, for: .Normal)
        _ = self.sendWhenOnline.sizeToFit()
        
        let atLayout = TextViewLayout(.initialize(string: strings().scheduleControllerAt, color: theme.colors.text, font: .normal(.title)), alwaysStaticItems: true)
        atLayout.measure(width: .greatestFiniteMagnitude)
        atView.update(atLayout)
        
        needsLayout = true
    }
    
    private var mode: DateSelectorModalController.Mode?
    
    func updateWithMode(_ mode: DateSelectorModalController.Mode, sendWhenOnline: Bool, infoText: TextViewLayout?) {
        self.mode = mode
        self.sendWhenOnline.isHidden = !sendWhenOnline
        switch mode {
        case .date, .dateAction:
            self.atView.isHidden = true
            self.sendOn.isHidden = true
            self.sendWhenOnline.isHidden = true
        case .schedule:
            self.atView.isHidden = false
            self.sendOn.isHidden = false
            self.sendWhenOnline.isHidden = !sendWhenOnline
        }
        
        if case let .dateAction(_, _, action) = mode {
            let current: TextView
            if let view = actionView {
                current = view
            } else {
                current = TextView()
                current.isSelectable = false
                current.scaleOnClick = true
                addSubview(current)
                self.actionView = current
            }
            let layout = TextViewLayout(.initialize(string: action.string, color: theme.colors.accent, font: .medium(.text)))
            layout.measure(width: .greatestFiniteMagnitude)
            current.update(layout)
            
            current.set(handler: { [weak self] _ in
                action.callback()
                self?.dismiss?()
            }, for: .Click)
        } else if let actionView {
            performSubviewRemoval(actionView, animated: false)
            self.actionView = nil
        }
        
        if let infoText {
            let current: TextView
            if let view = self.infoText {
                current = view
            } else {
                current = TextView()
                current.userInteractionEnabled = false
                current.isSelectable = false
                addSubview(current)
                self.infoText = current
            }
            current.update(infoText)
        } else if let view = self.infoText {
            performSubviewRemoval(view, animated: false)
            self.infoText = nil
        }
        
        needsLayout = true
    }
    
    
    override func layout() {
        super.layout()
        
        if let mode = mode {
            switch mode {
            case .date:
                self.dayPicker.setFrameSize(NSMakeSize(135, 30))
                self.timePicker.setFrameSize(NSMakeSize(135, 30))

                let fullWidth = dayPicker.frame.width + 15 + timePicker.frame.width
                self.containerView.setFrameSize(NSMakeSize(fullWidth, max(dayPicker.frame.height, timePicker.frame.height)))
                self.dayPicker.centerY(x: 0)
                self.timePicker.centerY(x: dayPicker.frame.maxX + 15)
                self.containerView.centerX(y: 10)
            case .schedule, .dateAction:
                self.dayPicker.setFrameSize(NSMakeSize(120, 30))
                self.timePicker.setFrameSize(NSMakeSize(120, 30))
                let fullWidth = dayPicker.frame.width + 15 + atView.frame.width + 15 + timePicker.frame.width
                self.containerView.setFrameSize(NSMakeSize(fullWidth, max(dayPicker.frame.height, timePicker.frame.height)))
                self.dayPicker.centerY(x: 0)
                self.atView.centerY(x: self.dayPicker.frame.maxX + 15)
                self.timePicker.centerY(x: self.atView.frame.maxX + 15)
                self.containerView.centerX(y: 10)
                _ = self.sendOn.sizeToFit(NSZeroSize, NSMakeSize(fullWidth, 40), thatFit: true)
                self.sendOn.centerX(y: containerView.frame.maxY + 30)
                self.sendWhenOnline.centerX(y: self.sendOn.frame.maxY + 15)
            }
        }
        
        var offset: CGFloat = containerView.frame.maxY + 15
        
        if let infoText {
            infoText.centerX(y: offset)
            offset += infoText.frame.height + 10
        }
        if let actionView {
            actionView.centerX(y: offset)
        }
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    required init(frame frameRect: NSRect) {
        fatalError("init(frame:) has not been implemented")
    }
}



extension TimePickerOption {
    var interval: TimeInterval {
        let hours = Double(self.hours) * 60.0 * 60
        let minutes = Double(self.minutes) * 60.0
        let seconds = Double(self.seconds ?? 0)
        return hours + minutes + seconds
    }
}
class DateSelectorModalController: ModalViewController {
    
    enum Mode {
        struct Action {
            var string: String
            var callback:()->Void
        }
        case schedule(PeerId)
        case date(title: String, doneTitle: String)
        case dateAction(title: String, done: (Date)->String, action: Action)
    }
    
    private let context: AccountContext
    private let selectedAt: (Date)->Void
    private let defaultDate: Date?
    private var sendWhenOnline: Bool = false
    fileprivate let mode: Mode
    private let disposable = MetaDisposable()
    private let infoText: TextViewLayout?
    init(context: AccountContext, defaultDate: Date = Date(timeIntervalSince1970: Date().timeIntervalSince1970 + 1 * 60 * 60), mode: Mode, selectedAt:@escaping(Date)->Void, infoText: TextViewLayout? = nil) {
        self.context = context
        self.defaultDate = defaultDate
        self.selectedAt = selectedAt
        self.infoText = infoText
        self.mode = mode
        
        var add_Height: CGFloat = 0
        if let infoText {
            add_Height = infoText.layoutSize.height + 15
        }
        
        switch mode {
        case .schedule:
            super.init(frame: NSMakeRect(0, 0, 330, 180 + add_Height))
        case .dateAction:
            super.init(frame: NSMakeRect(0, 0, 330, 80 + add_Height))
        case .date:
            super.init(frame: NSMakeRect(0, 0, 330, 70 + add_Height))
        }
        self.bar = .init(height: 0)
    }
    
    override func viewClass() -> AnyClass {
        return DateSelectorModalView.self
    }
    
    override var modalTheme: ModalViewController.Theme {
        return .init(text: presentation.colors.text, grayText: presentation.colors.grayText, background: .clear, border: .clear, accent: presentation.colors.accent, grayForeground: presentation.colors.grayBackground, activeBackground: presentation.colors.background, activeBorder: presentation.colors.border)
    }
    
    override var containerBackground: NSColor {
        return presentation.colors.listBackground
    }
    
    override var modalHeader: (left: ModalHeaderData?, center: ModalHeaderData?, right: ModalHeaderData?)? {
        let title: String
        switch mode {
        case .schedule:
            title = strings().scheduleControllerTitle
        case let .date(value, _):
            title = value
        case let .dateAction(value, _, _):
            title = value
        }
        return (left: ModalHeaderData(title: nil, image: theme.icons.modalClose, handler: { [weak self] in
            self?.close()
        }), center: ModalHeaderData(title: title, handler: {
            
        }), right: nil)
    }
    
    
    
    override open func measure(size: NSSize) {
        var height: CGFloat = 0
        
        if let infoText {
            height += infoText.layoutSize.height
        }
        
        switch mode {
        case .date:
            height += 70
        case .dateAction:
            height += 80
            if infoText != nil {
                height += 10
            }
        case .schedule:
            height += sendWhenOnline ? 160 : 130
        }
        
        self.modal?.resize(with:NSMakeSize(frame.width, height), animated: false)
    }
    
    override var dynamicSize: Bool {
        return true
    }
    
    var genericView: DateSelectorModalView {
        return self.view as! DateSelectorModalView
    }
    
    private func applyDay(_ date: Date) {
        genericView.dayPicker.selected = DatePickerOption(name: DateSelectorUtil.formatDay(date), value: date)
        let current = date.addingTimeInterval(self.genericView.timePicker.selected.interval)

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
        
        genericView.timePicker.selected = TimePickerOption(hours: timeinfo.tm_hour, minutes: timeinfo.tm_min, seconds: hasSeconds ? timeinfo.tm_sec : nil)

        if CalendarUtils.isSameDate(Date(), date: date, checkDay: true) {
            let formatted = hasSeconds ? DateSelectorUtil.formatTime(date) : DateSelectorUtil.shortFormatTime(date)
            genericView.sendOn.set(text: strings().scheduleSendToday(formatted), for: .Normal)
        } else {
            let formatted = hasSeconds ? DateSelectorUtil.formatTime(date) : DateSelectorUtil.shortFormatTime(date)
            genericView.sendOn.set(text: strings().scheduleSendDate(DateSelectorUtil.formatDay(date), formatted), for: .Normal)
        }
        
        switch mode {
        case let .dateAction(_, done, _):
            let date = self.currentDate
            self.modal?.interactions?.updateDone { button in
                button.set(text: done(date), for: .Normal)
            }
        default:
            break
        }
        
        
    }
    
    override var handleAllEvents: Bool {
        return true
    }
    
    var currentDate:Date {
        let day = self.genericView.dayPicker.selected.value
        return day.startOfDay.addingTimeInterval(self.genericView.timePicker.selected.interval)
    }
    
    private func select() {
        let day = self.genericView.dayPicker.selected.value
        let date = day.startOfDay.addingTimeInterval(self.genericView.timePicker.selected.interval)
        if CalendarUtils.isSameDate(Date(), date: day, checkDay: true) {
            if Date() > date {
                genericView.timePicker.shake()
                return
            }
        }
        self.selectedAt(date)
        self.close()
    }
    
    override func returnKeyAction() -> KeyHandlerResult {
        self.select()
        return .invoked
    }
    
    override func firstResponder() -> NSResponder? {
        return genericView.timePicker.firstResponder
    }
    
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        window?.set(handler: { _ -> KeyHandlerResult in
            
            return .invokeNext
        }, with: self, for: .Tab, priority: .modal)
        window?.set(handler: { _ -> KeyHandlerResult in
            
            return .invokeNext
        }, with: self, for: .LeftArrow, priority: .modal)
        window?.set(handler: { _ -> KeyHandlerResult in
            
            return .invokeNext
        }, with: self, for: .RightArrow, priority: .modal)
    }
    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        window?.removeAllHandlers(for: self)
    }
    

    override func viewDidLoad() {
        super.viewDidLoad()
                
        genericView.dismiss = { [weak self] in
            self?.close()
        }
        
        let context = self.context
        
        switch mode {
        case let .schedule(peerId):
            let presence = context.account.postbox.transaction {
                $0.getPeerPresence(peerId: peerId) as? TelegramUserPresence
            } |> deliverOnMainQueue
            
            disposable.set(presence.start(next: { [weak self] presence in
                var sendWhenOnline: Bool = false
                if let presence = presence {
                    switch presence.status {
                    case .present:
                        sendWhenOnline = peerId != context.peerId
                    default:
                        break
                    }
                }
                self?.sendWhenOnline = sendWhenOnline
                self?.initialize()
            }))
        case .date, .dateAction:
            initialize()
        }
    }
    
    override var modalInteractions: ModalInteractions? {
        switch mode {
        case .schedule:
            return nil
        case let .date(_, doneTitle):
            return ModalInteractions(acceptTitle: doneTitle, accept: { [weak self] in
                self?.select()
            }, singleButton: true)
        case let .dateAction(_, done, _):
            return ModalInteractions(acceptTitle: done(currentDate), accept: { [weak self] in
                self?.select()
            }, singleButton: true)
        }
    }
    
    var hasSeconds: Bool {
        switch mode {
        case .schedule:
            return false
        case .date, .dateAction:
            return true
        }
    }
    
    
    private func initialize() {
        let date = self.defaultDate ?? Date()
        
        var t: time_t = time_t(date.timeIntervalSince1970)
        var timeinfo: tm = tm()
        localtime_r(&t, &timeinfo)
        
       
        
        self.genericView.dayPicker.selected = DatePickerOption<Date>(name: DateSelectorUtil.formatDay(date), value: date)
        self.genericView.timePicker.selected = TimePickerOption(hours: 0, minutes: 0, seconds: hasSeconds ? 0 : nil)
        
        self.genericView.updateWithMode(self.mode, sendWhenOnline: self.sendWhenOnline, infoText: infoText)
        
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
            self?.select()
        }, for: .Click)
        
        self.genericView.sendWhenOnline.set(handler: { [weak self] _ in
            self?.selectedAt(Date(timeIntervalSince1970: TimeInterval(scheduleWhenOnlineTimestamp)))
            self?.close()
        }, for: .Click)
        
        self.readyOnce()
        
        self.genericView.dayPicker.set(handler: { [weak self] control in
            if let control = control as? DatePicker<Date>, let window = self?.window, !hasPopover(window) {
                let calendar = CalendarController(NSMakeRect(0, 0, 300, 300), window, current: control.selected.value, onlyFuture: true, selectHandler: { [weak self] date in
                    self?.applyDay(date)
                })
                showPopover(for: control, with: calendar, edge: .maxY, inset: NSMakePoint(-8, -60))
            }
        }, for: .Down)
        
        self.genericView.timePicker.set(handler: { [weak self] control in
            if let control = control as? DatePicker<Date>, let `self` = self, let window = self.window, !hasPopover(window) {
                var items:[SPopoverItem] = []
                
                let day = self.genericView.dayPicker.selected.value
                
                for interval in DateSelectorUtil.timeIntervals {
                    if let interval = interval {
                        let date = day.startOfDay.addingTimeInterval(interval)
                        if CalendarUtils.isSameDate(Date(), date: day, checkDay: true) {
                            if Date() > date {
                                continue
                            }
                        }
                        items.append(SPopoverItem(DateSelectorUtil.formatTime(date), { [weak self] in
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
    
    deinit {
        disposable.dispose()
    }
    
    override func initializer() -> NSView {
        return DateSelectorModalView(frame: NSMakeRect(_frameRect.minX, _frameRect.minY, _frameRect.width, _frameRect.height - bar.height), hasSeconds: hasSeconds);
    }
}
