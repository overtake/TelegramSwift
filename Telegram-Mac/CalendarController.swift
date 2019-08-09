//
//  CalendarController.swift
//  TelegramMac
//
//  Created by keepcoder on 17/01/2017.
//  Copyright © 2017 Telegram. All rights reserved.
//

import Cocoa
import TGUIKit

class CalendarControllerView : View {
    
}

class CalendarController: GenericViewController<CalendarControllerView> {
    
    private var navigation:NavigationViewController!
    private var interactions:CalendarMonthInteractions!
    private let onlyFuture: Bool
    private let current: Date
    override func viewDidLoad() {
        super.viewDidLoad()
        addSubview(navigation.view)
        readyOnce()
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        
        self.window?.set(handler: { [weak self] () -> KeyHandlerResult in
            if let current = self?.navigation.controller as? CalendarMonthController, current.isPrevEnabled, let backAction = self?.interactions.backAction {
                backAction(current.month.month)
            }
            return .invoked
        }, with: self, for: .LeftArrow, priority: .modal)
        
        self.window?.set(handler: { [weak self] () -> KeyHandlerResult in
            if let current = self?.navigation.controller as? CalendarMonthController, current.isNextEnabled, let nextAction = self?.interactions.nextAction {
                nextAction(current.month.month)
            }
            return .invoked
        }, with: self, for: .RightArrow, priority: .modal)
    }
    
    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        self.window?.remove(object: self, for: .LeftArrow)
        self.window?.remove(object: self, for: .RightArrow)
    }
    
    init(_ frameRect:NSRect, _ window: Window, current: Date = Date(), onlyFuture: Bool = false, selectHandler:@escaping (Date)->Void) {
        self.onlyFuture = onlyFuture
        self.current = current
        super.init(frame: frameRect)
        bar = .init(height: 0)
        self.interactions = CalendarMonthInteractions(selectAction: { [weak self] (selected) in
            self?.popover?.hide()
            selectHandler(selected)
        }, backAction: { [weak self] date in
            if let strongSelf = self {
                strongSelf.navigation.push(strongSelf.stepMonth(date: CalendarUtils.stepMonth(-1, date: date)), style: .pop)
            }
        }, nextAction: { [weak self] date in
            if let strongSelf = self {
                strongSelf.navigation.push(strongSelf.stepMonth(date: CalendarUtils.stepMonth(1, date: date)), style: .push)
            }
        })
        
        self.navigation = NavigationViewController(stepMonth(date: current), window)
        self.navigation._frameRect = frameRect
    }
    
    func stepMonth(date:Date) -> CalendarMonthController {
        return CalendarMonthController(date, onlyFuture: self.onlyFuture, selectDayAnyway: CalendarUtils.isSameDate(current, date: date, checkDay: false), interactions: interactions)
    }
}



