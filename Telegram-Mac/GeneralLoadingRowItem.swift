//
//  GeneralLoadingRowItem.swift
//  Telegram
//
//  Created by Mikhail Filimonov on 14.01.2021.
//  Copyright © 2021 Telegram. All rights reserved.
//

import Cocoa
import TGUIKit


class GeneralLoadingRowItem: GeneralRowItem {

    init(_ initialSize: NSSize, stableId: AnyHashable, viewType: GeneralViewType) {
        super.init(initialSize, height: 42, stableId: stableId, viewType: viewType)
    }
    
    override func viewClass() -> AnyClass {
        return GeneralLoadingRowView.self
    }
    
}

private final class GeneralLoadingRowView: GeneralContainableRowView {
    private let indicator: ProgressIndicator = ProgressIndicator(frame: NSMakeRect(0, 0, 20, 20))
    required init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        addSubview(indicator)
    }
    
    override func layout() {
        super.layout()
        indicator.center()
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override func updateColors() {
        super.updateColors()
        indicator.progressColor = theme.colors.text
    }
    
    override func set(item: TableRowItem, animated: Bool = false) {
        super.set(item: item, animated: animated)
    }
}
