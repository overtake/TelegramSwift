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
    let color: NSColor?
    let bgColor: NSColor?
    init(_ initialSize: NSSize, stableId: AnyHashable, viewType: GeneralViewType, color: NSColor? = nil, height: CGFloat = 42, backgroundColor: NSColor? = nil) {
        self.color = color
        self.bgColor = backgroundColor
        super.init(initialSize, height: height, stableId: stableId, viewType: viewType)
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
    
    override var backdorColor: NSColor {
        if let item = item as? GeneralLoadingRowItem {
            if let color = item.bgColor {
                return color
            }
            if item.viewType == .legacy {
                return .clear
            }
        }
        return super.backdorColor
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override func updateColors() {
        super.updateColors()
        guard let item = self.item as? GeneralLoadingRowItem else {
            return
        }
        indicator.progressColor = item.color ?? theme.colors.text
    }
    
    override func set(item: TableRowItem, animated: Bool = false) {
        super.set(item: item, animated: animated)
    }
}
