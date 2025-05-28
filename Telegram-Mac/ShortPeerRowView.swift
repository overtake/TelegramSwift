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
import SwiftSignalKit
import Postbox


//FB2126

class ShortPeerRowView: TableRowView, Notifable, ViewDisplayDelegate {
    private let containerView: GeneralRowContainerView = GeneralRowContainerView(frame: NSZeroRect)
    private let image:AvatarStoryControl = AvatarStoryControl(font: .avatar(.text), size: NSMakeSize(36, 36))
    private let photoContainer = Control()
    
    private var photoBadge: ImageView? = nil

    private var deleteControl:ImageButton?
    private var selectControl:SelectingControl?
    private let container:Control = Control()
    private var switchView:SwitchView?
    private var contextLabel:TextViewLabel?
    private var choiceControl:ImageView?
    private var photoOuter: View?
    private var monoforumMessagesView: TextView?
     #if !SHARE
    private var activities: ChatActivitiesModel?
    private var statusControl: PremiumStatusControl?
    private var leftStatusControl: PremiumStatusControl?
    #endif
    private let rightSeparatorView:View = View()
    private let separator:View = View()

    private var hiddenStatus: Bool = true
    private var badgeNode: View? = nil
    
    private var customAction: TextView?
    
    private var rightsActions: [ImageButton] = []
    
    required init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        container.frame = bounds
        photoContainer.addSubview(image)
        container.addSubview(photoContainer)
        container.displayDelegate = self
        containerView.addSubview(container)
        image.userInteractionEnabled = false
        containerView.addSubview(rightSeparatorView)
        containerView.addSubview(separator)
        
        container.set(handler: { [weak self] _ in
            self?.updateMouse(animated: true)
        }, for: .Hover)
        
        container.set(handler: { [weak self] _ in
            self?.updateMouse(animated: true)
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
        
        
        photoContainer.set(handler: { [weak self] _ in
            if let item = self?.item as? ShortPeerRowItem {
                item.openPeerStory()
            } 
        }, for: .Click)
        
        photoContainer.scaleOnClick = true
    }
    
    private func invokeIfNeededUp() {
        if let event = NSApp.currentEvent {
            super.mouseUp(with: event)
            if let item = item as? ShortPeerRowItem, let table = item.table, table.alwaysOpenRowsOnMouseUp, mouseInside() {
                if item.enabled {
                    invokeAction(item, clickCount: event.clickCount)
                } else {
                    if let action = item.disabledAction {
                        action()
                        containerView.shake(beep: false)
                    }
                }
            }
        }
        
    }
    
    override func shakeView() {
        containerView.shake(beep: true)
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
        if let item = item as? ShortPeerRowItem, let theme = item.customTheme {
            if item.isHighlighted {
                return theme.grayForeground
            } else if item.isSelected {
                return theme.accentColor
            } else {
                return theme.backgroundColor
            }
        }
        if let item = item as? ShortPeerRowItem, item.alwaysHighlight {
            return item.isSelected ? theme.colors.grayForeground : theme.colors.background
        }
        return isRowSelected ? theme.colors.accentSelect : item?.isHighlighted ?? false ? theme.colors.grayForeground : theme.colors.background
    }
    
    func takeStoryControl() -> NSView? {
        return self.image
    }
    func setOpenProgress(_ signal:Signal<Never, NoError>) {
        SetOpenStoryDisposable(self.image.pushLoadingStatus(signal: signal))
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
                                if let statusImage = item.statusImage {
                                    ctx.draw(statusImage, in: CGRect(origin: NSMakePoint(item.textInset(false), sY + 2), size: statusImage.backingSize))
                                }
                                status.1.draw(NSMakeRect(item.textInset(true), sY, status.0.size.width, status.0.size.height), in: ctx, backingScaleFactor: backingScaleFactor, backgroundColor: backgroundColor)
                            }
                        }
                        
                        title.1.draw(NSMakeRect(item.textInset(false), tY, title.0.size.width, title.0.size.height), in: ctx, backingScaleFactor: backingScaleFactor, backgroundColor: backgroundColor)
                        
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
                                if let statusImage = item.statusImage {
                                    ctx.draw(statusImage, in: CGRect(origin: NSMakePoint(item.textInset(false), sY + 2), size: statusImage.backingSize))
                                }
                                status.1.draw(NSMakeRect(item.textInset(true), sY, status.0.size.width, status.0.size.height), in: ctx, backingScaleFactor: backingScaleFactor, backgroundColor: backgroundColor)
                            }
                        }
                        
                        title.1.draw(NSMakeRect(item.textInset(false), tY, title.0.size.width, title.0.size.height), in: ctx, backingScaleFactor: backingScaleFactor, backgroundColor: backgroundColor)
                    }
                }
            }
        }
        
    }
    
    override func updateColors() {
        
        guard let item = self.item as? ShortPeerRowItem else {
            return
        }
        
        let highlighted = backdorColor

        let customTheme = item.customTheme
        
        self.containerView.background = backdorColor
        self.separator.backgroundColor = isRowSelected ? .clear : (customTheme?.borderColor ?? theme.colors.border)
        self.contextLabel?.background = backdorColor
        self.containerView.set(background: backdorColor, for: .Normal)
        self.containerView.set(background: highlighted, for: .Highlight)

        self.photoOuter?.layer?.borderColor = (isRowSelected ? .clear : (item.customTheme?.accentColor ?? theme.colors.accent)).cgColor
        
        
        self.background = item.viewType.rowBackground
        self.needsDisplay = true
        self.container.needsDisplay = true
    }
    
    override func updateMouse(animated: Bool) {
        super.updateMouse(animated: animated)
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
                case .plain, .interactable:
                    container.frame = bounds
                case let .selectable(_, side):
                    switch side {
                    case .left:
                        container.frame = .init(x: 30, y: 0, width: frame.width - 30, height: frame.height)
                    case .right:
                        container.frame = .init(x: 0, y: 0, width: frame.width, height: frame.height)
                    }
                default :
                    container.frame = .init(x: 30, y: 0, width: frame.width - 30, height: frame.height)
                }
                                
                switch item.interactionType {
                case .deletable:
                    if let deleteControl = deleteControl {
                        deleteControl.centerY(x: item.deleteInset)
                    }
                case let .selectable(_, side):
                    if let selectControl = selectControl {
                        switch side {
                        case .right:
                            selectControl.centerY(x: containerView.frame.width - selectControl.frame.width - item.inset.right)
                        case .left:
                            selectControl.centerY(x: item.deleteInset)
                        }
                    }
                default:
                    break
                }

                
                photoContainer.frame = NSMakeRect(item.inset.left + (item.leftImage != nil ? item.leftImage!.backingSize.width + 5 : 0), NSMinY(focus(item.photoSize)), item.photoSize.width, item.photoSize.height)
                image.frame = item.photoSize.bounds

                
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
                
                
                
                var addOffset: CGFloat = 0
                switch item.interactionType {
                case .selectable(_, let side):
                    switch side {
                    case .left:
                        addOffset += 30
                    default:
                        break
                    }
                default:
                    break
                }
                
                separator.frame = NSMakeRect(item.textInset(false) + addOffset, containerView.frame.height - .borderSize, containerView.frame.width - (item.drawSeparatorIgnoringInset ? 0 : item.inset.right) - item.textInset(false), .borderSize)
                
                #if !SHARE
                if let view = activities?.view {
                    view.setFrameOrigin(item.textInset(false) - 2, floorToScreenPixels(backingScaleFactor, frame.height / 2 + 1))
                }
                #endif
            case let .modern(position, innerInsets):
                self.containerView.frame = NSMakeRect(floorToScreenPixels(backingScaleFactor, (frame.width - item.blockWidth) / 2), item.inset.top, item.blockWidth, frame.height - item.inset.bottom - item.inset.top)
                self.containerView.setCorners(position.corners)
                self.rightSeparatorView.isHidden = true
                
                switch item.interactionType {
                case .plain, .interactable:
                    container.frame = .init(x: innerInsets.left, y: 0, width: containerView.frame.width - innerInsets.left - innerInsets.right, height: containerView.frame.height)
                case let .selectable(_, side):
                    switch side {
                    case .right:
                        container.frame = .init(x: innerInsets.left, y: 0, width: containerView.frame.width - innerInsets.left - innerInsets.right, height: containerView.frame.height)
                    case .left:
                        let offset = innerInsets.left + 20 + innerInsets.right
                        container.frame = .init(x: offset, y: 0, width: containerView.frame.width - offset - innerInsets.right, height: containerView.frame.height)
                    }
                case .deletable:
                    let offset = innerInsets.left + 24 + innerInsets.right
                    container.frame = .init(x: offset, y: 0, width: containerView.frame.width - offset - innerInsets.right, height: containerView.frame.height)
                }
                
                switch item.interactionType {
                case .deletable:
                    if let deleteControl = deleteControl {
                        deleteControl.centerY(x: item.deleteInset)
                    }
                case let .selectable(_, side):
                    if let selectControl = selectControl {
                        switch side {
                        case .right:
                            selectControl.centerY(x: containerView.frame.width - selectControl.frame.width - innerInsets.right)
                        case .left:
                            selectControl.centerY(x: item.deleteInset)
                        }
                    }
                default:
                    break
                }
                
                photoContainer.frame = NSMakeRect((item.leftImage != nil ? item.leftImage!.backingSize.width + 5 : 0), NSMinY(focus(item.photoSize)), item.photoSize.width, item.photoSize.height)
                
                image.frame = item.photoSize.bounds

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
               
                separator.frame = NSMakeRect(container.frame.minX + item.textInset(false), containerView.frame.height - .borderSize, container.frame.width - item.textInset(false), .borderSize)
                
                container.needsDisplay = true
                
            }
            
            var additional: CGFloat = 0
            
            #if !SHARE
            if let view = activities?.view {
                view.setFrameOrigin(item.textInset(false) - 2, floorToScreenPixels(backingScaleFactor, frame.height / 2 + 1))
            }
            if let statusControl = self.statusControl, let title = item.title {
                var tY = NSMinY(focus(title.0.size))
                
                if let status = (isRowSelected ? item.statusSelected : item.status) {
                    let t = title.0.size.height + status.0.size.height + 1.0
                    tY = floorToScreenPixels((self.frame.height - t) / 2.0)
                }

                statusControl.setFrameOrigin(NSMakePoint(item.textInset(false) + title.0.size.width + 2, tY + 1))
                additional += statusControl.frame.size.width + 2
            }
            
            if let statusControl = self.leftStatusControl, let title = item.title {
                var tY = NSMinY(focus(title.0.size))
                
                if let status = (isRowSelected ? item.statusSelected : item.status) {
                    let t = title.0.size.height + status.0.size.height + 1.0
                    tY = floorToScreenPixels((self.frame.height - t) / 2.0)
                }

                statusControl.setFrameOrigin(NSMakePoint(item.textInset(false) - statusControl.frame.width - 2, tY + 1))

            }
            
            #endif
            
            
            if let monoforumMessagesView, let title = item.ctxTitle {
                var tY = NSMinY(focus(title.0.size))
                if let status = item.ctxStatus {
                    let t = title.0.size.height + status.0.size.height + 1.0
                    tY = floorToScreenPixels(backingScaleFactor, (self.frame.height - t) / 2.0)
                }
                monoforumMessagesView.setFrameOrigin(NSMakePoint(item.textInset(false) + title.0.size.width + 2 + additional, tY))
            }
            

            if let photoOuter = photoOuter {
                photoOuter.frame = self.image.frame.insetBy(dx: -3, dy: -3)
                photoOuter.layer?.cornerRadius = photoOuter.frame.height / 2
            }
            if let photoBadge = self.photoBadge {
                if item.drawStarsPaid != nil {
                    
                    if let title = (isRowSelected ? item.titleSelected : item.title) {
                        var tY = NSMinY(focus(title.0.size))
                        
                        if let status = (isRowSelected ? item.statusSelected : item.status) {
                            let t = title.0.size.height + status.0.size.height + 1.0
                            tY = floorToScreenPixels(backingScaleFactor, (self.frame.height - t) / 2.0)
                        }
                        photoBadge.setFrameOrigin(NSMakePoint(item.textInset(false) + title.0.size.width + 4, tY))
                    }
                    
                } else {
                    photoBadge.setFrameOrigin(NSMakePoint(self.image.frame.maxX - photoBadge.frame.width / 2 + 5, self.image.frame.midY + 5))
                }
            }
        }
        
        if let customAction {
            customAction.centerY(x: containerView.frame.width - customAction.frame.width - 10)
        }
        
        if !rightsActions.isEmpty {
            var x: CGFloat = containerView.frame.width - rightsActions[rightsActions.count - 1].frame.width - 10
            for action in rightsActions.reversed() {
                action.centerY(x: x)
                x -= (action.frame.width + 10)
            }
        }
    }
    
    func updateInteractionType(_ previousType:ShortPeerItemInteractionType, _ interactionType:ShortPeerItemInteractionType, item:ShortPeerRowItem, animated:Bool) {
        
        let interactive:Bool
        switch interactionType {
        case .plain, .selectable, .interactable:
            interactive = false
        default:
            interactive = true
        }
        
        let containerRect: NSRect
        let separatorRect: NSRect
        switch item.viewType {
        case .legacy:
            containerRect = CGRect(origin: NSMakePoint((interactive ? 30 : 0), 0), size: NSMakeSize(containerView.frame.width - (interactive ? 30 : 0), containerView.frame.height))
            separatorRect = NSMakeRect(item.textInset(false), containerRect.height - .borderSize, containerRect.width - (item.drawSeparatorIgnoringInset ? 0 : item.inset.right) - item.textInset(false), .borderSize)
        case let .modern(_, innerInsets):
            switch item.interactionType {
            case .plain, .interactable:
                containerRect = .init(x: innerInsets.left, y: 0, width: containerView.frame.width - innerInsets.left - innerInsets.right, height: containerView.frame.height)
            case let .selectable(_, side):
                switch side {
                case .right:
                    containerRect = .init(x: innerInsets.left, y: 0, width: containerView.frame.width - innerInsets.left - innerInsets.right, height: containerView.frame.height)
                case .left:
                    let offset = innerInsets.left + 20 + innerInsets.right
                    containerRect = .init(x: offset, y: 0, width: containerView.frame.width - offset - innerInsets.right, height: containerView.frame.height)
                }
            case .deletable:
                let offset = innerInsets.left + 24 + innerInsets.right
                containerRect = .init(x: offset, y: 0, width: containerView.frame.width - offset - innerInsets.right, height: containerView.frame.height)
            }
            separatorRect = NSMakeRect(containerRect.minX + item.textInset(false), containerRect.height - .borderSize, containerRect.width - item.textInset(false), .borderSize)
            
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
        case .plain, .interactable:
            
            if let view = deleteControl {
                performSubviewRemoval(view, animated: animated)
                self.deleteControl = nil
            }
            
            if let view = selectControl {
                performSubviewRemoval(view, animated: animated)
                self.selectControl = nil
            }
            
        case let .selectable(interaction, _):
           
            let current: SelectingControl
            if let view = self.selectControl {
                current = view
            } else {
                let unselected: CGImage = item.customTheme?.unselectedImage ?? theme.icons.chatToggleUnselected
                let selected: CGImage = item.customTheme?.selectedImage ?? theme.icons.chatToggleSelected
                current = SelectingControl(unselectedImage: unselected, selectedImage: selected)
                self.selectControl = current
                containerView.addSubview(current)
                
                if animated {
                    current.layer?.animateAlpha(from: 0, to: 1, duration: 0.2)
                    current.layer?.animateScaleSpring(from: 0.1, to: 1, duration: 0.3)
                }
            }
            current.layer?.opacity = item.enabled ? 1 : 0.8
            current.set(selected: interaction.presentation.selected.contains(item.peerId), animated: animated)
                   
            if let view = deleteControl {
                performSubviewRemoval(view, animated: animated)
                self.deleteControl = nil
            }
        case let .deletable(onRemove, deletable):
            if let view = selectControl {
                performSubviewRemoval(view, animated: animated)
                self.selectControl = nil
            }
            
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
                    onRemove(item.peerId)
                }
            }, for: .Click)
            
            deleteControl?.isHidden = !deletable
            
        }
    }
    
    override func set(item:TableRowItem, animated:Bool = false) {
        
        let previousType:ShortPeerItemInteractionType = self.item == nil ? .plain : (self.item as? ShortPeerRowItem)!.interactionType

        
        guard let item = item as? ShortPeerRowItem else {return}
        
        #if !SHARE
        if item.highlightVerified, (!item.isLookSavedMessage || item.peerId != item.account.peerId) {
            let control = PremiumStatusControl.control(item.monoforumPeer ?? item.peer, account: item.account, inlinePacksContext: item.context?.inlinePacksContext, left: false, isSelected: isRowSelected, cached: self.statusControl, animated: animated)
            if let control = control {
                self.statusControl = control
                self.container.addSubview(control)
            } else if let view = self.statusControl {
                performSubviewRemoval(view, animated: animated)
                self.statusControl = nil
            }
        } else if let view = self.statusControl {
            performSubviewRemoval(view, animated: animated)
            self.statusControl = nil
        }
        
        if item.highlightVerified, (!item.isLookSavedMessage || item.peerId != item.account.peerId) {
            let control = PremiumStatusControl.control(item.monoforumPeer ?? item.peer, account: item.account, inlinePacksContext: item.context?.inlinePacksContext, left: true, isSelected: isRowSelected, cached: self.leftStatusControl, animated: animated)
            if let control = control {
                self.leftStatusControl = control
                self.container.addSubview(control)
            } else if let view = self.leftStatusControl {
                performSubviewRemoval(view, animated: animated)
                self.leftStatusControl = nil
            }
        } else if let view = self.leftStatusControl {
            performSubviewRemoval(view, animated: animated)
            self.leftStatusControl = nil
        }
        #endif
        
        switch previousType {
        case let .selectable(interaction, _):
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
            badge.onUpdate = { [weak self] in
                self?.needsLayout = true
            }
        } else {
            self.badgeNode?.removeFromSuperview()
            self.badgeNode = nil
        }
        
        if item.drawPhotoOuter {
            let current: View
            if let photoOuter = self.photoOuter {
                current = photoOuter
            } else {
                current = View()
                current.layer?.borderWidth = 1
                current.layer?.borderColor = (item.customTheme?.accentColor ?? theme.colors.accent).cgColor
                self.photoOuter = current
                addSubview(current)
            }
        } else {
            if let view = self.photoOuter {
                self.photoOuter = nil
                performSubviewRemoval(view, animated: animated)
            }
        }
        
        
        
        #if !SHARE
        if let activity = item.inputActivity {
            if activities == nil {
                activities = ChatActivitiesModel()
            }
            guard let activities = activities else {return}
            
            let inputActivites: (PeerId, [(Peer, PeerInputActivity)]) = (item.peerId, [(item.peer, activity)])
            
            activities.update(with: inputActivites, for: max(frame.width - 60, 160), theme:theme.activity(key: 4, foregroundColor: item.customTheme?.accentColor ?? theme.colors.accent, backgroundColor: backdorColor), layout: { [weak self] show in
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
        case let .selectable(interaction, _), let .interactable(interaction):
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
            separator.isHidden = !position.border || !item.drawCustomSeparator
        }
    
        photoContainer.userInteractionEnabled = item.story != nil
        
        let transition: ContainedViewLayoutTransition = animated ? .animated(duration: 0.2, curve: .easeOut) : .immediate
        if let indicator = item.avatarStoryIndicator {
            self.image.update(component: indicator, availableSize: item.photoSize.bounds.insetBy(dx: 3, dy: 3).size, transition: transition)
        } else {
            self.image.update(component: nil, availableSize: item.photoSize, transition: transition)
        }
        
        if let photo = item.photo {
            image.setSignal(photo)
        } else {
            if let monoforumPeer = item.monoforumPeer, item.peer.isMonoForum {
                image.setState(account: item.account, state: .PeerAvatar(item.peer, monoforumPeer.displayLetters, monoforumPeer.smallProfileImage, monoforumPeer.nameColor, nil, item.photoSize, true, nil))
            } else {
                image.setPeer(account: item.account, peer: item.peer, size: item.photoSize, cornerRadius: item.makeAvatarRound ? 6 : nil)
            }
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
        case let .context(stateback), let .nextContext(stateback):
            switchView?.removeFromSuperview()
            switchView = nil
            
            let label = stateback
            if !label.isEmpty {
                if contextLabel == nil {
                    contextLabel = TextViewLabel()
                    containerView.addSubview(contextLabel!)
                }
                contextLabel?.attributedString = .initialize(string: label, color: item.customTheme?.secondaryColor ?? theme.colors.grayText, font: item.statusStyle.font)
                contextLabel?.sizeToFit()
            } else {
                contextLabel?.removeFromSuperview()
                contextLabel = nil
            }
        case let .selectable(stateback):
            switchView?.removeFromSuperview()
            switchView = nil
            contextLabel?.removeFromSuperview()
            contextLabel = nil
            if stateback {
                choiceControl = ImageView()
                choiceControl?.image = #imageLiteral(resourceName: "Icon_UsernameAvailability").precomposed(item.customTheme?.accentColor ?? theme.colors.accent)
                choiceControl?.sizeToFit()
                containerView.addSubview(choiceControl!)
            }
        default:
            switchView?.removeFromSuperview()
            switchView = nil
            contextLabel?.removeFromSuperview()
            contextLabel = nil
            choiceControl?.removeFromSuperview()
            choiceControl = nil
            break
        }
        
        switch item.interactionType {
        case let .interactable(interaction):
            updatePresentation(item: item, value: interaction.presentation, animated: animated)
        default:
            updatePresentation(item: item, value: nil, animated: animated)
        }
        
        if let customAction = (isRowSelected ? item.customActionTextSelected : item.customActionText) {
            let current: TextView
            if let view = self.customAction {
                current = view
            } else {
                current = TextView()
                current.isSelectable = false
                current.scaleOnClick = true
                self.customAction = current
                containerView.addSubview(current)
            }
            current.update(customAction)
            current.backgroundColor = isRowSelected ? theme.colors.underSelectedColor : theme.colors.accent
            current.setFrameSize(customAction.layoutSize.bounds.insetBy(dx: -8, dy: -4).size)
            current.layer?.cornerRadius = current.frame.height / 2
            
            current.setSingle(handler: { [weak item] _ in
                item?.customAction?.callback()
            }, for: .Click)
            
        } else if let view = customAction {
            performSubviewRemoval(view, animated: animated)
            self.customAction = nil
        }
        
        if !item.rightActions.actions.isEmpty {
            while self.rightsActions.count > item.rightActions.actions.count {
                self.rightsActions.removeLast().removeFromSuperview()
            }
            while self.rightsActions.count < item.rightActions.actions.count {
                let view = ImageButton()
                containerView.addSubview(view)
                self.rightsActions.append(view)
            }
            
            for (i, action) in item.rightActions.actions.enumerated() {
                let view = self.rightsActions[i]
                view.set(image: action.icon, for: .Normal)
                view.scaleOnClick = true
                view.autohighlight = false
                view.sizeToFit()
                view.setSingle(handler: { [weak item] _ in
                    if let item {
                        item.rightActions.callback(item.peerId, i)
                    }
                }, for: .Click)
            }

        } else {
            while !self.rightsActions.isEmpty {
                self.rightsActions.removeLast().removeFromSuperview()
            }
        }
        
        if let displayLayout = item.ctxMonoforumMessages {
            let current: TextView
            if let view = self.monoforumMessagesView {
                current = view
            } else {
                current = TextView(frame: .zero)
                current.userInteractionEnabled = false
                current.isSelectable = false
                
                self.monoforumMessagesView = current
                containerView.addSubview(current)
            }
            
            current.update(displayLayout)
            current.setFrameSize(NSMakeSize(displayLayout.layoutSize.width + 4, displayLayout.layoutSize.height + 4))
            current.layer?.cornerRadius = .cornerRadius
            current.background = item.isSelected ? theme.colors.underSelectedColor : theme.colors.grayText.withAlphaComponent(0.15)
        } else if let view = self.monoforumMessagesView {
            performSubviewRemoval(view, animated: animated)
            self.monoforumMessagesView = nil
        }

        
        
        
        self.image._change(opacity: item.enabled ? 1 : 0.8, animated: animated)
        rightSeparatorView.backgroundColor = theme.colors.border
        contextLabel?.backgroundColor = backdorColor
        needsLayout = true
        self.container.setNeedsDisplayLayer()
        
        
        viewDidMoveToSuperview()
    }
    
    func invokeAction(_ item: ShortPeerRowItem, clickCount: Int) {
        switch item.interactionType {
        case let .selectable(interaction, side):
            switch side {
            case .left:
                if item.passLeftAction {
                    if item.peer.isForum, !interaction.presentation.selected.contains(item.peerId) {
                        if !interaction.openForum(item.peerId, item.peer.isMonoForum) {
                            interaction.update({$0.withToggledSelected(item.peerId, peer: item.peer)})
                        }
                    } else {
                        interaction.update({$0.withToggledSelected(item.peerId, peer: item.peer)})
                    }
                } else {
                    interaction.action(item.peerId, nil)
                }
            default:
                if item.peer.isForum, !interaction.presentation.selected.contains(item.peerId) {
                    if !interaction.openForum(item.peerId, item.peer.isMonoForum) {
                        interaction.update({$0.withToggledSelected(item.peerId, peer: item.peer)})
                    }
                } else {
                    interaction.update({$0.withToggledSelected(item.peerId, peer: item.peer)})
                }
            }
        case .deletable(_, true):
            break
        default:
            if clickCount <= 1 {
                if item.menuOnAction, let event = NSApp.currentEvent {
                    showContextMenu(event)
                } else if case .nextContext = item.type, let event = NSApp.currentEvent {
                    showContextMenu(event)
                } else {
                    item.action()
                }
             //   self.focusAnimation(nil)
            }
        }
    }
    
    
    
    func notify(with value: Any, oldValue: Any, animated: Bool) {
        if let item = item as? ShortPeerRowItem {
            switch item.interactionType {
            case .selectable:
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
            
            if let value = value as? SelectPeerPresentation {
                updatePresentation(item: item, value: value, animated: animated)
            } else if let view = self.photoBadge {
                performSubviewRemoval(view, animated: animated, scale: true)
                self.photoBadge = nil
            }
        }
        needsLayout = true
        
    }

    
    private func updatePresentation(item: ShortPeerRowItem, value: SelectPeerPresentation?, animated: Bool) {
        if value?.premiumRequired.contains(item.peerId) == true || item.drawStarsPaid != nil {
            let current: ImageView
            var isNew = false
            if let view = self.photoBadge {
                current = view
            } else {
                current = ImageView()
                addSubview(current)
                self.photoBadge = current
                isNew = true
            }
            if let drawStarsPaid = item.drawStarsPaid {
                current.image = generalSendPaidMessage(bgColor: theme.colors.accent, outerColor: theme.colors.background, imageColor: theme.colors.underSelectedColor, count: .initialize(string: drawStarsPaid.value.prettyNumber, color: theme.colors.underSelectedColor, font: .avatar(.small)))
                current.sizeToFit()
                current.setFrameOrigin(NSMakePoint(self.image.frame.minX + (self.image.frame.width - current.frame.width) / 2, self.image.frame.midY + 5))
            } else {
                current.image = theme.icons.premium_required_forward
                current.sizeToFit()
                current.setFrameOrigin(NSMakePoint(self.image.frame.maxX - current.frame.width / 2 + 5, self.image.frame.midY + 5))
            }
            
            if isNew, animated {
                current.layer?.animateAlpha(from: 0, to: 1, duration: 0.2)
                current.layer?.animateScaleSpring(from: 0.1, to: 1, duration: 0.2)
            }
        } else if let view = self.photoBadge {
            performSubviewRemoval(view, animated: animated, scale: true)
            self.photoBadge = nil
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
            case let .selectable(interaction, _), let .interactable(interaction):
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
