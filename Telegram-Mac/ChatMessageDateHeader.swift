//
//  ChatMessageDateHeader.swift
//  TelegramMac
//
//  Created by keepcoder on 20/11/2016.
//  Copyright © 2016 Telegram. All rights reserved.
//

import Cocoa
import TGUIKit
import TelegramCore
import SyncCore
import Postbox

private let timezoneOffset: Int32 = {
    let nowTimestamp = Int32(CFAbsoluteTimeGetCurrent() + NSTimeIntervalSince1970)
    var now: time_t = time_t(nowTimestamp)
    var timeinfoNow: tm = tm()
    localtime_r(&now, &timeinfoNow)
    return Int32(timeinfoNow.tm_gmtoff)
}()

private let granularity: Int32 = 60 * 60 * 24



func chatDateId(for timestamp:Int32) -> Int64 {
    return Int64(Calendar.autoupdatingCurrent.startOfDay(for: Date(timeIntervalSince1970: TimeInterval(timestamp))).timeIntervalSince1970)
}
func mediaDateId(for timestamp:Int32) -> Int64 {
    let startMonth = Calendar.autoupdatingCurrent.date(from: Calendar.current.dateComponents([.year, .month], from: Date(timeIntervalSince1970: TimeInterval(timestamp))))!
    let endMonth = Calendar.autoupdatingCurrent.date(byAdding: DateComponents(month: 1, day: -1), to: startMonth)!
    return Int64(endMonth.timeIntervalSince1970)
}

class ChatDateStickItem : TableStickItem {
    
    private let entry:ChatHistoryEntry
    let timestamp:Int32
    fileprivate let chatInteraction:ChatInteraction?
    let isBubbled: Bool
    let layout:TextViewLayout
    init(_ initialSize:NSSize, _ entry:ChatHistoryEntry, interaction: ChatInteraction, theme: TelegramPresentationTheme) {
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
        
        var text: String
        if timeinfo.tm_year == timeinfoNow.tm_year && timeinfo.tm_yday == timeinfoNow.tm_yday {
            
            switch interaction.mode {
            case .scheduled:
                text = L10n.chatDateScheduledForToday
            default:
                text = L10n.dateToday
            }
            
        } else {
            let dateFormatter = DateFormatter()
            dateFormatter.calendar = Calendar.autoupdatingCurrent
            //dateFormatter.timeZone = NSTimeZone.local
            dateFormatter.dateFormat = "dd MMMM";
            //&& (timeinfoNow.tm_mon >= timeinfo.tm_mon || (timeinfoNow.tm_year - timeinfo.tm_year) >= 2)
            if timeinfoNow.tm_year > timeinfo.tm_year  {
                dateFormatter.dateFormat = "dd MMMM yyyy";
            } else if timeinfoNow.tm_year < timeinfo.tm_year {
                dateFormatter.dateFormat = "dd MMMM yyyy";
            }
            let dateString = dateFormatter.string(from: Date(timeIntervalSince1970: TimeInterval(timestamp)))
            switch interaction.mode {
            case .scheduled:
                if timestamp == 2147457600 {
                    text = L10n.chatDateScheduledUntilOnline
                } else {
                    text = L10n.chatDateScheduledFor(dateString)
                }
            default:
                text = dateString
            }
        }
        
        
        self.layout = TextViewLayout(.initialize(string: text, color: theme.chatServiceItemTextColor, font: .medium(theme.fontSize)), maximumNumberOfLines: 1, truncationType: .end, alignment: .center)

        
        super.init(initialSize)
    }
    
    override var canBeAnchor: Bool {
        return false
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
        let success = super.makeSize(width, oldWidth: oldWidth)
        layout.measure(width: width - 40)
        return success
    }
    
    override var stableId: AnyHashable {
        return entry.stableId
    }
    
    override var height: CGFloat {
        return 30
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
        self.textView.disableBackgroundDrawing = true
       // textView.isEventLess = false
        super.init(frame: frameRect)
        addSubview(textView)
        textView.set(handler: { [weak self] control in
             if let strongSelf = self, let item = strongSelf.item as? ChatDateStickItem, let table = item.table {
                
                let row = table.visibleRows()
                var ignore: Bool = false
                if row.length > 1 {
                    if let underItem = table.item(at: row.location + row.length - 1) as? ChatDateStickItem {
                       ignore = item.timestamp == underItem.timestamp
                    }
                }
                
                if strongSelf.header && !ignore {
                    var calendar = NSCalendar.current
                    
                    calendar.timeZone = TimeZone(abbreviation: "UTC")!
                    let date = Date(timeIntervalSince1970: TimeInterval(item.timestamp + 86400))
                    let components = calendar.dateComponents([.year, .month, .day], from: date)
                    
                    item.chatInteraction?.jumpToDate(CalendarUtils.monthDay(components.day!, date: date))
                } else if let chatInteraction = item.chatInteraction, chatInteraction.mode == .history {
                    if !hasPopover(chatInteraction.context.window) {
                        let controller = CalendarController(NSMakeRect(0, 0, 250, 250), chatInteraction.context.window, current: Date(timeIntervalSince1970: TimeInterval(item.timestamp)), selectHandler: chatInteraction.jumpToDate)
                        showPopover(for: control, with: controller, edge: .maxY, inset: NSMakePoint(-100, -40))
                    }
                }
               
            }
        }, for: .Click)
    }
    
    override func hitTest(_ point: NSPoint) -> NSView? {
        return header && textView.layer?.opacity == 0 ? nil : super.hitTest(point)
    }
    
    override func mouseDown(with event: NSEvent) {
        guard header, let tableView = superview as? TableView else {
            super.mouseDown(with: event)
            return
        }
        
        tableView.documentView!.hitTest(tableView.documentView!.convert(event.locationInWindow, from: nil))?.mouseDown(with: event)
        
    }
    
    override func mouseUp(with event: NSEvent) {
        guard header, let tableView = superview as? TableView else {
            super.mouseUp(with: event)
            return
        }

        tableView.documentView!.hitTest(tableView.documentView!.convert(event.locationInWindow, from: nil))?.mouseUp(with: event)
        
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
        

        textView.backgroundColor = theme.chatServiceItemColor
        
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
