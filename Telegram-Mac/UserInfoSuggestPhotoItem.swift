//
//  UserInfoSuggestPhotoItem.swift
//  Telegram
//
//  Created by Mike Renoir on 07.12.2022.
//  Copyright © 2022 Telegram. All rights reserved.
//

import Foundation
import TelegramCore
import SwiftSignalKit
import Postbox
import TGUIKit

final class UserInfoSuggestPhotoItem : GeneralRowItem {
    fileprivate let context: AccountContext
    fileprivate let user: TelegramUser
    fileprivate let cachedData: CachedUserData
    fileprivate let textLayout: TextViewLayout
    
    init(_ initialSize: NSSize, context: AccountContext, stableId: AnyHashable, user: TelegramUser, cachedData: CachedUserData, type: UserInfoArguments.SetPhotoType, viewType: GeneralViewType) {
        self.context = context
        self.user = user
        self.cachedData = cachedData
        
        let text: String
        switch type {
        case .set:
            text = strings().userInfoSetPhotoConfirm(user.compactDisplayTitle, user.compactDisplayTitle)
        case .suggest:
            text = strings().userInfoSuggestConfirm(user.compactDisplayTitle)
        }
        self.textLayout = .init(.initialize(string: text, color: theme.colors.text, font: .normal(.text)), alignment: .center)
        
        super.init(initialSize, stableId: stableId, viewType: viewType)
        
        _ = makeSize(initialSize.width)
    }
    
    override func makeSize(_ width: CGFloat, oldWidth: CGFloat = 0) -> Bool {
        _ = super.makeSize(width, oldWidth: oldWidth)
        
        self.textLayout.measure(width: blockWidth - viewType.innerInset.left - viewType.innerInset.right)
        
        return true
    }
    
    override var height: CGFloat {
        return viewType.innerInset.top + 50 + viewType.innerInset.top + textLayout.layoutSize.height + viewType.innerInset.bottom
    }
    
    override func viewClass() -> AnyClass {
        return UserInfoSuggestPhotoView.self
    }
}


private final class UserInfoSuggestPhotoView: GeneralContainableRowView {
    private let textView = TextView()
    required init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        addSubview(textView)
        textView.isSelectable = false
        textView.userInteractionEnabled = false
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override func layout() {
        super.layout()
        
        guard let item = item as? GeneralRowItem else {
            return
        }
        
        textView.centerX(y: containerView.frame.height - textView.frame.height - item.viewType.innerInset.top)
    }
    
    override func set(item: TableRowItem, animated: Bool = false) {
        super.set(item: item, animated: animated)
        
        guard let item = item as? UserInfoSuggestPhotoItem else {
            return
        }
        
        textView.update(item.textLayout)
    }
}
