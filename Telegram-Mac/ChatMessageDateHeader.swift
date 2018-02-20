//
//  ChatMessageDateHeader.swift
//  TelegramMac
//
//  Created by keepcoder on 20/11/2016.
//  Copyright © 2016 Telegram. All rights reserved.
//

import Cocoa
import TGUIKit
import TelegramCoreMac
import PostboxMac

private let timezoneOffset: Int32 = {
    let nowTimestamp = Int32(CFAbsoluteTimeGetCurrent() + NSTimeIntervalSince1970)
    var now: time_t = time_t(nowTimestamp)
    var timeinfoNow: tm = tm()
    localtime_r(&now, &timeinfoNow)
    return Int32(timeinfoNow.tm_gmtoff)
}()

private let granularity: Int32 = 60 * 60 * 24



func chatDateId(for timestamp:Int32) -> Int64 {
    return Int64(Calendar.current.startOfDay(for: Date(timeIntervalSince1970: TimeInterval(timestamp))).timeIntervalSince1970)
}
func mediaDateId(for timestamp:Int32) -> Int64 {
    return Int64(Calendar.current.component(.month, from: Date(timeIntervalSince1970: TimeInterval(timestamp))))
}

class ChatDateStickItem : TableStickItem {
    
    private let entry:ChatHistoryEntry
    fileprivate let timestamp:Int32
    fileprivate let chatInteraction:ChatInteraction?
    let isBubbled: Bool
    let layout:TextViewLayout
    init(_ initialSize:NSSize, _ entry:ChatHistoryEntry, interaction: ChatInteraction) {
        self.entry = entry
        self.isBubbled = entry.renderType == .bubble
        self.chatInteraction = interaction
        if case let .DateEntry(index, _) = entry {
            self.timestamp = index.timestamp
        } else {
            fatalError()
        }
        
        let nowTimestamp = Int32(CFAbsoluteTimeGetCurrent() + NSTimeIntervalSince1970)
        
        var t: time_t = time_t(timestamp)
        var timeinfo: tm = tm()
        localtime_r(&t, &timeinfo)
        
        var now: time_t = time_t(nowTimestamp)
        var timeinfoNow: tm = tm()
        localtime_r(&now, &timeinfoNow)
        
        let text: String
        if timeinfo.tm_year == timeinfoNow.tm_year && timeinfo.tm_yday == timeinfoNow.tm_yday {
            text = tr(L10n.dateToday)
        } else {
            let dateFormatter = DateFormatter()
            dateFormatter.timeZone = NSTimeZone.local
            dateFormatter.dateFormat = "dd MMMM";
            if timeinfoNow.tm_year > timeinfo.tm_year && (timeinfoNow.tm_mon >= timeinfo.tm_mon || (timeinfoNow.tm_year - timeinfo.tm_year) >= 2) {
                dateFormatter.dateFormat = "dd MMMM yyyy";
            }
            text = dateFormatter.string(from: Date(timeIntervalSince1970: TimeInterval(timestamp)))

        }
        
        self.layout = TextViewLayout(.initialize(string: text, color: theme.colors.chatDateText, font: .normal(.text)), maximumNumberOfLines: 1, truncationType: .end, alignment: .center)

        
        super.init(initialSize)
    }
    
    required init(_ initialSize: NSSize) {
        entry = .DateEntry(MessageIndex.absoluteLowerBound(), .list)
        timestamp = 0
        self.isBubbled = false
        self.layout = TextViewLayout(NSAttributedString())
        self.chatInteraction = nil
        super.init(initialSize)
    }
    
    override func makeSize(_ width: CGFloat, oldWidth:CGFloat) -> Bool {
        layout.measure(width: width - 40)
        return super.makeSize(width, oldWidth: oldWidth)
    }
    
    override var stableId: AnyHashable {
        return entry.stableId
    }
    
    override var height: CGFloat {
        return 50
    }
    
    override func viewClass() -> AnyClass {
        return ChatDateStickView.self
    }
    
    
}

class ChatDateStickView : TableStickView {
    private let textView:TextView
    private let containerView: Control = Control()
    private var borderView: View = View()
    required init(frame frameRect: NSRect) {
        self.textView = TextView()
        self.textView.isSelectable = false
       // self.textView.userInteractionEnabled = false
        self.containerView.wantsLayer = true
       // textView.isEventLess = false
        super.init(frame: frameRect)
        addSubview(textView)
        textView.set(handler: { [weak self] _ in
             if let strongSelf = self, let item = strongSelf.item as? ChatDateStickItem, strongSelf.header {
                
                var calendar = NSCalendar.current
                
                calendar.timeZone = TimeZone(abbreviation: "UTC")!
                let date = Date(timeIntervalSince1970: TimeInterval(item.timestamp + 86400))
                let components = calendar.dateComponents([.year, .month, .day], from: date)
                
                item.chatInteraction?.jumpToDate(CalendarUtils.monthDay(components.day!, date: date))
            }
        }, for: .Click)
    }
    

    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override var backdorColor: NSColor {
        return .clear
    }
    
    override func updateIsVisible(_ visible: Bool, animated: Bool) {
        textView.change(opacity: visible ? 1 : 0, animated: animated)
    }
    
    
    override var header: Bool {
        didSet {
            updateColors()
        }
    }
    
    override func updateColors() {
        super.updateColors()
        

        textView.backgroundColor = theme.colors.chatDateActive
        
        //containerView.layer?.borderColor = theme.colors.border.cgColor
       // containerView.layer?.borderWidth = header || (theme.wallpaper != .none) ? 1.0 : 0
        

    }
    
    override func draw(_ layer: CALayer, in ctx: CGContext) {
        super.draw(layer, in: ctx)
    }
    
    override func layout() {
        super.layout()
        textView.center()
    }
    
    override func set(item: TableRowItem, animated: Bool) {
        if let item = item as? ChatDateStickItem {
            textView.update(item.layout)
            textView.setFrameSize(item.layout.layoutSize.width + 16, item.layout.layoutSize.height + 6)
            textView.layer?.cornerRadius = textView.frame.height / 2
//            if animated {
//                containerView.layer?.animateAlpha(from: 0, to: 1, duration: 0.2)
//            }
            
            self.needsLayout = true
        }
        super.set(item: item, animated:animated)
    }
}
