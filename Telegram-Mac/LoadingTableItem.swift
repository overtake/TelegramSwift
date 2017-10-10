//
//  LoadingTableItem.swift
//  Telegram
//
//  Created by keepcoder on 11/06/2017.
//  Copyright © 2017 Telegram. All rights reserved.
//

import Cocoa
import TGUIKit

class LoadingTableItem: GeneralRowItem {

    init(_ initialSize: NSSize, height: CGFloat, stableId: AnyHashable) {
        super.init(initialSize, height: height, stableId: stableId)
    }
    
    
    override func viewClass() -> AnyClass {
        return LoadingTableRowView.self
    }
}


class LoadingTableRowView : TableRowView {
    private let progress: ProgressIndicator = ProgressIndicator(frame: NSMakeRect(0, 0, 20, 20))
    
    required init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        addSubview(progress)
    }
    
    override func viewDidMoveToWindow() {
        if let _ = window {
            progress.animates = true
        } else {
            progress.animates = false
        }
    }
    
    override func layout() {
        super.layout()
        progress.center()
    }
    
    deinit {
        progress.animates = false
    }
    
    override func set(item: TableRowItem, animated: Bool) {
        super.set(item: item, animated: animated)
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}
