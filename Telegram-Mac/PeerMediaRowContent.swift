//
//  PeerMediaRowItem.swift
//  Telegram-Mac
//
//  Created by keepcoder on 27/10/2016.
//  Copyright © 2016 Telegram. All rights reserved.
//

import Cocoa
import TGUIKit
import TelegramCoreMac
import PostboxMac
import SwiftSignalKitMac

class PeerMediaRowItem: TableRowItem {
    
    var iconSize:NSSize = NSZeroSize
    var contentInset:NSEdgeInsets = NSEdgeInsets(left: 60.0, right: 10, top: 5, bottom: 5)
    
    var contentSize:NSSize = NSMakeSize(0, 50)
    
    override var stableId: AnyHashable {
        return entry.stableId
    }
    
    override var height: CGFloat {
        return contentSize.height
    }
    
    private var entry:PeerMediaSharedEntry
    var message:Message
    var account:Account
    var interface:ChatInteraction
    
    init(_ initialSize:NSSize, _ interface:ChatInteraction, _ account:Account, _ object: PeerMediaSharedEntry) {
        
        self.entry = object
        self.account = account
        self.interface = interface
        
        if case let .messageEntry(message) = object {
            self.message = message
        } else {
            fatalError("entry haven't message")
        }
        
        super.init(initialSize)
    }
    
    override func menuItems(in location: NSPoint) -> Signal<[ContextMenuItem], Void> {
        var items:[ContextMenuItem] = []
        if canForwardMessage(message, account: account) {
            items.append(ContextMenuItem(tr(L10n.messageContextForward), handler: { [weak self] in
                if let strongSelf = self {
                    strongSelf.interface.forwardMessages([strongSelf.message.id])
                }
            }))
        }
        
        if canDeleteMessage(message, account: account) {
            items.append(ContextMenuItem(tr(L10n.messageContextDelete), handler: { [weak self] in
                if let strongSelf = self {
                    strongSelf.interface.deleteMessages([strongSelf.message.id])
                }
            }))
        }
        
        items.append(ContextMenuItem(tr(L10n.messageContextGoto), handler: { [weak self] in
            if let strongSelf = self {
                strongSelf.interface.focusMessageId(nil, strongSelf.message.id, .center(id: 0, innerId: nil, animated: false, focus: false, inset: 0))
            }
        }))
        

        return .single(items)
    }
    
    override func viewClass() -> AnyClass {
        return PeerMediaRowView.self
    }
}

private let selectedImage = #imageLiteral(resourceName: "Icon_SelectionChecked").precomposed()
private let unselectedImage = #imageLiteral(resourceName: "Icon_SelectionUncheck").precomposed()

class PeerMediaRowView : TableRowView,ViewDisplayDelegate,Notifable {
    
    var contentView:View = View()
    private var selectingControl:SelectingControl = SelectingControl(unselectedImage:unselectedImage, selectedImage:selectedImage)
    
    required init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        super.addSubview(selectingControl)
        super.addSubview(contentView)
        contentView.displayDelegate = self
        selectingControl.centerY(x:-selectingControl.frame.width)

    }
    
    func notify(with value: Any, oldValue:Any, animated:Bool) {
        if let item = item as? PeerMediaRowItem {
            if let value = value as? ChatPresentationInterfaceState, let oldValue = oldValue as? ChatPresentationInterfaceState {
                if (value.state == .selecting) != (oldValue.state == .selecting) || value.isSelectedMessageId(item.message.id) != oldValue.isSelectedMessageId(item.message.id) {
                    updateSelectingMode(with: value.state == .selecting, animated: !NSIsEmptyRect(visibleRect))
                }
            }
        }
        
    }
    
    func isEqual(to other: Notifable) -> Bool {
        if let other = other as? PeerMediaRowView {
            return other == self
        }
        return false
    }
    
    override func draw(_ layer: CALayer, in ctx: CGContext) {
        super.draw(layer, in: ctx)
        
        if layer == contentView.layer {
            
            if let item = self.item as? PeerMediaRowItem {
                ctx.setFillColor(theme.colors.border.cgColor)
                ctx.fill(NSMakeRect(item.contentInset.left, layer.frame.height - .borderSize, layer.frame.width - item.contentInset.left - item.contentInset.right, .borderSize))
            }
        }
    }
    
    override func setFrameSize(_ newSize: NSSize) {
        super.setFrameSize(newSize)
        contentView.setFrameSize(newSize)
    }
    

    override func set(item: TableRowItem, animated: Bool) {
        if let item = self.item as? PeerMediaRowItem {
            item.interface.remove(observer: self)
        }
        super.set(item: item, animated: animated)
       
        if let item = self.item as? PeerMediaRowItem {
            item.interface.add(observer: self)
            updateSelectingMode(with: item.interface.presentation.state == .selecting)
        }
    }
    
    override func viewDidMoveToSuperview() {
        super.viewDidMoveToSuperview()
        if let item = self.item as? PeerMediaRowItem {
            if superview == nil {
                item.interface.remove(observer: self)
            } else {
                item.interface.add(observer: self)
            }
        }
    }
    
    override func mouseDown(with event: NSEvent) {
        super.mouseDown(with: event)
        if let item = item as? PeerMediaRowItem {
            if item.interface.presentation.state == .selecting {
                item.interface.update({$0.withToggledSelectedMessage(item.message.id)})
            }
        }
    }
    
   
    
    func updateSelectingMode(with selectingMode:Bool, animated:Bool = false) {
        
        if let item = item as? PeerMediaRowItem {
            let to:NSPoint
            if selectingMode {
                to = NSMakePoint(35,0)
            } else {
                to = NSMakePoint(0,0)
            }
            
            contentView.change(pos: to, animated: animated)
            let selectingFrom = NSMakePoint(-selectingControl.frame.width,selectingControl.frame.minY)
            let selectingTo = NSMakePoint(20.0 - floorToScreenPixels(scaleFactor: backingScaleFactor, selectingControl.frame.width/2.0),selectingControl.frame.minY)
            selectingControl.change(pos: selectingMode ? selectingTo : selectingFrom, animated: animated)
            selectingControl.set(selected: item.interface.presentation.isSelectedMessageId(item.message.id), animated: animated)
        }
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override func addSubview(_ view: NSView) {
        contentView.addSubview(view)
    }
    
    deinit {
        contentView.removeAllSubviews()
    }
    
}
