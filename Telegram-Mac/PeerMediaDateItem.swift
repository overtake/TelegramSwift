//
//  PeerMediaDateItem.swift
//  Telegram
//
//  Created by keepcoder on 27/11/2017.
//  Copyright © 2017 Telegram. All rights reserved.
//

import Cocoa
import TGUIKit
import TelegramCoreMac
import PostboxMac

class PeerMediaDateItem: TableRowItem {

    private let _stableId: AnyHashable
    private let messageIndex: MessageIndex
    fileprivate let textLayout: TextViewLayout
    init(_ initialSize: NSSize, index: MessageIndex, stableId: AnyHashable) {
        self.messageIndex = index
        self._stableId = stableId
        
        let timestamp = index.timestamp
        
        let nowTimestamp = Int32(CFAbsoluteTimeGetCurrent() + NSTimeIntervalSince1970)
        
        var t: time_t = time_t(timestamp)
        var timeinfo: tm = tm()
        localtime_r(&t, &timeinfo)
        
        var now: time_t = time_t(nowTimestamp)
        var timeinfoNow: tm = tm()
        localtime_r(&now, &timeinfoNow)
        
        let text: String
        let dateFormatter = DateFormatter()
        dateFormatter.timeZone = NSTimeZone.local
        dateFormatter.dateFormat = "MMMM yyyy";
        text = dateFormatter.string(from: Date(timeIntervalSince1970: TimeInterval(timestamp)))
        
        textLayout = TextViewLayout(.initialize(string: text, color: theme.colors.text, font: .normal(.text)))
        super.init(initialSize)
        _ = makeSize(initialSize.width, oldWidth: 0)
    }
    
    override func makeSize(_ width: CGFloat, oldWidth: CGFloat) -> Bool {
        textLayout.measure(width: width - 60)
        return super.makeSize(width, oldWidth: oldWidth)
    }
    
    override var stableId: AnyHashable {
        return _stableId
    }
    
    override var height: CGFloat {
        return 30
    }
    
    override func viewClass() -> AnyClass {
        return PeerMediaDateView.self
    }
}

fileprivate class PeerMediaDateView : TableRowView {
    private let textView: TextView = TextView()
    required init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        addSubview(textView)
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override func updateColors() {
        super.updateColors()
        textView.backgroundColor = theme.colors.background
    }
    
    override func layout() {
        super.layout()
        textView.centerY(x: 10)
    }
    
    override func set(item: TableRowItem, animated: Bool) {
        super.set(item: item, animated: animated)
        
        guard let item = item as? PeerMediaDateItem else {return}
        
        textView.update(item.textLayout)
    }
}
