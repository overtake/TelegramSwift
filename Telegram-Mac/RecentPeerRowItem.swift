//
//  RecentPeerRowItem.swift
//  Telegram
//
//  Created by keepcoder on 21/04/2017.
//  Copyright © 2017 Telegram. All rights reserved.
//

import Cocoa
import TGUIKit
import Postbox
import TelegramCore
import SyncCore
import SwiftSignalKit

class RecentPeerRowItem: ShortPeerRowItem {

    fileprivate let controlAction:()->Void
    fileprivate let canRemoveFromRecent:Bool
    fileprivate let badge: BadgeNode?
    fileprivate let canAddAsTag: Bool
    init(_ initialSize:NSSize, peer: Peer, account:Account, stableId:AnyHashable? = nil, enabled: Bool = true, height:CGFloat = 50, photoSize:NSSize = NSMakeSize(36, 36), titleStyle:ControlStyle = ControlStyle(font:.medium(.title), foregroundColor: theme.colors.text, highlightColor: .white), titleAddition:String? = nil, leftImage:CGImage? = nil, statusStyle:ControlStyle = ControlStyle(font:.normal(.text), foregroundColor: theme.colors.grayText, highlightColor:.white), status:String? = nil, borderType:BorderType = [], drawCustomSeparator:Bool = true, isLookSavedMessage: Bool = false, deleteInset:CGFloat? = nil, drawLastSeparator:Bool = false, inset:NSEdgeInsets = NSEdgeInsets(left:10.0), drawSeparatorIgnoringInset: Bool = false, interactionType:ShortPeerItemInteractionType = .plain, generalType:GeneralInteractedType = .none, action:@escaping ()->Void = {}, canRemoveFromRecent: Bool = false, controlAction:@escaping()->Void = {}, contextMenuItems:@escaping()->Signal<[ContextMenuItem], NoError> = { .single([]) }, unreadBadge: UnreadSearchBadge = .none, canAddAsTag: Bool = false) {
        self.canRemoveFromRecent = canRemoveFromRecent
        self.controlAction = controlAction
        self.canAddAsTag = canAddAsTag
        switch unreadBadge {
        case let .muted(count):
            badge = BadgeNode(.initialize(string: "\(count)", color: theme.chatList.badgeTextColor, font: .medium(.small)), theme.chatList.badgeMutedBackgroundColor)
        case let .unmuted(count):
            badge = BadgeNode(.initialize(string: "\(count)", color: theme.chatList.badgeTextColor, font: .medium(.small)), theme.chatList.badgeBackgroundColor)
        case .none:
            self.badge = nil
        }

        super.init(initialSize, peer: peer, account: account, stableId: stableId, enabled: enabled, height: height, photoSize: photoSize, titleStyle: titleStyle, titleAddition: titleAddition, leftImage: leftImage, statusStyle: statusStyle, status: status, borderType: borderType, drawCustomSeparator: drawCustomSeparator, isLookSavedMessage: isLookSavedMessage, deleteInset: deleteInset, drawLastSeparator: drawLastSeparator, inset: inset, drawSeparatorIgnoringInset: drawSeparatorIgnoringInset, interactionType: interactionType, generalType: generalType, action: action, contextMenuItems: contextMenuItems, highlightVerified: true)
    }
    
    
    override func viewClass() -> AnyClass {
        return RecentPeerRowView.self
    }
    
    override var textAdditionInset:CGFloat {
        return 20 + (highlightVerified ? 25 : 0)
    }
}

class RecentPeerRowView : ShortPeerRowView {
    private var trackingArea:NSTrackingArea?
    private let control:ImageButton = ImageButton()
    private var badgeView:View?

    required init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        //control.autohighlight = false
        layerContentsRedrawPolicy = .onSetNeedsDisplay
        control.isHidden = true
        
        control.set(handler: { [weak self] _ in
            if let item = self?.item as? RecentPeerRowItem {
                item.controlAction()
            }
        }, for: .Click)
    }
    
    open override func updateTrackingAreas() {
        super.updateTrackingAreas();
        
        
        if let trackingArea = trackingArea {
            self.removeTrackingArea(trackingArea)
        }
        
        trackingArea = nil
        
        if let _ = window {
            let options:NSTrackingArea.Options = [.cursorUpdate, .mouseEnteredAndExited, .mouseMoved, .activeAlways]
            self.trackingArea = NSTrackingArea.init(rect: self.bounds, options: options, owner: self, userInfo: nil)
            
            self.addTrackingArea(self.trackingArea!)
        }
    }
    
    override func viewDidMoveToSuperview() {
        super.viewDidMoveToSuperview()
        updateTrackingAreas()
    }
    
    deinit {
        if let trackingArea = self.trackingArea {
            self.removeTrackingArea(trackingArea)
        }
    }
    
    override func mouseMoved(with event: NSEvent) {
        super.mouseMoved(with: event)
        updateMouse()
    }
    
    override func mouseEntered(with event: NSEvent) {
        super.mouseEntered(with: event)
        updateMouse()
    }
    
    override func mouseExited(with event: NSEvent) {
        super.mouseExited(with: event)
        updateMouse()
    }
    
    override func updateMouse() {
        if mouseInside(), control.superview != nil {
            control.isHidden = false
            badgeView?.isHidden = true
        } else {
            control.isHidden = true
            badgeView?.isHidden = false
        }
    }
    
    override func set(item: TableRowItem, animated: Bool) {
        super.set(item: item, animated: animated)
        
        if let item = item as? RecentPeerRowItem {
            
            
            if item.canAddAsTag {
                control.set(image: isSelect ? theme.icons.search_filter_add_peer_active : theme.icons.search_filter_add_peer, for: .Normal)
            } else {
                control.set(image: isSelect ? theme.icons.recentDismissActive : theme.icons.recentDismiss, for: .Normal)
            }
            _ = control.sizeToFit()
            
            if item.canRemoveFromRecent || item.canAddAsTag {
                addSubview(control)
            } else {
                control.removeFromSuperview()
            }
            
            if let badgeNode = item.badge {
                if badgeView == nil {
                    badgeView = View()
                    addSubview(badgeView!)
                }
                badgeView?.setFrameSize(badgeNode.size)
                badgeNode.view = badgeView
                badgeNode.setNeedDisplay()
            } else {
                badgeView?.removeFromSuperview()
                badgeView = nil
            }
        }
        updateMouse()
        needsLayout = true
    }
    
    override var backdorColor: NSColor {
        if let item = item {
            return item.isHighlighted && !item.isSelected ? theme.colors.grayForeground : super.backdorColor
        } else {
            return super.backdorColor
        }
    }
    
    override func layout() {
        super.layout()
        
        
        control.centerY(x: frame.width - control.frame.width - 10)
        if let badgeView = badgeView {
            badgeView.centerY(x: frame.width - badgeView.frame.width - 10)
        }
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}
