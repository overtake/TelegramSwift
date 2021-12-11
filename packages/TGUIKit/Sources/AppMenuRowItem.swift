//
//  File.swift
//  
//
//  Created by Mikhail Filimonov on 06.12.2021.
//

import Foundation
import AppKit

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
    }
    
    
    open override var height: CGFloat {
        return 2
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
private final class AppMenuBasicItemView: TableRowView {
    override var backdorColor: NSColor {
        return .clear
    }
}


public class AppMenuSeparatorItem : AppMenuBasicItem {
    
    fileprivate let presentation: AppMenu.Presentation
    public init(_ initialSize: NSSize, presentation: AppMenu.Presentation) {
        self.presentation = presentation
        super.init(initialSize)
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
private final class AppMenuSeparatorItemView: TableRowView {
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
        view.frame = NSMakeRect(11 + 4, 2, frame.width - 22 - 8, 1)
    }
    
    override func set(item: TableRowItem, animated: Bool = false) {
        super.set(item: item, animated: animated)
    }
}


open class AppMenuRowItem : AppMenuBasicItem {
    public let item: ContextMenuItem
    public private(set) var text: TextViewLayout
    public let presentation: AppMenu.Presentation
    public let leftInset: CGFloat = 11
    public let innerInset: CGFloat = 4
    public let imageSize: CGFloat = 18
    public let moreSize: NSSize = NSMakeSize(6, 8)
    public let selectedSize: NSSize = NSMakeSize(9, 8)
    public let interaction: Interaction
    private var observation_i: NSKeyValueObservation?
    private var observation_t: NSKeyValueObservation?
    public init(_ initialSize: NSSize, item: ContextMenuItem, interaction: Interaction, presentation: AppMenu.Presentation) {
        self.item = item
        self.interaction = interaction
        self.presentation = presentation
        self.text = TextViewLayout(.initialize(string: item.title, color: presentation.primaryColor(item), font: .medium(.text)))
        super.init(initialSize)
        
        self.observation_i = item.observe(\.image) { [weak self] object, change in
            self?.redraw()
        }
        self.observation_t = item.observe(\.title) { [weak self] object, change in
            self?.redraw()
        }
    }
    
    public override func redraw(animated: Bool = false, options: NSTableView.AnimationOptions = .effectFade, presentAsNew: Bool = false) {
        
        self.text = TextViewLayout(.initialize(string: item.title, color: presentation.primaryColor(item), font: .medium(.text)))
        
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
            return menu.items.compactMap { $0 as? ContextMenuItem }.contains(where: { $0.itemImage != nil })
        }
        return false
    }
    
    open override var effectiveSize: NSSize {
        var defaultSize = NSMakeSize(text.layoutSize.width + leftInset * 2 + innerInset * 2, height)
        if let _ = self.item.image {
            defaultSize.width += imageSize + leftInset - 2
        }
        
        if hasDrawable {
            defaultSize.width += imageSize + leftInset - 2
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
        return 32
    }
    
    open override func makeSize(_ width: CGFloat = CGFloat.greatestFiniteMagnitude, oldWidth: CGFloat = 0) -> Bool {
        _ = super.makeSize(width, oldWidth: oldWidth)
        text.measure(width: width - leftInset * 2 - innerInset * 2)
        return true
    }
    
    open override var stableId: AnyHashable {
        return item.id
    }
    open override func viewClass() -> AnyClass {
        return AppMenuRowView.self
    }
}

open class AppMenuRowView: TableRowView {
    private let textView = TextView()
    private var imageView: ImageView? = nil
    private var drawable: AppMenuItemImageDrawable? = nil
    private let containerView = Control()
    private var more: ImageView? = nil
    public required init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        containerView.addSubview(textView)
        addSubview(containerView)
        textView.userInteractionEnabled = false
        textView.isSelectable = false
        textView.disableBackgroundDrawing = true
        containerView.layer?.cornerRadius = .cornerRadius
        containerView.scaleOnClick = true
        
        containerView.set(handler: { [weak self] _ in
            guard let item = self?.item as? AppMenuRowItem else {
                return
            }
            item.interaction.presentSubmenu(item.item)
        }, for: .Hover)
        
        
        containerView.set(handler: { [weak self] _ in
            self?.drawable?.updateState(.Hover)
            self?.updateState(.Hover)
        }, for: .Hover)
        containerView.set(handler: { [weak self] _ in
            self?.drawable?.updateState(.Highlight)
            self?.updateState(.Highlight)
        }, for: .Highlight)
        containerView.set(handler: { [weak self] _ in
            self?.drawable?.updateState(.Normal)
            self?.updateState(.Normal)
        }, for: .Normal)
        containerView.set(handler: { [weak self] _ in
            self?.drawable?.updateState(.Other)
            self?.updateState(.Other)
        }, for: .Other)
           
        containerView.set(handler: { [weak self] _ in
            guard let item = self?.item as? AppMenuRowItem else {
                return
            }
            item.interaction.action(item.item)
        }, for: .Click)
        
       
        
    }
    private var previous: ControlState = .Normal
    open func updateState(_ state: ControlState) {
      
    }
    
    open override func mouseDown(with event: NSEvent) {
        
    }
    open override func mouseUp(with event: NSEvent) {
        
    }
    
    open override func updateMouse() {
        super.updateMouse()
        updateColors()
    }
    
    open override func updateColors() {
        super.updateColors()
        guard let item = item as? AppMenuRowItem else {
            return
        }
        containerView.isSelected = item.isSelected
        
        containerView.isEnabled = item.item.isEnabled
        
        containerView.set(background: item.presentation.highlightColor, for: .Hover)
        containerView.set(background: .clear, for: .Normal)
        containerView.set(background: item.presentation.highlightColor, for: .Highlight)
        
        
    }
    
    public required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    open override func layout() {
        super.layout()
        
        guard let item = item as? AppMenuRowItem else {
            return
        }
        
        containerView.frame = bounds.insetBy(dx: item.innerInset, dy: 2)
        if let drawable = drawable {
            drawable.centerY(x: item.leftInset)
            textView.centerY(x: drawable.frame.maxX + item.leftInset - 2)
        } else if let imageView = imageView {
            imageView.centerY(x: item.leftInset)
            textView.centerY(x: imageView.frame.maxX + item.leftInset - 2)
        } else if item.hasDrawable {
            textView.centerY(x: item.leftInset + item.imageSize + item.leftInset - 2)
        } else {
            textView.centerY(x: item.leftInset)
        }
        if let more = more {
            more.centerY(x: containerView.frame.width - more.frame.width - item.leftInset)
        }
    }
    
    open override func set(item: TableRowItem, animated: Bool = false) {
        super.set(item: item, animated: animated)
        
        guard let item = item as? AppMenuRowItem else {
            return
        }
        textView.update(item.text)
        
        
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
                containerView.addSubview(drawable)
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
                containerView.addSubview(current)
                self.imageView = current
            }
            current.layer?.contents = image
        } else if let view = self.imageView {
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
                current.contentGravity = .center
                containerView.addSubview(current)
                self.more = current
            }
            current.image = item.item.state == .on ? item.presentation.selected : item.presentation.more
        } else if let view = self.more {
            performSubviewRemoval(view, animated: animated)
        }
        needsLayout = true
    }
    
    open override var backdorColor: NSColor {
        return .clear
    }
}
