//
//  TextAndLabelItem.swift
//  Telegram-Mac
//
//  Created by keepcoder on 12/10/2016.
//  Copyright © 2016 Telegram. All rights reserved.
//

import Cocoa
import TGUIKit
import TelegramCore

import Postbox
import SwiftSignalKit

class TextAndLabelItem: GeneralRowItem {


    
    private var labelStyle:ControlStyle = ControlStyle()
    private var textStyle:ControlStyle = ControlStyle()

    private var label:NSAttributedString
    
    var labelLayout:(TextNodeLayout, TextNode)?
    var textLayout:TextViewLayout
    let isTextSelectable:Bool
    let callback:()->Void
    let canCopy: Bool
    
    
    var hasMore: Bool? = true {
        didSet {
            if hasMore == nil {
                textLayout.maximumNumberOfLines = 0
                textLayout.cutout = nil
                _ = makeSize(width, oldWidth: 0)
                
                if let table = self.table {
                    table.enumerateItems { item -> Bool in
                        item.table?.reloadData(row: item.index, animated: true)
                        return true
                    }
                }

            }
        }
    }
    
    let moreLayout: TextViewLayout
    let copyMenuText: String
    let _copyToClipboard:(()->Void)?
    let accentColor: NSColor
    let hideText: Bool?
    let toggleHide:(()->Void)?
    let borderColor: NSColor
    init(_ initialSize:NSSize, stableId:AnyHashable, label:String, copyMenuText: String, labelColor: NSColor = theme.colors.accent, textColor: NSColor = theme.colors.text, backgroundColor: NSColor = theme.colors.background, text:String, context: AccountContext?, viewType: GeneralViewType = .legacy, detectLinks:Bool = false, onlyInApp: Bool = false, isTextSelectable:Bool = true, callback:@escaping ()->Void = {}, openInfo:((PeerId, Bool, MessageId?, ChatInitialAction?)->Void)? = nil, hashtag:((String)->Void)? = nil, selectFullWord: Bool = false, canCopy: Bool = true, _copyToClipboard:(()->Void)? = nil, textFont: NSFont = .normal(.title), hideText: Bool? = nil, toggleHide: (()->Void)? = nil, accentColor: NSColor = theme.colors.accent, borderColor: NSColor = theme.colors.border, linkInteractions: TextViewInteractions = globalLinkExecutor) {
        self.callback = callback
        self.accentColor = accentColor
        self.hideText = hideText
        self.toggleHide = toggleHide
        self.isTextSelectable = isTextSelectable
        self.copyMenuText = copyMenuText
        self.borderColor = borderColor
        self.label = NSAttributedString.initialize(string: label, color: labelColor, font: .normal(FontSize.text))
        let attr = NSMutableAttributedString()
        var text = text.trimmed.fullTrimmed
        text = hideText == true ? Array(repeating: "*", count: text.count / 2).joined() : text
        _ = attr.append(string: text, color: textColor, font: textFont)
        if detectLinks, let context = context {
            attr.detectLinks(type: [.Links, .Hashtags, .Mentions], onlyInApp: onlyInApp, context: context, color: theme.colors.link, openInfo: openInfo, hashtag: hashtag, applyProxy: { settings in
                applyExternalProxy(settings, accountManager: context.sharedContext.accountManager)
            })
        }
        self.canCopy = canCopy
        if canCopy {
            self._copyToClipboard = _copyToClipboard
        } else {
            self._copyToClipboard = nil
        }
        
        textLayout = TextViewLayout(attr, maximumNumberOfLines: 3, alwaysStaticItems: !detectLinks)
        textLayout.interactions = linkInteractions
        textLayout.selectWholeText = !detectLinks
        if selectFullWord {
            textLayout.interactions.copy = {
                copyToClipboard(text)
                return true
            }
        }
        
        var showFull:(()->Void)? = nil
        
        let moreAttr = parseMarkdownIntoAttributedString(strings().peerInfoShowMoreText, attributes: MarkdownAttributes(body: MarkdownAttributeSet(font: .normal(.title), textColor: textColor), bold: MarkdownAttributeSet(font: .bold(.title), textColor: textColor), link: MarkdownAttributeSet(font: .normal(.title), textColor: theme.colors.link), linkAttribute: { contents in
            return (NSAttributedString.Key.link.rawValue, inAppLink.callback(contents, { _ in
                showFull?()
            }))
        }))
        self.moreLayout = TextViewLayout(moreAttr)
        self.moreLayout.interactions = globalLinkExecutor
        
        
        self.moreLayout.measure(width: .greatestFiniteMagnitude)
        super.init(initialSize,stableId: stableId, type: .none, viewType: viewType, action: callback, drawCustomSeparator: true, backgroundColor: backgroundColor)
        
        showFull = { [weak self] in
            self?.hasMore = nil
        }
    }
    
    override func viewClass() -> AnyClass {
        return TextAndLabelRowView.self
    }
    
    var textWidth:CGFloat {
        switch viewType {
        case .legacy:
            return width - inset.left - inset.right - (_copyToClipboard != nil ? 30 : 0)
        case let .modern(_, inner):
            return blockWidth - inner.left - inner.right - (_copyToClipboard != nil ? 30 : 0)
        }
    }
    
    override var height: CGFloat {
        switch viewType {
        case .legacy:
            return labelsHeight + 20
        case let .modern(_, insets):
            return labelsHeight + insets.top + insets.bottom - 4
        }
    }
    
    var labelsHeight:CGFloat {
        var inset:CGFloat = 0
        if let labelLayout = labelLayout {
            inset = labelLayout.0.size.height
        }
        return (textLayout.layoutSize.height + inset + 4)
    }
    
    var textY:CGFloat {
        var inset:CGFloat = 0
        if let labelLayout = labelLayout {
            inset = labelLayout.0.size.height
        }
        return ((height - labelsHeight) / 2.0) + inset + 4.0
    }
    
    var labelY:CGFloat {
        return (height - labelsHeight) / 2.0
    }
    
    override func menuItems(in location: NSPoint) -> Signal<[ContextMenuItem], NoError> {
        if !canCopy {
            return .single([])
        } else {
            return .single([ContextMenuItem(self.copyMenuText, handler: { [weak self] in
                if let strongSelf = self {
                    if let _copyToClipboard = strongSelf._copyToClipboard {
                        _copyToClipboard()
                    } else {
                        copyToClipboard(strongSelf.textLayout.attributedString.string)
                    }
                }
            }, itemImage: MenuAnimation.menu_copy.value)])
        }
       
    }
//
    override func makeSize(_ width: CGFloat, oldWidth:CGFloat) -> Bool {
        let result = super.makeSize(width, oldWidth: oldWidth)
        textLayout.measure(width: textWidth)
        
        if hasMore != nil {
            hasMore = !textLayout.isPerfectSized
        }
        if hasMore == true {
            textLayout.cutout = TextViewCutout(bottomRight: NSMakeSize(moreLayout.layoutSize.width + 10, 0))
            textLayout.measure(width: textWidth)
        }
        
        labelLayout = TextNode.layoutText(maybeNode: nil,  label, nil, 1, .end, NSMakeSize(textWidth, .greatestFiniteMagnitude), nil, false, .left)
        return result
    }
    
}

class TextAndLabelRowView: GeneralRowView {
    private let containerView = GeneralRowContainerView(frame: NSZeroRect)
    private var labelView:TextView = TextView()
    private let moreView: TextView = TextView()
    private let copyView: ImageButton = ImageButton()
    private let toggleVisibility = ImageButton()
    override func draw(_ layer: CALayer, in ctx: CGContext) {
        
        if let item = item as? TextAndLabelItem, let label = item.labelLayout, layer == containerView.layer {
            switch item.viewType {
            case .legacy:
                label.1.draw(NSMakeRect(item.inset.left, item.labelY, label.0.size.width, label.0.size.height), in: ctx, backingScaleFactor: backingScaleFactor, backgroundColor: backdorColor)
                if item.drawCustomSeparator {
                    ctx.setFillColor(item.borderColor.cgColor)
                    ctx.fill(NSMakeRect(item.inset.left, frame.height - .borderSize, frame.width - item.inset.left - item.inset.right, .borderSize))
                }
            case let .modern(position, insets):
                label.1.draw(NSMakeRect(insets.left, item.labelY, label.0.size.width, label.0.size.height), in: ctx, backingScaleFactor: backingScaleFactor, backgroundColor: backdorColor)
                if position.border {
                    ctx.setFillColor(item.borderColor.cgColor)
                    ctx.fill(NSMakeRect(insets.left, self.containerView.frame.height - .borderSize, self.containerView.frame.width - insets.left - insets.right, .borderSize))
                }
            }
        }
        
    }
    
    
    
    override var backdorColor: NSColor {
        if let item = item as? TextAndLabelItem {
            return item.backgroundColor
        } else {
            return theme.colors.background
        }
    }
    override func updateColors() {
        if let item = item as? TextAndLabelItem {
            self.labelView.backgroundColor = backdorColor
            self.containerView.backgroundColor = backdorColor
            self.background = item.viewType.rowBackground
        }
    }
    
    override func mouseUp(with event: NSEvent) {
        if mouseInside() {
            if let item = item as? TextAndLabelItem {
                item.action()
            }
        } else {
            super.mouseUp(with: event)
        }
    }
    

    
    required init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        containerView.addSubview(labelView)
        containerView.addSubview(toggleVisibility)
        
        toggleVisibility.scaleOnClick = true
        toggleVisibility.autohighlight = false
        
        self.addSubview(self.containerView)
        self.containerView.displayDelegate = self
        self.containerView.userInteractionEnabled = false
        containerView.addSubview(moreView)
        labelView.set(handler: { [weak self] _ in
            if let item = self?.item as? TextAndLabelItem {
                item.action()
            }
        }, for: .Click)
        
        copyView.autohighlight = true
        
        copyView.set(handler: { [weak self] _ in
            if let item = self?.item as? TextAndLabelItem {
                item._copyToClipboard?()
            }
        }, for: .Click)
        
        toggleVisibility.set(handler: { [weak self] _ in
            if let item = self?.item as? TextAndLabelItem {
                item.toggleHide?()
            }
        }, for: .Click)
        
        containerView.addSubview(copyView)
    }
    
    override func layout() {
        super.layout()
        if let item = item as? TextAndLabelItem {
            switch item.viewType {
            case .legacy:
                self.containerView.frame = bounds

                if let _ = item.labelLayout {
                    labelView.setFrameOrigin(item.inset.left, item.textY)
                } else {
                    labelView.centerY(x:item.inset.left)
                }
                
                if let label = item.labelLayout {
                    toggleVisibility.setFrameOrigin(NSMakePoint(item.inset.left + label.0.size.width + 3, item.labelY))
                }
                copyView.centerY(x: containerView.frame.width - copyView.frame.width - item.inset.left)
            case let .modern(_, innerInsets):
                self.containerView.frame = NSMakeRect(floorToScreenPixels(backingScaleFactor, (frame.width - item.blockWidth) / 2), item.inset.top, item.blockWidth, frame.height - item.inset.bottom - item.inset.top)

                if let _ = item.labelLayout {
                    labelView.setFrameOrigin(innerInsets.left, item.textY)
                } else {
                    labelView.centerY(x: innerInsets.left)
                }
                
                if let label = item.labelLayout {
                    toggleVisibility.setFrameOrigin(NSMakePoint(innerInsets.left + label.0.size.width + 3, item.labelY))
                }
                
                copyView.centerY(x: containerView.frame.width - copyView.frame.width - innerInsets.right)

                moreView.setFrameOrigin(NSMakePoint(containerView.frame.width - moreView.frame.width - innerInsets.right, containerView.frame.height - innerInsets.bottom - moreView.frame.height + 2))
            }
            self.containerView.setCorners(item.viewType.corners)

        }
        
    }
    
    
    override func set(item:TableRowItem, animated:Bool = false) {
        super.set(item: item, animated: animated)
        
        if let item = item as? TextAndLabelItem {
           // labelView.userInteractionEnabled = item.isTextSelectable
            labelView.userInteractionEnabled = item.canCopy
            labelView.isSelectable = item.isTextSelectable
            labelView.update(item.textLayout)
            
            moreView.isHidden = item.hasMore != true
            moreView.update(item.moreLayout)
            
            copyView.set(image: NSImage(named: "Icon_FastCopyLink")!.precomposed(item.accentColor), for: .Normal)
            copyView.sizeToFit()
            copyView.scaleOnClick = true
            copyView.isHidden = item._copyToClipboard == nil
            toggleVisibility.isHidden = item.hideText == nil
            
            if let hideText = item.hideText {
                toggleVisibility.set(image: NSImage(named: hideText ? "Icon_Eye_On" : "Icon_Eye_Off")!.precomposed(item.accentColor), for: .Normal)
                toggleVisibility.sizeToFit()
            }
            
        }
        containerView.needsDisplay = true
        needsLayout = true
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    
}
