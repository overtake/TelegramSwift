//
//  TurnOnNotificationsRowItem.swift
//  Telegram
//
//  Created by Mikhail Filimonov on 17.08.2021.
//  Copyright © 2021 Telegram. All rights reserved.
//

import Foundation
import TGUIKit

final class TitleAndInfoAlertItem : GeneralRowItem {
    fileprivate let header: TextViewLayout
    fileprivate let text: TextViewLayout
    init(_ initialSize: NSSize, stableId: AnyHashable, title: String, info: String, viewType: GeneralViewType, inset: NSEdgeInsets = NSEdgeInsets(left: 20, right: 20)) {
        let hAttr: NSAttributedString = .initialize(string: title, color: theme.colors.text, font: .medium(.text))
        let tAttr: NSAttributedString = .initialize(string: info, color: theme.colors.text, font: .normal(.text))
        header = .init(hAttr)
        text = .init(tAttr)

        super.init(initialSize, stableId: stableId, viewType: viewType, inset: inset)
    }
    
    override func makeSize(_ width: CGFloat, oldWidth: CGFloat = 0) -> Bool {
        _ = super.makeSize(width, oldWidth: oldWidth)
        
        header.measure(width: blockWidth - viewType.innerInset.left - viewType.innerInset.right - 30)
        text.measure(width: blockWidth - viewType.innerInset.left - viewType.innerInset.right)

        return true
    }
    
    override var height: CGFloat {
        return viewType.innerInset.bottom + viewType.innerInset.top + 6 + header.layoutSize.height + text.layoutSize.height
    }
    override func viewClass() -> AnyClass {
        return TitleAndInfoAlertItemView.self
    }
    
}


private final class TitleAndInfoAlertItemView: GeneralContainableRowView {
    private let imageView: ImageView = ImageView()
    private let textView = TextView()
    private let headerView = TextView()
    required init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        
        textView.userInteractionEnabled = false
        textView.isSelectable = false
        
        headerView.userInteractionEnabled = false
        headerView.isSelectable = false
        
        addSubview(imageView)
        addSubview(headerView)
        addSubview(textView)
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override func layout() {
        super.layout()
        
        guard let item = item as? TitleAndInfoAlertItem else {
            return
        }
        
        imageView.setFrameOrigin(NSMakePoint(item.viewType.innerInset.left, item.viewType.innerInset.top))
        headerView.setFrameOrigin(NSMakePoint(imageView.frame.maxX + 6, item.viewType.innerInset.top))
        textView.setFrameOrigin(NSMakePoint(item.viewType.innerInset.left, headerView.frame.maxY + 6))

    }
    
    override func set(item: TableRowItem, animated: Bool = false) {
        super.set(item: item, animated: animated)
        guard let item = item as? TitleAndInfoAlertItem else {
            return
        }
        
        imageView.image = #imageLiteral(resourceName: "Icon_MessageSentFailed").precomposed()
        imageView.sizeToFit()
        
        textView.update(item.text)
        headerView.update(item.header)
    }
}
