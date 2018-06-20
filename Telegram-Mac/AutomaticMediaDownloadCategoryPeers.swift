//
//  AutomaticMediaDownloadCategoryPeers.swift
//  Telegram
//
//  Created by keepcoder on 18/04/2017.
//  Copyright © 2017 Telegram. All rights reserved.
//

import Cocoa
import PostboxMac
import SwiftSignalKitMac

public struct AutomaticMediaDownloadCategoryPeers: PostboxCoding, Equatable {
    public let privateChats: Bool
    public let groupChats: Bool
    public let channels: Bool
    public let fileSize: Int32?
    public init(privateChats: Bool, groupChats: Bool, channels: Bool, fileSize: Int32?) {
        self.privateChats = privateChats
        self.groupChats = groupChats
        self.channels = channels
        self.fileSize = fileSize
        
        if fileSize == 1 {
            var bp:Int = 0
            bp += 1
        }
    }
    
    public init(decoder: PostboxDecoder) {
        self.privateChats = decoder.decodeInt32ForKey("pc", orElse: 0) != 0
        self.groupChats = decoder.decodeInt32ForKey("g", orElse: 0) != 0
        self.channels = decoder.decodeInt32ForKey("c", orElse: 0) != 0
        self.fileSize = decoder.decodeOptionalInt32ForKey("fs")

    }
    
    public func encode(_ encoder: PostboxEncoder) {
        encoder.encodeInt32(self.privateChats ? 1 : 0, forKey: "pc")
        encoder.encodeInt32(self.groupChats ? 1 : 0, forKey: "g")
        encoder.encodeInt32(self.channels ? 1 : 0, forKey: "c")
        if let fileSize = self.fileSize {
            encoder.encodeInt32(fileSize, forKey: "fs")
        } else {
            encoder.encodeNil(forKey: "fs")
        }
    }
    
    public func withUpdatedPrivateChats(_ privateChats: Bool) -> AutomaticMediaDownloadCategoryPeers {
        return AutomaticMediaDownloadCategoryPeers(privateChats: privateChats, groupChats: self.groupChats, channels: self.channels, fileSize: self.fileSize)
    }
    
    public func withUpdatedGroupChats(_ groupChats: Bool) -> AutomaticMediaDownloadCategoryPeers {
        return AutomaticMediaDownloadCategoryPeers(privateChats: self.privateChats, groupChats: groupChats, channels: self.channels, fileSize: self.fileSize)
    }
    
    public func withUpdatedChannels(_ channels: Bool) -> AutomaticMediaDownloadCategoryPeers {
        return AutomaticMediaDownloadCategoryPeers(privateChats: self.privateChats, groupChats: self.groupChats, channels: channels, fileSize: self.fileSize)
    }
    public func withUpdatedSizeLimit(_ sizeLimit: Int32?) -> AutomaticMediaDownloadCategoryPeers {
        return AutomaticMediaDownloadCategoryPeers(privateChats: self.privateChats, groupChats: self.groupChats, channels: channels, fileSize: sizeLimit)
    }
    
    public static func ==(lhs: AutomaticMediaDownloadCategoryPeers, rhs: AutomaticMediaDownloadCategoryPeers) -> Bool {
        if lhs.privateChats != rhs.privateChats {
            return false
        }
        if lhs.channels != rhs.channels {
            return false
        }
        if lhs.groupChats != rhs.groupChats {
            return false
        }
        if lhs.fileSize != rhs.fileSize {
            return false
        }
        return true
    }
}

public struct AutomaticMediaDownloadCategories: PostboxCoding, Equatable {
    public let photo: AutomaticMediaDownloadCategoryPeers
    public let video: AutomaticMediaDownloadCategoryPeers
    public let voice: AutomaticMediaDownloadCategoryPeers
    public let files: AutomaticMediaDownloadCategoryPeers
    public let instantVideo: AutomaticMediaDownloadCategoryPeers
    public let gif: AutomaticMediaDownloadCategoryPeers
    
    public init(photo: AutomaticMediaDownloadCategoryPeers, video: AutomaticMediaDownloadCategoryPeers, files: AutomaticMediaDownloadCategoryPeers, voice: AutomaticMediaDownloadCategoryPeers, instantVideo: AutomaticMediaDownloadCategoryPeers, gif: AutomaticMediaDownloadCategoryPeers) {
        self.photo = photo
        self.video = video
        self.files = files
        self.voice = voice
        self.instantVideo = instantVideo
        self.gif = gif
    }
    
    public init(decoder: PostboxDecoder) {
        self.photo = decoder.decodeObjectForKey("p", decoder: { AutomaticMediaDownloadCategoryPeers(decoder: $0) }) as! AutomaticMediaDownloadCategoryPeers
        self.video = decoder.decodeObjectForKey("vd", decoder: { AutomaticMediaDownloadCategoryPeers(decoder: $0) }) as! AutomaticMediaDownloadCategoryPeers
        self.files = decoder.decodeObjectForKey("f", decoder: { AutomaticMediaDownloadCategoryPeers(decoder: $0) }) as! AutomaticMediaDownloadCategoryPeers
        self.voice = decoder.decodeObjectForKey("v", decoder: { AutomaticMediaDownloadCategoryPeers(decoder: $0) }) as! AutomaticMediaDownloadCategoryPeers
        self.instantVideo = decoder.decodeObjectForKey("iv", decoder: { AutomaticMediaDownloadCategoryPeers(decoder: $0) }) as! AutomaticMediaDownloadCategoryPeers
        self.gif = decoder.decodeObjectForKey("g", decoder: { AutomaticMediaDownloadCategoryPeers(decoder: $0) }) as! AutomaticMediaDownloadCategoryPeers
    }
    
    public func encode(_ encoder: PostboxEncoder) {
        encoder.encodeObject(self.photo, forKey: "p")
        encoder.encodeObject(self.video, forKey: "vd")
        encoder.encodeObject(self.files, forKey: "f")
        encoder.encodeObject(self.voice, forKey: "v")
        encoder.encodeObject(self.instantVideo, forKey: "iv")
        encoder.encodeObject(self.gif, forKey: "g")
    }
    
    public func withUpdatedPhoto(_ photo: AutomaticMediaDownloadCategoryPeers) -> AutomaticMediaDownloadCategories {
        return AutomaticMediaDownloadCategories(photo: photo, video: video, files: files, voice: voice, instantVideo: instantVideo, gif: gif)
    }
    public func withUpdatedVideo(_ video: AutomaticMediaDownloadCategoryPeers) -> AutomaticMediaDownloadCategories {
        return AutomaticMediaDownloadCategories(photo: photo, video: video, files: files, voice: voice, instantVideo: instantVideo, gif: gif)
    }
    public func withUpdatedFiles(_ files: AutomaticMediaDownloadCategoryPeers) -> AutomaticMediaDownloadCategories {
        return AutomaticMediaDownloadCategories(photo: photo, video: video, files: files, voice: voice, instantVideo: instantVideo, gif: gif)
    }
    
    public func withUpdatedVoice(_ voice: AutomaticMediaDownloadCategoryPeers) -> AutomaticMediaDownloadCategories {
        return AutomaticMediaDownloadCategories(photo: photo, video: video, files: files, voice: voice, instantVideo: instantVideo, gif: gif)
    }
    
    public func withUpdatedInstantVideo(_ instantVideo: AutomaticMediaDownloadCategoryPeers) -> AutomaticMediaDownloadCategories {
        return AutomaticMediaDownloadCategories(photo: photo, video: video, files: files, voice: voice, instantVideo: instantVideo, gif: gif)
    }
    
    public func withUpdatedGif(_ gif: AutomaticMediaDownloadCategoryPeers) -> AutomaticMediaDownloadCategories {
        return AutomaticMediaDownloadCategories(photo: photo, video: video, files: files, voice: voice, instantVideo: instantVideo, gif: gif)
    }
    
    public static func ==(lhs: AutomaticMediaDownloadCategories, rhs: AutomaticMediaDownloadCategories) -> Bool {
        if lhs.photo != rhs.photo {
            return false
        }
        if lhs.video != rhs.video {
            return false
        }
        if lhs.files != rhs.files {
            return false
        }
        if lhs.voice != rhs.voice {
            return false
        }
        if lhs.instantVideo != rhs.instantVideo {
            return false
        }
        if lhs.gif != rhs.gif {
            return false
        }
        return true
    }
}

public struct AutomaticMediaDownloadSettings: PreferencesEntry, Equatable {
    public let categories: AutomaticMediaDownloadCategories
    public let automaticDownload: Bool
    public let downloadFolder: String
    public let automaticSaveDownloadedFiles: Bool
    public static var defaultSettings: AutomaticMediaDownloadSettings {
        let categories = AutomaticMediaDownloadCategories(photo: AutomaticMediaDownloadCategoryPeers(privateChats: true, groupChats: true, channels: true, fileSize: nil), video: AutomaticMediaDownloadCategoryPeers(privateChats: false, groupChats: false, channels: false, fileSize: 10 * 1024 * 1024), files: AutomaticMediaDownloadCategoryPeers(privateChats: false, groupChats: false, channels: false, fileSize: 10 * 1024 * 1024), voice: AutomaticMediaDownloadCategoryPeers(privateChats: true, groupChats: true, channels: true, fileSize: nil), instantVideo: AutomaticMediaDownloadCategoryPeers(privateChats: true, groupChats: true, channels: true, fileSize: nil), gif: AutomaticMediaDownloadCategoryPeers(privateChats: true, groupChats: true, channels: true, fileSize: 10 * 1024 * 1024))
        return AutomaticMediaDownloadSettings(categories: categories, automaticDownload: true, downloadFolder: FastSettings.downloadsFolder ?? "~/Downloads/".nsstring.expandingTildeInPath, automaticSaveDownloadedFiles: false)
    }
    
    init(categories: AutomaticMediaDownloadCategories, automaticDownload: Bool, downloadFolder: String, automaticSaveDownloadedFiles: Bool) {
        self.categories = categories
        self.automaticDownload = automaticDownload
        self.downloadFolder = downloadFolder
        self.automaticSaveDownloadedFiles = automaticSaveDownloadedFiles
    }
    
    public init(decoder: PostboxDecoder) {
        self.categories = decoder.decodeObjectForKey("c", decoder: { AutomaticMediaDownloadCategories(decoder: $0) }) as! AutomaticMediaDownloadCategories
        self.automaticDownload = decoder.decodeBoolForKey("a", orElse: true)
        self.downloadFolder = decoder.decodeStringForKey("d", orElse: FastSettings.downloadsFolder ?? "~/Downloads/".nsstring.expandingTildeInPath)
        self.automaticSaveDownloadedFiles = decoder.decodeBoolForKey("ad", orElse: false)
    
    }
    
    public func encode(_ encoder: PostboxEncoder) {
        encoder.encodeObject(self.categories, forKey: "c")
        encoder.encodeBool(self.automaticDownload, forKey: "a")
        encoder.encodeString(self.downloadFolder, forKey: "d")
        encoder.encodeBool(self.automaticSaveDownloadedFiles, forKey: "ad")
        
    }
    
    public func isEqual(to: PreferencesEntry) -> Bool {
        if let to = to as? AutomaticMediaDownloadSettings {
            return self == to
        } else {
            return false
        }
    }
    
    public static func ==(lhs: AutomaticMediaDownloadSettings, rhs: AutomaticMediaDownloadSettings) -> Bool {
        return lhs.categories == rhs.categories && lhs.automaticDownload == rhs.automaticDownload && lhs.downloadFolder == rhs.downloadFolder && lhs.automaticSaveDownloadedFiles == rhs.automaticSaveDownloadedFiles
    }
    
    func withUpdatedCategories(_ categories: AutomaticMediaDownloadCategories) -> AutomaticMediaDownloadSettings {
        return AutomaticMediaDownloadSettings(categories: categories, automaticDownload: automaticDownload, downloadFolder: self.downloadFolder, automaticSaveDownloadedFiles: self.automaticSaveDownloadedFiles)
    }
    
    func withUpdatedAutomaticDownload(_ automaticDownload: Bool) -> AutomaticMediaDownloadSettings {
        return AutomaticMediaDownloadSettings(categories: categories, automaticDownload: automaticDownload, downloadFolder: self.downloadFolder, automaticSaveDownloadedFiles: self.automaticSaveDownloadedFiles)
    }
    
    func withUpdatedDownloadFolder(_ folder: String) -> AutomaticMediaDownloadSettings {
        return AutomaticMediaDownloadSettings(categories: categories, automaticDownload: automaticDownload, downloadFolder: folder, automaticSaveDownloadedFiles: self.automaticSaveDownloadedFiles)
    }
    
    func withUpdatedAutomaticSaveDownloadedFiles(_ automaticSaveDownloadedFiles: Bool) -> AutomaticMediaDownloadSettings {
        return AutomaticMediaDownloadSettings(categories: categories, automaticDownload: automaticDownload, downloadFolder: self.downloadFolder, automaticSaveDownloadedFiles: automaticSaveDownloadedFiles)
    }
}

func updateMediaDownloadSettingsInteractively(postbox: Postbox, _ f: @escaping (AutomaticMediaDownloadSettings) -> AutomaticMediaDownloadSettings) -> Signal<Void, NoError> {
    return postbox.transaction { transaction -> Void in
        transaction.updatePreferencesEntry(key: ApplicationSpecificPreferencesKeys.automaticMediaDownloadSettings, { entry in
            let currentSettings: AutomaticMediaDownloadSettings
            if let entry = entry as? AutomaticMediaDownloadSettings {
                currentSettings = entry
            } else {
                currentSettings = AutomaticMediaDownloadSettings.defaultSettings
            }
            return f(currentSettings)
        })
    }
}

func automaticDownloadSettings(postbox: Postbox) -> Signal<AutomaticMediaDownloadSettings, Void> {
    return postbox.preferencesView(keys: [ApplicationSpecificPreferencesKeys.automaticMediaDownloadSettings]) |> map { value in
        return value.values[ApplicationSpecificPreferencesKeys.automaticMediaDownloadSettings] as? AutomaticMediaDownloadSettings ?? AutomaticMediaDownloadSettings.defaultSettings
    }
}
