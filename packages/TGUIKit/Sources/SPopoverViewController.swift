//
//  SPopoverViewController.swift
//  Telegram-Mac
//
//  Created by keepcoder on 09/11/2016.
//  Copyright © 2016 Telegram. All rights reserved.
//

import Cocoa
import SwiftSignalKit


public struct SPopoverAdditionItemView {
    let context: Any?
    let view: NSView
    let updateIsSelected:((Bool)->Void)?
    public init(context: Any?, view: NSView, updateIsSelected:((Bool)->Void)? = nil) {
        self.context = context
        self.view = view
        self.updateIsSelected = updateIsSelected
    }
}

public struct SPopoverItem : Equatable {
    public let title:String
    let image:CGImage?
    let textColor: NSColor
    let height: CGFloat
    public let handler:()->Void
    let isSeparator: Bool
    let drawSeparatorBorder: Bool
    let additionView: SPopoverAdditionItemView?
    
    public init(_ title:String, _ handler:@escaping ()->Void, _ image:CGImage? = nil, _ textColor: NSColor = presentation.colors.text, height: CGFloat = 40.0, isSeparator: Bool = false, drawSeparatorBorder: Bool = true, additionView: SPopoverAdditionItemView? = nil) {
        self.title = title
        self.image = image
        self.textColor = textColor
        self.handler = handler
        self.height = height
        self.isSeparator = false
        self.additionView = additionView
        self.drawSeparatorBorder = drawSeparatorBorder
    }
    
    public init(_ drawSeparatorBorder: Bool = true) {
        self.title = ""
        self.image = nil
        self.textColor = presentation.colors.text
        self.handler = {}
        self.height = 10
        self.isSeparator = true
        self.drawSeparatorBorder = drawSeparatorBorder
        self.additionView = nil
    }
    
    public static func ==(lhs: SPopoverItem, rhs: SPopoverItem) -> Bool {
        return lhs.title == rhs.title && lhs.textColor == rhs.textColor
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
        let items = items.map { item -> TableRowItem in
            if item.isSeparator {
                return SPopoverSeparatorItem(item.drawSeparatorBorder)
            } else {
                return SPopoverRowItem(NSZeroSize, height: item.height, image: item.image, alignAsImage: alignAsImage, title: item.title, textColor: item.textColor, additionView: item.additionView, clickHandler: {
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
                })
            }
        }
        
        
        let width: CGFloat = items.isEmpty ? 200 : items.compactMap({ $0 as? SPopoverRowItem }).max(by: {$0.itemWidth < $1.itemWidth})!.itemWidth
        
        for item in headerItems {
            _ = item.makeSize(width + 48 + 18)
        }
        
        
        
        self.items = headerItems + (headerItems.isEmpty ? [] : [SPopoverSeparatorItem(false)]) + items
        
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
    
    
    public override func becomeFirstResponder() -> Bool? {
        return nil
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
