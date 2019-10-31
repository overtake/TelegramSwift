//
//  RecentSessionRowItem.swift
//  Telegram
//
//  Created by keepcoder on 08/03/2017.
//  Copyright © 2017 Telegram. All rights reserved.
//

import Cocoa
import TGUIKit
import TelegramCoreMac
class RecentSessionRowItem: GeneralRowItem {
    
    let session:RecentAccountSession
    
    let headerLayout:TextViewLayout
    let descLayout:TextViewLayout
    let dateLayout:TextViewLayout
    let revoke:()->Void

    
    init(_ initialSize: NSSize, session:RecentAccountSession, stableId:AnyHashable, viewType: GeneralViewType, revoke: @escaping()->Void) {
        self.session = session
        self.revoke = revoke
        headerLayout = TextViewLayout(.initialize(string: session.appName + " " + session.appVersion, color: theme.colors.text, font: .normal(.title)))
        
        let attr = NSMutableAttributedString()
        
        _ = attr.append(string: session.deviceModel + ", " + session.platform + " " + session.systemVersion, color: theme.colors.text, font: .normal(.text))
        
        _ = attr.append(string: "\n")
        
        _ = attr.append(string: session.ip + " " + session.country, color: theme.colors.grayText, font: .normal(.text))
        
        descLayout = TextViewLayout(attr, lineSpacing: 2)
    
        dateLayout = TextViewLayout(.initialize(string: session.isCurrent ? tr(L10n.peerStatusOnline) : DateUtils.string(forMessageListDate: session.activityDate), color: session.isCurrent ? theme.colors.accent : theme.colors.grayText, font: .normal(.text)))
        
        super.init(initialSize, stableId: stableId, viewType: viewType)
        
        _ = makeSize(initialSize.width, oldWidth: initialSize.width)
    }
    
    override func makeSize(_ width: CGFloat, oldWidth: CGFloat) -> Bool {
        let success = super.makeSize(width, oldWidth: oldWidth)
        headerLayout.measure(width: width - 60)
        descLayout.measure(width: width - 60)
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

class RecentSessionRowView : TableRowView, ViewDisplayDelegate {
    private let containerView = GeneralRowContainerView(frame: NSZeroRect)
    let headerTextView = TextView()
    let descTextView = TextView()
    let dateTextView = TextView()
    let reset:TitleButton = TitleButton()
    required init(frame frameRect: NSRect) {
        
        reset.set(font: .normal(.title), for: .Normal)
  
        super.init(frame: frameRect)
        containerView.addSubview(headerTextView)
        containerView.addSubview(descTextView)
        containerView.addSubview(dateTextView)
        containerView.addSubview(reset)
        
        addSubview(containerView)
        
        containerView.displayDelegate = self
        
        reset.set(handler: { [weak self] _ in
            if let item = self?.item as? RecentSessionRowItem {
                confirm(for: mainWindow, information: tr(L10n.recentSessionsConfirmRevoke), successHandler: { _ in
                    item.revoke()
                })
            }
        }, for: .SingleClick)
    }
    
    override func updateColors() {
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
    
    override func draw(_ layer: CALayer, in ctx: CGContext) {
        super.draw(layer, in: ctx)
        
        if let item = item as? RecentSessionRowItem, layer == containerView.layer {
            ctx.setFillColor(theme.colors.border.cgColor)
            switch item.viewType {
            case .legacy:
                ctx.fill(NSMakeRect(30, containerView.frame.height - .borderSize, frame.width - 60, .borderSize))
            case let .modern(position, insets):
                if position.border {
                    ctx.fill(NSMakeRect(insets.left, containerView.frame.height - .borderSize, containerView.frame.width - insets.left - insets.right, .borderSize))
                }
            }
        }
        
    }
    
    override func set(item: TableRowItem, animated: Bool) {
        super.set(item: item)
 
        reset.set(text: tr(L10n.recentSessionsRevoke), for: .Normal)
        reset.set(color: theme.colors.accent, for: .Normal)
        reset.set(background: theme.colors.background, for: .Normal)
        _ = reset.sizeToFit()
        
        if let item = item as? RecentSessionRowItem {
            reset.isHidden = item.session.isCurrent
            containerView.setCorners(item.viewType.corners, animated: animated)
        }
        
        self.needsLayout = true
    }
    
    override func layout() {
        super.layout()
        if let item = item as? RecentSessionRowItem {
            switch item.viewType {
            case .legacy:
                self.containerView.frame = self.bounds
                self.containerView.setCorners([])
                self.headerTextView.update(item.headerLayout, origin: NSMakePoint(30, 10))
                self.descTextView.update(item.descLayout, origin: NSMakePoint(30, headerTextView.frame.maxY + 4))
                self.dateTextView.update(item.dateLayout, origin: NSMakePoint(self.containerView.frame.width - 30 - item.dateLayout.layoutSize.width, 10))
                self.reset.setFrameOrigin(frame.width - 25 - reset.frame.width, self.containerView.frame.height - reset.frame.height - 10)
            case let .modern(position, insets):
                self.containerView.frame = NSMakeRect(floorToScreenPixels(backingScaleFactor, (frame.width - item.blockWidth) / 2), item.inset.top, item.blockWidth, frame.height - item.inset.bottom - item.inset.top)
                self.containerView.setCorners(position.corners)
                self.headerTextView.update(item.headerLayout, origin: NSMakePoint(insets.left, insets.top))
                self.descTextView.update(item.descLayout, origin: NSMakePoint(insets.left, headerTextView.frame.maxY + 4))
                self.dateTextView.update(item.dateLayout, origin: NSMakePoint(self.containerView.frame.width - insets.right - item.dateLayout.layoutSize.width, insets.top))
                self.reset.setFrameOrigin(self.containerView.frame.width - insets.right + 5 - reset.frame.width, self.containerView.frame.height - reset.frame.height - 7)
            }
        }
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}
