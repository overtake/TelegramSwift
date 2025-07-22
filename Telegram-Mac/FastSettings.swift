//
//  FastSettings.swift
//  TelegramMac
//
//  Created by keepcoder on 27/01/2017.
//  Copyright © 2017 Telegram. All rights reserved.
//

import Cocoa
import TelegramCore
import Localization
import SwiftSignalKit
import Postbox
import ObjcUtils
import InAppSettings
import TGUIKit
import WebKit
import TelegramMedia

func clearUserDefaultsObject(forKeyPrefix prefix: String) {
    let defaults = UserDefaults.standard
    let keys = defaults.dictionaryRepresentation().keys
    
    for key in keys {
        if key.hasPrefix(prefix) {
            defaults.removeObject(forKey: key)
        }
    }
}


// Extension to handle rawValue conversion
extension UniversalVideoContentVideoQuality {
    public typealias RawValue = Int
    
    public init?(rawValue: Int) {
        switch rawValue {
        case -1: // Use -1 to represent auto
            self = .auto
        case let quality where quality >= 0:
            self = .quality(quality)
        default:
            return nil
        }
    }
    
    public var rawValue: Int {
        switch self {
        case .auto:
            return -1 // Use -1 to represent auto
        case .quality(let value):
            return value
        }
    }
}




enum SendingType :String {
    case enter = "enter"
    case cmdEnter = "cmdEnter"
}

enum EntertainmentState : Int32 {
    case emoji = 0
    case stickers = 1
    case gifs = 2
}

enum RecordingStateSettings : Int32 {
    case voice = 0
    case video = 1
}

enum ForceTouchAction: Int32 {
    case edit
    case reply
    case forward
    case previewMedia
    case react
}

enum ContextTextTooltip : Int32 {
    case reply
    case edit
}

enum BotPemissionKey: String {
    case contact = "PermissionInlineBotContact"
}


enum AppTooltip {
    case voiceRecording
    case videoRecording
    case mediaPreview_archive
    case mediaPreview_collage
    case mediaPreview_media
    case mediaPreview_file
    fileprivate var localizedString: String {
        switch self {
        case .voiceRecording:
            return strings().appTooltipVoiceRecord
        case .videoRecording:
            return strings().appTooltipVideoRecord
        case .mediaPreview_archive:
            return strings().previewSenderArchiveTooltip
        case .mediaPreview_collage:
            return strings().previewSenderCollageTooltip
        case .mediaPreview_media:
            return strings().previewSenderMediaTooltip
        case .mediaPreview_file:
            return strings().previewSenderFileTooltip
        }
    }
    
    private var version:Int {
        return 1
    }
    
    fileprivate var key: String {
        switch self {
        case .voiceRecording:
            return "app_tooltip_voice_recording_" + "\(version)"
        case .videoRecording:
            return "app_tooltip_video_recording_" + "\(version)"
        case .mediaPreview_archive:
             return "app_tooltip_mediaPreview_archive_" + "\(version)"
        case .mediaPreview_collage:
             return "app_tooltip_mediaPreview_collage_" + "\(version)"
        case .mediaPreview_media:
             return "app_tooltip_mediaPreview_media_" + "\(version)"
        case .mediaPreview_file:
             return "app_tooltip_mediaPreview_file_" + "\(version)"
        }
    }
    
    fileprivate var showCount: Int {
        return 4
    }
    
}

func getAppTooltip(for value: AppTooltip, callback: (String) -> Void) {
    let shownCount: Int = UserDefaults.standard.integer(forKey: value.key)
    
    var success: Bool = false
    
    defer {
        if success {
            UserDefaults.standard.set(shownCount + 1, forKey: value.key)
            UserDefaults.standard.synchronize()
        }
    }
    //shownCount == 0 || (shownCount < value.showCount && arc4random_uniform(100) > 100 / 3)
    if true {
        success = true
        callback(value.localizedString)
    }
}

class FastSettings {
    private static let kVideoQuality = "kVideoQuality"

    private static let kSendingType = "kSendingType"
    private static let kEntertainmentType = "kEntertainmentType"
    private static let kSidebarType = "kSidebarType1"
    private static let kSidebarShownType = "kSidebarShownType2"
    private static let kDebugWebApp = "kDebugWebApp"
    private static let kRecordingStateType = "kRecordingStateType"
    private static let kInAppSoundsType = "kInAppSoundsType"
    private static let kIsMinimisizeType = "kIsMinimisizeType"
    private static let kAutomaticConvertEmojiesType = "kAutomaticConvertEmojiesType2"
    private static let kSuggestSwapEmoji = "kSuggestSwapEmoji"
    private static let kForceTouchAction = "kForceTouchAction"
    private static let kNeedCollage = "kNeedCollage"
	private static let kInstantViewScrollBySpace = "kInstantViewScrollBySpace"
    private static let kAutomaticallyPlayGifs = "kAutomaticallyPlayGifs"
    private static let kArchiveIsHidden = "kArchiveIsHidden"
    private static let kRTFEnable = "kRTFEnable";
    private static let kNeedShowChannelIntro = "kNeedShowChannelIntro"
    
    private static let kNoticeAdChannel = "kNoticeAdChannel"
    private static let kPlayingRate = "kPlayingRate2"
    private static let kPlayingMusicRate = "kPlayingMusicRate"
    private static let kPlayingVideoRate = "kPlayingVideoRate"

    private static let kSVCShareMicro = "kSVCShareMicro"

    private static let kReactionsMode = "kReactionsMode"

    private static let kVolumeRate = "kVolumeRate"
    private static let kStoryVolumeRate = "kStoryVolumeRate"

    private static let kArchiveAutohidden = "kArchiveAutohidden"
    private static let kAutohideArchiveFeature = "kAutohideArchiveFeature"

    private static let kLeftColumnWidth = "kLeftColumnWidth"

    private static let kShowEmptyTips = "kShowEmptyTips"

    
    private static let kConfirmWebApp = "kConfirmWebApp"

    private static let kAnimateInputEmoji = "kAnimateInputEmoji"
    private static let kUseNativeGraphicContext = "kUseNativeGraphicContext"

    
    private static let kPhotoSize = "kPhotoSize"

    
    private static let kStoryMuted = "kStoryMuted"
    private static let kStoryHD = "kStoryHD"
    
    private static let kHashtagChannel = "kHashtagChannel";
    
    
    private static let kContactsSort = "kContactsSort";
    
    private static let kAgeVerification = "kAgeVerification2";
    
    public static var contactsSort: PeerListState.ContactsSort {
        get {
            if let value = UserDefaults.standard.value(forKey: kContactsSort) as? Int32 {
                return .init(rawValue: value) ?? .lastSeen
            } else {
                return .lastSeen
            }
        }
        set {
            UserDefaults.standard.setValue(newValue.rawValue, forKey: kContactsSort)
        }
    }


    public static var hasHashtagChannelBadge: Bool {
        get {
            return UserDefaults.standard.bool(forKey: kHashtagChannel)
        }
        set {
            UserDefaults.standard.setValue(newValue, forKey: kHashtagChannel)
        }
    }
    
    static var sendingType:SendingType {
        let type = UserDefaults.standard.value(forKey: kSendingType) as? String
        if let type = type {
            return SendingType(rawValue: type) ?? .enter
        }
        return .enter
    }
    
    static var videoQuality: UniversalVideoContentVideoQuality {
        get {
            let rawValue = UserDefaults.standard.integer(forKey: kVideoQuality)
            return UniversalVideoContentVideoQuality(rawValue: rawValue) ?? .auto
        }
        set {
            UserDefaults.standard.set(newValue.rawValue, forKey: kVideoQuality)
            UserDefaults.standard.synchronize()
        }
    }
    
    static var entertainmentState:EntertainmentState {
        return EntertainmentState(rawValue: Int32(UserDefaults.standard.integer(forKey: kEntertainmentType))) ?? .emoji
    }
    
    static func changeEntertainmentState(_ state:EntertainmentState) {
        UserDefaults.standard.set(state.rawValue, forKey: kEntertainmentType)
        UserDefaults.standard.synchronize()
    }
    
    static func changeSendingType(_ type:SendingType) {
        UserDefaults.standard.set(type.rawValue, forKey: kSendingType)
        UserDefaults.standard.synchronize()
    }
    
    static func checkSendingAbility(for event:NSEvent) -> Bool {
        return isEnterAccessObjc(event, sendingType == .cmdEnter)
    }
    
    static func isChannelMessagesMuted(_ peerId: PeerId) -> Bool {
        return UserDefaults.standard.bool(forKey: "\(peerId)_m_muted")
    }
    
    static func toggleChannelMessagesMuted(_ peerId: PeerId) -> Void {
        UserDefaults.standard.set(!isChannelMessagesMuted(peerId), forKey: "\(peerId)_m_muted")
    }
    
    static func monoforumState(_ peerId: PeerId) -> MonoforumUIState {
        let int = UserDefaults.standard.integer(forKey: "\(peerId)_monoforum_state")
        return MonoforumUIState(rawValue: int) ?? .vertical
    }
    
    static func setMonoforumState(_ peerId: PeerId, state: MonoforumUIState) -> Void {
        UserDefaults.standard.set(state.rawValue, forKey: "\(peerId)_monoforum_state")
    }

    
    static var photoDimension: CGFloat {
        if let largePhotos = UserDefaults.standard.value(forKey: kPhotoSize) as? Bool {
            return largePhotos ? 2560 : 1280
        } else {
            return 1280
        }
    }
    
    static var sendLargePhotos: Bool {
        return UserDefaults.standard.bool(forKey: kPhotoSize)
    }
    
    static func sendLargePhotos(_ value: Bool) {
        UserDefaults.standard.setValue(value, forKey: kPhotoSize)
    }

    
    static func needConfirmPaid(_ peerId: PeerId, price: Int) -> Bool {
        return UserDefaults.standard.bool(forKey: "\(peerId)_confirm_paid_\(price)_3")
    }
    
    static func toggleCofirmPaid(_ peerId: PeerId, price: Int) -> Void {
        UserDefaults.standard.set(!needConfirmPaid(peerId, price: price), forKey: "\(peerId)_confirm_paid_\(price)_3")
    }
    
    static func shouldConfirmWebApp(_ peerId: PeerId) -> Bool {
        let value = UserDefaults.standard.value(forKey: "\(peerId)_\(kConfirmWebApp)")
        return value as? Bool ?? true
    }
    
    static func markWebAppAsConfirmed(_ peerId: PeerId) -> Void {
        UserDefaults.standard.set(false, forKey: "\(peerId)_\(kConfirmWebApp)")
    }
    
    @available(macOS 12.0, *)
    static func botAccessTo(_ type: WKMediaCaptureType, peerId: PeerId) -> Bool {
        let value = UserDefaults.standard.value(forKey: "wk2_bot_access_\(type.rawValue)_\(peerId.toInt64())") as? Bool
        
        if let value = value {
            return value
        } else {
            return false
        }
    }
    
    static func allowBotAccessToBiometric(peerId: PeerId, accountId: PeerId) {
        FastSettings.setBotAccessToBiometricRequested(peerId: peerId, accountId: accountId)
        UserDefaults.standard.setValue(true, forKey: "_biometric_bot_\(peerId.toInt64())_\(accountId.toInt64())")
        UserDefaults.standard.synchronize()
    }
    static func disallowBotAccessToBiometric(peerId: PeerId, accountId: PeerId) {
        FastSettings.setBotAccessToBiometricRequested(peerId: peerId, accountId: accountId)
        UserDefaults.standard.setValue(false, forKey: "_biometric_bot_\(peerId.toInt64())_\(accountId.toInt64())")
        UserDefaults.standard.synchronize()
    }
    static func botAccessToBiometric(peerId: PeerId, accountId: PeerId) -> Bool {
        let value = UserDefaults.standard.value(forKey: "_biometric_bot_\(peerId.toInt64())_\(accountId.toInt64())") as? Bool
        if let value = value {
            return value
        } else {
            return false
        }
    }
    
    static func setBotAccessToBiometricRequested(peerId: PeerId, accountId: PeerId) {
        UserDefaults.standard.setValue(true, forKey: "_biometric_bot_\(peerId.toInt64())_requested_\(accountId.toInt64())")
        UserDefaults.standard.synchronize()
    }
    static func botAccessToBiometricRequested(peerId: PeerId, accountId: PeerId) -> Bool {
        let value = UserDefaults.standard.value(forKey: "_biometric_bot_\(peerId.toInt64())_requested_\(accountId.toInt64())") as? Bool
        if let value = value {
            return value
        } else {
            return false
        }
    }
    static func botBiometricTokenIsSaved(peerId: PeerId, accountId: PeerId, value: Bool) {
        UserDefaults.standard.setValue(value, forKey: "_biometric_bot_\(peerId.toInt64())_token_saved_\(accountId.toInt64())")
        UserDefaults.standard.synchronize()
    }
    static func botBiometricRequestedTokenSaved(peerId: PeerId, accountId: PeerId) -> Bool {
        let value = UserDefaults.standard.value(forKey: "_biometric_bot_\(peerId.toInt64())_token_saved_\(accountId.toInt64())") as? Bool
        if let value = value {
            return value
        } else {
            return false
        }
    }
    
    
    
    @available(macOS 12.0, *)
    static func allowBotAccessTo(_ type: WKMediaCaptureType, peerId: PeerId) {
        UserDefaults.standard.setValue(true, forKey: "wk2_bot_access_\(type.rawValue)_\(peerId.toInt64())")
        UserDefaults.standard.synchronize()
    }
    
        
    static var playingRate: Double {
        let double = UserDefaults.standard.double(forKey: kPlayingRate)
        if double == 0 {
            return 1.0
        }
        return min(max(double, 0.2), 2.5)
    }
    
    static func setPlayingRate(_ rate: Double) {
        UserDefaults.standard.set(rate, forKey: kPlayingRate)
    }
    
    static var playingMusicRate: Double {
        let double = UserDefaults.standard.double(forKey: kPlayingMusicRate)
        if double == 0 {
            return 1.0
        }
        return min(max(double, 0.2), 2.5)
    }
    
    static func setPlayingMusicRate(_ rate: Double) {
        UserDefaults.standard.set(rate, forKey: kPlayingMusicRate)
    }
    
    static var playingVideoRate: Double {
        let double = UserDefaults.standard.double(forKey: kPlayingVideoRate)
        if double == 0 {
            return 1.0
        }
        return min(max(double, 0.2), 2.5)
    }
    
    static func setPlayingVideoRate(_ rate: Double) {
        UserDefaults.standard.set(rate, forKey: kPlayingVideoRate)
    }
    
    static var volumeRate: Float {
        if UserDefaults.standard.value(forKey: kVolumeRate) != nil {
            return min(max(UserDefaults.standard.float(forKey: kVolumeRate), 0), 1)
        } else {
            return 0.8
        }
    }
    
    static var volumeStoryRate: Float {
        if UserDefaults.standard.value(forKey: kStoryVolumeRate) != nil {
            return min(max(UserDefaults.standard.float(forKey: kStoryVolumeRate), 0), 1)
        } else {
            return 0.8
        }
    }
    
    static func setStoryVolumeRate(_ rate: Float) {
        UserDefaults.standard.set(rate, forKey: kStoryVolumeRate)
    }
    
    static func setVolumeRate(_ rate: Float) {
        UserDefaults.standard.set(rate, forKey: kVolumeRate)
    }
    
    static var isMinimisize: Bool {
        get {
            return UserDefaults.standard.bool(forKey: kIsMinimisizeType)
        }
        set {
            UserDefaults.standard.set(newValue, forKey: kIsMinimisizeType)
        }
    }
    static var canViewPeerId: Bool {
        get {
            return UserDefaults.standard.bool(forKey: "kCanViewPeerId")
        }
        set {
            UserDefaults.standard.set(newValue, forKey: "kCanViewPeerId")
        }
    }
    
    
    
    static var sidebarEnabled:Bool {
        return UserDefaults.standard.bool(forKey: kSidebarType)
    }
    
    static var sidebarShown: Bool {
        return !UserDefaults.standard.bool(forKey: kSidebarShownType)
    }
    
    static var debugWebApp: Bool {
        return UserDefaults.standard.bool(forKey: kDebugWebApp)
    }
    
    static func toggleDebugWebApp() {
        UserDefaults.standard.set(!debugWebApp, forKey: kDebugWebApp)
        
    }
    
    static var recordingState: RecordingStateSettings {
        return RecordingStateSettings(rawValue: Int32(UserDefaults.standard.integer(forKey: kRecordingStateType))) ?? .voice
    }
    
    static var isNeedCollage: Bool {
        get {
            if UserDefaults.standard.value(forKey: kNeedCollage) == nil {
                return true
            }
            return UserDefaults.standard.bool(forKey: kNeedCollage)
        }
        set {
            UserDefaults.standard.set(newValue, forKey: kNeedCollage)
            UserDefaults.standard.synchronize()
        }
    }
    
    static var enableRTF: Bool {
        set {
            UserDefaults.standard.set(!newValue, forKey: kRTFEnable)
            UserDefaults.standard.synchronize()
        }
        get {
             return !UserDefaults.standard.bool(forKey: kRTFEnable)
        }
    }
    
    static func toggleIsNeedCollage(_ enable: Bool) -> Void {
        UserDefaults.standard.set(enable, forKey: kNeedCollage)
        UserDefaults.standard.synchronize()
    }
    
    static var vcShareMicro: Bool {
        if let value = UserDefaults.standard.value(forKey: kSVCShareMicro) as? Bool {
            return value
        }
        return true
    }
    static func updateVCShareMicro(_ value: Bool) {
        UserDefaults.standard.setValue(value, forKey: kSVCShareMicro)
    }
    
    static var emptyTips: Bool {
        if let value = UserDefaults.standard.value(forKey: kShowEmptyTips) as? Bool {
            return value
        }
        return true
    }
    static func updateEmptyTips(_ value: Bool) {
        UserDefaults.standard.setValue(value, forKey: kShowEmptyTips)
    }
    
    static func systemUnsupported(_ time: Int32?) -> Bool {
        if #available(macOS 10.13, *) {
            return false
        } else {
            if let time = time {
                return time < Int(Date().timeIntervalSince1970)
            } else {
                return true
            }
        }
    }
    static func hideUnsupported() {
        UserDefaults.standard.setValue(Int(Date().timeIntervalSince1970) + 7 * 24 * 60 * 60, forKey: "unsupported")
    }
    
    
    static func toggleRecordingState() {
        UserDefaults.standard.set((recordingState == .voice ? RecordingStateSettings.video : RecordingStateSettings.voice).rawValue, forKey: kRecordingStateType)
    }
    
    static var needShowChannelIntro: Bool {
        return !UserDefaults.standard.bool(forKey: kNeedShowChannelIntro)
    }
    
    static func markChannelIntroHasSeen() {
        UserDefaults.standard.set(true, forKey: kNeedShowChannelIntro)
    }
    
    static var lastAgeVerification: TimeInterval? {
        get {
            return UserDefaults.standard.value(forKey: kAgeVerification) as? TimeInterval
        }
        set {
            UserDefaults.standard.set(newValue, forKey: kAgeVerification)
        }
    }
    
    static var forceTouchAction: ForceTouchAction {
        if UserDefaults.standard.value(forKey: kForceTouchAction) != nil {
            return ForceTouchAction(rawValue: Int32(UserDefaults.standard.integer(forKey: kForceTouchAction))) ?? .react
        } else {
            return .react
        }
    }
    
    static func toggleForceTouchAction(_ action: ForceTouchAction) {
        UserDefaults.standard.set(action.rawValue, forKey: kForceTouchAction)
        UserDefaults.standard.synchronize()
    }
    
    static func tooltipAbility(for tooltip: ContextTextTooltip) -> Bool {
        let value = UserDefaults.standard.integer(forKey: "tooltip:\(tooltip.rawValue)")
        UserDefaults.standard.set(value + 1, forKey: "tooltip:\(tooltip.rawValue)")
        return value < 12
    }
    
    static func archivedTooltipCountAndIncrement() -> Int {
        let value = UserDefaults.standard.integer(forKey: "archivation_tooltips")
        UserDefaults.standard.set(value + 1, forKey: "archivation_tooltips")
        return value
    }
    
    static var showAdAlert: Bool {
        return !UserDefaults.standard.bool(forKey: kNoticeAdChannel)
    }
    
    static func adAlertViewed() {
        UserDefaults.standard.set(true, forKey: kNoticeAdChannel)
        UserDefaults.standard.synchronize()
    }
    
    static func openInQuickLook(_ ext: String) -> Bool {
        return !UserDefaults.standard.bool(forKey: "open_in_quick_look_\(ext)")
    }
    static func toggleOpenInQuickLook(_ ext: String) -> Void {
        UserDefaults.standard.set(openInQuickLook(ext), forKey: "open_in_quick_look_\(ext)")
        UserDefaults.standard.synchronize()
    }
    
    static func toggleSidebarShown(_ enable: Bool) {
        UserDefaults.standard.set(!enable, forKey: kSidebarShownType)
        UserDefaults.standard.synchronize()
    }
    
    static func toggleSidebar(_ enable: Bool) {
        UserDefaults.standard.set(enable, forKey: kSidebarType)
        UserDefaults.standard.synchronize()
    }
    
    static func toggleInAppSouds(_ enable: Bool) {
        UserDefaults.standard.set(!enable, forKey: kInAppSoundsType)
        UserDefaults.standard.synchronize()
    }
    
    static func toggleReactionMode(_ legacy: Bool) {
        UserDefaults.standard.set(legacy, forKey: kReactionsMode)
        UserDefaults.standard.synchronize()
    }
    
    static var legacyReactions: Bool {
        UserDefaults.standard.bool(forKey: kReactionsMode)
    }
    
    static var inAppSounds: Bool {
        return !UserDefaults.standard.bool(forKey: kInAppSoundsType)
    }
	
	static func toggleInstantViewScrollBySpace(_ enable: Bool) {
		UserDefaults.standard.set(enable, forKey: kInstantViewScrollBySpace)
        UserDefaults.standard.synchronize()
	}
    
    static func toggleAutomaticReplaceEmojies(_ enable: Bool) {
        UserDefaults.standard.set(!enable, forKey: kAutomaticConvertEmojiesType)
        UserDefaults.standard.synchronize()
    }
    
    static var suggestSwapEmoji: Bool {
        if let value = UserDefaults.standard.value(forKey: kSuggestSwapEmoji) as? Bool {
            return value
        }
        return true
    }
    static func toggleSwapEmoji(_ value: Bool) -> Void {
        UserDefaults.standard.setValue(value, forKey: kSuggestSwapEmoji)
        UserDefaults.standard.synchronize()
    }
    
    static var isPossibleReplaceEmojies: Bool {
        return !UserDefaults.standard.bool(forKey: kAutomaticConvertEmojiesType)
    }
	
	static var instantViewScrollBySpace: Bool {
		return UserDefaults.standard.bool(forKey: kInstantViewScrollBySpace)
	}
    
    static func toggleAutoPlayGifs(_ enable: Bool) {
        UserDefaults.standard.set(!enable, forKey: kAutomaticallyPlayGifs)
        UserDefaults.standard.synchronize()
    }
    
    static var gifsAutoPlay:Bool {
        return !UserDefaults.standard.bool(forKey: kAutomaticallyPlayGifs)
    }
    
    static var archiveStatus: ItemHideStatus {
        get {
            let value = UserDefaults.standard.integer(forKey: kArchiveIsHidden)
            return ItemHideStatus(rawValue: min(value, 3))!
        }
        set {
            UserDefaults.standard.set(newValue.rawValue, forKey: kArchiveIsHidden)
            UserDefaults.standard.synchronize()
        }
    }
    
    static func showPromoTitle(for peerId: PeerId) -> Bool {
        return UserDefaults.standard.value(forKey: "promo_\(peerId)_1") as? Bool ?? true
    }
    static func removePromoTitle(for peerId: PeerId) {
        UserDefaults.standard.set(false, forKey: "promo_\(peerId)_1")
        UserDefaults.standard.synchronize()
    }
    
    static func isTestLiked(_ messageId: MessageId) -> Bool {
        return UserDefaults.standard.value(forKey: "isTestLiked_\(messageId)") as? Bool ?? false
    }
    static func toggleTestLike(_ messageId: MessageId) {
        UserDefaults.standard.set(!isTestLiked(messageId), forKey: "isTestLiked_\(messageId)")
        UserDefaults.standard.synchronize()
    }
    
    static func isSecretChatWebPreviewAvailable(for accountId: Int64) -> Bool? {
        return UserDefaults.standard.value(forKey: "IsSecretChatWebPreviewAvailable_\(accountId)") as? Bool
    }
    
    static func setSecretChatWebPreviewAvailable(for accountId: Int64, value: Bool) -> Void {
        UserDefaults.standard.set(value, forKey: "IsSecretChatWebPreviewAvailable_\(accountId)")
        UserDefaults.standard.synchronize()
    }
    
    static var storyIsMuted: Bool {
        get {
            return UserDefaults.standard.value(forKey: kStoryMuted) as? Bool ?? false
        }
        set {
            UserDefaults.standard.set(newValue, forKey: kStoryMuted)
        }
    }
    
    
    private static let kDefaultScreenShareKey = "kDefaultScreenShare"
    private static let kDefaultVideoShare = "kDefaultVideoShare"
    static func defaultScreenShare() -> String? {
        return UserDefaults.standard.value(forKey: kDefaultScreenShareKey) as? String
    }
    static func setDefaultScreenShare(_ uniqueId: String?) -> Void {
        if let uniqueId = uniqueId {
            UserDefaults.standard.set(uniqueId, forKey: kDefaultScreenShareKey)
        } else {
            UserDefaults.standard.removeObject(forKey: kDefaultScreenShareKey)
        }
        UserDefaults.standard.synchronize()
    }
    static func defaultVideoShare() -> String? {
        return UserDefaults.standard.value(forKey: kDefaultVideoShare) as? String
    }
    static func setDefaultVideoShare(_ uniqueId: String?) -> Void {
        if let uniqueId = uniqueId {
            UserDefaults.standard.set(uniqueId, forKey: kDefaultVideoShare)
        } else {
            UserDefaults.standard.removeObject(forKey: kDefaultVideoShare)
        }
        UserDefaults.standard.synchronize()
    }
    
    static var downloadsFolder:String? {
        let paths = NSSearchPathForDirectoriesInDomains(.downloadsDirectory, .userDomainMask, true)
        let path = paths.first
        return path
    }
    
    
    static func requstPermission(with permission: BotPemissionKey, for peerId: PeerId, success: @escaping()->Void) {
                
        let localizedHeader = _NSLocalizedString("Confirm.Header.\(permission.rawValue)")
        let localizedDesc = _NSLocalizedString("Confirm.Desc.\(permission.rawValue)")
        verifyAlert_button(for: mainWindow, header: localizedHeader, information: localizedDesc, successHandler: { _ in
            success()
        })
    }
    
    
    static func updateLeftColumnWidth(_ width: CGFloat) {
        UserDefaults.standard.set(round(width), forKey: kLeftColumnWidth)
        UserDefaults.standard.synchronize()
    }
    static var leftColumnWidth: CGFloat {
        return round(UserDefaults.standard.value(forKey: kLeftColumnWidth) as? CGFloat ?? 300)
    }
    
    static func dismissPendingRequests(_ peerIds:[PeerId], for peerId: PeerId) {
        
        var peers = UserDefaults.standard.value(forKey: "pendingRequests2_\(peerId)") as? [Int64] ?? []
        peers.append(contentsOf: peerIds.map { $0.toInt64() })
        peers = peers.uniqueElements
        
        UserDefaults.standard.set(peers, forKey: "pendingRequests2_\(peerId)")
        UserDefaults.standard.synchronize()
    }
    
    static func dissmissRequestChat(_ peerId: PeerId) -> Void {
        UserDefaults.standard.set(true, forKey: "dissmissRequestChat_\(peerId)")
        UserDefaults.standard.synchronize()
    }
    static func dissmissedRequestChat(_ peerId: PeerId) -> Bool {
        return UserDefaults.standard.bool(forKey: "dissmissRequestChat_\(peerId)")
    }
    
    
    static func canBeShownPendingRequests(_ peerIds:[PeerId], for peerId: PeerId) -> Bool {
        let peers = UserDefaults.standard.value(forKey: "pendingRequests2_\(peerId)") as? [Int64] ?? []
        
        let intersection = Set(peerIds.map { $0.toInt64() }).intersection(peers)
        return intersection.count != peerIds.count
    }
    
    static var animateInputEmoji: Bool {
        return UserDefaults.standard.bool(forKey: kAnimateInputEmoji)
    }
    static func toggleAnimateInputEmoji() {
        return UserDefaults.standard.set(!animateInputEmoji, forKey: kAnimateInputEmoji)
    }
    static var useNativeGraphicContext: Bool {
        let value = UserDefaults.standard.value(forKey: kUseNativeGraphicContext) as? Bool
        return value ?? true
    }
    static func toggleNativeGraphicContext() {
        return UserDefaults.standard.set(!useNativeGraphicContext, forKey: kUseNativeGraphicContext)
    }
    
    
    static var premiumPerks:[String] {
        let perks = [PremiumValue.stories.rawValue,
                     PremiumValue.wallpapers.rawValue,
                     PremiumValue.peer_colors.rawValue,
                     PremiumValue.saved_tags.rawValue,
                     PremiumValue.last_seen.rawValue,
                     PremiumValue.message_privacy.rawValue,
                     PremiumValue.business.rawValue,
                     PremiumValue.folder_tags.rawValue,
                     PremiumValue.business_intro.rawValue,
                     PremiumValue.business_bots.rawValue,
                     PremiumValue.business_links.rawValue]
        let dismissedPerks = UserDefaults.standard.value(forKey: "dismissedPerks") as? [String] ?? []
        return perks.filter { !dismissedPerks.contains($0) }
    }
    static func dismissPremiumPerk(_ string: String) {
        var dismissedPerks = UserDefaults.standard.value(forKey: "dismissedPerks") as? [String] ?? []
        dismissedPerks.append(string)
        UserDefaults.standard.setValue(dismissedPerks, forKey: "dismissedPerks")
    }
    
    static func getUUID(_ id: Int64) -> UUID? {
        let stored = UserDefaults.standard.string(forKey: "_uuid_\(id)")
        if let stored = stored {
            return .init(uuidString: stored)
        } else {
            let uuid: UUID = UUID()
            UserDefaults.standard.setValue(uuid.uuidString, forKey: "_uuid_\(id)")
            return uuid
        }
    }
    
    static func defaultUUID() -> UUID? {
        let stored = UserDefaults.standard.string(forKey: "_uuid_default")
        if let stored = stored {
            return .init(uuidString: stored)
        } else {
            let uuid: UUID = UUID()
            UserDefaults.standard.setValue(uuid.uuidString, forKey: "_uuid_default")
            return uuid
        }
    }
    
    static func isDefaultAccount(_ id: Int64) -> Bool {
        let accountId = UserDefaults.standard.value(forKey: "_default_account_id")
        
        if let accountId = accountId as? Int64 {
            return accountId == id
        } else {
            UserDefaults.standard.setValue(id, forKey: "_default_account_id")
            return true
        }

    }
    
    static func clear_uuid(_ id: Int64) {
        if #available(macOS 14.0, *) {
            if let uuid = FastSettings.getUUID(id) {
//                autoreleasepool {
//                    let configuration = WKWebViewConfiguration()
//                    configuration.websiteDataStore = WKWebsiteDataStore(forIdentifier: uuid)
//                }
//                WKWebsiteDataStore.remove(forIdentifier: uuid, completionHandler: { _ in
//                })
            }
        }
    }
}

fileprivate let TelegramFileMediaBoxPath:String = "TelegramFileMediaBoxPathAttributeKey"

func saveAs(_ file:TelegramMediaFile, account:Account) {
    
    let name = account.postbox.mediaBox.resourceData(file.resource) |> mapToSignal { data -> Signal< (String, String), NoError> in
        if data.complete {
            var ext:String = ""
            let fileName = file.fileName ?? data.path.nsstring.lastPathComponent
            if let ext = file.fileName?.nsstring.pathExtension {
                return .single((data.path, ext))
            }
            ext = fileName.nsstring.pathExtension
            return resourceType(mimeType: file.mimeType) |> mapToSignal { _type -> Signal<(String, String), NoError> in
                let ext = _type == "*" || _type == nil ? (ext.length == 0 ? "file" : ext) : _type!
                
                return .single((data.path, ext))
            }
        } else {
            return .complete()
        }
    } |> deliverOnMainQueue
    
    _ = name.start(next: { path, ext in
        savePanel(file: path, ext: ext, for: mainWindow, defaultName: file.fileName)
    })
}

func copyToDownloads(_ file: TelegramMediaFile, postbox: Postbox, saveAnyway: Bool = false) -> Signal<String?, NoError>  {
    let path = downloadFilePath(file, postbox)
    return combineLatest(queue: resourcesQueue, path, downloadedFilePaths(postbox)) |> map { (expanded, paths) in
        guard var (boxPath, adopted) = expanded else {
            return nil
        }
        let id = file.fileId
        if let path = paths.path(for: id), !saveAnyway {
            let lastModified = Int32(FileManager.default.modificationDateForFileAtPath(path: path.downloadedPath)?.timeIntervalSince1970 ?? 0)
            if fileSize(path.downloadedPath) == Int64(path.size), lastModified == path.lastModified {
                return path.downloadedPath
            }
        }
        var i:Int = 1
        let deletedPathExt = adopted.nsstring.deletingPathExtension
        while FileManager.default.fileExists(atPath: adopted, isDirectory: nil) {
            let ext = adopted.nsstring.pathExtension
            adopted = "\(deletedPathExt) (\(i)).\(ext)"
            i += 1
        }
        
        try? FileManager.default.copyItem(atPath: boxPath, toPath: adopted)

        let quarantineData = "does not really matter what is here".cString(using: String.Encoding.utf8)!
        let quarantineDataLength = Int(strlen(quarantineData))
        
//        setxattr(adopted.cString(using: .utf8), "com.apple.quarantine", quarantineData, quarantineDataLength, 0, XATTR_CREATE)
        
        //removexattr(adopted.cString(using: .utf8), "com.apple.quarantine", 0)
        
        let lastModified = FileManager.default.modificationDateForFileAtPath(path: adopted)?.timeIntervalSince1970 ?? FileManager.default.creationDateForFileAtPath(path: adopted)?.timeIntervalSince1970 ?? Date().timeIntervalSince1970
        
        let fs = fileSize(boxPath)
        let fileSize = fs ?? file.size ?? 0
        let path = DownloadedPath(id: id, downloadedPath: adopted, size: Int64(fileSize), lastModified: Int32(lastModified))
        
        _ = updateDownloadedFilePaths(postbox, {
            $0.withAddedPath(path)
        }).start()
        
        return adopted
    }
    
//    return downloadFilePath(file, postbox) |> deliverOn(resourcesQueue) |> map { (boxPath, adopted) in
//        var adopted = adopted
//        var i:Int = 1
//        let deletedPathExt = adopted.nsstring.deletingPathExtension
//        while FileManager.default.fileExists(atPath: adopted, isDirectory: nil) {
//            let ext = adopted.nsstring.pathExtension
//            let box = FileManager.xattrStringValue(forKey: TelegramFileMediaBoxPath, at: URL(fileURLWithPath: adopted))
//            if box == boxPath {
//                return
//            }
//
//            adopted = "\(deletedPathExt) (\(i)).\(ext)"
//            i += 1
//        }
//
//        try? FileManager.default.copyItem(atPath: boxPath, toPath: adopted)
//        FileManager.setXAttrStringValue(boxPath, forKey: TelegramFileMediaBoxPath, at: URL(fileURLWithPath: adopted))
//    }
//
}

extension String {
    var fixedFileName: String {
        var string = self.replacingOccurrences(of: "/", with: "_")
        
        var range = string.nsstring.range(of: ".")
        while range.location == 0 {
            string = string.nsstring.replacingCharacters(in: range, with: "_")
            range = string.nsstring.range(of: ".")
        }
        return string
    }
}

func downloadFilePath(_ file: TelegramMediaFile, _ postbox: Postbox) -> Signal<(String, String)?, NoError> {
    return combineLatest(postbox.mediaBox.resourceData(file.resource), automaticDownloadSettings(postbox: postbox)) |> take(1) |> mapToSignal { data, settings -> Signal< (String, String)?, NoError> in
        if data.complete {
            var ext:String = ""
            let fileName = (file.fileName ?? data.path.nsstring.lastPathComponent).fixedFileName
            ext = fileName.nsstring.pathExtension
            if !ext.isEmpty {
                return .single((data.path, "\(settings.downloadFolder)/\(fileName.nsstring.deletingPathExtension).\(ext)"))
            } else {
                return .single((data.path, "\(settings.downloadFolder)/\(fileName.nsstring.deletingPathExtension)"))
//                return resourceType(mimeType: file.mimeType) |> mapToSignal { (ext) -> Signal<(String, String)?, NoError> in
//                    if let folder = FastSettings.downloadsFolder {
//                        let ext = ext == "*" || ext == nil ? "file" : ext!
//                        return .single((data.path, "\(folder)/\(fileName).\( ext )"))
//                    }
//                    return .single(nil)
//                }
            }
        } else {
            return .single(nil)
        }
    }
}

func fileFinderPath(_ file: TelegramMediaFile, _ postbox: Postbox) -> Signal<String?, NoError> {
    return combineLatest(downloadFilePath(file, postbox), downloadedFilePaths(postbox)) |> map { (expanded, paths) in
        guard let (boxPath, adopted) = expanded else {
            return nil
        }
        if let id = file.id {
            do {
                
                if let path = paths.path(for: id) {
                    let lastModified = Int32(FileManager.default.modificationDateForFileAtPath(path: path.downloadedPath)?.timeIntervalSince1970 ?? 0)
                    if fileSize(path.downloadedPath) == Int64(path.size), lastModified == path.lastModified {
                       return path.downloadedPath
                    }
                }
                
                return adopted
            }
        } else {
            return nil
        }
    }
}

func showInFinder(_ file:TelegramMediaFile, account:Account)  {
    let path = downloadFilePath(file, account.postbox) |> deliverOnMainQueue
    
    _ = combineLatest(queue: .mainQueue(), path, downloadedFilePaths(account.postbox)).start(next: { (expanded, paths) in
        
        guard let (boxPath, adopted) = expanded else {
            return
        }
        if let id = file.id {
            do {
                
                if let path = paths.path(for: id) {
                    let lastModified = Int32(FileManager.default.modificationDateForFileAtPath(path: path.downloadedPath)?.timeIntervalSince1970 ?? 0)
                    if fileSize(path.downloadedPath) == Int64(path.size), lastModified == path.lastModified {
                        NSWorkspace.shared.activateFileViewerSelecting([URL(fileURLWithPath: path.downloadedPath)])
                        return
                    }
                
                }
                
                var adopted = adopted
                var i:Int = 1
                let deletedPathExt = adopted.nsstring.deletingPathExtension
                while FileManager.default.fileExists(atPath: adopted, isDirectory: nil) {
                    let ext = adopted.nsstring.pathExtension
                    adopted = "\(deletedPathExt) (\(i)).\(ext)"
                    i += 1
                }
                
                try? FileManager.default.copyItem(atPath: boxPath, toPath: adopted)
           
                let quarantineData = "does not really matter what is here".cString(using: String.Encoding.utf8)!
                let quarantineDataLength = Int(strlen(quarantineData))
                
//                setxattr(adopted.cString(using: .utf8), "com.apple.quarantine", quarantineData, quarantineDataLength, 0, XATTR_CREATE)

                    // removexattr(adopted.cString(using: .utf8), "com.apple.quarantine", 0)

                
                let lastModified = FileManager.default.modificationDateForFileAtPath(path: adopted)?.timeIntervalSince1970 ?? FileManager.default.creationDateForFileAtPath(path: adopted)?.timeIntervalSince1970 ?? Date().timeIntervalSince1970
                
                let fs = fileSize(boxPath)
                let fileSize = fs ?? file.size ?? 0
                let path = DownloadedPath(id: id, downloadedPath: adopted, size: Int64(fileSize), lastModified: Int32(lastModified))
                
                NSWorkspace.shared.activateFileViewerSelecting([URL(fileURLWithPath: adopted)])
                _ = updateDownloadedFilePaths(account.postbox, {
                    $0.withAddedPath(path)
                }).start()
                
            }
        }
    })
}




func putFileToTemp(from:String, named:String) -> Signal<String?, NoError> {
    return Signal { subscriber in
        
        let new = NSTemporaryDirectory() + named
        try? FileManager.default.removeItem(atPath: new)
        try? FileManager.default.copyItem(atPath: from, toPath: new)
        
        subscriber.putNext(new)
        subscriber.putCompletion()
        return EmptyDisposable
    }
}


