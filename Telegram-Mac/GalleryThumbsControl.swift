//
//  GalleryThumbsControl.swift
//  Telegram
//
//  Created by keepcoder on 10/11/2017.
//  Copyright © 2017 Telegram. All rights reserved.
//

import Cocoa
import TGUIKit

class GalleryThumbsControl: ViewController {
    
    private var maxVisibleItems: Int = 5
    
    private var items: [MGalleryItem] = []
    
    var selectedIndex: Int? {
        didSet {
            if selectedIndex != oldValue {
                genericView.layoutItems(selectedIndex: selectedIndex, animated: true)
            }
        }
    }

    
    func merge(with transition:UpdateTransition<MGalleryItem>) {
        var items = self.items
        for rdx in transition.deleted.reversed() {
            items.remove(at: rdx)
        }
        
        let searchItem:(AnyHashable)->MGalleryItem? = { stableId in
            for item in items {
                if item.stableId == stableId {
                    return item
                }
            }
            return nil
        }
        
        for (idx,item) in transition.inserted {
            let item = searchItem(item.stableId) ?? item
            items.insert(item, at: idx)
        }
        for (idx,item) in transition.updated {
            let item = searchItem(item.stableId) ?? item
            items[idx] = item
        }
        self.items = items
        
        genericView.makeItems(items: items, animated: false)
    }
    
    var genericView:GalleryThumbsControlView {
        return view as! GalleryThumbsControlView
    }
    
    override func viewClass() -> AnyClass {
        return GalleryThumbsControlView.self
    }
}
