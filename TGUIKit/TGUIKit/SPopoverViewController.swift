//
//  SPopoverViewController.swift
//  Telegram-Mac
//
//  Created by keepcoder on 09/11/2016.
//  Copyright © 2016 Telegram. All rights reserved.
//

import Cocoa
import TGUIKit
import SwiftSignalKitMac


public struct SPopoverItem : Equatable {
    let title:String
    let image:CGImage?
    let textColor: NSColor
    let height: CGFloat
    let handler:()->Void
    public init(_ title:String, _ handler:@escaping ()->Void, _ image:CGImage? = nil, _ textColor: NSColor = presentation.colors.text, height: CGFloat = 40.0) {
        self.title = title
        self.image = image
        self.textColor = textColor
        self.handler = handler
        self.height = height
    }
    
    public static func ==(lhs: SPopoverItem, rhs: SPopoverItem) -> Bool {
        return lhs.title == rhs.title && lhs.textColor.hexString == rhs.textColor.hexString
    }
}



public class SPopoverViewController: GenericViewController<TableView> {
    private let items:[TableRowItem]
    private let disposable = MetaDisposable()
    public override func viewDidLoad() {
        super.viewDidLoad()
        
        genericView.insert(items: items)
        genericView.needUpdateVisibleAfterScroll = true
        genericView.reloadData()
        
        readyOnce()
    }
    
    public init(items:[SPopoverItem], visibility:Int = 4, handlerDelay: Double = 0.15, headerItems: [TableRowItem] = []) {
        weak var controller:SPopoverViewController?
        let alignAsImage = !items.filter({$0.image != nil}).isEmpty
        let items = items.map { item in
            return SPopoverRowItem(NSZeroSize, height: item.height, image: item.image, alignAsImage: alignAsImage, title: item.title, textColor: item.textColor, clickHandler: {
                Queue.mainQueue().justDispatch {
                    controller?.popover?.hide()
                    
                    if handlerDelay == 0 {
                        item.handler()
                    } else {
                        _ = (Signal<Void, NoError>.single(Void()) |> delay(handlerDelay, queue: Queue.mainQueue())).start(next: {
                            item.handler()
                        })
                    }
                    
                }
        })}
        
        
        
        let width: CGFloat = items.isEmpty ? 200 : items.max(by: {$0.title.layoutSize.width < $1.title.layoutSize.width})!.title.layoutSize.width
        
        for item in headerItems {
            _ = item.makeSize(width + 48 + 18)
        }
        
        
        
        self.items = headerItems + (headerItems.isEmpty ? [] : [SPopoverSeparatorItem(NSZeroSize)]) + items
        
        var height: CGFloat = 0
        for (i, item) in self.items.enumerated() {
            if i < visibility {
                height += item.height
            } else {
                height += item.height / 2
                break
            }
        }
        
      //  let height = min(visibility * 40 + 20, items.count * 40)
        super.init(frame: NSMakeRect(0, 0, width + 45 + 18, CGFloat(height)))
        bar = .init(height: 0)
        controller = self
    }
    
    deinit {
        disposable.dispose()
    }
    
    
    public override func viewWillAppear(_ animated: Bool) {
        
    }
    

}





//public func presntContextMenu(for event: NSEvent, items: [SPopoverItem]) -> Void {
//    
//    
//    let controller = SPopoverViewController(items: items, visibility: Int.max, handlerDelay: 0)
//    
//    let window = Window(contentRect: NSMakeRect(event.locationInWindow.x, event.locationInWindow.y, controller.frame.width, controller.frame.height), styleMask: [], backing: .buffered, defer: true)
//    window.contentView = controller.view
//    window.backgroundColor = .clear
//    event.window?.addChildWindow(window, ordered: .above)
//    window.makeKeyAndOrderFront(nil)
//    
//}
