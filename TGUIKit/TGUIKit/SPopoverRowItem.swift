//
//  SPopoverRowItem.swift
//  Telegram-Mac
//
//  Created by keepcoder on 28/09/2016.
//  Copyright © 2016 Telegram. All rights reserved.
//

import Cocoa
import SwiftSignalKitMac

class SPopoverRowItem: TableRowItem {
    private let _height: CGFloat
    override var height: CGFloat {
        return _height
    }
    
    private var unique:Int64
    
    override var stableId: AnyHashable {
        return unique
    }
    
    let iStyle:ControlStyle = ControlStyle(backgroundColor: presentation.colors.blueSelect, highlightColor: presentation.colors.underSelectedColor)
    
    
    // data
    let image:CGImage?
    let title:TextViewLayout
    let activeTitle: TextViewLayout
    let clickHandler:() -> Void
    
     override func viewClass() -> AnyClass {
        return SPopoverRowView.self
    }
    let alignAsImage: Bool
    init(_ initialSize:NSSize, height: CGFloat, image:CGImage? = nil, alignAsImage: Bool, title:String, textColor: NSColor, clickHandler:@escaping() ->Void = {}) {
        self.image = image
        self._height = height
        self.alignAsImage = alignAsImage
        self.title = TextViewLayout(.initialize(string: title, color: textColor, font: .normal(.title)))
        self.activeTitle = TextViewLayout(.initialize(string: title, color: presentation.colors.underSelectedColor, font: .normal(.title)))
        
        self.title.measure(width: .greatestFiniteMagnitude)
        self.activeTitle.measure(width: .greatestFiniteMagnitude)
        self.clickHandler = clickHandler
        unique = Int64(arc4random())
        super.init(initialSize)
    }
    
}


private class SPopoverRowView: TableRowView {
    
    var image:ImageView = ImageView()
    
    var overlay:OverlayControl = OverlayControl();
    
    var text:TextView = TextView();
    
    
    required init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        self.addSubview(overlay)
        self.addSubview(image)
        
        self.addSubview(text)
        text.isSelectable = false
        text.userInteractionEnabled = false
        
        overlay.set(handler: {[weak self] (state) in
            self?.overlay.backgroundColor = presentation.colors.blueSelect
            if let item = self?.item as? SPopoverRowItem {
                if let image = item.image {
                    self?.image.image = item.iStyle.highlight(image: image)
                }
                self?.text.backgroundColor = presentation.colors.blueSelect
                self?.text.update(item.activeTitle)
            }
            }, for: .Hover)
        
        overlay.set(handler: {[weak self] (state) in
            self?.overlay.backgroundColor = presentation.colors.background
            if let item = self?.item as? SPopoverRowItem {
                self?.image.image = item.image
                self?.text.backgroundColor = presentation.colors.background
                self?.text.update(item.title)
            }
            }, for: .Normal)
    }
    
    override func setFrameSize(_ newSize: NSSize) {
        super.setFrameSize(newSize)
        overlay.setFrameSize(newSize)
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


final class SPopoverSeparatorItem : TableRowItem {
    
    override var stableId: AnyHashable {
        return arc4random()
    }
    
    override init(_ initialSize: NSSize) {
        super.init(initialSize)
    }
    
    override func viewClass() -> AnyClass {
        return SPopoverSeparatorView.self
    }
    
    override var height: CGFloat {
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
