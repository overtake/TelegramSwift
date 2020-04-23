//
//  FastSettings.swift
//  TelegramMac
//
//  Created by keepcoder on 27/01/2017.
//  Copyright © 2017 Telegram. All rights reserved.
//

import Cocoa
import TelegramCore
import SyncCore
import SwiftSignalKit
import Postbox

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
            return L10n.appTooltipVoiceRecord
        case .videoRecording:
            return L10n.appTooltipVideoRecord
        case .mediaPreview_archive:
            return L10n.previewSenderArchiveTooltip
        case .mediaPreview_collage:
            return L10n.previewSenderCollageTooltip
        case .mediaPreview_media:
            return L10n.previewSenderMediaTooltip
        case .mediaPreview_file:
            return L10n.previewSenderFileTooltip
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

    private static let kSendingType = "kSendingType"
    private static let kEntertainmentType = "kEntertainmentType"
    private static let kSidebarType = "kSidebarType1"
    private static let kSidebarShownType = "kSidebarShownType2"
    private static let kRecordingStateType = "kRecordingStateType"
    private static let kInAppSoundsType = "kInAppSoundsType"
    private static let kIsMinimisizeType = "kIsMinimisizeType"
    private static let kAutomaticConvertEmojiesType = "kAutomaticConvertEmojiesType2"
    private static let kForceTouchAction = "kForceTouchAction"
    private static let kNeedCollage = "kNeedCollage"
	private static let kInstantViewScrollBySpace = "kInstantViewScrollBySpace"
    private static let kAutomaticallyPlayGifs = "kAutomaticallyPlayGifs"
    private static let kArchiveIsHidden = "kArchiveIsHidden"
    private static let kRTFEnable = "kRTFEnable";
    private static let kNeedShowChannelIntro = "kNeedShowChannelIntro"
    
    private static let kNoticeAdChannel = "kNoticeAdChannel"
    private static let kPlayingRate = "kPlayingRate"


    private static let kVolumeRate = "kVolumeRate"
    
    private static let kArchiveAutohidden = "kArchiveAutohidden"
    private static let kAutohideArchiveFeature = "kAutohideArchiveFeature"

    private static let kLeftColumnWidth = "kLeftColumnWidth"

    static var sendingType:SendingType {
        let type = UserDefaults.standard.value(forKey: kSendingType) as? String
        if let type = type {
            return SendingType(rawValue: type) ?? .enter
        }
        return .enter
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
    
    static var playingRate: Double {
        return min(max(UserDefaults.standard.double(forKey: kPlayingRate), 1), 1.7)
    }
    
    static func setPlayingRate(_ rate: Double) {
        UserDefaults.standard.set(rate, forKey: kPlayingRate)
    }
    
    static var volumeRate: Float {
        if UserDefaults.standard.value(forKey: kVolumeRate) != nil {
            return min(max(UserDefaults.standard.float(forKey: kVolumeRate), 0), 1)
        } else {
            return 0.8
        }
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
    
    static var sidebarEnabled:Bool {
        return UserDefaults.standard.bool(forKey: kSidebarType)
    }
    
    static var sidebarShown: Bool {
        return !UserDefaults.standard.bool(forKey: kSidebarShownType)
    }
    
    static var recordingState: RecordingStateSettings {
        return RecordingStateSettings(rawValue: Int32(UserDefaults.standard.integer(forKey: kRecordingStateType))) ?? .voice
    }
    
    static var isNeedCollage: Bool {
        return UserDefaults.standard.bool(forKey: kNeedCollage)
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
    
    static func toggleRecordingState() {
        UserDefaults.standard.set((recordingState == .voice ? RecordingStateSettings.video : RecordingStateSettings.voice).rawValue, forKey: kRecordingStateType)
    }
    
    static var needShowChannelIntro: Bool {
        return !UserDefaults.standard.bool(forKey: kNeedShowChannelIntro)
    }
    
    static func markChannelIntroHasSeen() {
        UserDefaults.standard.set(true, forKey: kNeedShowChannelIntro)
    }
    
    static var forceTouchAction: ForceTouchAction {
        return ForceTouchAction(rawValue: Int32(UserDefaults.standard.integer(forKey: kForceTouchAction))) ?? .edit
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
    
    static var archiveStatus: HiddenArchiveStatus {
        get {
            let value = UserDefaults.standard.integer(forKey: kArchiveIsHidden)
            return HiddenArchiveStatus(rawValue: min(value, 3))!
        }
        set {
            UserDefaults.standard.set(newValue.rawValue, forKey: kArchiveIsHidden)
            UserDefaults.standard.synchronize()
        }
    }
    
    
    static var downloadsFolder:String? {
        let paths = NSSearchPathForDirectoriesInDomains(.downloadsDirectory, .userDomainMask, true)
        let path = paths.first
        return path
    }
    
    
    static func requstPermission(with permission: BotPemissionKey, for peerId: PeerId, success: @escaping()->Void) {
                
        let localizedHeader = _NSLocalizedString("Confirm.Header.\(permission.rawValue)")
        let localizedDesc = _NSLocalizedString("Confirm.Desc.\(permission.rawValue)")
        confirm(for: mainWindow, header: localizedHeader, information: localizedDesc, successHandler: { _ in
            success()
        })
    }
    
    static func diceHasAlreadyPlayed(_ message: Message) -> Bool {
        return UserDefaults.standard.bool(forKey: "dice_\(message.id.id)_\(message.id.namespace)_\(message.stableId)")
    }
    static func markDiceAsPlayed(_ message: Message) {
        UserDefaults.standard.set(true, forKey: "dice_\(message.id.id)_\(message.id.namespace)_\(message.stableId)")
        UserDefaults.standard.synchronize()
    }
    
    static func updateLeftColumnWidth(_ width: CGFloat) {
        UserDefaults.standard.set(round(width), forKey: kLeftColumnWidth)
        UserDefaults.standard.synchronize()
    }
    static var leftColumnWidth: CGFloat {
        return round(UserDefaults.standard.value(forKey: kLeftColumnWidth) as? CGFloat ?? 300)
    }
    
    /*
 
     +(void)requestPermissionWithKey:(NSString *)permissionKey peer_id:(int)peer_id handler:(void (^)(bool success))handler {
     
     static NSMutableDictionary *denied;
     
     static dispatch_once_t onceToken;
     dispatch_once(&onceToken, ^{
     denied =  [NSMutableDictionary dictionary];
     });
     
     
     
     NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
     
     NSString *key = [NSString stringWithFormat:@"%@:%d",permissionKey,peer_id];
     
     BOOL access = [defaults boolForKey:key];
     
     
     if(access) {
     if(handler)
     handler(access);
     } else {
     
     if([denied[key] boolValue]) {
     if(handler)
     handler(NO);
     return;
     }
     
     NSString *localizeHeaderKey = [NSString stringWithFormat:@"Confirm.Header.%@",permissionKey];
     NSString *localizeDescKey = [NSString stringWithFormat:@"Confirm.Desc.%@",permissionKey];
     confirm(NSLocalizedString(localizeHeaderKey, nil), NSLocalizedString(localizeDescKey, nil), ^{
     if(handler)
     handler(YES);
     
     [defaults setBool:YES forKey:key];
     [defaults synchronize];
     }, ^{
     if(handler)
     handler(NO);
     
     [denied setValue:@(YES) forKey:key];
     
     [defaults setBool:NO forKey:key];
     [defaults synchronize];
     });
     }
     
     }

 */
    
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
        savePanel(file: path, ext: ext, for: mainWindow)
    })
}

func copyToDownloads(_ file: TelegramMediaFile, postbox: Postbox) -> Signal<String?, NoError>  {
    let path = downloadFilePath(file, postbox)
    return combineLatest(queue: resourcesQueue, path, downloadedFilePaths(postbox)) |> map { (expanded, paths) in
        guard let (boxPath, adopted) = expanded else {
            return nil
        }
        if let id = file.id {
            if let path = paths.path(for: id) {
                let lastModified = Int32(FileManager.default.modificationDateForFileAtPath(path: path.downloadedPath)?.timeIntervalSince1970 ?? 0)
                if fileSize(path.downloadedPath) == Int(path.size), lastModified == path.lastModified {
                    return path.downloadedPath
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
            
            
            let lastModified = FileManager.default.modificationDateForFileAtPath(path: adopted)?.timeIntervalSince1970 ?? FileManager.default.creationDateForFileAtPath(path: adopted)?.timeIntervalSince1970 ?? Date().timeIntervalSince1970
            
            let fs = fileSize(boxPath)
            let path = DownloadedPath(id: id, downloadedPath: adopted, size: fs != nil ? Int32(fs!) : nil ?? Int32(file.size ?? 0), lastModified: Int32(lastModified))
            
            _ = updateDownloadedFilePaths(postbox, {
                $0.withAddedPath(path)
            }).start()
            
            return adopted
        } else {
            return adopted
        }
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

func downloadFilePath(_ file: TelegramMediaFile, _ postbox: Postbox) -> Signal<(String, String)?, NoError> {
    return combineLatest(postbox.mediaBox.resourceData(file.resource) |> take(1), automaticDownloadSettings(postbox: postbox) |> take(1)) |> mapToSignal { data, settings -> Signal< (String, String)?, NoError> in
        if data.complete {
            var ext:String = ""
            let fileName = file.fileName ?? data.path.nsstring.lastPathComponent
            ext = fileName.nsstring.pathExtension
            if !ext.isEmpty {
                return .single((data.path, "\(settings.downloadFolder)/\(fileName.nsstring.deletingPathExtension).\(ext)"))
            } else {
                return resourceType(mimeType: file.mimeType) |> mapToSignal { (ext) -> Signal<(String, String)?, NoError> in
                    if let folder = FastSettings.downloadsFolder {
                        let ext = ext == "*" || ext == nil ? "file" : ext!
                        return .single((data.path, "\(folder)/\(fileName).\( ext )"))
                    }
                    return .single(nil)
                }
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
                    if fileSize(path.downloadedPath) == Int(path.size), lastModified == path.lastModified {
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
    
    _ = combineLatest(path, downloadedFilePaths(account.postbox)).start(next: { (expanded, paths) in
        
        guard let (boxPath, adopted) = expanded else {
            return
        }
        if let id = file.id {
            do {
                
                if let path = paths.path(for: id) {
                    let lastModified = Int32(FileManager.default.modificationDateForFileAtPath(path: path.downloadedPath)?.timeIntervalSince1970 ?? 0)
                    if fileSize(path.downloadedPath) == Int(path.size), lastModified == path.lastModified {
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

                
                let lastModified = FileManager.default.modificationDateForFileAtPath(path: adopted)?.timeIntervalSince1970 ?? FileManager.default.creationDateForFileAtPath(path: adopted)?.timeIntervalSince1970 ?? Date().timeIntervalSince1970
                
                let fs = fileSize(boxPath)
                let path = DownloadedPath(id: id, downloadedPath: adopted, size: fs != nil ? Int32(fs!) : nil ?? Int32(file.size ?? 0), lastModified: Int32(lastModified))
                
                
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


