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
    override func viewDidLoad() {
        super.viewDidLoad()
        addSubview(navigation.view)
        readyOnce()
    }
    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        bar = .init(height: 0)
    }
    override init() {
        super.init()
        bar = .init(height: 0)
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
    
    init(_ frameRect:NSRect, selectHandler:@escaping (Date)->Void) {
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
        
        self.navigation = NavigationViewController(stepMonth(date: Date()))
        self.navigation._frameRect = frameRect
    }
    
    func stepMonth(date:Date) -> CalendarMonthController {
        return CalendarMonthController(date, interactions: interactions)
    }
}



