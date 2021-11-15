//
//  ChatCalendarHeaderRowItem.swift
//  Telegram
//
//  Created by Mikhail Filimonov on 01.11.2021.
//  Copyright © 2021 Telegram. All rights reserved.
//

import Foundation
import TGUIKit

final class ChatCalendarHeaderRowItem : TableStickItem {
    
    fileprivate let titleLayout: TextViewLayout?
    private let _stableId: AnyHashable
    init(_ initialSize: NSSize, stableId: AnyHashable, month: CalendarMonthStruct) {
        self._stableId = stableId
        
        
        let formatter:DateFormatter = DateFormatter()
        formatter.locale = Locale(identifier: appAppearance.language.languageCode)
        formatter.dateFormat = "MMMM yyyy"
        let monthString:String = formatter.string(from: month.month)
        
        self.titleLayout = .init(.initialize(string: monthString, color: theme.colors.text, font: .medium(.title)), maximumNumberOfLines: 1)
        self.titleLayout?.measure(width: .greatestFiniteMagnitude)
        
        super.init(initialSize)
    }
    
    required init(_ initialSize: NSSize) {
        self.titleLayout = nil
        self._stableId = AnyHashable(0)
        super.init(initialSize)
    }
    
    override var stableId: AnyHashable {
        return _stableId
    }
    
    override var height: CGFloat {
        return 50
    }
    
    
    override func viewClass() -> AnyClass {
        return ChatCalendarHeaderRowView.self
    }
}


private final class ChatCalendarHeaderRowView: TableStickView {
    private let headerView: TextView = TextView()
    private let daysContainer:View = View()
    private let borderView = View()
    required init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        addSubview(headerView)
        addSubview(daysContainer)
        addSubview(borderView)
        headerView.userInteractionEnabled = false
        headerView.isSelectable = false
        
        let days:[String] = [strings().calendarWeekDaysMonday, strings().calendarWeekDaysTuesday, strings().calendarWeekDaysWednesday, strings().calendarWeekDaysThrusday, strings().calendarWeekDaysFriday, strings().calendarWeekDaysSaturday, strings().calendarWeekDaysSunday]
        for day in days {
            let view = TextView()
            view.userInteractionEnabled = false
            view.isSelectable = false
            let layout: TextViewLayout = .init(.initialize(string: day, color: theme.colors.text, font: .normal(.small)), alignment: .center)
            layout.measure(width: .greatestFiniteMagnitude)
            view.update(layout)
            daysContainer.addSubview(view)
        }
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override func updateColors() {
        super.updateColors()
        borderView.backgroundColor = theme.colors.border
    }
    
    
    override var header: Bool {
        didSet {
            borderView.change(opacity: header ? 1 : 0, animated: true)
        }
    }
    
    override func layout() {
        super.layout()
        self.headerView.centerX(y: 4)
        daysContainer.frame = NSMakeRect(0, frame.height - 21, frame.width, 20)
        borderView.frame = NSMakeRect(0, frame.height - .borderSize, frame.width, .borderSize)
        var x: CGFloat = 10
        let per: CGFloat = (frame.width - 20) / CGFloat(daysContainer.subviews.count)
        for subview in daysContainer.subviews {
            subview.setFrameSize(per, subview.frame.height)
            subview.centerY(x: x)
            x += subview.frame.width
        }
    }
    
    override func set(item: TableRowItem, animated: Bool = false) {
        super.set(item: item, animated: animated)
        
        guard let item = item as? ChatCalendarHeaderRowItem else {
            return
        }
        
        borderView.change(opacity: 0, animated: animated)
        
        self.headerView.update(item.titleLayout)
        
        
        
        needsLayout = true
    }
}
