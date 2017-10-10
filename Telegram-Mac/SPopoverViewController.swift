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

struct SPopoverItem {
    let title:String
    let image:CGImage?
    let textColor: NSColor
    let handler:()->Void
    init(_ title:String, _ handler:@escaping ()->Void, _ image:CGImage? = nil, _ textColor: NSColor = theme.colors.text) {
        self.title = title
        self.image = image
        self.textColor = textColor
        self.handler = handler
    }
}

class SPopoverViewController: GenericViewController<TableView> {
    private let items:[SPopoverRowItem]
    private let disposable = MetaDisposable()
    override func viewDidLoad() {
        super.viewDidLoad()
        
        genericView.insert(items: items)
        genericView.needUpdateVisibleAfterScroll = true
        genericView.reloadData()
        
        readyOnce()
    }
    
    init(items:[SPopoverItem], visibility:Int = 4) {
        weak var controller:SPopoverViewController?
        let alignAsImage = !items.filter({$0.image != nil}).isEmpty
        self.items = items.map({ item in SPopoverRowItem(NSZeroSize, image: item.image, alignAsImage: alignAsImage, title: item.title, textColor: item.textColor, clickHandler: {
            Queue.mainQueue().justDispatch {
                controller?.popover?.hide()
                
                _ = (Signal<Void, Void>.single(Void()) |> delay(0.15, queue: Queue.mainQueue())).start(next: {
                    item.handler()
                })
            }
        })})
        let width: CGFloat = self.items.max(by: {$0.title.layoutSize.width < $1.title.layoutSize.width})!.title.layoutSize.width
        let height = min(visibility * 40 + 20, items.count * 40)
        super.init(frame: NSMakeRect(0, 0, width + 45 + 18, CGFloat(height)))
        bar = .init(height: 0)
        controller = self
    }
    
    deinit {
        disposable.dispose()
    }
    
    
    override func viewWillAppear(_ animated: Bool) {
        
    }
    

}


