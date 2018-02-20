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
class RecentSessionRowItem: TableRowItem {
    
    let session:RecentAccountSession
    let _stableId:AnyHashable
    
    let headerLayout:TextViewLayout
    let descLayout:TextViewLayout
    let dateLayout:TextViewLayout
    let revoke:()->Void
    override var stableId: AnyHashable {
        return _stableId
    }
    
    init(_ initialSize: NSSize, session:RecentAccountSession, stableId:AnyHashable, revoke: @escaping()->Void) {
        self._stableId = stableId
        self.session = session
        self.revoke = revoke
        headerLayout = TextViewLayout(.initialize(string: session.appName + " " + session.appVersion, color: theme.colors.text, font: .normal(.title)))
        
        let attr = NSMutableAttributedString()
        
        _ = attr.append(string: session.deviceModel + ", " + session.platform + " " + session.systemVersion, color: theme.colors.text, font: .normal(.text))
        
        _ = attr.append(string: "\n")
        
        _ = attr.append(string: session.ip + " " + session.country, color: theme.colors.grayText, font: .normal(.text))
        
        descLayout = TextViewLayout(attr, lineSpacing: 2)
    
        dateLayout = TextViewLayout(.initialize(string: session.isCurrent ? tr(L10n.peerStatusOnline) : DateUtils.string(forMessageListDate: session.creationDate), color: session.isCurrent ? theme.colors.blueText : theme.colors.grayText, font: .normal(.text)))
        
        super.init(initialSize)
        
        _ = makeSize(initialSize.width, oldWidth: initialSize.width)
    }
    
    override func makeSize(_ width: CGFloat, oldWidth: CGFloat) -> Bool {
        headerLayout.measure(width: width - 60)
        descLayout.measure(width: width - 60)
        dateLayout.measure(width: .greatestFiniteMagnitude)
        return super.makeSize(width, oldWidth: oldWidth)
    }
    
    override var height: CGFloat {
        return 70
    }
    
    override func viewClass() -> AnyClass {
        return RecentSessionRowView.self
    }
}

class RecentSessionRowView : TableRowView {
    let headerTextView = TextView()
    let descTextView = TextView()
    let dateTextView = TextView()
    let reset:TitleButton = TitleButton()
    required init(frame frameRect: NSRect) {
        
        reset.set(font: .normal(.title), for: .Normal)
  
        super.init(frame: frameRect)
        addSubview(headerTextView)
        addSubview(descTextView)
        addSubview(dateTextView)
        addSubview(reset)
        
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
    }
    
    override func draw(_ layer: CALayer, in ctx: CGContext) {
        super.draw(layer, in: ctx)
        
        ctx.setFillColor(theme.colors.border.cgColor)
        ctx.fill(NSMakeRect(30, frame.height - .borderSize, frame.width - 60, .borderSize))
        
    }
    
    override func set(item: TableRowItem, animated: Bool) {
        super.set(item: item)
        
        reset.set(text: tr(L10n.recentSessionsRevoke), for: .Normal)
        reset.set(color: theme.colors.blueUI, for: .Normal)
        reset.set(background: theme.colors.background, for: .Normal)
        _ = reset.sizeToFit()
        
        if let item = item as? RecentSessionRowItem {
            reset.isHidden = item.session.isCurrent
        }
        
        self.needsLayout = true
    }
    
    override func layout() {
        super.layout()
        if let item = item as? RecentSessionRowItem {
            headerTextView.update(item.headerLayout, origin: NSMakePoint(30, 10))
            descTextView.update(item.descLayout, origin: NSMakePoint(30, headerTextView.frame.maxY + 4))
            dateTextView.update(item.dateLayout, origin: NSMakePoint(frame.width - 30 - item.dateLayout.layoutSize.width, 10))
            reset.setFrameOrigin(frame.width - 25 - reset.frame.width, frame.height - reset.frame.height - 10)
        }
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}
