//
//  ShortPeerRowView.swift
//  Telegram-Mac
//
//  Created by keepcoder on 29/09/2016.
//  Copyright © 2016 Telegram. All rights reserved.
//

import Cocoa
import TGUIKit
import TelegramCore
import SyncCore
import Postbox


//FB2126

class ShortPeerRowView: TableRowView, Notifable, ViewDisplayDelegate {
    private let containerView: GeneralRowContainerView = GeneralRowContainerView(frame: NSZeroRect)
    private var image:AvatarControl = AvatarControl(font: .avatar(.text))
    private var deleteControl:ImageButton?
    private var selectControl:SelectingControl?
    private let container:Control = Control()
    private var switchView:SwitchView?
    private var contextLabel:TextViewLabel?
    private var choiceControl:ImageView?
     #if !SHARE
    private var activities: ChatActivitiesModel?
    #endif
    private let rightSeparatorView:View = View()
    private let separator:View = View()

    private var hiddenStatus: Bool = true
    private var badgeNode: View? = nil
    
    required init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        container.frame = bounds
        container.addSubview(image)
        container.displayDelegate = self
        containerView.addSubview(container)
        image.userInteractionEnabled = false
        containerView.addSubview(rightSeparatorView)
        containerView.addSubview(separator)
        
        container.set(handler: { [weak self] _ in
            self?.updateMouse()
        }, for: .Hover)
        
        container.set(handler: { [weak self] _ in
            self?.updateMouse()
        }, for: .Normal)
        
        container.userInteractionEnabled = false

        addSubview(self.containerView)
        
        containerView.set(handler: { [weak self] _ in
            self?.invokeIfNeededDown()
        }, for: .Down)
        
        containerView.set(handler: { [weak self] _ in
            self?.invokeIfNeededUp()
        }, for: .Up)
        
        containerView.set(handler: { [weak self] _ in
            self?.updateColors()
        }, for: .Normal)
        containerView.set(handler: { [weak self] _ in
            self?.updateColors()
        }, for: .Highlight)
    }
    
    private func invokeIfNeededUp() {
        if let event = NSApp.currentEvent {
            super.mouseUp(with: event)
            if let item = item as? ShortPeerRowItem, let table = item.table, table.alwaysOpenRowsOnMouseUp, mouseInside() {
                if item.enabled {
                    invokeAction(item, clickCount: event.clickCount)
                }
            }
        }
        
    }
    private func invokeIfNeededDown() {
        if let event = NSApp.currentEvent {
            super.mouseDown(with: event)
            if let item = item as? ShortPeerRowItem, let table = item.table, !table.alwaysOpenRowsOnMouseUp, let event = NSApp.currentEvent, mouseInside() {
                if item.enabled {
                    invokeAction(item, clickCount: event.clickCount)
                }
            }
        }
    }
    
    override var border: BorderType? {
        didSet {
            container.border = border
        }
    }
    


    private var isRowSelected: Bool {
        if let item = item as? ShortPeerRowItem {
            if item.highlightOnHover {
                return self.mouseInside() || item.isSelected
            } else if item.alwaysHighlight {
                return false
            }
        }
        return item?.isSelected ?? false
    }
    
    
    override var backdorColor: NSColor {
        if let item = item as? ShortPeerRowItem, item.alwaysHighlight {
            return item.isSelected ? theme.colors.grayForeground : theme.colors.background
        }
        return isRowSelected ? theme.colors.accentSelect : item?.isHighlighted ?? false ? theme.colors.grayForeground : theme.colors.background
    }
    
    
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override func draw(_ layer: CALayer, in ctx: CGContext) {
        
        if let item = item as? ShortPeerRowItem {
            if layer == container.layer {
                switch item.viewType {
                case .legacy:
                    if backingScaleFactor == 1.0 {
                        ctx.setFillColor(backdorColor.cgColor)
                        ctx.fill(NSMakeRect(0, 0, layer.bounds.width - .borderSize, layer.bounds.height))
                    }
                    if let leftImage = item.leftImage {
                        let focus = container.focus(leftImage.backingSize)
                        ctx.draw(leftImage, in: NSMakeRect(item.inset.left, focus.minY, focus.width, focus.height))
                    }
                    if let title = (isRowSelected ? item.titleSelected : item.title) {
                        var tY = NSMinY(focus(title.0.size))
                        
                        if let status = (isRowSelected ? item.statusSelected : item.status) {
                            let t = title.0.size.height + status.0.size.height + 1.0
                            tY = floorToScreenPixels(backingScaleFactor, (self.frame.height - t) / 2.0)
                            
                            let sY = tY + title.0.size.height + 1.0
                            if hiddenStatus {
                                status.1.draw(NSMakeRect(item.textInset, sY, status.0.size.width, status.0.size.height), in: ctx, backingScaleFactor: backingScaleFactor, backgroundColor: backgroundColor)
                            }
                        }
                        
                        title.1.draw(NSMakeRect(item.textInset, tY, title.0.size.width, title.0.size.height), in: ctx, backingScaleFactor: backingScaleFactor, backgroundColor: backgroundColor)
                        
                        if item.peer.isVerified && item.highlightVerified {
                            ctx.draw(isRowSelected ? theme.icons.verifyDialogActive : theme.icons.verifyDialog, in: NSMakeRect(item.textInset + title.0.size.width - 1, tY - 3, 24, 24))
                        }
                        if item.peer.isScam && item.highlightVerified {
                            ctx.draw(isRowSelected ? theme.icons.scamActive : theme.icons.scam, in: NSMakeRect(item.textInset + title.0.size.width + 5, tY + 1, theme.icons.scam.backingSize.width, theme.icons.scam.backingSize.height))
                        }
                    }
                case .modern:
                    if backingScaleFactor == 1.0 {
                        ctx.setFillColor(backdorColor.cgColor)
                        ctx.fill(NSMakeRect(0, 0, layer.bounds.width - .borderSize, layer.bounds.height))
                    }
                    if let leftImage = item.leftImage {
                        let focus = container.focus(leftImage.backingSize)
                        ctx.draw(leftImage, in: NSMakeRect(0, focus.minY, focus.width, focus.height))
                    }
                    if let title = (isRowSelected ? item.titleSelected : item.title) {
                        var tY = NSMinY(focus(title.0.size))
                        
                        if let status = (isRowSelected ? item.statusSelected : item.status) {
                            let t = title.0.size.height + status.0.size.height + 1.0
                            tY = (NSHeight(self.frame) - t) / 2.0
                            
                            let sY = tY + title.0.size.height + 1.0
                            if hiddenStatus {
                                status.1.draw(NSMakeRect(item.textInset, sY, status.0.size.width, status.0.size.height), in: ctx, backingScaleFactor: backingScaleFactor, backgroundColor: backgroundColor)
                            }
                        }
                        
                        title.1.draw(NSMakeRect(item.textInset, tY, title.0.size.width, title.0.size.height), in: ctx, backingScaleFactor: backingScaleFactor, backgroundColor: backgroundColor)
                        
                        if item.peer.isVerified && item.highlightVerified {
                            ctx.draw(isRowSelected ? theme.icons.verifyDialogActive : theme.icons.verifyDialog, in: NSMakeRect(item.textInset + title.0.size.width - 1, tY - 3, 24, 24))
                        }
                        if item.peer.isScam && item.highlightVerified {
                            ctx.draw(isRowSelected ? theme.icons.scamActive : theme.icons.scam, in: NSMakeRect(item.textInset + title.0.size.width + 5, tY + 1, theme.icons.scam.backingSize.width, theme.icons.scam.backingSize.height))
                        }
                    }
                }
            }
        }
        
    }
    
    override func updateColors() {
        
        let highlighted = backdorColor

        
        self.containerView.background = backdorColor
        self.separator.backgroundColor = theme.colors.border
        self.contextLabel?.background = backdorColor
        containerView.set(background: backdorColor, for: .Normal)
        containerView.set(background: highlighted, for: .Highlight)

        guard let item = item as? ShortPeerRowItem else {
            return
        }
        self.background = item.viewType.rowBackground
        needsDisplay = true
    }
    
    override func updateMouse() {
        super.updateMouse()
        updateColors()
        container.needsDisplay = true
        guard let item = item as? ShortPeerRowItem else {
           return
        }
        item.badgeNode?.isSelected = isRowSelected
    }
    
    override func layout() {
        super.layout()
        if let item = item as? ShortPeerRowItem {
            switch item.viewType {
            case .legacy:
                self.containerView.frame = bounds
                self.containerView.setCorners([])
                if let border = border, border.contains(.Right) {
                    rightSeparatorView.isHidden = false
                    rightSeparatorView.frame = NSMakeRect(frame.width - .borderSize, 0, .borderSize, frame.height)
                } else {
                    rightSeparatorView.isHidden = true
                }
                switch item.interactionType {
                case .plain:
                    container.frame = bounds
                case .selectable:
                    container.frame = .init(x: 0, y: 0, width: frame.width, height: frame.height)
                default :
                    container.frame = .init(x: 30, y: 0, width: frame.width - 30, height: frame.height)
                }
                
                if let deleteControl = deleteControl {
                    deleteControl.centerY(x: item.deleteInset)
                }
                if let selectControl = selectControl {
                    selectControl.centerY(x: frame.width - selectControl.frame.width - item.inset.right)
                }
                image.frame = NSMakeRect(item.inset.left + (item.leftImage != nil ? item.leftImage!.backingSize.width + 5 : 0), NSMinY(focus(item.photoSize)), item.photoSize.width, item.photoSize.height)
                if let switchView = switchView {
                    switchView.centerY(x:container.frame.width - switchView.frame.width - item.inset.right)
                }
                if let contextLabel = contextLabel {
                    contextLabel.centerY(x:frame.width - contextLabel.frame.width - item.inset.right)
                }
                container.needsDisplay = true
                
                if let choiceControl = choiceControl {
                    choiceControl.centerY(x: frame.width - choiceControl.frame.width - item.inset.right)
                }
                
                if let badgeNode = badgeNode, let itemNode = item.badgeNode {
                    badgeNode.setFrameSize(itemNode.size)
                    badgeNode.centerY(x: containerView.frame.width - badgeNode.frame.width - item.inset.left)
                }
                
                separator.frame = NSMakeRect(item.textInset, containerView.frame.height - .borderSize, containerView.frame.width - (item.drawSeparatorIgnoringInset ? 0 : item.inset.right) - item.textInset, .borderSize)
                
                #if !SHARE
                if let view = activities?.view {
                    view.setFrameOrigin(item.textInset - 2, floorToScreenPixels(backingScaleFactor, frame.height / 2 + 1))
                }
                #endif
            case let .modern(position, innerInsets):
                self.containerView.frame = NSMakeRect(floorToScreenPixels(backingScaleFactor, (frame.width - item.blockWidth) / 2), item.inset.top, item.blockWidth, frame.height - item.inset.bottom - item.inset.top)
                self.containerView.setCorners(position.corners)
                self.rightSeparatorView.isHidden = true
                
                switch item.interactionType {
                case .plain:
                    container.frame = .init(x: innerInsets.left, y: 0, width: containerView.frame.width - innerInsets.left - innerInsets.right, height: containerView.frame.height)
                case .selectable:
                    container.frame = .init(x: innerInsets.left, y: 0, width: containerView.frame.width - innerInsets.left - innerInsets.right, height: containerView.frame.height)
                case .deletable:
                    let offset = innerInsets.left + 24 + innerInsets.left
                    container.frame = .init(x: offset, y: 0, width: containerView.frame.width - offset - innerInsets.right, height: containerView.frame.height)
                }
                
                if let deleteControl = deleteControl {
                    deleteControl.centerY(x: item.deleteInset)
                }
                if let selectControl = selectControl {
                    selectControl.centerY(x: containerView.frame.width - selectControl.frame.width - innerInsets.right)
                }
                image.frame = NSMakeRect((item.leftImage != nil ? item.leftImage!.backingSize.width + 5 : 0), NSMinY(focus(item.photoSize)), item.photoSize.width, item.photoSize.height)
                if let switchView = switchView {
                    switchView.centerY(x: containerView.frame.width - switchView.frame.width - innerInsets.right)
                }
                if let contextLabel = contextLabel {
                    contextLabel.centerY(x: containerView.frame.width - contextLabel.frame.width - innerInsets.right)
                }
                
                if let choiceControl = choiceControl {
                    choiceControl.centerY(x: containerView.frame.width - choiceControl.frame.width - innerInsets.right)
                }
                if let badgeNode = badgeNode, let itemNode = item.badgeNode {
                    badgeNode.setFrameSize(itemNode.size)
                    badgeNode.centerY(x: containerView.frame.width - badgeNode.frame.width - innerInsets.right)
                }
                
                separator.frame = NSMakeRect(container.frame.minX + item.textInset, containerView.frame.height - .borderSize, container.frame.width - item.textInset, .borderSize)
                
                #if !SHARE
                if let view = activities?.view {
                    view.setFrameOrigin(item.textInset - 2, floorToScreenPixels(backingScaleFactor, frame.height / 2 + 1))
                }
                #endif
                
                container.needsDisplay = true
                
            }
            
        }
    }
    
    func updateInteractionType(_ previousType:ShortPeerItemInteractionType, _ interactionType:ShortPeerItemInteractionType, item:ShortPeerRowItem, animated:Bool) {
        
        let interactive:Bool
        switch interactionType {
        case .plain, .selectable:
            interactive = false
        default:
            interactive = true
        }
        
        let containerRect: NSRect
        let separatorRect: NSRect
        switch item.viewType {
        case .legacy:
            containerRect = CGRect(origin: NSMakePoint((interactive ? 30 : 0), 0), size: NSMakeSize(containerView.frame.width - (interactive ? 30 : 0), containerView.frame.height))
            separatorRect = NSMakeRect(item.textInset, containerRect.height - .borderSize, containerRect.width - (item.drawSeparatorIgnoringInset ? 0 : item.inset.right) - item.textInset, .borderSize)
        case let .modern(_, innerInsets):
            switch item.interactionType {
            case .plain:
                containerRect = .init(x: innerInsets.left, y: 0, width: containerView.frame.width - innerInsets.left - innerInsets.right, height: containerView.frame.height)
            case .selectable:
                containerRect = .init(x: innerInsets.left, y: 0, width: containerView.frame.width - innerInsets.left - innerInsets.right, height: containerView.frame.height)
            case .deletable:
                let offset = innerInsets.left + 24 + innerInsets.left
                containerRect = .init(x: offset, y: 0, width: containerView.frame.width - offset - innerInsets.right, height: containerView.frame.height)
            }
            separatorRect = NSMakeRect(containerRect.minX + item.textInset, containerRect.height - .borderSize, containerRect.width - item.textInset, .borderSize)
            
            if let contextLabel = contextLabel {
                var rect = containerView.focus(contextLabel.frame.size)
                rect.origin.x = containerView.frame.width - contextLabel.frame.width - innerInsets.right
                contextLabel.change(pos: rect.origin, animated: animated)
            }
            if let switchView = switchView {
                var rect = containerView.focus(switchView.frame.size)
                rect.origin.x = containerView.frame.width - switchView.frame.width - innerInsets.right
                switchView.change(pos: rect.origin, animated: animated)
            }
            if let choiceControl = choiceControl {
                var rect = containerView.focus(choiceControl.frame.size)
                rect.origin.x = containerView.frame.width - choiceControl.frame.width - innerInsets.right
                choiceControl.change(pos: rect.origin, animated: animated)
            }
        }
        
       
        
        self.separator.change(size: separatorRect.size, animated: animated)
        self.separator.change(pos: separatorRect.origin, animated: animated)

        
        self.container.change(size: containerRect.size, animated: false)
        self.container.change(pos: containerRect.origin, animated: animated)

        
       
        
        switch interactionType {
        case .plain:
            
            if let remove = deleteControl {
                remove.change(pos: NSMakePoint(-remove.frame.width, remove.frame.minY), animated: animated, removeOnCompletion: false, completion: { [weak self] (completed) in
                    if completed {
                        self?.deleteControl?.removeFromSuperview()
                        self?.deleteControl = nil
                    }
                })
                remove.change(opacity: 0, animated: animated)
            }
            
            if let select = selectControl {
                select.change(pos: NSMakePoint(-select.frame.width, select.frame.minY), animated: animated, removeOnCompletion: false, completion: { [weak self] (completed) in
                    if completed {
                        self?.selectControl?.removeFromSuperview()
                        self?.selectControl = nil
                    }
                })
                select.change(opacity: 0, animated: animated)
            }
            
        case let .selectable(interaction):
           
            if selectControl == nil {
                selectControl = SelectingControl(unselectedImage: theme.icons.chatToggleUnselected, selectedImage: theme.icons.chatToggleSelected)
            }
            selectControl?.set(selected: interaction.presentation.selected.contains(item.peerId), animated: animated)
            
            containerView.addSubview(selectControl!)
            
            deleteControl?.removeFromSuperview()
            deleteControl = nil
        case let .deletable(interaction):
            selectControl?.removeFromSuperview()
            selectControl = nil

            if deleteControl == nil {
                deleteControl = ImageButton()
                deleteControl?.autohighlight = false
                deleteControl?.set(image: theme.icons.deleteItem, for: .Normal)
                _ = deleteControl?.sizeToFit()
                
                containerView.addSubview(deleteControl!)
                deleteControl?.layer?.opacity = 0
                deleteControl?.centerY(x: -theme.icons.deleteItem.backingSize.width)
            }
            
            
            if item.enabled {
                deleteControl?.set(image: theme.icons.deleteItem, for: .Normal)
            } else {
                deleteControl?.set(image: theme.icons.deleteItemDisabled, for: .Normal)
                deleteControl?.set(image: theme.icons.deleteItemDisabled, for: .Highlight)
            }

            deleteControl?.change(opacity: 1, animated: animated)
            deleteControl?.change(pos: NSMakePoint(item.deleteInset, deleteControl!.frame.minY), animated: animated)
            deleteControl?.removeAllHandlers()
            deleteControl?.set(handler: { [weak item] _ in
                if let item = item, item.enabled {
                    interaction.onRemove(item.peerId)
                }
            }, for: .Click)
            
            deleteControl?.isHidden = !interaction.deletable
            
        }
    }
    
    override func set(item:TableRowItem, animated:Bool = false) {
        
        let previousType:ShortPeerItemInteractionType = self.item == nil ? .plain : (self.item as? ShortPeerRowItem)!.interactionType

        
        guard let item = item as? ShortPeerRowItem else {return}
        
        
        switch previousType {
        case let .selectable(interaction):
            interaction.remove(observer: self)
        case .deletable:
            break
        default:
            break
        }
        
        super.set(item: item, animated: animated)
        
        
        containerView.setCorners(item.viewType.corners, animated: animated && item.viewType != .legacy)
        
        
        self.border = item.border
        
        if let badge = item.badgeNode {
            if badgeNode == nil {
                badgeNode = View()
                containerView.addSubview(badgeNode!)
            }
            badge.view = badgeNode
            badge.view?.needsDisplay = true
        } else {
            self.badgeNode?.removeFromSuperview()
            self.badgeNode = nil
        }
        
        
        #if !SHARE
        if let activity = item.inputActivity {
            if activities == nil {
                activities = ChatActivitiesModel()
            }
            guard let activities = activities else {return}
            
            let inputActivites: (PeerId, [(Peer, PeerInputActivity)]) = (item.peerId, [(item.peer, activity)])
            
            activities.update(with: inputActivites, for: max(frame.width - 60, 160), theme:theme.activity(key: 4, foregroundColor: theme.colors.accent, backgroundColor: theme.colors.background), layout: { [weak self] show in
                self?.needsLayout = true
                self?.hiddenStatus = !show
                self?.needsDisplay = true
                self?.activities?.view?.isHidden = !show
            })
            container.addSubview(activities.view!)
            
        } else {
            hiddenStatus = true
            activities?.view?.removeFromSuperview()
        }
        #endif
        
        switch previousType {
        case let .selectable(interaction):
            interaction.add(observer: self)
        case .deletable:
            break
        default:
            break
        }
        
        switch item.viewType {
        case .legacy:
            let canSeparate: Bool = item.index != item.table!.count - 1
            separator.isHidden = !(!isRowSelected && item.drawCustomSeparator && (canSeparate || item.drawLastSeparator))
        case let .modern(position, _):
            separator.isHidden = !position.border
        }
        
        image.setFrameSize(item.photoSize)
        if let photo = item.photo {
            image.setSignal(photo)
        } else {
            image.setPeer(account: item.account, peer: item.peer)
        }
        
        self.updateInteractionType(previousType, item.interactionType, item:item, animated:animated)
        choiceControl?.removeFromSuperview()
        choiceControl = nil
        
        switch item.type {
        case let .switchable(stateback):
            contextLabel?.removeFromSuperview()
            contextLabel = nil
            if switchView == nil {
                switchView = SwitchView()
                containerView.addSubview(switchView!)
            }
            switchView?.stateChanged = item.action
            switchView?.setIsOn(stateback,animated:animated)
            switchView?.isEnabled = item.enabled
        case let .context(stateback:stateback):
            switchView?.removeFromSuperview()
            switchView = nil
            
            let label = stateback
            if !label.isEmpty {
                if contextLabel == nil {
                    contextLabel = TextViewLabel()
                    containerView.addSubview(contextLabel!)
                }
                contextLabel?.attributedString = .initialize(string: label, color: theme.colors.grayText, font: item.statusStyle.font)
                contextLabel?.sizeToFit()
            } else {
                contextLabel?.removeFromSuperview()
                contextLabel = nil
            }
        case let .selectable(stateback: stateback):
            if stateback {
                choiceControl = ImageView()
                choiceControl?.image = theme.icons.generalSelect
                choiceControl?.sizeToFit()
                containerView.addSubview(choiceControl!)
            }
            
        default:
            switchView?.removeFromSuperview()
            switchView = nil
            contextLabel?.removeFromSuperview()
            contextLabel = nil
            break
        }
        rightSeparatorView.backgroundColor = theme.colors.border
        contextLabel?.backgroundColor = backdorColor
        needsLayout = true
        self.container.setNeedsDisplayLayer()
    }
    
    func invokeAction(_ item: ShortPeerRowItem, clickCount: Int) {
        switch item.interactionType {
        case let .selectable(interaction):
            interaction.update({$0.withToggledSelected(item.peerId, peer: item.peer)})
        default:
            if clickCount <= 1 {
                item.action()
             //   self.focusAnimation(nil)
            }
        }
    }
    
    
    
    func notify(with value: Any, oldValue: Any, animated: Bool) {
        
        if let item = item as? ShortPeerRowItem {
            switch item.interactionType {
            case .selectable(_):
                if let value = value as? SelectPeerPresentation, let oldValue = oldValue as? SelectPeerPresentation {
                    let new = value.selected.contains(item.peerId)
                    let old = oldValue.selected.contains(item.peerId)
                    if new != old {
                        selectControl?.set(selected: new, animated: animated)
                    }
                }
                
            default:
                break
            }
        }
    }

    

    func isEqual(to other: Notifable) -> Bool {
        if let other = other as? ShortPeerRowView {
            return other == self
        }
        
        return false
    }
    
    override func viewDidMoveToSuperview() {
        
        if let item = item as? ShortPeerRowItem {
            switch item.interactionType {
            case let .selectable(interaction):
                if superview == nil {
                    interaction.remove(observer: self)
                } else {
                    interaction.add(observer: self)
                }
            case .deletable:
                break
            default:
                break
            }
        }
        
       
    }
    
}
