//
//  ChatCalendarMonthRowItem.swift
//  Telegram
//
//  Created by Mikhail Filimonov on 01.11.2021.
//  Copyright © 2021 Telegram. All rights reserved.
//

import Foundation
import TGUIKit


final class ChatCalendarMonthRowItem : GeneralRowItem {
    
    fileprivate let month: CalendarMonthStruct
    init(_ initialSize: NSSize, stableId: AnyHashable, month: CalendarMonthStruct) {
        self.month = month
        super.init(initialSize, height: 46.0 * CGFloat(month.linesCount), stableId: stableId)
    }
    
    
    
    override func viewClass() -> AnyClass {
        return ChatCalendarMonthRowView.self
    }
}


private final class ChatCalendarMonthRowView : TableRowView {
    private let month: CalendarMonthView
    required init(frame frameRect: NSRect) {
        month = CalendarMonthView(frame: frameRect.size.bounds)
        super.init(frame: frameRect)
        addSubview(month)
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    
    
    override func set(item: TableRowItem, animated: Bool = false) {
        super.set(item: item, animated: animated)
        
        guard let item = item as? ChatCalendarMonthRowItem else {
            return
        }
        month.setFrameSize(NSMakeSize(frame.width, item.height))
        month.layout(for: item.month)
    }
}
