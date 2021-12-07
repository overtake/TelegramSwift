//
//  File.swift
//  
//
//  Created by Mikhail Filimonov on 06.12.2021.
//

import Foundation
import AppKit

public class AppMenuBasicItem : TableRowItem {
    
    struct Interaction {
        let action:(ContextMenuItem)->Void
        let presentSubmenu:(ContextMenuItem)->Void
        let cancelSubmenu:(ContextMenuItem)->Void
    }
    
    
    public override var height: CGFloat {
        return 2
    }
    public var effectiveSize: NSSize {
        return NSMakeSize(0, height)
    }
    public override var stableId: AnyHashable {
        return arc4random64()
    }
    public override func viewClass() -> AnyClass {
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


final class AppMenuRowItem : AppMenuBasicItem {
    fileprivate let item: ContextMenuItem
    let text: TextViewLayout
    let presentation: AppMenu.Presentation
    let leftInset: CGFloat = 11
    let innerInset: CGFloat = 4
    let imageSize: CGFloat = 18
    let moreSize: NSSize = NSMakeSize(6, 8)
    let selectedSize: NSSize = NSMakeSize(9, 8)
    let interaction: Interaction
    private var observation: NSKeyValueObservation?
    init(_ initialSize: NSSize, item: ContextMenuItem, interaction: Interaction, presentation: AppMenu.Presentation) {
        self.item = item
        self.interaction = interaction
        self.presentation = presentation
        self.text = TextViewLayout(.initialize(string: item.title, color: item.isEnabled ? presentation.textColor : presentation.disabledTextColor, font: .medium(.text)))
        super.init(initialSize)
        
        self.observation = item.observe(\.image) { [weak self] object, change in
            self?.redraw()
        }
        
    }
    
    deinit {
        self.observation?.invalidate()
    }
    
    override var effectiveSize: NSSize {
        var defaultSize = NSMakeSize(text.layoutSize.width + leftInset * 2 + innerInset * 2, height)
        if let _ = self.item.image {
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
    
    override var height: CGFloat {
        return 32
    }
    
    override func makeSize(_ width: CGFloat = CGFloat.greatestFiniteMagnitude, oldWidth: CGFloat = 0) -> Bool {
        _ = super.makeSize(width, oldWidth: oldWidth)
        text.measure(width: width - leftInset * 2 - innerInset * 2)
        return true
    }
    
    override var stableId: AnyHashable {
        return item.id
    }
    override func viewClass() -> AnyClass {
        return AppMenuRowView.self
    }
}

private final class AppMenuRowView: TableRowView {
    private let textView = TextView()
    private var imageView: ImageView? = nil
    private let containerView = Control()
    private var more: ImageView? = nil
    required init(frame frameRect: NSRect) {
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
            guard let item = self?.item as? AppMenuRowItem else {
                return
            }
            item.interaction.action(item.item)
        }, for: .Click)
        
       
        
    }
    
    override func mouseDown(with event: NSEvent) {
        
    }
    override func mouseUp(with event: NSEvent) {
        
    }
    
    override func updateMouse() {
        super.updateMouse()
        updateColors()
    }
    
    override func updateColors() {
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
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override func layout() {
        super.layout()
        
        guard let item = item as? AppMenuRowItem else {
            return
        }
        
        containerView.frame = bounds.insetBy(dx: item.innerInset, dy: 2)
        if let imageView = imageView {
            imageView.centerY(x: item.leftInset)
            textView.centerY(x: imageView.frame.maxX + item.leftInset - 2)
        } else {
            textView.centerY(x: item.leftInset)
        }
        if let more = more {
            more.centerY(x: containerView.frame.width - more.frame.width - item.leftInset)
        }
    }
    
    override func set(item: TableRowItem, animated: Bool = false) {
        super.set(item: item, animated: animated)
        
        guard let item = item as? AppMenuRowItem else {
            return
        }
        textView.update(item.text)
        
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
        
    }
    
    override var backdorColor: NSColor {
        return .clear
    }
}
