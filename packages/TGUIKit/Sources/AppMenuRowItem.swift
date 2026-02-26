//
//  File.swift
//  
//
//  Created by Mikhail Filimonov on 06.12.2021.
//

import Foundation
import AppKit
import SwiftSignalKit

public protocol AppMenuItemImageDrawable : NSView {
    func updateState(_ controlState: ControlState)
    func setColor(_ color: NSColor)
    func isEqual(to other: ContextMenuItem) -> Bool
}

open class AppMenuBasicItem : TableRowItem {
    
    public struct Interaction {
        public let action:(ContextMenuItem)->Void
        public let presentSubmenu:(ContextMenuItem)->Void
        public let cancelSubmenu:(ContextMenuItem)->Void
        public let hover:(ContextMenuItem)->Void
        public let close:()->Void
    }
    
    fileprivate(set) public var menuItem: ContextMenuItem?
    fileprivate(set) public var interaction: Interaction?
    public let presentation: AppMenu.Presentation

    public init(_ initialSize: NSSize, presentation: AppMenu.Presentation, menuItem: ContextMenuItem? = nil, interaction: Interaction? = nil) {
        self.menuItem = menuItem
        self.interaction = interaction
        self.presentation = presentation
        super.init(initialSize)
    }
    
    public var searchable: String {
        return ""
    }
        
    open override var height: CGFloat {
        return 4
    }
    open var effectiveSize: NSSize {
        return NSMakeSize(0, height)
    }
    open override var stableId: AnyHashable {
        return arc4random64()
    }
    open override func viewClass() -> AnyClass {
        return AppMenuBasicItemView.self
    }
}
open class AppMenuBasicItemView: TableRowView {
    
    public let containerView = Control()

    public required init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        super.addSubview(containerView)
        containerView.layer?.cornerRadius = .cornerRadius
    }
    
    required public init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    open override func addSubview(_ view: NSView) {
        containerView.addSubview(view)
    }
    
    open override func layout() {
        super.layout()
        containerView.frame = bounds.insetBy(dx: 4, dy: 0)
    }
    
    public var contentSize: NSSize {
        return containerView.frame.size
    }
    
    deinit {
        containerView.removeAllSubviews()
    }
    
    open override var backdorColor: NSColor {
        return .clear
    }
}


public class AppMenuSeparatorItem : AppMenuBasicItem {
    
    public init(_ initialSize: NSSize, presentation: AppMenu.Presentation) {
        super.init(initialSize, presentation: presentation)
    }
    
    public override var height: CGFloat {
        return 5
    }
    public override var effectiveSize: NSSize {
        return NSMakeSize(0, height)
    }
    public override var stableId: AnyHashable {
        return arc4random64()
    }
    public override func viewClass() -> AnyClass {
        return AppMenuSeparatorItemView.self
    }
}
private final class AppMenuSeparatorItemView: AppMenuBasicItemView {
    private let view: View = View()
    required init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        addSubview(view)
    }
    required public init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    override var backdorColor: NSColor {
        return .clear
    }
    
    override func updateColors() {
        super.updateColors()
        guard let item = item as? AppMenuSeparatorItem else {
            return
        }
        view.backgroundColor = item.presentation.borderColor
    }
    
    override func layout() {
        super.layout()
        view.frame = NSMakeRect(11, 2, containerView.frame.width - 22, 1)
    }
    
    override func set(item: TableRowItem, animated: Bool = false) {
        super.set(item: item, animated: animated)
    }
}


open class AppMenuRowItem : AppMenuBasicItem {
    public let item: ContextMenuItem
    public private(set) var text: TextViewLayout
    public let leftInset: CGFloat = 11
    public let innerInset: CGFloat = 4
    public let moreSize: NSSize = NSMakeSize(6, 8)
    public let selectedSize: NSSize = NSMakeSize(9, 8)
    
    fileprivate let keyEquivalentText: TextViewLayout?
    
    private var observation_i: NSKeyValueObservation?
    private var observation_t: NSKeyValueObservation?
    public init(_ initialSize: NSSize, item: ContextMenuItem, interaction: Interaction, presentation: AppMenu.Presentation) {
        self.item = item
        let textColor = presentation.primaryColor(item)
        
        let attr: NSAttributedString

        if let attribted = item.attributedTitle {
            attr = attribted
        } else {
            attr = parseMarkdownIntoAttributedString(item.title, attributes: MarkdownAttributes(body: MarkdownAttributeSet(font: .medium(.text), textColor: textColor), bold: MarkdownAttributeSet(font: .bold(.text), textColor: textColor), link: MarkdownAttributeSet(font: .bold(.text), textColor: presentation.colors.accentIcon), linkAttribute: { contents in
                return (NSAttributedString.Key.link.rawValue, contents)
            }))
        }
        
        
        self.text = TextViewLayout(attr, maximumNumberOfLines: item.removeTail ? 1 : .max)
        
        if item.keyEquivalent.isEmpty {
            keyEquivalentText = nil
        } else {
            keyEquivalentText = TextViewLayout(.initialize(string: item.keyEquivalent, color: presentation.secondaryColor(item), font: .medium(.text)))
        }
        super.init(initialSize, presentation: presentation, menuItem: item, interaction: interaction)
        self.menuItem = item
        self.observation_i = item.observe(\.image, options: .new, changeHandler: { [weak self] object, change in
            self?.redraw(animated: true)
        })
        self.observation_t = item.observe(\.title, options: .new, changeHandler: { [weak self] object, change in
            self?.redraw(animated: true)
        })
        item.redraw = { [weak self] in
            self?.redraw(animated: true)
        }
    }
    
    open var imageSize: CGFloat {
        return 18
    }

    
    public override var searchable: String {
        return item.title
    }
    
    public override func redraw(animated: Bool = false, options: NSTableView.AnimationOptions = .effectFade, presentAsNew: Bool = false) {
        let textColor = presentation.primaryColor(item)
        let attr = parseMarkdownIntoAttributedString(item.title, attributes: MarkdownAttributes(body: MarkdownAttributeSet(font: .medium(.text), textColor: textColor), bold: MarkdownAttributeSet(font: .bold(.text), textColor: textColor), link: MarkdownAttributeSet(font: .bold(.text), textColor: presentation.colors.accentIcon), linkAttribute: { contents in
            return (NSAttributedString.Key.link.rawValue, contents)
        }))
        
        self.text = TextViewLayout(attr, maximumNumberOfLines: item.removeTail ? 1 : .max)
        
        _ = makeSize(self.width)
        
        super.redraw(animated: animated, options: options, presentAsNew: presentAsNew)
        
    }
    
    public var drawable: AppMenuItemImageDrawable? {
        return item.itemImage?(presentation.primaryColor(item), item)
    }
    
    deinit {
        self.observation_i?.invalidate()
        self.observation_t?.invalidate()
    }
    
    var hasDrawable: Bool {
        if let menu = item.menu {
            
            var range: NSRange = NSMakeRange(NSNotFound, 0)
            for (i, item) in menu.items.enumerated() {
                if item === self.item {
                    range.location = i
                    range.length = 1
                } else if range.location != NSNotFound {
                    if item is ContextSeparatorItem {
                        break
                    } else {
                        range.length += 1
                    }
                }
            }
            if range.location != NSNotFound, range.location > 0 {
                for i in stride(from: range.location - 1, to: -1, by: -1) {
                    let item = menu.items[i]
                    if item is ContextSeparatorItem {
                        break
                    } else {
                        range.location -= 1
                        range.length += 1
                    }
                }
            }
            let blockItems = menu.items[range.min ..< range.max]
            
            return blockItems.compactMap { $0 as? ContextMenuItem }.contains(where: { $0.itemImage != nil })
        }
        return false
    }
    
    open var textSize: CGFloat {
        return text.layoutSize.width + leftInset * 2 + innerInset * 2
    }
    
    open override var effectiveSize: NSSize {
        var defaultSize = NSMakeSize(textSize, height)
        
        if let _ = self.item.image {
            defaultSize.width += imageSize + leftInset - 2
        } else if imageSize != 18 {
            defaultSize.width += imageSize + leftInset - 2
        }
        
        if hasDrawable {
            defaultSize.width += imageSize + leftInset - 2
        }
        if let keyEquivalentText = keyEquivalentText {
            defaultSize.width += keyEquivalentText.layoutSize.width + 6
        }
        
        if item.submenu != nil {
            defaultSize.width += moreSize.width + leftInset
        }
        if item.state == .on {
            defaultSize.width += selectedSize.width + leftInset
        }
        return defaultSize
    }
    
    open override var height: CGFloat {
        if self.text.lines.count <= 1 {
            return 28
        } else {
            return self.text.layoutSize.height + 8
        }
    }
    
    open var textMaxWidth: CGFloat {
        let width = item.overrideWidth ?? width
        return width - leftInset * 2 - innerInset * 2
    }
    
    open override func makeSize(_ width: CGFloat = CGFloat.greatestFiniteMagnitude, oldWidth: CGFloat = 0) -> Bool {
        _ = super.makeSize(width, oldWidth: oldWidth)
        let width = item.overrideWidth ?? width
        self.text.measure(width: textMaxWidth)
        self.keyEquivalentText?.measure(width: .greatestFiniteMagnitude)
        return true
    }
    
    open override var stableId: AnyHashable {
        return item.id
    }
    open override func viewClass() -> AnyClass {
        return AppMenuRowView.self
    }
}

open class AppMenuRowView: AppMenuBasicItemView {
    private var textView: TextView?
    private var customTextView: NSView?
    private var imageView: ImageView? = nil
    private var keyEquivalent: TextView? = nil
    private var drawable: AppMenuItemImageDrawable? = nil
    private var more: ImageView? = nil
    private var lockView: ImageView? = nil
    
    public let contentView = View()
    
    private let hoverDisposable = MetaDisposable()
    
    public required init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        super.addSubview(contentView)

        containerView.scaleOnClick = true

        containerView.layer?.cornerRadius = .cornerRadius
        containerView.scaleOnClick = true
        
        let CheckWindow:() -> Bool = { [weak self] in
            let wNumber = NSWindow.windowNumber(at: NSEvent.mouseLocation, belowWindowWithWindowNumber: 0)
            guard wNumber == self?.window?.windowNumber else {
                return false
            }
            return true
        }
        
        containerView.set(handler: { [weak self] _ in
            guard let item = self?.item as? AppMenuRowItem, CheckWindow() else {
                return
            }
            item.interaction?.presentSubmenu(item.item)
        }, for: .Hover)
        
        
        containerView.set(handler: { [weak self] _ in
            guard let item = self?.item as? AppMenuRowItem else {
                return
            }
            if !CheckWindow() {
                return
            }
            if item.item.isEnabled {
                self?.drawable?.updateState(.Hover)
                self?.updateState(.Hover)
            }
           
            
            self?.hoverDisposable.set(delaySignal(0.5).start(completed: {
                guard let item = self?.item as? AppMenuRowItem else {
                    return
                }
                item.interaction?.hover(item.item)
            }))
            
        }, for: .Hover)
        containerView.set(handler: { [weak self] _ in
            guard let item = self?.item as? AppMenuRowItem else {
                return
            }
            if !CheckWindow() {
                return
            }
            if item.item.isEnabled {
                self?.drawable?.updateState(.Highlight)
                self?.updateState(.Highlight)
            }
            self?.hoverDisposable.set(nil)
        }, for: .Highlight)
        containerView.set(handler: { [weak self] _ in
            if !CheckWindow() {
                return
            }
            self?.drawable?.updateState(.Normal)
            self?.updateState(.Normal)
            self?.hoverDisposable.set(nil)
        }, for: .Normal)
        containerView.set(handler: { [weak self] _ in
            if !CheckWindow() {
                return
            }
            self?.drawable?.updateState(.Other)
            self?.updateState(.Other)
            self?.hoverDisposable.set(nil)
        }, for: .Other)
           
        containerView.set(handler: { [weak self] _ in
            if !CheckWindow() {
                return
            }
            self?.invokeClick()
        }, for: .SingleClick)
        
        containerView.set(handler: { [weak self] _ in
            if !CheckWindow() {
                return
            }
            self?.invokeClick()
        }, for: .RightDown)
    }
    
    open func invokeClick() {
        guard let item = self.item as? AppMenuRowItem else {
            return
        }
        item.interaction?.action(item.item)
    }
    
    open override func addSubview(_ view: NSView) {
        contentView.addSubview(view)
    }
    
    private var previous: ControlState = .Normal
    open func updateState(_ state: ControlState) {
      
    }
    
    open override func mouseDown(with event: NSEvent) {
        
    }
    open override func mouseUp(with event: NSEvent) {
        var bp = 0
        bp += 1
    }
    open override func cursorUpdate(with event: NSEvent) {
        super.cursorUpdate(with: event)
        NSCursor.arrow.set()
    }
    
    open override func updateMouse(animated: Bool) {
        super.updateMouse(animated: animated)
        updateColors()
        containerView.updateState()
    }

    
    open override func updateColors() {
        super.updateColors()
        guard let item = item as? AppMenuRowItem, let table = item.table else {
            return
        }
        containerView.isSelected = item.isSelected
        
        
        let canHighlight = table.selectedItem() == nil || item.isSelected
        containerView.isEnabled = item.item.isEnabled && canHighlight

        containerView.set(background: canHighlight ? item.presentation.highlightColor : .clear, for: .Hover)
        containerView.set(background: .clear, for: .Normal)
        containerView.set(background: canHighlight ? item.presentation.highlightColor : .clear, for: .Highlight)
        
        
    }
    
    public required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    public var textX: CGFloat {
        guard let item = item as? AppMenuRowItem else {
            return 0
        }
        if let _ = drawable {
            return item.leftInset + item.imageSize + item.leftInset - 2
        } else if let _ = imageView {
            return item.leftInset + item.imageSize + item.leftInset - 2
        } else if item.hasDrawable {
            return item.leftInset + item.imageSize + item.leftInset - 2
        } else {
            return item.leftInset
        }
    }
    
    open var textY: CGFloat {
        guard let item = item as? AppMenuRowItem else {
            return 0
        }
        return focus(item.text.layoutSize).minY
    }
    
    public var rightX: CGFloat {
        guard let item = item as? AppMenuRowItem else {
            return 0
        }
        var right: CGFloat = containerView.frame.width - item.leftInset
        if item.item.submenu != nil {
            right -= (item.moreSize.width + 2)
        }
        return right
    }
    
    public var imageFrame: NSRect {
        return imageView?.frame ?? .zero
    }
    
    open override func layout() {
        super.layout()
        
        contentView.setFrameSize(containerView.frame.size)
        
        guard let item = item as? AppMenuRowItem else {
            return
        }
        
        if let drawable = drawable {
            if item.text.numberOfLines == 1 {
                drawable.centerY(x: item.leftInset)
            } else {
                drawable.setFrameOrigin(NSMakePoint(item.leftInset, 4))
            }
            currentTextView?.setFrameOrigin(NSMakePoint(drawable.frame.maxX + item.leftInset - 2, textY))
        } else if let imageView = imageView {
            imageView.centerY(x: item.leftInset)
            currentTextView?.setFrameOrigin(NSMakePoint(imageView.frame.maxX + item.leftInset - 2, textY))
        } else if item.hasDrawable {
            currentTextView?.setFrameOrigin(NSMakePoint(item.leftInset + item.imageSize + item.leftInset - 2, textY))
        } else {
            currentTextView?.setFrameOrigin(NSMakePoint(item.leftInset, textY))
        }
        if let more = more {
            more.centerY(x: containerView.frame.width - item.leftInset - more.frame.width)
        }
        
        if let keyEquivalent = keyEquivalent {
            keyEquivalent.centerY(x: self.rightX - keyEquivalent.frame.width)
        }
        
        if let lockView = lockView {
            lockView.setFrameOrigin(textX + item.text.layoutSize.width, textY)
        }
    }
    open override func viewDidMoveToWindow() {
        super.viewDidMoveToWindow()
      //  self.drawable?.updateState(.Hover)
    }
    
    var currentTextView: NSView? {
        return textView ?? customTextView
    }
    
    open override func set(item: TableRowItem, animated: Bool = false) {
        super.set(item: item, animated: animated)
        
        guard let item = item as? AppMenuRowItem else {
            return
        }
        
        
        if let customTextView = item.item.customTextView?() {
            self.customTextView?.removeFromSuperview()
            self.customTextView = customTextView
            addSubview(customTextView)
            if let textView {
                performSubviewRemoval(textView, animated: animated)
                self.textView = nil
            }
        } else {
            if let customTextView {
                performSubviewRemoval(customTextView, animated: animated)
                self.customTextView = nil
            }
            let current: TextView
            if let view = self.textView {
                current = view
            } else {
                current = TextView()
                self.textView = current
                self.addSubview(current)
                current.userInteractionEnabled = false
                current.isSelectable = false
                current.disableBackgroundDrawing = true
                current.isEventLess = true
            }
            current.update(item.text)
        }
        
        let isEnabled = item.menuItem?.isEnabled == true
        
        
        if item.menuItem?.locked == true {
            let current: ImageView
            if let view = self.lockView {
                current = view
            } else {
                current = ImageView()
                addSubview(current)
                self.lockView = current
            }
            current.image = NSImage(named: "Icon_EmojiLock")?.precomposed(isEnabled ? item.presentation.textColor : item.presentation.disabledTextColor)
            current.sizeToFit()
        } else if let view = self.lockView {
            performSubviewRemoval(view, animated: animated)
            self.lockView = nil
        }
        
        currentTextView?._change(opacity: item.item.title.isEmpty ? 0 : 1, animated: animated)
        
        let drawable: AppMenuItemImageDrawable?
        if let current = self.drawable, current.isEqual(to: item.item) {
            drawable = current
        } else if let current = item.drawable {
            drawable = current
            self.drawable = drawable
        } else {
            drawable = nil
        }
        
        if let drawable = drawable {
            if drawable.superview != containerView {
                contentView.addSubview(drawable)
            }
        } else if let current = self.drawable {
            self.drawable = nil
            performSubviewRemoval(current, animated: animated)
        }
        
        
        if let image = item.item.image {
            let current: ImageView
            if let view = self.imageView {
                current = view
            } else {
                current = ImageView()
                current.setFrameSize(item.imageSize, item.imageSize)
                current.isEventLess = true
                containerView.addSubview(current)
                self.imageView = current
            }
            current.layer?.contents = image
            current.layer?.opacity = item.item.isEnabled ? 1 : 0.4
        } else if let view = self.imageView {
            self.imageView = nil
            performSubviewRemoval(view, animated: animated)
        }
        
        if item.item.submenu != nil || item.item.state == .on {
            let current: ImageView
            if let view = self.more {
                current = view
            } else {
                current = ImageView()
                if item.item.state == .on {
                    current.setFrameSize(item.selectedSize)
                } else {
                    current.setFrameSize(item.moreSize)
                }
                current.layer?.masksToBounds = false
                current.contentGravity = .center
                contentView.addSubview(current)
                self.more = current
            }
            let stateOnImage = item.item.stateOnImage?.precomposed(item.presentation.primaryColor(item.item))
            current.image = item.item.state == .on ? stateOnImage ?? item.presentation.selected : item.presentation.more
            current.layer?.opacity = item.item.isEnabled ? 1 : 0.4
        } else if let view = self.more {
            self.more = nil
            performSubviewRemoval(view, animated: animated)
        }
        
        if let keyEquivalent = item.keyEquivalentText {
            let current: TextView
            if let view = self.keyEquivalent {
                current = view
            } else {
                current = TextView()
                current.userInteractionEnabled = false
                current.isSelectable = false
                current.isEventLess = true
                self.addSubview(current)
                self.keyEquivalent = current
            }
            current.update(keyEquivalent)
            current.alphaValue = item.item.isEnabled ? 1 : 0.8
        } else if let view = self.keyEquivalent {
            self.keyEquivalent = nil
            performSubviewRemoval(view, animated: animated)
        }
        
        needsLayout = true
    }
    
    open override var backdorColor: NSColor {
        return .clear
    }
}
