//
//  CalendarMonthController.swift
//  TelegramMac
//
//  Created by keepcoder on 17/01/2017.
//  Copyright © 2017 Telegram. All rights reserved.
//

import Cocoa
import TGUIKit

struct CalendarMonthInteractions {
    let selectAction:(Date)->Void
    let backAction:((Date)->Void)?
    let nextAction:((Date)->Void)?
    init(selectAction:@escaping (Date)->Void, backAction:((Date)->Void)? = nil, nextAction:((Date)->Void)? = nil) {
        self.selectAction = selectAction
        self.backAction = backAction
        self.nextAction = nextAction
    }
}

struct CalendarMonthStruct {
    let month:Date
    let prevMonth:Date
    let nextMonth:Date
    
    let lastDayOfMonth:Int
    let lastDayOfPrevMonth:Int
    let lastDayOfNextMonth:Int
    
    let currentStartDay:Int
    let selectedDay:Int?
    
    let components:DateComponents
    let dayHandler:(Int)->Void
    init(month:Date, dayHandler:@escaping (Int)->Void) {
        self.month = month
        self.dayHandler = dayHandler
        self.prevMonth = CalendarUtils.stepMonth(-1, date: month)
        self.nextMonth = CalendarUtils.stepMonth(1, date: month)
        self.lastDayOfMonth = CalendarUtils.lastDay(ofTheMonth: month)
        self.lastDayOfPrevMonth = CalendarUtils.lastDay(ofTheMonth: month)
        self.lastDayOfNextMonth = CalendarUtils.lastDay(ofTheMonth: month)
        var calendar = NSCalendar.current
        
        calendar.timeZone = TimeZone(abbreviation: "UTC")!
        let components = calendar.dateComponents([.year, .month, .day], from: month)
        self.currentStartDay = CalendarUtils.weekDay(Date(timeIntervalSince1970: month.timeIntervalSince1970 - TimeInterval(components.day! * 24*60*60)))
        
        if CalendarUtils.isSameDate(month, date: Date(), checkDay: false) {
            selectedDay = components.day!
        } else {
            selectedDay = nil
        }
        
        self.components = components
    }
}

class CalendarMonthView : View {
    private var month:CalendarMonthStruct?
    required init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        backgroundColor = theme.colors.background
    }
    
    override func scrollWheel(with event: NSEvent) {
        
    }
    
    func layout(for month:CalendarMonthStruct) {
        self.month = month
        self.removeAllSubviews()
        
        for i in 0 ..< 7 * 6 {
            let day = TitleButton()
            day.set(font: .normal(.text), for: .Normal)
            day.set(background: theme.colors.background, for: .Normal)
            let current:Int
            if i + 1 < month.currentStartDay {
                current = (month.lastDayOfPrevMonth - month.currentStartDay) + i + 2
                day.set(color: .grayText, for: .Normal)

            } else if (i + 2) - month.currentStartDay > month.lastDayOfMonth {
                current = (i + 2) - (month.currentStartDay + month.lastDayOfMonth)
                day.set(color: .grayText, for: .Normal)
            } else {
                current = (i + 1) - month.currentStartDay + 1
                
                day.set(color: .white, for: .Highlight)
                
                if (i + 1) % 7 == 0 || (i + 2) % 7 == 0 {
                    day.set(color: theme.colors.redUI, for: .Normal)
                } else {
                    day.set(color: theme.colors.text, for: .Normal)
                }
                
                day.layer?.cornerRadius = .cornerRadius
                
                if let selectedDay = month.selectedDay, current == selectedDay {
                    day.isSelected = true
                    day.set(background: theme.colors.blueSelect, for: .Highlight)
                    day.apply(state: .Highlight)
                } else {
                    day.set(background: theme.colors.blueUI, for: .Highlight)
                }
                
                day.set(handler: { (control) in
                    
                    month.dayHandler(current)
                    
                }, for: .Click)
                
            }
            day.set(text: "\(current)", for: .Normal)
            
            addSubview(day)
        }
        
        self.needsLayout = true
    }
    
    override func layout() {
        super.layout()
        let oneSize:NSSize = NSMakeSize(floorToScreenPixels(scaleFactor: backingScaleFactor, frame.width / 7), floorToScreenPixels(scaleFactor: backingScaleFactor, frame.height / 6))
        var inset:NSPoint = NSMakePoint(0, 0)
        for i in 0 ..< subviews.count {
            subviews[i].frame = NSMakeRect(inset.x, inset.y, oneSize.width, oneSize.height)
            inset.x += oneSize.width
            
            if (i + 1) % 7 == 0 {
                inset.x = 0
                inset.y += oneSize.height
            }
        }
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
}



class CalendarMonthController: GenericViewController<CalendarMonthView> {
    let interactions:CalendarMonthInteractions
    let month:CalendarMonthStruct
    init(_ month:Date, interactions:CalendarMonthInteractions) {
        self.month = CalendarMonthStruct(month: month, dayHandler: { day in
            interactions.selectAction(CalendarUtils.monthDay(day, date: month))
        })
        self.interactions = interactions
        
        super.init()
        self.bar = NavigationBarStyle(height: 40)
    }
    
    override func getCenterBarViewOnce() -> TitledBarView {
        let formatter:DateFormatter = DateFormatter()
        formatter.locale = Locale(identifier: appAppearance.language.languageCode)
        formatter.dateFormat = "MMMM"
        let monthString:String = formatter.string(from: month.month)
        formatter.dateFormat = "yyyy"
        let yearString:String = formatter.string(from: month.month)
        
        return TitledBarView(controller: self, .initialize(string: monthString, color: theme.colors.text, font:.medium(.text)), .initialize(string:yearString, color: theme.colors.grayText, font:.normal(.small)))
    }
    
    var isNextEnabled:Bool {
        return !CalendarUtils.isSameDate(month.month, date: Date(), checkDay: false)
    }
    
    var isPrevEnabled:Bool {
        return month.components.year! > 2013 || (month.components.year == 2013 && month.components.month! >= 9)
    }
    
    override func getLeftBarViewOnce() -> BarView {
        let bar = ImageBarView(controller: self, theme.icons.calendarBack)
        bar.button.isEnabled = isPrevEnabled
        
        if isPrevEnabled {
            bar.button.set(handler: { [weak self] (control) in
                if let backAction = self?.interactions.backAction, let month = self?.month.month {
                    backAction(month)
                }
            }, for: .Click)
        }
        
        bar.set(image: bar.button.isEnabled ? theme.icons.calendarBack : theme.icons.calendarBackDisabled)
        bar.setFrameSize(40,bar.frame.height)
        bar.set(background: theme.colors.background, for: .Normal)
        return bar
    }
    
    override func getRightBarViewOnce() -> BarView {
        let bar = ImageBarView(controller: self, theme.icons.calendarNext)
        bar.button.isEnabled = isNextEnabled

        if isNextEnabled {
            bar.button.set(handler: { [weak self] (control) in
                if let nextAction = self?.interactions.nextAction, let month = self?.month.month {
                    nextAction(month)
                }
            }, for: .Click)
        }
       
        bar.set(image: bar.button.isEnabled ? theme.icons.calendarNext : theme.icons.calendarNextDisabled)
        bar.setFrameSize(40,bar.frame.height)
        bar.set(background: theme.colors.background, for: .Normal)
        return bar
    }
    
    override var removeAfterDisapper: Bool {
        return true
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        genericView.layout(for: month)
        
        readyOnce()
    }

    
    
    
}

