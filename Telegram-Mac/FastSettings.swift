//
//  FastSettings.swift
//  TelegramMac
//
//  Created by keepcoder on 27/01/2017.
//  Copyright © 2017 Telegram. All rights reserved.
//

import Cocoa
import TelegramCoreMac
import SwiftSignalKitMac
import PostboxMac

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
}

enum ContextTextTooltip : Int32 {
    case reply
    case edit
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
    private static let kNeedShowChannelIntro = "kNeedShowChannelIntro"
    
    private static let kNoticeAdChannel = "kNoticeAdChannel"

    private static let kBadgeFilter = "kBadgeFilter"

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
    
    static var showAdAlert: Bool {
        return !UserDefaults.standard.bool(forKey: kNoticeAdChannel)
    }
    
    static func adAlertViewed() {
        UserDefaults.standard.set(true, forKey: kNoticeAdChannel)
        UserDefaults.standard.synchronize()
    }
    
    static func openInQuickLook(_ ext: String) -> Bool {
        return UserDefaults.standard.bool(forKey: "open_in_quick_look_\(ext)")
    }
    static func toggleOpenInQuickLook(_ ext: String) -> Void {
        UserDefaults.standard.set(!openInQuickLook(ext), forKey: "open_in_quick_look_\(ext)")
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
    
    static func toggleBadgeFilter(_ enable: Bool)  {
        UserDefaults.standard.set(!enable, forKey: kBadgeFilter)
        UserDefaults.standard.synchronize()
    }
    
    static var isFiltredBadge: Bool {
        return !UserDefaults.standard.bool(forKey: kBadgeFilter)
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
    
    
    static var downloadsFolder:String? {
        let paths = NSSearchPathForDirectoriesInDomains(.downloadsDirectory, .userDomainMask, true)
        let path = paths.first
        return path
    }
    
}

fileprivate let TelegramFileMediaBoxPath:String = "TelegramFileMediaBoxPathAttributeKey"

func saveAs(_ file:TelegramMediaFile, account:Account) {
    
    let name = account.postbox.mediaBox.resourceData(file.resource) |> mapToSignal { data -> Signal< (String, String), Void> in
        if data.complete {
            var ext:String = ""
            let fileName = file.fileName ?? data.path.nsstring.lastPathComponent
            if let ext = file.fileName?.nsstring.pathExtension {
                return .single((data.path, ext))
            }
            ext = fileName.nsstring.pathExtension
            return resourceType(mimeType: file.mimeType) |> mapToSignal { _type -> Signal<(String, String), Void> in
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

func copyToDownloads(_ file: TelegramMediaFile, postbox: Postbox) -> Signal<Void, Void>  {
    return downloadFilePath(file, postbox) |> deliverOn(resourcesQueue) |> map { (boxPath, adopted) in
        var adopted = adopted
        var i:Int = 1
        let deletedPathExt = adopted.nsstring.deletingPathExtension
        while FileManager.default.fileExists(atPath: adopted, isDirectory: nil) {
            let ext = adopted.nsstring.pathExtension
            let box = FileManager.xattrStringValue(forKey: TelegramFileMediaBoxPath, at: URL(fileURLWithPath: adopted))
            if box == boxPath {
                return
            }
            
            adopted = "\(deletedPathExt) (\(i)).\(ext)"
            i += 1
        }
        
        try? FileManager.default.copyItem(atPath: boxPath, toPath: adopted)
        FileManager.setXAttrStringValue(boxPath, forKey: TelegramFileMediaBoxPath, at: URL(fileURLWithPath: adopted))
    }
    
}

private func downloadFilePath(_ file: TelegramMediaFile, _ postbox: Postbox) -> Signal<(String, String), Void> {
    return combineLatest(postbox.mediaBox.resourceData(file.resource), automaticDownloadSettings(postbox: postbox)) |> mapToSignal { data, settings -> Signal< (String, String), Void> in
        if data.complete {
            var ext:String = ""
            let fileName = file.fileName ?? data.path.nsstring.lastPathComponent
            ext = fileName.nsstring.pathExtension
            if !ext.isEmpty {
                return .single((data.path, "\(settings.downloadFolder)/\(fileName.nsstring.deletingPathExtension).\(ext)"))
            } else {
                return resourceType(mimeType: file.mimeType) |> mapToSignal { (ext) -> Signal<(String, String), Void> in
                    if let folder = FastSettings.downloadsFolder {
                        let ext = ext == "*" || ext == nil ? "file" : ext!
                        return .single((data.path, "\(folder)/\(fileName).\( ext )"))
                    }
                    return .complete()
                }
            }
        } else {
            return .complete()
        }
    }
}

func showInFinder(_ file:TelegramMediaFile, account:Account)  {
    let path = downloadFilePath(file, account.postbox) |> deliverOnMainQueue
    
    _ = path.start(next: { (boxPath, adopted) in
        do {
            var adopted = adopted
            
            var i:Int = 1
            let deletedPathExt = adopted.nsstring.deletingPathExtension
            while FileManager.default.fileExists(atPath: adopted, isDirectory: nil) {
                let ext = adopted.nsstring.pathExtension
                let box = FileManager.xattrStringValue(forKey: TelegramFileMediaBoxPath, at: URL(fileURLWithPath: adopted))
                if box == boxPath {
                    NSWorkspace.shared.activateFileViewerSelecting([URL(fileURLWithPath: adopted)])
                    return
                }
                
                adopted = "\(deletedPathExt) (\(i)).\(ext)"
                i += 1
            }
            
            try? FileManager.default.copyItem(atPath: boxPath, toPath: adopted)
            FileManager.setXAttrStringValue(boxPath, forKey: TelegramFileMediaBoxPath, at: URL(fileURLWithPath: adopted))
            NSWorkspace.shared.activateFileViewerSelecting([URL(fileURLWithPath: adopted)])
        }
    })
}

func putFileToTemp(from:String, named:String) -> Signal<String?, Void> {
    return Signal { subscriber in
        
        let new = NSTemporaryDirectory() + named
        try? FileManager.default.copyItem(atPath: from, toPath: new)
        
        subscriber.putNext(new)
        subscriber.putCompletion()
        return EmptyDisposable
    }
}
