//
//  Avatar_MonogramView.swift
//  Telegram
//
//  Created by Mike Renoir on 19.04.2022.
//  Copyright © 2022 Telegram. All rights reserved.
//

import Foundation
import TGUIKit
import AppKit

final class Avatar_MonogramView : View {
    private let tableView = TableView(frame: .zero)
    required init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        addSubview(tableView)
        
        _ = tableView.addItem(item: GeneralRowItem(frame.size, height: 20, stableId: "1", backgroundColor: .clear))
        _ = tableView.addItem(item: GeneralRowItem(frame.size, height: 20, stableId: "2", backgroundColor: .clear))
        _ = tableView.addItem(item: GeneralRowItem(frame.size, height: 20, stableId: "3", backgroundColor: .clear))
        _ = tableView.addItem(item: GeneralRowItem(frame.size, height: 20, stableId: "4", backgroundColor: .clear))

        tableView.getBackgroundColor = {
            theme.colors.listBackground
        }
    }
    
    override func layout() {
        super.layout()
        tableView.frame = bounds
    }
    
    
    func set(text: String?, updateText:@escaping(String)->Void, animated: Bool) {
        
        
        tableView.replace(item: GeneralRowItem(frame.size, height: 20, stableId: "1", backgroundColor: .clear), at: 0, animated: animated)
        
        
        
        let input = InputDataRowItem(frame.size, stableId: "2", mode: .plain, error: nil, viewType: .singleItem, currentText: text ?? "", placeholder: nil, inputPlaceholder: "Enter symbols", insets: .init(left: 20, right: 20), filter: { $0 }, updated: updateText, limit: 2)
        tableView.replace(item: input, at: 1, animated: animated)
        tableView.replace(item: GeneralTextRowItem(frame.size, stableId: "3", text: .initialize(string: "Maximum length is 2 symbols", color: theme.colors.listGrayText, font: .normal(12)), inset: NSEdgeInsets(left: 20, right: 20), viewType: .textBottomItem), at: 2, animated: animated)
        
        tableView.replace(item: GeneralRowItem(frame.size, height: 20, stableId: "4", backgroundColor: .clear), at: 3, animated: animated)
        
    }
    
    var firstResponder: NSResponder? {
        if let view = tableView.item(at: 1).view as? InputDataRowView {
            return view.firstResponder
        }
        return tableView.item(at: 1).view
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}
