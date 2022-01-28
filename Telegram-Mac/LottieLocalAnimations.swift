//
//  LottieLocalAnimations.swift
//  Telegram
//
//  Created by Mikhail Filimonov on 19.02.2020.
//  Copyright © 2020 Telegram. All rights reserved.
//

import Cocoa
import TelegramCore

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
    
    case screenoff
    case screenon
    
    case cameraon
    case cameraoff
    
    case bot_menu_close
    case bot_close_menu
    
    case request_join_link
    case thumbsup
    case zoom
    
    case device_android
    case device_chrome
    case device_edge
    case device_firefox
    case device_ipad
    case device_iphone
    case device_linux
    case device_mac
    case device_safari
    case device_ubuntu
    case device_windows
    
    
    case menu_add_to_folder
    case menu_archive
    case menu_clear_history
    case menu_delete
    case menu_mute
    case menu_pin
    case menu_unmuted
    case menu_unread
    case menu_read
    case menu_unpin
    case menu_unarchive
    case menu_mute_for_1_hour
    case menu_mute_for_2_days
    case menu_forward
    case menu_open_with
    case menu_reply
    case menu_report
    case menu_restrict
    case menu_retract_vote
    case menu_stop_poll
    case menu_leave
    case menu_edit
    case menu_copy_media
    case menu_copy
    case menu_copy_link
    case menu_save_as
    case menu_select_messages
    case menu_schedule_message
    case menu_send_now
    case menu_seen
    case menu_view_replies
    case menu_add_to_favorites
    case menu_add_gif
    case menu_remove_gif
    case menu_plus
    case menu_remove_from_favorites
    case menu_copyright
    case menu_pornography
    case menu_violence
    case menu_view_sticker_set
    case menu_show_message
    case menu_promote
    case menu_video_call
    case menu_call
    case menu_secret_chat
    case menu_unblock
    case menu_shared_media
    case menu_show_in_finder
    case menu_statistics
    case menu_share
    case menu_reset
    case menu_change_colors
    case open_profile
    case menu_create_group
    case menu_video_chat
    case menu_show_info
    case menu_channel
    case menu_check_selected
    case menu_collapse
    case menu_expand
    case menu_replace
    case menu_folder
    case menu_calendar
    case menu_reactions
    case menu_music
    case menu_voice
    case menu_video
    case menu_file
    case menu_open_profile
    case menu_select_multiple
    case menu_moon
    case menu_sun
    case menu_lock
    case menu_poll
    case menu_location
    case menu_camera
    
    
    case menu_folder_all_chats
    case menu_folder_animal
    case menu_folder_book
    case menu_folder_bot
    case menu_folder_coin
    case menu_folder_flash
    case menu_folder_folder
    case menu_folder_game
    case menu_folder_group
    case menu_folder_home
    case menu_folder_lamp
    case menu_folder_like
    case menu_folder_lock
    case menu_folder_love
    case menu_folder_math
    case menu_folder_music
    case menu_folder_paint
    case menu_folder_personal
    case menu_folder_plane
    case menu_folder_read
    case menu_folder_sport
    case menu_folder_star
    case menu_folder_student
    case menu_folder_telegram
    case menu_folder_unread
    case menu_folder_virus
    case menu_folder_work

    
    
    case menu_speaker_muted
    case menu_speaker
    
    case menu_sharescreen_slash
    case menu_sharescreen
    
    
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
        var thumbAtFrame: Int = 0
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
            thumbAtFrame = 60
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
        return ChatAnimatedStickerMediaLayoutParameters(playPolicy: playPolicy, alwaysAccept: true, cache: .temporaryLZ4(.thumb), hidePlayer: hidePlayer, media: self.file, shimmer: false, thumbAtFrame: thumbAtFrame)
    }
}
