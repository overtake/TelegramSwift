//
//  PeerMediaRowItem.swift
//  Telegram-Mac
//
//  Created by keepcoder on 27/10/2016.
//  Copyright © 2016 Telegram. All rights reserved.
//

import Cocoa
import TGUIKit
import TelegramCore
import SyncCore
import Postbox
import SwiftSignalKit

let PeerMediaIconSize:NSSize = NSMakeSize(40, 40)

class PeerMediaRowItem: GeneralRowItem {
    
    
    var contentInset:NSEdgeInsets = NSEdgeInsets(left: 50.0, right: 0, top: 0, bottom: 0)
    
    var contentSize:NSSize = NSMakeSize(0, 40)
    
    override var height: CGFloat {
        return contentSize.height + viewType.innerInset.top + viewType.innerInset.bottom + inset.top + inset.bottom
    }
    
    private var entry:PeerMediaSharedEntry
    let message:Message
    let interface:ChatInteraction
    let automaticDownload: AutomaticMediaDownloadSettings
    
    init(_ initialSize:NSSize, _ interface:ChatInteraction, _ object: PeerMediaSharedEntry, viewType: GeneralViewType = .legacy) {
        self.entry = object
        self.interface = interface
        if case let .messageEntry(message, automaticDownload, _) = object {
            self.message = message
            self.automaticDownload = automaticDownload
        } else {
            fatalError("entry haven't message")
        }
        
        super.init(initialSize, stableId: object.stableId, viewType: viewType, inset: NSEdgeInsetsZero)
    }
    
    override func menuItems(in location: NSPoint) -> Signal<[ContextMenuItem], NoError> {

        var items:[ContextMenuItem] = []
        if canForwardMessage(message, account: interface.context.account) {
            items.append(ContextMenuItem(L10n.messageContextForward, handler: { [weak self] in
                if let strongSelf = self {
                    strongSelf.interface.forwardMessages([strongSelf.message.id])
                }
            }))
        }
        
        if canDeleteMessage(message, account: interface.context.account) {
            items.append(ContextMenuItem(L10n.messageContextDelete, handler: { [weak self] in
                if let strongSelf = self {
                    strongSelf.interface.deleteMessages([strongSelf.message.id])
                }
            }))
        }
        
        items.append(ContextMenuItem(L10n.messageContextGoto, handler: { [weak self] in
            if let strongSelf = self {
                strongSelf.interface.focusMessageId(nil, strongSelf.message.id, .center(id: 0, innerId: nil, animated: false, focus: .init(focus: false), inset: 0))
            }
        }))
        

        return .single(items)
    }
    
    override var instantlyResize: Bool {
        return true
    }
    
    override func viewClass() -> AnyClass {
        return PeerMediaRowView.self
    }
    
    var separatorOffset: CGFloat {
        return 10 + 40 + viewType.innerInset.left
    }
}

class PeerMediaRowView : TableRowView,ViewDisplayDelegate,Notifable {
    let containerView: GeneralRowContainerView = GeneralRowContainerView(frame: NSZeroRect)
    var contentView:View = View()
    private let separatorView = View()
    private var selectingControl:SelectingControl?
    
    required init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        containerView.addSubview(contentView)
        containerView.addSubview(separatorView)
        super.addSubview(containerView)
        contentView.displayDelegate = self
        
        containerView.set(handler: { [weak self] _ in
            if let item = self?.item as? PeerMediaRowItem {
               if item.interface.presentation.state == .selecting {
                   item.interface.update({$0.withToggledSelectedMessage(item.message.id)})
               }
           }
        }, for: .Click)

    }
    
    override func updateColors() {
        guard let item = item as? PeerMediaRowItem else {
            return
        }
        self.backgroundColor = item.viewType.rowBackground
        self.containerView.backgroundColor = backdorColor
        self.separatorView.backgroundColor = theme.colors.border
    }
    
    override func layout() {
        guard let item = item as? PeerMediaRowItem else {
            return
        }
        
        let contentX = item.interface.presentation.state == .selecting ? item.viewType.innerInset.left + 22 + item.viewType.innerInset.left : item.viewType.innerInset.left
        
        self.containerView.frame = NSMakeRect(floorToScreenPixels(backingScaleFactor, (frame.width - item.blockWidth) / 2), item.inset.top, item.blockWidth, frame.height - item.inset.bottom - item.inset.top)
        self.containerView.setCorners(item.viewType.corners)
        
        self.contentView.setFrameSize(NSMakeSize(self.containerView.frame.width - item.viewType.innerInset.left - item.viewType.innerInset.right, self.containerView.frame.height - item.viewType.innerInset.bottom - item.viewType.innerInset.top))
        self.contentView.centerY(x: contentX)
        
        self.separatorView.frame = NSMakeRect(item.separatorOffset + (item.interface.presentation.state == .selecting ? 22 + item.viewType.innerInset.left : 0), self.containerView.frame.height - .borderSize, self.containerView.frame.width - item.separatorOffset - item.viewType.innerInset.right, .borderSize)
        
        selectingControl?.centerY(x: item.interface.presentation.state == .selecting ? item.viewType.innerInset.left : -22)

        super.layout()
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
        
    }

    

    override func set(item: TableRowItem, animated: Bool) {
        if let item = self.item as? PeerMediaRowItem {
            item.interface.remove(observer: self)
        }
        super.set(item: item, animated: animated)
       
        if let item = self.item as? PeerMediaRowItem {
            item.interface.add(observer: self)
            updateSelectingMode(with: item.interface.presentation.state == .selecting, animated: animated)
            
            separatorView.isHidden = !item.viewType.hasBorder
        }
        needsLayout = true
    }
    
    override func viewDidMoveToSuperview() {
        super.viewDidMoveToSuperview()
        if let item = self.item as? PeerMediaRowItem {
            if superview == nil {
                item.interface.remove(observer: self)
            } else {
                item.interface.add(observer: self)
                updateSelectingMode(with: item.interface.presentation.state == .selecting, animated: !NSIsEmptyRect(visibleRect))
            }
        }
    }
    
    func updateSelectingMode(with selectingMode:Bool, animated:Bool = false) {
        
        if let item = item as? PeerMediaRowItem {
            
            containerView.userInteractionEnabled = selectingMode

            let to:NSPoint
            if selectingMode {
                to = NSMakePoint(item.viewType.innerInset.left + 22 + item.viewType.innerInset.left, self.contentView.frame.minY)
            } else {
                to = NSMakePoint(item.viewType.innerInset.left, self.contentView.frame.minY)
            }
            
            self.separatorView.change(pos: NSMakePoint(item.separatorOffset + (selectingMode ? 22 + item.viewType.innerInset.left : 0), self.containerView.frame.height - .borderSize), animated: animated)
            contentView.change(pos: to, animated: animated)

            if selectingMode {
                if selectingControl == nil {
                    selectingControl = SelectingControl(unselectedImage: theme.icons.chatToggleUnselected, selectedImage: theme.icons.chatToggleSelected)
                    containerView.addSubview(selectingControl!)
                    selectingControl!.centerY(x: -22)
                    selectingControl?.change(pos: NSMakePoint(item.viewType.innerInset.left, selectingControl!.frame.minY), animated: animated)
                }
            } else {
                if let selectingControl = selectingControl {
                    let point = NSMakePoint(-22, selectingControl.frame.minY)
                    self.selectingControl = nil
                    selectingControl.change(pos: point, animated: animated, completion: { [weak selectingControl] _ in
                         selectingControl?.removeFromSuperview()
                    })
                }
            }
            selectingControl?.set(selected: item.interface.presentation.isSelectedMessageId(item.message.id), animated: animated)

            
//            selectingControl.change(pos: selectingMode ? selectingTo : selectingFrom, animated: animated)
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
