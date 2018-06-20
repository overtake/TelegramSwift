//
//  ShortPeerRowView.swift
//  Telegram-Mac
//
//  Created by keepcoder on 29/09/2016.
//  Copyright © 2016 Telegram. All rights reserved.
//

import Cocoa
import TGUIKit
import TelegramCoreMac
import PostboxMac


//FB2126

class ShortPeerRowView: TableRowView, Notifable, ViewDisplayDelegate {
    
    private var image:AvatarControl = AvatarControl(font: .avatar(.text))
    private var deleteControl:ImageButton?
    private var selectControl:SelectingControl?
    private let container:View = View()
    private var switchView:SwitchView?
    private var contextLabel:TextViewLabel?
    private var choiceControl:ImageView?
     #if !SHARE
    private var activities: ChatActivitiesModel?
    #endif
    private let rightSeparatorView:View = View()
    private var hiddenStatus: Bool = true
    required init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        container.frame = bounds
        container.addSubview(image)
        container.displayDelegate = self
        addSubview(container)
        image.userInteractionEnabled = false
        addSubview(rightSeparatorView)
    }
    
    override var border: BorderType? {
        didSet {
            container.border = border
        }
    }
    
    
    override var backdorColor: NSColor {
        return item?.isSelected ?? false ? theme.colors.blueSelect : theme.colors.background
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override func draw(_ layer: CALayer, in ctx: CGContext) {
        
        if let item = item as? ShortPeerRowItem {
            
            //ctx.setFillColor(backdorColor.cgColor)
            //ctx.fill(NSMakeRect(0, 0, layer.bounds.width - .borderSize, layer.bounds.height))
            if layer == container.layer {
                
                let canSeparate: Bool = item.index != item.table!.count - 1
                
                
                if !item.isSelected && item.drawCustomSeparator && (canSeparate || item.drawLastSeparator) {
                    ctx.setFillColor(theme.colors.border.cgColor)
                    ctx.fill(NSMakeRect(item.textInset, container.frame.height - .borderSize, container.frame.width - (item.drawSeparatorIgnoringInset ? 0 : item.inset.right) - item.textInset, .borderSize))
                }
                
                if let leftImage = item.leftImage {
                    let focus = container.focus(leftImage.backingSize)
                    ctx.draw(leftImage, in: NSMakeRect(item.inset.left, focus.minY, focus.width, focus.height))
                }
                
                if let title = item.ctxTitle {
                    var tY = NSMinY(focus(title.0.size))
                    
                    if let status = item.ctxStatus {
                        let t = title.0.size.height + status.0.size.height + 1.0
                        tY = (NSHeight(self.frame) - t) / 2.0
                        
                        let sY = tY + title.0.size.height + 1.0
                        if hiddenStatus {
                            status.1.draw(NSMakeRect(item.textInset, sY, status.0.size.width, status.0.size.height), in: ctx, backingScaleFactor: backingScaleFactor, backgroundColor: backgroundColor)
                        }
                    }
                    
                    title.1.draw(NSMakeRect(item.textInset, tY, title.0.size.width, title.0.size.height), in: ctx, backingScaleFactor: backingScaleFactor, backgroundColor: backgroundColor)
                }
            } else {
                super.draw(layer, in: ctx)
                let canSeparate: Bool = item.index != item.table!.count - 1
                if !item.isSelected && item.drawCustomSeparator && (canSeparate || item.drawLastSeparator) {
                    ctx.setFillColor(theme.colors.border.cgColor)
                  //  ctx.fill(NSMakeRect(30, container.frame.height - .borderSize, frame.width, .borderSize))
                }
               
            }
        }
        
    }
    
    
    
    override func layout() {
        super.layout()
        if let item = item as? ShortPeerRowItem {
            
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
            #if !SHARE
            if let view = activities?.view {
                view.setFrameOrigin(item.textInset - 2, floorToScreenPixels(scaleFactor: backingScaleFactor, frame.height / 2 + 1))
            }
            #endif
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
        

        self.container.change(size: NSMakeSize(frame.width - (interactive ? 30 : 0), frame.height), animated: false)
        self.container.change(pos: NSMakePoint((interactive ? 30 : 0), 0), animated: animated)
        
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
            selectControl?.set(selected: interaction.presentation.selected.contains(item.peer.id), animated: animated)
            
            addSubview(selectControl!)
            
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
                
                addSubview(deleteControl!)
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
                    interaction.onRemove(item.peer.id)
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
        
        #if !SHARE
        if let activity = item.inputActivity {
            if activities == nil {
                activities = ChatActivitiesModel()
            }
            guard let activities = activities else {return}
            
            let inputActivites: (PeerId, [(Peer, PeerInputActivity)]) = (item.peer.id, [(item.peer, activity)])
            
            activities.update(with: inputActivites, for: max(frame.width - 60, 160), theme:theme.activity(key: 4, foregroundColor: theme.colors.blueUI, backgroundColor: theme.colors.background), layout: { [weak self] show in
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
        
        self.border = item.border
        image.setFrameSize(item.photoSize)
        if let photo = item.photo {
            image.setSignal(photo)
        } else {
            image.setPeer(account: item.account, peer: item.peer)
        }
        
        self.updateInteractionType(previousType,item.interactionType, item:item, animated:animated)
        choiceControl?.removeFromSuperview()
        choiceControl = nil
        
        switch item.type {
        case let .switchable(stateback):
            contextLabel?.removeFromSuperview()
            contextLabel = nil
            if switchView == nil {
                switchView = SwitchView()
                container.addSubview(switchView!)
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
                    addSubview(contextLabel!)
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
                addSubview(choiceControl!)
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
    
    override func mouseDown(with event: NSEvent) {
        super.mouseDown(with:event)
        
        if let item = item as? ShortPeerRowItem {
            if item.enabled {
                switch item.interactionType {
                case let .selectable(interaction):
                    interaction.update({$0.withToggledSelected(item.peer.id, peer: item.peer)})
                default:
                    if event.clickCount == 1 {
                        item.action()
                        self.focusAnimation(nil)
                    }
                }
            } 
        }
    }
    
    func notify(with value: Any, oldValue: Any, animated: Bool) {
        
        if let item = item as? ShortPeerRowItem {
            switch item.interactionType {
            case .selectable(_):
                if let value = value as? SelectPeerPresentation, let oldValue = oldValue as? SelectPeerPresentation {
                    let new = value.selected.contains(item.peer.id)
                    let old = oldValue.selected.contains(item.peer.id)
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
