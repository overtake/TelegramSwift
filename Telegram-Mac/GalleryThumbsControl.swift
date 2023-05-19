//
//  GalleryThumbsControl.swift
//  Telegram
//
//  Created by keepcoder on 10/11/2017.
//  Copyright © 2017 Telegram. All rights reserved.
//

import Cocoa
import TGUIKit
import SwiftSignalKit
import TelegramCore


class GalleryThumbsControl: ViewController {
    private let interactions: GalleryInteractions
   
    var afterLayoutTransition:((Bool)->Void)? = nil
    
    init(interactions: GalleryInteractions) {
        self.interactions = interactions
        super.init(frame: NSMakeRect(0, 0, 400, 80))
    }
    
    private(set) var items:[MGalleryItem] = []
    
    
    func layoutItems(with items: [MGalleryItem], selectedIndex selected: Int, animated: Bool) -> UpdateTransition<MGalleryItem> {
      
        let current: MGalleryItem? = selected > items.count - 1 || selected < 0 ? nil : items[selected]
        
        var newItems:[MGalleryItem] = []
        
        var isForceInstant: Bool = false
        for item in items {
            if case .instantMedia = item.entry {
                isForceInstant = true
                newItems = items
                break
            }
        }
        
        if !isForceInstant, let current = current {
            switch current.entry {
            case .message(let entry):
                
                if let message = entry.message {
                    if let groupInfo = message.groupInfo {
                        
                        newItems.append(current)
                        
                        var next: Int = selected + 1
                        var prev: Int = selected - 1
                        
                        var prevFilled: Bool = prev < 0
                        var nextFilled: Bool = next >= items.count
                        
                        while !prevFilled || !nextFilled {
                            if !prevFilled {
                                prevFilled = items[prev].entry.message?.groupInfo != groupInfo
                                if !prevFilled {
                                    newItems.insert(items[prev], at: 0)
                                }
                                prev -= 1
                            }
                            if !nextFilled {
                                nextFilled = items[next].entry.message?.groupInfo != groupInfo
                                if !nextFilled {
                                    newItems.append(items[next])
                                }
                                next += 1
                            }
                            
                            prevFilled = prevFilled || prev < 0
                            nextFilled = nextFilled || next >= items.count
                            
                        }
                    }
                }
                
            case .instantMedia:
                newItems = items
            case .photo:
                newItems = items
            case .secureIdDocument:
                newItems = items
            }
        }

        if newItems.count == 1 {
            newItems = []
        }
        
        let (deleteIndices, indicesAndItems, updateIndices) = mergeListsStableWithUpdates(leftList: self.items, rightList: newItems)
        
        
        
        for rdx in deleteIndices.reversed() {
            genericView.removeItem(at: rdx, animated: animated)
            self.items.remove(at: rdx)
        }
        
        
        for (idx, item, _) in indicesAndItems {
            genericView.insertItem(item, at: idx, isSelected: current?.stableId == item.stableId, animated: animated, callback: { [weak self] item in
                self?.interactions.select(item)
            })
            self.items.insert(item, at: idx)
        }
        for (idx, item, _) in updateIndices {
            let item =  item
            genericView.updateItem(item, at: idx)
            self.items[idx] = item
        }
        
        for i in 0 ..< self.items.count {
            if current?.stableId == self.items[i].stableId {
                genericView.layoutItems(selectedIndex: i, animated: animated)
                break
            }
        }

        genericView.updateHighlight()
        
        if self.items.count <= 1 {
            genericView.change(opacity: 0, animated: animated, completion: { [weak self] completed in
                if completed {
                    self?.genericView.isHidden = true
                }
            })
        } else {
            genericView.isHidden = false
            genericView.change(opacity: 1, animated: animated)
        }
        
        afterLayoutTransition?(animated)
        
        return UpdateTransition<MGalleryItem>(deleted: deleteIndices, inserted: indicesAndItems.map {($0.0, $0.1)}, updated: updateIndices.map {($0.0, $0.1)})
    }
    
    deinit {
        var bp:Int = 0
        bp += 1
    }
    
    var genericView:GalleryThumbsControlView {
        return view as! GalleryThumbsControlView
    }
    
    override func viewClass() -> AnyClass {
        return GalleryThumbsControlView.self
    }
}
