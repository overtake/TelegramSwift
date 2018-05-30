//
//  RecentPeerRowItem.swift
//  Telegram
//
//  Created by keepcoder on 21/04/2017.
//  Copyright © 2017 Telegram. All rights reserved.
//

import Cocoa
import TGUIKit
import PostboxMac
import TelegramCoreMac

class RecentPeerRowItem: ShortPeerRowItem {

    let removeAction:()->Void
    let canRemoveFromRecent:Bool
    
    init(_ initialSize:NSSize, peer: Peer, account:Account, stableId:AnyHashable? = nil, enabled: Bool = true, height:CGFloat = 50, photoSize:NSSize = NSMakeSize(36, 36), titleStyle:ControlStyle = ControlStyle(font:.medium(.title), foregroundColor: theme.colors.text, highlightColor: .white), titleAddition:String? = nil, leftImage:CGImage? = nil, statusStyle:ControlStyle = ControlStyle(font:.normal(.text), foregroundColor: theme.colors.grayText, highlightColor:.white), status:String? = nil, borderType:BorderType = [], drawCustomSeparator:Bool = true, isLookSavedMessage: Bool = false, deleteInset:CGFloat? = nil, drawLastSeparator:Bool = false, inset:NSEdgeInsets = NSEdgeInsets(left:10.0), drawSeparatorIgnoringInset: Bool = false, interactionType:ShortPeerItemInteractionType = .plain, generalType:GeneralInteractedType = .none, action:@escaping ()->Void = {}, canRemoveFromRecent: Bool = false, removeAction:@escaping()->Void = {}, contextMenuItems:@escaping()->[ContextMenuItem] = {[]}) {
        self.canRemoveFromRecent = canRemoveFromRecent
        self.removeAction = removeAction
        super.init(initialSize, peer: peer, account: account, stableId: stableId, enabled: enabled, height: height, photoSize: photoSize, titleStyle: titleStyle, titleAddition: titleAddition, leftImage: leftImage, statusStyle: statusStyle, status: status, borderType: borderType, drawCustomSeparator: drawCustomSeparator, isLookSavedMessage: isLookSavedMessage, deleteInset: deleteInset, drawLastSeparator: drawLastSeparator, inset: inset, drawSeparatorIgnoringInset: drawSeparatorIgnoringInset, interactionType: interactionType, generalType: generalType, action: action, contextMenuItems: contextMenuItems)
    }
    
    
    override func viewClass() -> AnyClass {
        return RecentPeerRowView.self
    }
    
    override var textAdditionInset:CGFloat {
        return 15
    }
}

class RecentPeerRowView : ShortPeerRowView {
    private var trackingArea:NSTrackingArea?
    private let removeControl:ImageButton = ImageButton()
    required init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        //removeControl.autohighlight = false
    
        removeControl.isHidden = true
        
        removeControl.set(handler: { [weak self] _ in
            if let item = self?.item as? RecentPeerRowItem {
                item.removeAction()
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
        if mouseInside() {
            removeControl.isHidden = false
        } else {
            removeControl.isHidden = true
        }
    }
    
    override func set(item: TableRowItem, animated: Bool) {
        super.set(item: item, animated: animated)
        removeControl.set(image: isSelect ? theme.icons.recentDismissActive : theme.icons.recentDismiss, for: .Normal)
        removeControl.sizeToFit()
        if let item = item as? RecentPeerRowItem {
            if item.canRemoveFromRecent {
                addSubview(removeControl)
            } else {
                removeControl.removeFromSuperview()
            }
        }
        needsLayout = true
    }
    
    override func layout() {
        super.layout()
        removeControl.centerY(x: frame.width - removeControl.frame.width - 10)
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}
