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
        return 30 + inset.bottom + inset.top
    }
    
    
    init(_ initialSize: NSSize, stableId: AnyHashable, searchInteractions:SearchInteractions, isLoading:Bool = false, drawCustomSeparator: Bool = true, border: BorderType = [], inset: NSEdgeInsets = NSEdgeInsets(left:30,right:30, top: 10, bottom: 10)) {
        self.searchInteractions = searchInteractions
        self.isLoading = isLoading
        super.init(initialSize, height: 0, stableId: stableId, type: .none, drawCustomSeparator: drawCustomSeparator, border: border, inset: inset)
    }
    
}


class SearchRowView : TableRowView {
    
    let searchView:SearchView
    

    required init(frame frameRect: NSRect) {
        searchView = SearchView(frame: NSMakeRect(0, 0, frameRect.width - 20, 30))
        super.init(frame: frameRect)
        addSubview(searchView)
        
        searchView.searchInteractions = SearchInteractions ({ [weak self] state in
            if let item = self?.item as? SearchRowItem {
                item.searchInteractions.stateModified(state)
            }
        }, { [weak self] text in
            if let item = self?.item as? SearchRowItem {
                item.searchInteractions.textModified(text)
            }
        })
    }
    
    
    override func layout() {
        super.layout()
        if let item = item as? SearchRowItem {
            searchView.setFrameSize(frame.width - item.inset.left - item.inset.right, searchView.frame.height)
            searchView.center()
        }
        
    }
    
    override func set(item: TableRowItem, animated: Bool) {
        super.set(item: item)
        if let item = item as? SearchRowItem {
            self.searchView.isLoading = item.isLoading
            self.searchView.updateLocalizationAndTheme()
        }
    }

    override var backdorColor: NSColor {
        return theme.colors.background
    }
    
    override var firstResponder:NSResponder? {
        return searchView.input
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}
