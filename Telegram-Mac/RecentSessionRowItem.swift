//
//  RecentSessionRowItem.swift
//  Telegram
//
//  Created by keepcoder on 08/03/2017.
//  Copyright © 2017 Telegram. All rights reserved.
//

import Cocoa
import TGUIKit
import TelegramCore
import DateUtils

class RecentSessionRowItem: GeneralRowItem {
    
    let session:RecentAccountSession
    
    let headerLayout:TextViewLayout
    let descLayout:TextViewLayout
    let dateLayout:TextViewLayout
    let handler:()->Void
    let icon: (CGImage?, LocalAnimatedSticker?)
    
    init(_ initialSize: NSSize, session:RecentAccountSession, stableId:AnyHashable, viewType: GeneralViewType, icon: (CGImage?, LocalAnimatedSticker?), handler: @escaping()->Void) {
        self.session = session
        self.handler = handler
        self.icon = icon
        headerLayout = TextViewLayout(.initialize(string: session.deviceModel, color: theme.colors.text, font: .normal(.title)), maximumNumberOfLines: 1)
        
        let attr = NSMutableAttributedString()
        
                
        _ = attr.append(string:session.appName + " " + session.appVersion.prefixWithDots(30) + ", " + session.platform + " " + session.systemVersion, color: theme.colors.text, font: .normal(.text))
        
        _ = attr.append(string: "\n")
        
        _ = attr.append(string: session.ip + " " + session.country, color: theme.colors.grayText, font: .normal(.text))
        
        descLayout = TextViewLayout(attr, maximumNumberOfLines: 2, lineSpacing: 2)
    
        dateLayout = TextViewLayout(.initialize(string: session.isCurrent ? strings().peerStatusOnline : DateUtils.string(forMessageListDate: session.activityDate), color: session.isCurrent ? theme.colors.accent : theme.colors.grayText, font: .normal(.text)))
        
        super.init(initialSize, stableId: stableId, viewType: viewType)
        
        _ = makeSize(initialSize.width, oldWidth: initialSize.width)
    }
    
    override func makeSize(_ width: CGFloat, oldWidth: CGFloat) -> Bool {
        let success = super.makeSize(width, oldWidth: oldWidth)
        headerLayout.measure(width: blockWidth - 90 - (icon.0 != nil ? 38 : 0))
        descLayout.measure(width: blockWidth - 40 - (icon.0 != nil ? 38 : 0))
        dateLayout.measure(width: .greatestFiniteMagnitude)
        return success
    }
    
    override var height: CGFloat {
        return 75
    }
    
    override func viewClass() -> AnyClass {
        return RecentSessionRowView.self
    }
}

class RecentSessionRowView : GeneralContainableRowView {
    private let headerTextView = TextView()
    private let descTextView = TextView()
    private let dateTextView = TextView()
    private let iconView: ImageView = ImageView()
    required init(frame frameRect: NSRect) {
          
        super.init(frame: frameRect)
        self.addSubview(headerTextView)
        self.addSubview(descTextView)
        self.addSubview(dateTextView)
        addSubview(iconView)
        
        headerTextView.userInteractionEnabled = false
        headerTextView.isSelectable = false
            
        dateTextView.userInteractionEnabled = false
        dateTextView.isSelectable = false
        
        descTextView.userInteractionEnabled = false
        descTextView.isSelectable = false


        containerView.set(handler: { [weak self] _ in
            if let item = self?.item as? RecentSessionRowItem {
                item.handler()
            }
        }, for: .Click)
    }
    
    override func updateColors() {
        super.updateColors()
        headerTextView.backgroundColor = backdorColor
        descTextView.backgroundColor = backdorColor
        dateTextView.backgroundColor = backdorColor
        containerView.backgroundColor = backdorColor
        if let item = item as? RecentSessionRowItem {
            self.background = item.viewType.rowBackground
        }
    }
    
    override var backdorColor: NSColor {
        return theme.colors.background
    }
    
    
    override func set(item: TableRowItem, animated: Bool) {
        super.set(item: item)
 
        
        
        if let item = item as? RecentSessionRowItem {
            self.iconView.image = item.icon.0
            self.iconView.sizeToFit()
        }
        
        self.needsLayout = true
    }
    
    override func layout() {
        super.layout()
        guard let item = item as? RecentSessionRowItem  else {
            return
        }
        let insets = item.viewType.innerInset
        self.iconView.setFrameOrigin(NSMakePoint(insets.left, insets.top))
        let left: CGFloat = (item.icon.0 != nil ? 38 : 0)
        self.headerTextView.update(item.headerLayout, origin: NSMakePoint(left + insets.left, insets.top - 2))
        self.descTextView.update(item.descLayout, origin: NSMakePoint(left + insets.left, headerTextView.frame.maxY + 4))
        self.dateTextView.update(item.dateLayout, origin: NSMakePoint(self.containerView.frame.width - insets.right - item.dateLayout.layoutSize.width, insets.top))

    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}
