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

enum LocalAnimatedSticker : String {
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
    case discussion
    case group_call_chatlist_typing
    case invitations
    case destructor
    case gigagroup
    case police
    
    case voice_chat_raise_hand_1
    case voice_chat_raise_hand_2
    case voice_chat_raise_hand_3
    case voice_chat_raise_hand_4
    case voice_chat_raise_hand_5
    case voice_chat_raise_hand_6
    case voice_chat_raise_hand_7

    case voice_chat_hand_on_muted
    case voice_chat_hand_on_unmuted
    case voice_chat_hand_off
    case voice_chat_mute
    case voice_chat_unmute

    case voice_chat_start_chat_to_mute
    case voice_chat_set_reminder
    case voice_chat_set_reminder_to_raise_hand
    case voice_chat_set_reminder_to_mute
    case voice_chat_cancel_reminder_to_raise_hand
    case voice_chat_cancel_reminder
    case voice_chat_cancel_reminder_to_mute
    
    case playlist_play_pause
    case playlist_pause_play

    var file: TelegramMediaFile {
        let resource:LocalBundleResource = LocalBundleResource(name: self.rawValue, ext: "tgs")
        return TelegramMediaFile(fileId: MediaId(namespace: 0, id: MediaId.Id(resource.name.hashValue)), partialReference: nil, resource: resource, previewRepresentations: [], videoThumbnails: [], immediateThumbnailData: nil, mimeType: "application/x-tgsticker", size: nil, attributes: [.Sticker(displayText: "", packReference: nil, maskData: nil), .Animated, .FileName(fileName: "telegram-animoji.tgs")])
    }
    
    
    private static var cachedData:[String: Data] = [:]
    var data: Data? {
        if let data = LocalAnimatedSticker.cachedData[self.rawValue] {
            return data
        }
        let path = Bundle.main.path(forResource: self.rawValue, ofType: "tgs")
        if let path = path {
            let data = try? Data(contentsOf: URL(fileURLWithPath: path))
            if let data = data {
                LocalAnimatedSticker.cachedData[self.rawValue] = data
                return data
            }
        }
        return nil
    }
    
    var parameters: ChatAnimatedStickerMediaLayoutParameters {
        let playPolicy: LottiePlayPolicy?
        var hidePlayer: Bool = true
        switch self {
        case .brilliant_static:
            playPolicy = .loop
        case .brilliant_loading:
            playPolicy = .loop
        case .smart_guy:
            playPolicy = .once
        case .fly_dollar:
            playPolicy = .loop
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
            playPolicy = .loop
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
            playPolicy = .onceEnd
            hidePlayer = false
        case .dice_idle:
            playPolicy = .once
        case .folder:
            playPolicy = .once
        case .new_folder:
            playPolicy = .loop
        case .folder_empty:
            playPolicy = .loop
        case .graph_loading:
            playPolicy = .loop
            hidePlayer = false
        case .dart_idle:
            playPolicy = .once
        case .discussion:
            playPolicy = .loop
            hidePlayer = false
        case .group_call_chatlist_typing:
            playPolicy = .loop
            hidePlayer = false
        case .invitations:
            playPolicy = .loop
            hidePlayer = false
        case .destructor:
            playPolicy = .loop
            hidePlayer = false
        case .gigagroup:
            playPolicy = .loop
            hidePlayer = false
        case .police:
            playPolicy = .loop
            hidePlayer = false
        default:
            playPolicy = .loop
            hidePlayer = false
        }
        return ChatAnimatedStickerMediaLayoutParameters(playPolicy: playPolicy, alwaysAccept: true, cache: .temporaryLZ4(.thumb), hidePlayer: hidePlayer, media: self.file)
    }
}
