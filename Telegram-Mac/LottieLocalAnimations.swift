//
//  LottieLocalAnimations.swift
//  Telegram
//
//  Created by Mikhail Filimonov on 19.02.2020.
//  Copyright © 2020 Telegram. All rights reserved.
//

import Cocoa
import TelegramCore
import SyncCore
import Postbox

enum LocalAnimatedSticker {
    case brilliant_static
    case brilliant_loading
    case smart_guy
    case fly_dollar
    case gift
    case keychain
    case keyboard_typing
    case swap_money
    case write_words
    case chiken_born
    case sad
    case success
    case monkey_unsee
    case monkey_see
    case think_spectacular
    case success_saved
    case dice_idle
    case folder
    case new_folder
    case folder_empty
    case graph_loading
    case dart_idle
    var file: TelegramMediaFile {
        let resource:LocalBundleResource
        switch self {
        case .brilliant_static:
            resource = LocalBundleResource(name: "brilliant_static", ext: "tgs")
        case .brilliant_loading:
            resource = LocalBundleResource(name: "brilliant_loading", ext: "tgs")
        case .smart_guy:
            resource = LocalBundleResource(name: "smart_guy", ext: "tgs")
        case .fly_dollar:
            resource = LocalBundleResource(name: "fly_dollar", ext: "tgs")
        case .gift:
            resource = LocalBundleResource(name: "gift", ext: "tgs")
        case .keychain:
            resource = LocalBundleResource(name: "keychain", ext: "tgs")
        case .keyboard_typing:
            resource = LocalBundleResource(name: "keyboard_typing", ext: "tgs")
        case .swap_money:
            resource = LocalBundleResource(name: "swap_money", ext: "tgs")
        case .write_words:
            resource = LocalBundleResource(name: "write_words", ext: "tgs")
        case .chiken_born:
            resource = LocalBundleResource(name: "chiken_born", ext: "tgs")
        case .sad:
            resource = LocalBundleResource(name: "sad_man", ext: "tgs")
        case .success:
            resource = LocalBundleResource(name: "wallet_success_created", ext: "tgs")
        case .monkey_unsee:
            resource = LocalBundleResource(name: "monkey_unsee", ext: "tgs")
        case .monkey_see:
            resource = LocalBundleResource(name: "monkey_see", ext: "tgs")
        case .think_spectacular:
            resource = LocalBundleResource(name: "think_spectacular", ext: "tgs")
        case .success_saved:
            resource = LocalBundleResource(name: "success_saved", ext: "tgs")
        case .dice_idle:
            resource = LocalBundleResource(name: "dice_idle", ext: "tgs")
        case .folder:
            resource = LocalBundleResource(name: "folder", ext: "tgs")
        case .new_folder:
            resource = LocalBundleResource(name: "folder_new", ext: "tgs")
        case .folder_empty:
            resource = LocalBundleResource(name: "folder_empty", ext: "tgs")
        case .graph_loading:
            resource = LocalBundleResource(name: "graph_loading", ext: "tgs")
        case .dart_idle:
            resource = LocalBundleResource(name: "dart_idle", ext: "tgs")
        }
        return TelegramMediaFile(fileId: MediaId(namespace: 0, id: MediaId.Id(resource.name.hashValue)), partialReference: nil, resource: resource, previewRepresentations: [], immediateThumbnailData: nil, mimeType: "application/x-tgsticker", size: nil, attributes: [.Sticker(displayText: "", packReference: nil, maskData: nil), .Animated, .FileName(fileName: "telegram-animoji.tgs")])
    }
    
    var parameters: ChatAnimatedStickerMediaLayoutParameters {
        let playPolicy: LottiePlayPolicy?
        var alwaysAccept: Bool? = nil
        switch self {
        case .brilliant_static:
            playPolicy = .loop
        case .brilliant_loading:
            playPolicy = .loop
        case .smart_guy:
            playPolicy = .once
        case .fly_dollar:
            playPolicy = .loop
            alwaysAccept = true
        case .gift:
            playPolicy = .once
        case .keychain:
            playPolicy = .once
        case .keyboard_typing:
            playPolicy = .once
        case .swap_money:
            playPolicy = .once
        case .write_words:
            playPolicy = .once
        case .chiken_born:
            playPolicy = .onceEnd
        case .sad:
            playPolicy = .once
        case .success:
            playPolicy = .once
        case .monkey_unsee:
            playPolicy = .once
        case .monkey_see:
            playPolicy = .once
        case .think_spectacular:
            playPolicy = .once
        case .success_saved:
            playPolicy = .onceToFrame(25)
        case .dice_idle:
            playPolicy = .once
        case .folder:
            playPolicy = .once
        case .new_folder:
            playPolicy = .loop
        case .folder_empty:
            playPolicy = .once
        case .graph_loading:
            playPolicy = .loop
        case .dart_idle:
            playPolicy = .once
        }
        return ChatAnimatedStickerMediaLayoutParameters(playPolicy: playPolicy, alwaysAccept: alwaysAccept, media: self.file)
    }
}
