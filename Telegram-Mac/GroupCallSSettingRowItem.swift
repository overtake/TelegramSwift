//
//  GroupCallSSettingRowItem.swift
//  Telegram
//
//  Created by Mikhail Filimonov on 26/11/2020.
//  Copyright © 2020 Telegram. All rights reserved.
//

import Foundation
import TGUIKit

final class GroupCallsSettingRowItem : GeneralRowItem {
    init(_ initialSize: NSSize, stableId: AnyHashable, viewType: GeneralViewType = .legacy, action: @escaping () -> Void) {
        super.init(initialSize, height: 40, stableId: stableId, type: .none, viewType: viewType, action: action, inset: NSEdgeInsets.init(left: 20, right: 20, top: 0, bottom: 0))
    }
    
    override func viewClass() -> AnyClass {
        return GroupCallsSettingRowView.self
    }
}

private final class GroupCallsSettingRowView : GeneralContainableRowView {
    private let textView: TextView = TextView()
    private let separatorView = View()
    required init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        addSubview(textView)
        addSubview(separatorView)
    }
    
    override var backdorColor: NSColor {
        return GroupCallTheme.membersColor
    }
    
    override func updateColors() {
        super.updateColors()
        textView.backgroundColor = backdorColor

    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override func set(item: TableRowItem, animated: Bool = false) {
        super.set(item: item, animated: animated)
        
        guard let item = item as? GroupCallsSettingRowItem else {
            return
        }
        
    }
}
