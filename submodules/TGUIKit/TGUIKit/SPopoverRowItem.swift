//
//  SPopoverRowItem.swift
//  Telegram-Mac
//
//  Created by keepcoder on 28/09/2016.
//  Copyright © 2016 Telegram. All rights reserved.
//

import Cocoa
import SwiftSignalKit

class SPopoverRowItem: TableRowItem {
    private let _height: CGFloat
    override var height: CGFloat {
        return _height
    }
    
    private var unique:Int64
    
    override var stableId: AnyHashable {
        return unique
    }
    
    let iStyle:ControlStyle = ControlStyle(backgroundColor: presentation.colors.accentSelect, highlightColor: presentation.colors.underSelectedColor)
    
    
    // data
    let image:CGImage?
    let title:TextViewLayout
    let activeTitle: TextViewLayout
    let clickHandler:() -> Void
    
     override func viewClass() -> AnyClass {
        return SPopoverRowView.self
    }
    let alignAsImage: Bool
    let additionView: SPopoverAdditionItemView?
    init(_ initialSize:NSSize, height: CGFloat, image:CGImage? = nil, alignAsImage: Bool, title:String, textColor: NSColor, additionView: SPopoverAdditionItemView? = nil, clickHandler:@escaping() ->Void = {}) {
        self.image = image
        self._height = height
        self.alignAsImage = alignAsImage
        self.title = TextViewLayout(.initialize(string: title, color: textColor, font: .normal(.title)), maximumNumberOfLines: 1)
        self.activeTitle = TextViewLayout(.initialize(string: title, color: presentation.colors.underSelectedColor, font: .normal(.title)), maximumNumberOfLines: 1)
        self.additionView = additionView
        self.title.measure(width: 200)
        self.activeTitle.measure(width: 200)
        self.clickHandler = clickHandler
        unique = Int64(arc4random())
        super.init(initialSize)
    }
    var itemWidth: CGFloat {
        return self.title.layoutSize.width + (additionView != nil ? 40 : 0)
    }
}


private class SPopoverRowView: TableRowView {
    
    var image:ImageView = ImageView()
    
    var overlay:OverlayControl = OverlayControl()
    
    var text:TextView = TextView();
    
    
    required init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        self.addSubview(overlay)
        overlay.addSubview(image)
        
        overlay.addSubview(text)
        text.isSelectable = false
        text.userInteractionEnabled = false
        
        overlay.set(handler: {[weak self] (state) in
            self?.overlay.backgroundColor = presentation.colors.accentSelect
            if let item = self?.item as? SPopoverRowItem {
                if let image = item.image {
                    self?.image.image = item.iStyle.highlight(image: image)
                }
                self?.text.backgroundColor = presentation.colors.accentSelect
                self?.text.update(item.activeTitle)
                item.additionView?.updateIsSelected?(self?.mouseInside() ?? false)
            }
        }, for: .Hover)
        
        overlay.set(handler: {[weak self] (state) in
            self?.overlay.backgroundColor = presentation.colors.background
            if let item = self?.item as? SPopoverRowItem {
                self?.image.image = item.image
                self?.text.backgroundColor = presentation.colors.background
                self?.text.update(item.title)
                item.additionView?.updateIsSelected?(self?.mouseInside() ?? false)
            }
        }, for: .Normal)
    }
    
    override func setFrameSize(_ newSize: NSSize) {
        super.setFrameSize(newSize)
        overlay.setFrameSize(newSize)
    }
    
    override func layout() {
        super.layout()
        if let item = item as? SPopoverRowItem {
            if item.image != nil || item.alignAsImage {
                text.centerY(self, x: 45)
            } else {
                text.center()
            }
        }
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    
    override func updateMouse() {
        overlay.updateState()
    }
    
    override func set(item:TableRowItem, animated:Bool = false) {
        super.set(item: item, animated: animated)
        
        overlay.removeAllHandlers()
        overlay.backgroundColor = presentation.colors.background
        text.backgroundColor = presentation.colors.background
        if let item = item as? SPopoverRowItem {
            
            if let view = item.additionView {
                overlay.addSubview(view.view)
                view.view.setFrameOrigin(NSMakePoint(frame.width - 34, 10))
            }
            
            image.image = item.image
            overlay.removeAllHandlers()
            overlay.set(handler: {_ in
                item.clickHandler()
            }, for: .Click)
            image.sizeToFit()
            image.centerY(self, x: floorToScreenPixels(backingScaleFactor, (45 - image.frame.width) / 2))
            
            text.update(item.title)
            
            if item.image != nil || item.alignAsImage {
                text.centerY(self, x: 45)
            } else {
                text.center()
            }
        }
        
    }
    
}


public final class SPopoverSeparatorItem : TableRowItem {
    
    override public var stableId: AnyHashable {
        return arc4random()
    }
    
    override public init(_ initialSize: NSSize) {
        super.init(initialSize)
    }
    public init() {
        super.init(NSZeroSize)
    }
    
    override public func viewClass() -> AnyClass {
        return SPopoverSeparatorView.self
    }
    
    override public var height: CGFloat {
        return 10
    }
}


private final class SPopoverSeparatorView : TableRowView {
    private let separator: View = View()
    required init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        addSubview(separator)
    }
    override func updateColors() {
        super.updateColors()
        separator.backgroundColor = presentation.colors.border
    }
    
    override func layout() {
        super.layout()
        separator.setFrameSize(NSMakeSize(frame.width, .borderSize))
        separator.center()
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}
