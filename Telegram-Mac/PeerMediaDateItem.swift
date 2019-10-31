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

class PeerMediaDateItem: TableStickItem {

    private let _stableId: AnyHashable
    private let messageIndex: MessageIndex
    fileprivate let textLayout: TextViewLayout
    let viewType: GeneralViewType
    let inset: NSEdgeInsets

    init(_ initialSize: NSSize, index: MessageIndex, stableId: AnyHashable) {
        self.messageIndex = index
        self._stableId = stableId
        self.viewType = .modern(position: .single, insets: NSEdgeInsetsMake(3, 0, 3, 0))
        self.inset = NSEdgeInsets(left: 30, right: 30)
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
        text = dateFormatter.string(from: Date(timeIntervalSince1970: TimeInterval(timestamp))).uppercased()
        
        textLayout = TextViewLayout(.initialize(string: text, color: theme.colors.listGrayText, font: .normal(.short)))
        super.init(initialSize)
        _ = makeSize(initialSize.width, oldWidth: 0)
    }
    
    required init(_ initialSize: NSSize) {
        self._stableId = AnyHashable(0)
        self.messageIndex = MessageIndex.absoluteLowerBound()
        self.textLayout = TextViewLayout(.initialize(string: ""))
        self.viewType = .separator
        self.inset = NSEdgeInsets(left: 30, right: 30)
        super.init(initialSize)
    }

    
    override func makeSize(_ width: CGFloat, oldWidth: CGFloat) -> Bool {
        let success = super.makeSize(width, oldWidth: oldWidth)
        textLayout.measure(width: width - 60)
        return success
    }
    
    override var stableId: AnyHashable {
        return _stableId
    }
    
    override var height: CGFloat {
        return textLayout.layoutSize.height + viewType.innerInset.top + viewType.innerInset.bottom + 9
    }
    
    override func viewClass() -> AnyClass {
        return PeerMediaDateView.self
    }
}

fileprivate class PeerMediaDateView : TableStickView {
     private let containerView = GeneralRowContainerView(frame: NSZeroRect)
       private let textView = TextView()
       required init(frame frameRect: NSRect) {
           super.init(frame: frameRect)
           addSubview(self.containerView)
           containerView.addSubview(self.textView)
           self.textView.disableBackgroundDrawing = true
           self.textView.isSelectable = false
           self.textView.userInteractionEnabled = false
       }
       
       override var header: Bool {
           didSet {
               updateColors()
           }
       }
       override func updateIsVisible(_ visible: Bool, animated: Bool) {
           containerView.change(opacity: visible ? 1 : 0, animated: animated)
       }
       
       override var backdorColor: NSColor {
           return theme.colors.listBackground.withAlphaComponent(0.8)
       }
       
       override func updateColors() {
           guard let item = item as? PeerMediaDateItem else {
               return
           }
           self.backgroundColor = item.viewType.rowBackground
           self.containerView.backgroundColor = backdorColor
       }
       
       override func layout() {
           super.layout()
           guard let item = item as? PeerMediaDateItem else {
               return
           }
           let blockWidth = min(600, frame.width - item.inset.left - item.inset.right)
           
           self.containerView.frame = NSMakeRect(floorToScreenPixels(backingScaleFactor, (frame.width - blockWidth) / 2), item.inset.top, blockWidth, frame.height - item.inset.bottom - item.inset.top)
           self.containerView.setCorners([])
           
           textView.centerY(x: item.viewType.innerInset.left + 12)
       }
       
       override func set(item: TableRowItem, animated: Bool = false) {
           super.set(item: item, animated: animated)
           
           guard let item = item as? PeerMediaDateItem else {
               return
           }
           self.textView.update(item.textLayout)
           
           needsLayout = true
       }
       
       required init?(coder: NSCoder) {
           fatalError("init(coder:) has not been implemented")
       }
}
