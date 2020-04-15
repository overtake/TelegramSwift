////
////  WalletTransactionDateStickItem.swift
////  Telegram
////
////  Created by Mikhail Filimonov on 25/09/2019.
////  Copyright © 2019 Telegram. All rights reserved.
////
//
//import Cocoa
//import TGUIKit
//
//
//class WalletTransactionDateStickItem: TableStickItem {
//
//    fileprivate let timestamp:Int32
//    let layout:TextViewLayout
//    let viewType: GeneralViewType
//    let inset: NSEdgeInsets
//    init(_ initialSize:NSSize, timestamp: Int32, viewType: GeneralViewType) {
//        self.timestamp = timestamp
//        self.viewType = viewType
//        self.inset = NSEdgeInsets(left: 30, right: 30)
//        let nowTimestamp = Int32(CFAbsoluteTimeGetCurrent() + NSTimeIntervalSince1970)
//        
//        var t: time_t = time_t(timestamp)
//        var timeinfo: tm = tm()
//        localtime_r(&t, &timeinfo)
//        
//        var now: time_t = time_t(nowTimestamp)
//        var timeinfoNow: tm = tm()
//        localtime_r(&now, &timeinfoNow)
//        
//        var text: String
//        if timeinfo.tm_year == timeinfoNow.tm_year && timeinfo.tm_yday == timeinfoNow.tm_yday {
//            text = L10n.dateToday
//        } else {
//            let dateFormatter = DateFormatter()
//            dateFormatter.calendar = Calendar.autoupdatingCurrent
//            //dateFormatter.timeZone = NSTimeZone.local
//            dateFormatter.dateFormat = "dd MMMM";
//            if timeinfoNow.tm_year > timeinfo.tm_year && (timeinfoNow.tm_mon >= timeinfo.tm_mon || (timeinfoNow.tm_year - timeinfo.tm_year) >= 2) {
//                dateFormatter.dateFormat = "dd MMMM yyyy";
//            } else if timeinfoNow.tm_year < timeinfo.tm_year {
//                dateFormatter.dateFormat = "dd MMMM yyyy";
//            }
//            text = dateFormatter.string(from: Date(timeIntervalSince1970: TimeInterval(timestamp)))
//            
//        }
//        self.layout = TextViewLayout(.initialize(string: text, color: theme.colors.listGrayText, font: .normal(.text)), maximumNumberOfLines: 1, truncationType: .end, alignment: .center)
//        
//        super.init(initialSize)
//        self.layout.measure(width: .greatestFiniteMagnitude)
//    }
//    
//    override var canBeAnchor: Bool {
//        return false
//    }
//    
//    required init(_ initialSize: NSSize) {
//        self.timestamp = 0
//        self.viewType = .legacy
//        self.layout = TextViewLayout(NSAttributedString())
//        self.inset = NSEdgeInsets(left: 30, right: 30)
//        super.init(initialSize)
//    }
//    
//    override func makeSize(_ width: CGFloat, oldWidth:CGFloat) -> Bool {
//        let success = super.makeSize(width, oldWidth: oldWidth)
//        return success
//    }
//    
//    override var stableId: AnyHashable {
//        return self.timestamp
//    }
//    
//    override var height: CGFloat {
//        return 30
//    }
//    
//    override func viewClass() -> AnyClass {
//        return WalletTransactionDateStickView.self
//    }
//    
//}
//
//
//private final class WalletTransactionDateStickView : TableStickView {
//    private let containerView = GeneralRowContainerView(frame: NSZeroRect)
//    private let textView = TextView()
//    required init(frame frameRect: NSRect) {
//        super.init(frame: frameRect)
//        addSubview(self.containerView)
//        containerView.addSubview(self.textView)
//        self.textView.disableBackgroundDrawing = true
//        self.textView.isSelectable = false
//        self.textView.userInteractionEnabled = false
//    }
//    
//    override var header: Bool {
//        didSet {
//            updateColors()
//        }
//    }
//    
//    
//    override var backdorColor: NSColor {
//        return theme.colors.listBackground.withAlphaComponent(0.8)
//    }
//    
//    override func updateColors() {
//        guard let item = item as? WalletTransactionDateStickItem else {
//            return
//        }
//        self.backgroundColor = item.viewType.rowBackground
//        self.containerView.backgroundColor = backdorColor
//    }
//    
//    override func layout() {
//        super.layout()
//        guard let item = item as? WalletTransactionDateStickItem else {
//            return
//        }
//        
//        let blockWidth = min(600, frame.width - item.inset.left - item.inset.right)
//        
//        self.containerView.frame = NSMakeRect(floorToScreenPixels(backingScaleFactor, (frame.width - blockWidth) / 2), item.inset.top, blockWidth, frame.height - item.inset.bottom - item.inset.top)
//        self.containerView.setCorners([])
//        
//        textView.centerY(x: item.viewType.innerInset.left)
//    }
//    
//    override func set(item: TableRowItem, animated: Bool = false) {
//        super.set(item: item, animated: animated)
//        
//        guard let item = item as? WalletTransactionDateStickItem else {
//            return
//        }
//        self.textView.update(item.layout)
//        
//        needsLayout = true
//    }
//    
//    required init?(coder: NSCoder) {
//        fatalError("init(coder:) has not been implemented")
//    }
//}
