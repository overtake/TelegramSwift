//
//  GeneralInteractedRowView.swift
//  Telegram-Mac
//
//  Created by keepcoder on 12/10/2016.
//  Copyright © 2016 Telegram. All rights reserved.
//

import Cocoa
import TGUIKit


class GeneralInteractedRowView: GeneralRowView {
        
    let containerView: GeneralRowContainerView = GeneralRowContainerView(frame: NSZeroRect)
    private(set) var switchView:SwitchView?
    private(set) var selectLeftControl: SelectingControl?
    private(set) var progressView: ProgressIndicator?
    private(set) var textView:TextView?
    private(set) var descriptionView: TextView?
    private let nextView:ImageView = ImageView()
    private var imageContext:ImageView?
    
    private let nameView = TextView()

    private var badgeView: View?
    
    private var rightIconView: ImageView?
    
    override func set(item:TableRowItem, animated:Bool = false) {
        
        
        
        if let item = item as? GeneralInteractedRowItem {
            
            
            nameView.update(item.isSelected ? item.nameLayoutSelected : item.nameLayout)
                        
            if let descLayout = item.descLayout {
                if descriptionView == nil {
                    descriptionView = TextView()
                    descriptionView?.userInteractionEnabled = false
                    descriptionView?.isSelectable = false
                    descriptionView?.isEventLess = true
                    containerView.addSubview(descriptionView!)
                }
                descriptionView?.update(descLayout)
            } else {
                descriptionView?.removeFromSuperview()
                descriptionView = nil
            }
            
            nextView.isHidden = true
            if case let .switchable(stateback) = item.type {
                if switchView == nil {
                    switchView = SwitchView(frame: NSMakeRect(0, 0, 32, 20))
                    containerView.addSubview(switchView!)
                }
                switchView?.autoswitch = item.autoswitch
                switchView?.presentation = item.switchAppearance
                switchView?.setIsOn(stateback,animated:animated)
                
                switchView?.stateChanged = item.switchAction ?? item.action
                switchView?.userInteractionEnabled = item.enabled
                switchView?.isEnabled = item.enabled
            } else {
                switchView?.removeFromSuperview()
                switchView = nil
            }
            if case let .selectableLeft(value) = item.type {
                
                let unselected: CGImage = item.customTheme?.unselectedImage ?? theme.icons.chatToggleUnselected
                let selected: CGImage = item.customTheme?.selectedImage ?? theme.icons.chatToggleSelected

                let current: SelectingControl
                if let view = self.selectLeftControl {
                    current = view
                } else {
                    
                    current = SelectingControl(unselectedImage: unselected, selectedImage: selected)
                    containerView.addSubview(current)
                    self.selectLeftControl = current
                }
                current.update(unselectedImage: unselected, selectedImage: selected, selected: value, animated: animated)
                
                current.layer?.opacity = item.enabled ? 1 : 0.7
            } else if let view = self.selectLeftControl {
                performSubviewRemoval(view, animated: animated)
                self.selectLeftControl = nil
            }
                        
            if let badgeNode = item.badgeNode {
                if badgeView == nil {
                    badgeView = View()
                    containerView.addSubview(badgeView!)
                }
                badgeView?.setFrameSize(badgeNode.size)
                badgeNode.view = badgeView
                badgeNode.setNeedDisplay()
            } else {
                self.badgeView?.removeFromSuperview()
                self.badgeView = nil
            }
            
            if case let .image(stateback) = item.type {
                nextView.image = stateback
                nextView.sizeToFit()
                nextView.isHidden = item.isSelected
            }
            
            switch item.type {
            case let .context(value), let .nextContext(value), let .contextSelector(value, _), let .imageContext(_, value):
                if textView == nil {
                    textView = TextView()
                    textView?.animates = false
                    textView?.userInteractionEnabled = false
                    textView?.isEventLess = true
                    containerView.addSubview(textView!)
                }
                let grayText = item.customTheme?.grayTextColor ?? theme.colors.grayText
                let underselect = item.customTheme?.underSelectedColor ?? theme.colors.underSelectedColor

                let layout = item.isSelected ? nil : TextViewLayout(.initialize(string: value, color: isSelect ? underselect : grayText, font: .normal(.title)), maximumNumberOfLines: 1)
                
                textView?.set(layout: layout)
                var nextVisible: Bool = true
                if case let .contextSelector(value, items) = item.type {
                    nextVisible = !items.isEmpty && !value.isEmpty
                } else if case .imageContext = item.type {
                    nextVisible = true
                } else if case .context = item.type {
                    nextVisible = false
                }
                nextView.isHidden = !nextVisible
            default:
                textView?.removeFromSuperview()
                textView = nil
            }
            if case let .nextImage(image) = item.type {
                let current:ImageView
                if let view = self.imageContext {
                    current = view
                } else {
                    current = ImageView()
                    containerView.addSubview(current)
                    self.imageContext = current
                }
                current.image = image 
                current.sizeToFit()
            } else if let view = self.imageContext {
                performSubviewRemoval(view, animated: animated)
                self.imageContext = nil
            }
            textView?.backgroundColor = backdorColor
            
            if case let .selectable(value) = item.type {
                nextView.isHidden = !value
                
                nextView.image = generateCheckSelected(foregroundColor: item.customTheme?.accentColor ?? theme.colors.accent, backgroundColor: item.customTheme?.underSelectedColor ?? theme.colors.underSelectedColor)
                
                nextView.sizeToFit()
            }
            if case let .imageContext(image, _) = item.type {
                nextView.isHidden = false
                nextView.image = image
                nextView.sizeToFit()
            }
            
            var needNextImage: Bool = false
            if case .colorSelector = item.type {
                needNextImage = true
            }
            if case .next = item.type {
                needNextImage = true
            }
            if case .nextContext = item.type {
                needNextImage = true
            }
            if case .nextImage = item.type {
                needNextImage = true
            }
            if case let .contextSelector(value, items) = item.type {
                needNextImage = !items.isEmpty && !value.isEmpty
            }
            if needNextImage {
                nextView.isHidden = false
                                
                let color = (item.customTheme?.grayTextColor ?? theme.colors.grayText).withAlphaComponent(0.5)
                nextView.image = item.isSelected ? nil : NSImage(named: "Icon_GeneralNext")?.precomposed(color)
                nextView.sizeToFit()
            }
            switch item.viewType {
            case .legacy:
                containerView.setCorners([], animated: false)
            case .modern:
                containerView.setCorners(self.isResorting ? GeneralViewItemCorners.all : item.viewType.corners, animated: animated)
            }
            
            switch item.type {
            case .loading:
                if progressView == nil {
                    self.progressView = ProgressIndicator(frame: NSMakeRect(0, 0, 20, 20))
                    containerView.addSubview(self.progressView!)
                }
            default:
                self.progressView?.removeFromSuperview()
                self.progressView = nil
            }

            if let rightIcon = item.rightIcon {
                let current: ImageView
                if let view = rightIconView {
                    current = view
                } else {
                    current = ImageView()
                    self.rightIconView = current
                    containerView.addSubview(current)
                }
                current.image = rightIcon
                current.sizeToFit()
            } else if let view = rightIconView {
                performSubviewRemoval(view, animated: animated)
                self.rightIconView = nil
            }
        }
        super.set(item: item, animated: animated)
        
        
        containerView.needsLayout = true
        containerView.needsDisplay = true
    }
    
    override func updateIsResorting() {
        if let item = self.item {
            self.set(item: item, animated: true)
        }
    }
    
    override var backdorColor: NSColor {
        guard let item = item as? GeneralInteractedRowItem else {
            return super.backdorColor
        }
        if let theme = item.customTheme {
            return theme.backgroundColor
        }
        return isSelect ? theme.colors.accentSelect : theme.colors.background
    }
    
    var highlightColor: NSColor {
        guard let item = item as? GeneralInteractedRowItem else {
            return super.backdorColor
        }
        if let theme = item.customTheme {
            return theme.highlightColor
        }
        return theme.colors.grayHighlight
    }
    
    override var borderColor: NSColor {
        guard let item = item as? GeneralInteractedRowItem else {
            return theme.colors.border
        }
        if item.disableBorder {
            return .clear
        }
        if let theme = item.customTheme {
            return theme.borderColor
        }
        return theme.colors.border
    }
    
    override func updateColors() {
        if let item = item as? GeneralInteractedRowItem {
            self.background = item.viewType.rowBackground
            let highlighted = isSelect ? self.backdorColor : highlightColor
            descriptionView?.backgroundColor = containerView.controlState == .Highlight && !isSelect ? .clear : self.backdorColor
            textView?.backgroundColor = containerView.controlState == .Highlight && !isSelect ? .clear : self.backdorColor
            containerView.set(background: self.backdorColor, for: .Normal)
            containerView.set(background: highlighted, for: .Highlight)
            progressView?.progressColor = item.customTheme?.secondaryColor ?? theme.colors.grayIcon
        }
        containerView.needsDisplay = true
    }
    
    override func shakeView() {
        self.shake()
    }
    
    private var textXAdditional: CGFloat {
        var textXAdditional:CGFloat = 0
        guard let item = item as? GeneralInteractedRowItem else {return 0}
        let t = item.isSelected ? item.activeThumb : item.thumb
        if let thumb = t {
            if let textInset = thumb.textInset {
                textXAdditional = textInset
            } else {
                textXAdditional = thumb.thumb.backingSize.width + 10
            }
        }
        if let _ = self.selectLeftControl {
            textXAdditional += 24 + item.viewType.innerInset.left
        }
        return textXAdditional
    }
    
    override func draw(_ layer: CALayer, in ctx: CGContext) {
                
        if let item = item as? GeneralInteractedRowItem, layer == containerView.layer {
            
            switch item.viewType {
            case .legacy:
                super.draw(layer, in: ctx)
                let t = item.isSelected ? item.activeThumb : item.thumb
                if let thumb = t {
                    var f = focus(thumb.thumb.backingSize)
                    if item.descLayout != nil {
                        f.origin.y = 11
                    }
                    let icon = thumb.thumb //isSelect ? ControlStyle(highlightColor: .white).highlight(image: thumb.thumb) :
                    ctx.draw(icon, in: NSMakeRect(item.inset.left, f.minY, f.width, f.height))
                }
                
                if item.drawCustomSeparator, !isSelect && !self.isResorting && containerView.controlState != .Highlight {
                    ctx.setFillColor(borderColor.cgColor)
                    ctx.fill(NSMakeRect(textXAdditional + item.inset.left, frame.height - .borderSize, frame.width - (item.inset.left + item.inset.right + textXAdditional), .borderSize))
                }
                
                
                if case let .colorSelector(stateback) = item.type {
                    ctx.setFillColor(stateback.cgColor)
                    ctx.fillEllipse(in: NSMakeRect(frame.width - 14 - item.inset.right - 16, floorToScreenPixels(backingScaleFactor, (frame.height - 14) / 2), 14, 14))
                }
            case let .modern(position, insets):
                let t = item.isSelected ? item.activeThumb : item.thumb
                if let thumb = t {
                    var f = focus(thumb.thumb.backingSize)
                    
                    let icon = thumb.thumb
                    var x: CGFloat = insets.left + (thumb.thumbInset ?? 0)
                    if case .selectableLeft = item.type {
                        x += 35
                    } else {
                        if item.descLayout != nil {
                           // f.origin.y = insets.top
                        }
                    }
                    ctx.draw(icon, in: NSMakeRect(x, f.minY, f.width, f.height))
                }
                
                if position.border, !isSelect && !self.isResorting  {
                    ctx.setFillColor(borderColor.cgColor)
                    ctx.fill(NSMakeRect(textXAdditional + insets.left, containerView.frame.height - .borderSize, containerView.frame.width - (insets.left + insets.right + textXAdditional), .borderSize))
                }
                
                let nameLayout = (item.isSelected ? item.nameLayoutSelected : item.nameLayout)
                
                var textRect = focus(NSMakeSize(nameLayout.layoutSize.width,nameLayout.layoutSize.height))
                textRect.origin.x = insets.left + textXAdditional
                if item.descLayout == nil {
                    textRect.origin.y = insets.top - 1
                } else {
                    textRect.origin.y = 5
                }
                                
                if let afterNameImage = item.afterNameImage {
                    ctx.draw(afterNameImage, in: CGRect(x: textRect.maxX + 8, y: textRect.minY, width: afterNameImage.backingSize.width, height: afterNameImage.backingSize.height))
                }
                
               
                
                if case let .colorSelector(stateback) = item.type {
                    ctx.setFillColor(stateback.cgColor)
                    ctx.fillEllipse(in: NSMakeRect(containerView.frame.width - 14 - insets.right, floorToScreenPixels(backingScaleFactor, (containerView.frame.height - 14) / 2), 14, 14))
                }
            }
        }
    }
    
   
    
    required init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        
        containerView.layerContentsRedrawPolicy = .duringViewResize
        
        nextView.sizeToFit()
        containerView.addSubview(nextView)
        self.containerView.displayDelegate = self
        self.addSubview(self.containerView)
        
        containerView.addSubview(nameView)
        
        nameView.userInteractionEnabled = false
        nameView.isSelectable = false
        
        
        containerView.set(handler: { [weak self] _ in
            self?.updateColors()
        }, for: .Highlight)
        containerView.set(handler: { [weak self] _ in
            self?.updateColors()
        }, for: .Normal)
        containerView.set(handler: { [weak self] _ in
            self?.updateColors()
        }, for: .Hover)
        
        containerView.set(handler: { [weak self] _ in
            self?.invokeIfNeededDown()
        }, for: .Down)
        
        containerView.set(handler: { [weak self] _ in
            if let event = NSApp.currentEvent {
                self?.mouseDragged(with: event)
            }
        }, for: .MouseDragging)
        
        containerView.set(handler: { [weak self] _ in
            self?.invokeIfNeededUp()
        }, for: .Up)
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    func invokeAction(_ item: GeneralInteractedRowItem) {
        if item.enabled {
            if let textView = self.textView {
                switch item.type {
                case let .contextSelector(_, items):
                    if let event = NSApp.currentEvent {
                        let menu = ContextMenu()

                        for item in items {
                            menu.addItem(item)
                        }
                        AppMenu.show(menu: menu, event: event, for: textView)
                    }
                    
                    return
                default:
                    break
                }
            }
            
            switch item.type {
            case let .switchable(enabled):
                if item.autoswitch && item.switchAction == nil {
                    item.type = .switchable(!enabled)
                    self.switchView?.send(event: .Click)
                    return
                }
            default:
                break
            }
            item.action()
        } else {
            if let action = item.disabledAction {
                action()
            }
        }
    }
    private func invokeIfNeededUp() {
        if let event = NSApp.currentEvent {
            guard let item = item as? GeneralInteractedRowItem else {
                return
            }
            if case .contextSelector = item.type {
                
            } else if let table = item.table, table.alwaysOpenRowsOnMouseUp, containerView.mouseInside() {
                invokeAction(item)
            } else {
                super.mouseUp(with: event)
            }
        }
        
    }
    private func invokeIfNeededDown() {
        if let event = NSApp.currentEvent {
            guard let item = item as? GeneralInteractedRowItem else {
                return
            }
            if case .contextSelector = item.type {
                invokeAction(item)
            } else if let table = item.table, !table.alwaysOpenRowsOnMouseUp, containerView.mouseInside() {
                invokeAction(item)
            } else {
                super.mouseDown(with: event)
            }
        }
    }
    
    
    override func layout() {
        super.layout()
        
        
        if let item = item as? GeneralInteractedRowItem {
            let insets = item.inset
                        
            switch item.viewType {
            case .legacy:
                self.containerView.frame = bounds
                self.containerView.setCorners([])
                if let descriptionView = descriptionView {
                    descriptionView.setFrameOrigin(insets.left + textXAdditional, floorToScreenPixels(backingScaleFactor, frame.height - descriptionView.frame.height - 6))
                }
                let nextInset = nextView.isHidden ? 0 : nextView.frame.width + 6 + (insets.right == 0 ? 10 : 0)
                
                if let switchView = switchView {
                    switchView.centerY(x:frame.width - insets.right - switchView.frame.width - nextInset, addition: -1)
                }
                
                if let badgeView = badgeView {
                    badgeView.centerY(x:frame.width - insets.right - badgeView.frame.width - nextInset, addition: -1)
                }
                
                let nameLayout = (item.isSelected ? item.nameLayoutSelected : item.nameLayout)
                
                var textRect = focus(NSMakeSize(nameLayout.layoutSize.width, nameLayout.layoutSize.height))
                textRect.origin.x = item.inset.left + textXAdditional
                textRect.origin.y -= 2
                if item.descLayout != nil {
                    textRect.origin.y = 10
                }
                nameView.setFrameOrigin(textRect.origin)
                
                if let textView = textView {
                    var width:CGFloat = containerView.frame.width - item.nameLayout.layoutSize.width - nextInset - insets.right - insets.left - 10
                    textView.textLayout?.measure(width: width)
                    textView.update(textView.textLayout)
                    textView.centerY(x: containerView.frame.width - insets.right - textView.frame.width - nextInset, addition: -1)
                    if !nextView.isHidden {
                        textView.setFrameOrigin(textView.frame.minX,textView.frame.minY - 1)
                    }
                }
                if let current = self.imageContext {
                    current.centerY(x: containerView.frame.width - insets.right - current.frame.width - nextInset)
                    if !nextView.isHidden {
                        current.setFrameOrigin(current.frame.minX, current.frame.minY - 2)
                    }
                }
                
                nextView.centerY(x: frame.width - (insets.right == 0 ? 10 : insets.right) - nextView.frame.width)
                if let progressView = progressView {
                    progressView.centerY(x: frame.width - (insets.right == 0 ? 10 : insets.right) - progressView.frame.width, addition: -1)
                }
            case let .modern(_, innerInsets):
                self.containerView.frame = NSMakeRect(floorToScreenPixels(backingScaleFactor, (frame.width - item.blockWidth) / 2), insets.top, item.blockWidth, frame.height - insets.bottom - insets.top)
                
                
                self.containerView.setCorners(self.isResorting ? GeneralViewItemCorners.all : item.viewType.corners)
                
                if let current = self.selectLeftControl {
                    current.centerY(x: innerInsets.left)
                }
                
                if let descriptionView = self.descriptionView {
                    descriptionView.setFrameOrigin(innerInsets.left + textXAdditional, containerView.frame.height - descriptionView.frame.height - 5)
                }
                var nextInset = nextView.isHidden ? 0 : nextView.frame.width + 6
                
                if let switchView = switchView {
                    switchView.centerY(x: containerView.frame.width - innerInsets.right - switchView.frame.width - nextInset, addition: -1)
                }
                
                let nameLayout = (item.isSelected ? item.nameLayoutSelected : item.nameLayout)
                
                var textRect = focus(NSMakeSize(nameLayout.layoutSize.width, nameLayout.layoutSize.height))
                textRect.origin.x = innerInsets.left + textXAdditional
                if item.descLayout == nil {
                    textRect.origin.y = innerInsets.top - 1
                } else {
                    textRect.origin.y = 5
                }
                
                nameView.setFrameOrigin(textRect.origin)

                
                if let textView = textView {
                    var width:CGFloat = containerView.frame.width - item.nameLayout.layoutSize.width - innerInsets.right - insets.left - 10
                    textView.textLayout?.measure(width: width)
                    textView.update(textView.textLayout)
                    textView.centerY(x: containerView.frame.width - innerInsets.right - textView.frame.width - nextInset)
                    if !nextView.isHidden {
                        textView.setFrameOrigin(textView.frame.minX, textView.frame.minY - 1)
                    }
                }
                if let current = self.imageContext {
                    current.centerY(x: containerView.frame.width - innerInsets.right - current.frame.width - nextInset)
                    if !nextView.isHidden {
                        current.setFrameOrigin(current.frame.minX, current.frame.minY - 2)
                    }
                }
                
                if let textView = textView {
                    nextInset += textView.frame.width + 10
                }
                nextView.centerY(x: containerView.frame.width - innerInsets.right - nextView.frame.width, addition: -1)
                if let progressView = progressView {
                    progressView.centerY(x: containerView.frame.width - innerInsets.right - progressView.frame.width, addition: -1)
                }
                
                if let badgeView = badgeView {
                    badgeView.centerY(x: containerView.frame.width - innerInsets.right - badgeView.frame.width - nextInset, addition: -1)
                }
                
                if let imageView = self.rightIconView {
                    imageView.centerY(x: containerView.frame.width - imageView.frame.width - nextInset - 10)
                }
            }
        }
    }
    
}
