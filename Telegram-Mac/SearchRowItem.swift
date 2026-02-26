//
//  SearchRowItem.swift
//  Telegram-Mac
//
//  Created by keepcoder on 09/11/2016.
//  Copyright © 2016 Telegram. All rights reserved.
//

import Cocoa
import TGUIKit
class SearchRowItem: GeneralRowItem {

    fileprivate let searchInteractions:SearchInteractions
    fileprivate let isLoading:Bool
    override func viewClass() -> AnyClass {
        return SearchRowView.self
    }
    
    override var height: CGFloat {
        return 50
    }
    
    
    init(_ initialSize: NSSize, stableId: AnyHashable, searchInteractions:SearchInteractions, isLoading:Bool = false, drawCustomSeparator: Bool = true, border: BorderType = [], viewType: GeneralViewType = .legacy, inset: NSEdgeInsets = .init(top: 0, left: 20, bottom: 0, right: 20)) {
        self.searchInteractions = searchInteractions
        self.isLoading = isLoading
        super.init(initialSize, height: 50, stableId: stableId, type: .none, viewType: viewType, drawCustomSeparator: drawCustomSeparator, border: border, inset: inset)
    }
    
    
}


class SearchRowView : GeneralContainableRowView {
    
    let searchView:SearchView
    

    required init(frame frameRect: NSRect) {
        searchView = SearchView(frame: NSMakeRect(0, 0, frameRect.width - 20, 30))
        super.init(frame: frameRect)
        addSubview(searchView)
        
        
    }
    
    
    override func layout() {
        super.layout()
        if let item = item as? SearchRowItem {
            searchView.setFrameSize(containerView.frame.width - item.viewType.innerInset.left - item.viewType.innerInset.right, searchView.frame.height)
            searchView.center()
        }
        
    }
    
    override func set(item: TableRowItem, animated: Bool) {
        super.set(item: item, animated: animated)
        
        if let item = item as? SearchRowItem {
            self.searchView.isLoading = item.isLoading
            self.searchView.updateLocalizationAndTheme(theme: theme)
            
            
            searchView.searchInteractions = SearchInteractions ({ [weak self] state, animated in
                if let item = self?.item as? SearchRowItem {
                    item.searchInteractions.stateModified(state, animated)
                }
            }, { [weak self] text in
                    if let item = self?.item as? SearchRowItem {
                        item.searchInteractions.textModified(text)
                }
            })
        }
    }

    
    override var firstResponder:NSResponder? {
        return searchView.input
    }
    
    override func onRemove(_ animation: NSTableView.AnimationOptions) {
        self.isHidden = true
//        searchView.cancel(false)
//        searchView.isHidden = true
    }
    
    override func onInsert(_ animation: NSTableView.AnimationOptions, appearAnimated: Bool) {
        
        if animation.contains(.effectFade) {
            self.isHidden = true
            self.searchView.layer?.animateAlpha(from: 0, to: 1, duration: 0.2, timingFunction: .easeOut, completion: { [weak self] _ in
                self?.isHidden = false
            })
        }
        //        searchView.cancel(false)
        //        searchView.isHidden = true
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}
