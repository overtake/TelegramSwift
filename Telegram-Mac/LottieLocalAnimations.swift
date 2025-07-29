//
//  LottieLocalAnimations.swift
//  Telegram
//
//  Created by Mikhail Filimonov on 19.02.2020.
//  Copyright © 2020 Telegram. All rights reserved.
//

import Cocoa
import TelegramCore
import TelegramMedia
import Postbox

private let version = 1

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
    case global_autoremove
    case gigagroup
    case police
    case duck_empty
    case ton_logo
    case bulb
    
    case diamond
    
    case affiliate_link
    
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
    
    case group_call_share
    case group_call_minmax
    case group_call_maxmin
    case group_call_stream_empty
    
    case cameraon
    case cameraoff
    
    case bot_menu_close
    case bot_close_menu
    case bot_menu_web_app

    case request_join_link
    case thumbsup
    case zoom
    case code_note
    case email_recovery
    case qrcode_matrix
    case login_airplane
    case login_word
    
    case hand_animation
    
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
    
    case change_sim
    case pirate_flag
    case expired_story
    
    case stories_archive
    
    case share_folder
    case countdown5s
    
    case text_to_voice
    case voice_to_text
    case voice_dots
    case transcription_locked
    
    case premium_addone
    case premium_double
    case premium_unlock
    
    case premium_gift_12
    case premium_gift_6
    case premium_gift_3
    
    case ton_gift_green
    case ton_gift_blue
    case ton_gift_red

    case single_voice_fire
    
    case show_status_profile
    case show_status_read
    
    case duck_webapp_error
    case browser_back_to_close
    case browser_close_to_back
    case browser_more
    
    case improving_video
    
    case topics

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
    case menu_online
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
    case menu_folder_add
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
    case menu_unlock
    case menu_poll
    case menu_list
    case menu_location
    case menu_camera
    case menu_translate
    case menu_gear
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
    case menu_drugs
    case menu_reload
    case menu_webapp_placeholder
    case menu_autodelete_1d
    case menu_autodelete_1h
    case menu_autodelete_1m
    case menu_autodelete_1w
    case menu_autodelete_never
    case menu_autodelete_customize
    case menu_speaker_muted
    case menu_speaker
    case menu_sharescreen_slash
    case menu_sharescreen
    case menu_note_download
    case menu_note_slash
    case menu_smile
    case menu_monogram
    case menu_gift
    case menu_add_member
    case menu_topics
    case menu_pause
    case menu_play
    case menu_hide
    case menu_show
    case menu_report_false_positive
    case menu_bio
    case menu_send_spoiler
    case menu_forever
    case menu_add
    case menu_more
    case menu_atsign
    case menu_speed
    case menu_success
    case menu_save_to_profile
    case menu_move_to_contacts
    case menu_stories
    case menu_download_circle_lock
    case menu_download_circle
    case menu_eye_locked
    case menu_eye_slash
    case menu_lighting
    case menu_quote
    case menu_boost
    case menu_boost_plus
    case menu_search
    case menu_eye
    case menu_ban
    case menu_adult_slash
    case menu_adult
    case menu_sort_up
    case menu_sort_down
    case menu_verification
    case menu_paid
    case menu_apps
    case menu_close_multiple
    case menu_edited
    case menu_transfer
    case menu_wear
    case menu_wearoff
    case menu_calendar_up
    case menu_cash_up
    case menu_hashtag_up
    case menu_check
    case menu_uncheck
    
    case emoji_category_activities
    case emoji_category_angry
    case emoji_category_arrow_to_search
    case emoji_category_away
    case emoji_category_bath
    case emoji_category_busy
    case emoji_category_dislike
    case emoji_category_food
    case emoji_category_happy
    case emoji_category_heart
    case emoji_category_hi
    case emoji_category_home
    case emoji_category_like
    case emoji_category_neutral
    case emoji_category_omg
    case emoji_category_party
    case emoji_category_recent
    case emoji_category_sad
    case emoji_category_search_to_arrow
    case emoji_category_sleep
    case emoji_category_study
    case emoji_category_tongue
    case emoji_category_vacation
    case emoji_category_what
    case emoji_category_work
    
    case menu_tag_filter
    case menu_tag_remove
    case menu_tag_rename
    
    case menu_hd
    case menu_hd_lock
    case menu_sd
    
    case forum_topic
    
    case custom_reaction
    
    case business_away_message
    case business_greeting_message
    case business_hours
    case business_chatbot
    case business_location
    case business_quick_reply
    case business_links
    
    case fragment_username
    case fragment
    
    case chatlist_game
    case chatlist_music
    case chatlist_poll
    case chatlist_voice
    
    case star_currency_new
    case star_currency_part_new
    
    
    case premium_reaction_6
    
    case premium_reaction_effect_1
    case premium_reaction_effect_2
    case premium_reaction_effect_3
    case premium_reaction_effect_4
    case premium_reaction_effect_5
    
    case freeze_duck
    case direct_messages
    
    var file: TelegramMediaFile {
        let resource:LocalBundleResource = LocalBundleResource(name: self.rawValue, ext: "tgs")
        return TelegramMediaFile(fileId: MediaId(namespace: 0, id: MediaId.Id(resource.name.hashValue)), partialReference: nil, resource: resource, previewRepresentations: [], videoThumbnails: [], immediateThumbnailData: nil, mimeType: "application/x-tgsticker", size: nil, attributes: [.Sticker(displayText: "", packReference: nil, maskData: nil), .Animated, .FileName(fileName: "telegram-animoji.tgs")], alternativeRepresentations: [])
    }
    
    var monochromeFile: TelegramMediaFile {
        let resource:LocalBundleResource = LocalBundleResource(name: self.rawValue, ext: "tgs")
        return TelegramMediaFile(fileId: MediaId(namespace: 0, id: MediaId.Id(resource.name.hashValue)), partialReference: nil, resource: resource, previewRepresentations: [], videoThumbnails: [], immediateThumbnailData: nil, mimeType: "application/x-tgsticker", size: nil, attributes: [.Sticker(displayText: "", packReference: nil, maskData: nil), .Animated, .FileName(fileName: "telegram-animoji.tgs"), .CustomEmoji(isPremium: false, isSingleColor: true, alt: "", packReference: nil)], alternativeRepresentations: [])
    }
    
    func menuIcon(_ color: NSColor) -> CGImage? {
        return NSImage(named: self.rawValue)?.precomposed(color)
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
    
    static func bestForStarsGift(_ amount: Int64) -> LocalAnimatedSticker {
        if amount < 1000 {
            return LocalAnimatedSticker.premium_gift_3
        } else if amount < 2500 {
            return LocalAnimatedSticker.premium_gift_6
        } else {
            return LocalAnimatedSticker.premium_gift_12
        }
    }
    
    static func bestForTonGift(_ amount: Int64) -> LocalAnimatedSticker {
        if amount <= 10 * 1_000_000_000 {
            return LocalAnimatedSticker.ton_gift_green
        } else if amount <= 50 * 1_000_000_000 {
            return LocalAnimatedSticker.ton_gift_blue
        } else {
            return LocalAnimatedSticker.ton_gift_red
        }
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
        case .premium_gift_3:
            playPolicy = .onceEnd
        case .premium_gift_6:
            playPolicy = .onceEnd
        case .premium_gift_12:
            playPolicy = .onceEnd
        case .show_status_read:
            playPolicy = .onceEnd
        case .show_status_profile:
            playPolicy = .onceEnd
        case .business_hours:
            playPolicy = .onceEnd
        case .business_location:
            playPolicy = .onceEnd
        case .business_quick_reply:
            playPolicy = .onceEnd
        case .business_chatbot:
            playPolicy = .onceEnd
        case .business_away_message:
            playPolicy = .onceEnd
        case .business_links:
            playPolicy = .onceEnd
        case .business_greeting_message:
            playPolicy = .onceEnd
        case .fragment_username:
            playPolicy = .onceEnd
        case .fragment:
            playPolicy = .onceEnd
        case .ton_logo:
            playPolicy = .onceEnd
        case .affiliate_link:
            playPolicy = .onceEnd
        case .freeze_duck:
            playPolicy = .onceEnd
        case .topics:
            playPolicy = .onceEnd
        default:
            playPolicy = .loop
            hidePlayer = false
        }
        return ChatAnimatedStickerMediaLayoutParameters(playPolicy: playPolicy, alwaysAccept: true, cache: .temporaryLZ4(.thumb), hidePlayer: hidePlayer, media: self.file, shimmer: false, thumbAtFrame: thumbAtFrame)
    }
}
