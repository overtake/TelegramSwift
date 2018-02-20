//
//  SPopoverRowItem.swift
//  Telegram-Mac
//
//  Created by keepcoder on 28/09/2016.
//  Copyright © 2016 Telegram. All rights reserved.
//

import Cocoa
import TGUIKit
import SwiftSignalKitMac
class SPopoverRowItem: TableRowItem {

    override var height: CGFloat {
        return 40
    }
    
    private var unique:Int64
    
    override var stableId: AnyHashable {
        return unique
    }
    
    let iStyle:ControlStyle = ControlStyle(backgroundColor: theme.colors.blueSelect, highlightColor:.white)
    
    
    // data
    let image:CGImage?
    let title:TextViewLayout
    let activeTitle: TextViewLayout
    let clickHandler:() -> Void
    
     override func viewClass() -> AnyClass {
        return SPopoverRowView.self
    }
    let alignAsImage: Bool
    init(_ initialSize:NSSize, image:CGImage? = nil, alignAsImage: Bool, title:String, textColor: NSColor, clickHandler:@escaping() ->Void = {}) {
        self.image = image
        self.alignAsImage = alignAsImage
        self.title = TextViewLayout(.initialize(string: title, color: textColor, font: .normal(.title)))
        self.activeTitle = TextViewLayout(.initialize(string: title, color: .white, font: .normal(.title)))
        
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
            self?.overlay.backgroundColor = theme.colors.blueSelect
            if let item = self?.item as? SPopoverRowItem {
                if let image = item.image {
                    self?.image.image = item.iStyle.highlight(image: image)
                }
                self?.text.backgroundColor = theme.colors.blueSelect
                self?.text.update(item.activeTitle)
            }
            }, for: .Hover)
        
        overlay.set(handler: {[weak self] (state) in
            self?.overlay.backgroundColor = theme.colors.background
            if let item = self?.item as? SPopoverRowItem {
                self?.image.image = item.image
                self?.text.backgroundColor = theme.colors.background
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
        overlay.backgroundColor = theme.colors.background
        text.backgroundColor = theme.colors.background
        if let item = item as? SPopoverRowItem {
            image.image = item.image
            overlay.removeAllHandlers()
            overlay.set(handler: {_ in
                item.clickHandler()
            }, for: .Click)
            image.sizeToFit()
            image.centerY(self, x: floorToScreenPixels(scaleFactor: backingScaleFactor, (45 - image.frame.width) / 2))
            
            text.update(item.title)
            
            if item.image != nil || item.alignAsImage {
                text.centerY(self, x: 45)
            } else {
                text.center()
            }
        }
        
    }
    
}
