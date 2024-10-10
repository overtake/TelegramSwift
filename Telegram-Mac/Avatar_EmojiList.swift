//
//  Avatar_EmojiListController.swift
//  Telegram
//
//  Created by Mike Renoir on 15.04.2022.
//  Copyright © 2022 Telegram. All rights reserved.
//

import Foundation
import TGUIKit
import TelegramCore
import Postbox
import TelegramMedia

final class Avatar_EmojiListView : View {
    
    private class ItemView: Control {
        private let player: LottiePlayerView = LottiePlayerView()
        required init(frame frameRect: NSRect) {
            super.init(frame: frameRect)
            addSubview(player)
            player.backgroundColor = .random
        }
        
        func set(_ item: StickerPackItem, context: AccountContext, animated: Bool) {
            
        }
        
        override func layout() {
            super.layout()
            player.frame = bounds.insetBy(dx: 5, dy: 5)
        }
        
        override func stateDidUpdate(_ state: ControlState) {
            super.stateDidUpdate(state)
        }
        
        required init?(coder: NSCoder) {
            fatalError("init(coder:) has not been implemented")
        }
    }
    private let tableView = TableView()
    
    required init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        addSubview(tableView)
        tableView.getBackgroundColor = {
            theme.colors.listBackground
        }
        _ = tableView.addItem(item: GeneralRowItem(.zero))
    }
    
    override func layout() {
        super.layout()
        tableView.frame = bounds
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    func set(list: [StickerPackItem], context: AccountContext, selectForeground: @escaping(TelegramMediaFile)->Void, animated: Bool) {
        
        let arguments = StickerPanelArguments(context: context, sendMedia: {  media, view, silent, schedule, _ in
            if let media = media as? TelegramMediaFile {
                selectForeground(media)
            }
        }, showPack: { _ in
            
        }, addPack: { _ in
            
        }, navigate: { _ in
            
        }, clearRecent: {
            
        }, removePack: { _ in
            
        }, closeInlineFeatured: { _ in
            
        }, openFeatured: { _ in
            
        }, selectEmojiCategory: { _ in
            
        }, mode: .common)
        
        let item = StickerPackPanelRowItem(frame.size, context: context, arguments: arguments, files: list.map { $0.file }, packInfo: .emojiRelated, collectionId: .pack(ItemCollectionId(namespace: 0, id: 0)), canSend: true, playOnHover: true)
        _ = item.makeSize(frame.width)
        
        
        tableView.beginTableUpdates()
        tableView.replace(item: item, at: 0, animated: animated)
        tableView.endTableUpdates()

        needsLayout = true
    }
}
