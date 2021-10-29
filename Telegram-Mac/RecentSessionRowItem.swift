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

class RecentSessionRowItem: GeneralRowItem {
    
    let session:RecentAccountSession
    
    let headerLayout:TextViewLayout
    let descLayout:TextViewLayout
    let dateLayout:TextViewLayout
    let revoke:()->Void
    let icon: (CGImage?, String?)
    
    init(_ initialSize: NSSize, session:RecentAccountSession, stableId:AnyHashable, viewType: GeneralViewType, icon: (CGImage?, String?), revoke: @escaping()->Void) {
        self.session = session
        self.revoke = revoke
        self.icon = icon
        headerLayout = TextViewLayout(.initialize(string: session.deviceModel, color: theme.colors.text, font: .normal(.title)), maximumNumberOfLines: 1)
        
        let attr = NSMutableAttributedString()
        
                
        _ = attr.append(string:session.appName + " " + session.appVersion.prefixWithDots(30) + ", " + session.platform + " " + session.systemVersion, color: theme.colors.text, font: .normal(.text))
        
        _ = attr.append(string: "\n")
        
        _ = attr.append(string: session.ip + " " + session.country, color: theme.colors.grayText, font: .normal(.text))
        
        descLayout = TextViewLayout(attr, maximumNumberOfLines: 2, lineSpacing: 2)
    
        dateLayout = TextViewLayout(.initialize(string: session.isCurrent ? tr(L10n.peerStatusOnline) : DateUtils.string(forMessageListDate: session.activityDate), color: session.isCurrent ? theme.colors.accent : theme.colors.grayText, font: .normal(.text)))
        
        super.init(initialSize, stableId: stableId, viewType: viewType)
        
        _ = makeSize(initialSize.width, oldWidth: initialSize.width)
    }
    
    override func makeSize(_ width: CGFloat, oldWidth: CGFloat) -> Bool {
        let success = super.makeSize(width, oldWidth: oldWidth)
        headerLayout.measure(width: blockWidth - 80 - (icon.0 != nil ? 38 : 0))
        descLayout.measure(width: blockWidth - 80 - (icon.0 != nil ? 38 : 0))
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
    private let reset:TitleButton = TitleButton()
    private let iconView: ImageView = ImageView()
    required init(frame frameRect: NSRect) {
        
        reset.set(font: .normal(.title), for: .Normal)
  
        super.init(frame: frameRect)
        self.addSubview(headerTextView)
        self.addSubview(descTextView)
        self.addSubview(dateTextView)
        self.addSubview(reset)
        addSubview(iconView)
                        
        reset.set(handler: { [weak self] _ in
            if let item = self?.item as? RecentSessionRowItem {
                confirm(for: mainWindow, information: tr(L10n.recentSessionsConfirmRevoke), successHandler: { _ in
                    item.revoke()
                })
            }
        }, for: .SingleClick)
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
 
        reset.set(text: tr(L10n.recentSessionsRevoke), for: .Normal)
        reset.set(color: theme.colors.accent, for: .Normal)
        reset.set(background: theme.colors.background, for: .Normal)
        _ = reset.sizeToFit()
        
        
        if let item = item as? RecentSessionRowItem {
            reset.isHidden = item.session.isCurrent
            self.iconView.image = item.icon.0
            self.iconView.sizeToFit()
        }
        
        self.needsLayout = true
    }
    
    override func layout() {
        super.layout()
        if let item = item as? RecentSessionRowItem {
            switch item.viewType {
            case .legacy:
                self.headerTextView.update(item.headerLayout, origin: NSMakePoint(30, 10))
                self.descTextView.update(item.descLayout, origin: NSMakePoint(30, headerTextView.frame.maxY + 4))
                self.dateTextView.update(item.dateLayout, origin: NSMakePoint(self.containerView.frame.width - 30 - item.dateLayout.layoutSize.width, 10))
                self.reset.setFrameOrigin(frame.width - 25 - reset.frame.width, self.containerView.frame.height - reset.frame.height - 10)
            case let .modern(_, insets):
                
                self.iconView.setFrameOrigin(NSMakePoint(insets.left, insets.top))
                
                let left: CGFloat = (item.icon.0 != nil ? 38 : 0)
                
                self.headerTextView.update(item.headerLayout, origin: NSMakePoint(left + insets.left, insets.top - 2))
                self.descTextView.update(item.descLayout, origin: NSMakePoint(left + insets.left, headerTextView.frame.maxY + 4))
                self.dateTextView.update(item.dateLayout, origin: NSMakePoint(self.containerView.frame.width - insets.right - item.dateLayout.layoutSize.width, insets.top))
                self.reset.setFrameOrigin(self.containerView.frame.width - insets.right + 5 - reset.frame.width, self.containerView.frame.height - reset.frame.height - 7)
            }
        }
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}
