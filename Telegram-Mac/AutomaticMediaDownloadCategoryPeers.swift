//
//  AutomaticMediaDownloadCategoryPeers.swift
//  Telegram
//
//  Created by keepcoder on 18/04/2017.
//  Copyright © 2017 Telegram. All rights reserved.
//

import Cocoa
import Postbox
import SwiftSignalKit
import TelegramCore

public struct AutomaticMediaDownloadCategoryPeers: Codable, Equatable {
    public let privateChats: Bool
    public let groupChats: Bool
    public let channels: Bool
    public let fileSize: Int32?
    public init(privateChats: Bool, groupChats: Bool, channels: Bool, fileSize: Int32?) {
        self.privateChats = privateChats
        self.groupChats = groupChats
        self.channels = channels
        self.fileSize = fileSize
    }
    
    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: StringCodingKey.self)

        self.privateChats = try container.decode(Int32.self, forKey: "pc") != 0
        self.groupChats = try container.decode(Int32.self, forKey: "g") != 0
        self.channels = try container.decode(Int32.self, forKey: "c") != 0
        self.fileSize = try container.decodeIfPresent(Int32.self, forKey: "fs")

    }
    
    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: StringCodingKey.self)

        try container.encode(Int32(self.privateChats ? 1 : 0), forKey: "pc")
        try container.encode(Int32(self.groupChats ? 1 : 0), forKey: "g")
        try container.encode(Int32(self.channels ? 1 : 0), forKey: "c")
        if let fileSize = self.fileSize {
            try container.encode(fileSize, forKey: "fs")
        } else {
            try container.encodeNil(forKey: "fs")
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

public struct AutomaticMediaDownloadCategories: Codable, Equatable {
    public let photo: AutomaticMediaDownloadCategoryPeers
    public let video: AutomaticMediaDownloadCategoryPeers
    public let files: AutomaticMediaDownloadCategoryPeers
    
    public init(photo: AutomaticMediaDownloadCategoryPeers, video: AutomaticMediaDownloadCategoryPeers, files: AutomaticMediaDownloadCategoryPeers) {
        self.photo = photo
        self.video = video
        self.files = files
    }
    
    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: StringCodingKey.self)
        
        
        self.photo = try container.decode(AutomaticMediaDownloadCategoryPeers.self, forKey: "p")
        self.video = try container.decode(AutomaticMediaDownloadCategoryPeers.self, forKey: "vd")
        self.files = try container.decode(AutomaticMediaDownloadCategoryPeers.self, forKey: "f")
    }
    
    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: StringCodingKey.self)
        try container.encode(self.photo, forKey: "p")
        try container.encode(self.video, forKey: "vd")
        try container.encode(self.files, forKey: "f")
    }
    
    public func withUpdatedPhoto(_ photo: AutomaticMediaDownloadCategoryPeers) -> AutomaticMediaDownloadCategories {
        return AutomaticMediaDownloadCategories(photo: photo, video: video, files: files)
    }
    public func withUpdatedVideo(_ video: AutomaticMediaDownloadCategoryPeers) -> AutomaticMediaDownloadCategories {
        return AutomaticMediaDownloadCategories(photo: photo, video: video, files: files)
    }
    public func withUpdatedFiles(_ files: AutomaticMediaDownloadCategoryPeers) -> AutomaticMediaDownloadCategories {
        return AutomaticMediaDownloadCategories(photo: photo, video: video, files: files)
    }
    
    public func withUpdatedVoice(_ voice: AutomaticMediaDownloadCategoryPeers) -> AutomaticMediaDownloadCategories {
        return AutomaticMediaDownloadCategories(photo: photo, video: video, files: files)
    }
    
    public func withUpdatedInstantVideo(_ instantVideo: AutomaticMediaDownloadCategoryPeers) -> AutomaticMediaDownloadCategories {
        return AutomaticMediaDownloadCategories(photo: photo, video: video, files: files)
    }
    
    public func withUpdatedGif(_ gif: AutomaticMediaDownloadCategoryPeers) -> AutomaticMediaDownloadCategories {
        return AutomaticMediaDownloadCategories(photo: photo, video: video, files: files)
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
        return true
    }
}

public struct AutomaticMediaDownloadSettings: Codable, Equatable {
    public let categories: AutomaticMediaDownloadCategories
    public let automaticDownload: Bool
    public let downloadFolder: String
    public let automaticSaveDownloadedFiles: Bool
    public static var defaultSettings: AutomaticMediaDownloadSettings {
        let categories = AutomaticMediaDownloadCategories(photo: AutomaticMediaDownloadCategoryPeers(privateChats: true, groupChats: true, channels: true, fileSize: nil), video: AutomaticMediaDownloadCategoryPeers(privateChats: true, groupChats: true, channels: true, fileSize: 10 * 1024 * 1024), files: AutomaticMediaDownloadCategoryPeers(privateChats: false, groupChats: false, channels: false, fileSize: 10 * 1024 * 1024))
        return AutomaticMediaDownloadSettings(categories: categories, automaticDownload: true, downloadFolder: "~/Downloads/".nsstring.expandingTildeInPath, automaticSaveDownloadedFiles: false)
    }

    
    init(categories: AutomaticMediaDownloadCategories, automaticDownload: Bool, downloadFolder: String, automaticSaveDownloadedFiles: Bool) {
        self.categories = categories
        self.automaticDownload = automaticDownload
        self.downloadFolder = downloadFolder
        self.automaticSaveDownloadedFiles = automaticSaveDownloadedFiles
    }
    
    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: StringCodingKey.self)
        self.categories = try container.decode(AutomaticMediaDownloadCategories.self, forKey: "c")
        self.automaticDownload = try container.decode(Bool.self, forKey: "a")
        self.downloadFolder = try container.decodeIfPresent(String.self, forKey: "d") ?? AutomaticMediaDownloadSettings.defaultSettings.downloadFolder
        self.automaticSaveDownloadedFiles = try container.decode(Bool.self, forKey: "ad")
    
    }
    
    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: StringCodingKey.self)

        try container.encode(self.categories, forKey: "c")
        try container.encode(self.automaticDownload, forKey: "a")
        try container.encode(self.downloadFolder, forKey: "d")
        try container.encode(self.automaticSaveDownloadedFiles, forKey: "ad")
        
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
            if let entry = entry?.get(AutomaticMediaDownloadSettings.self) {
                currentSettings = entry
            } else {
                currentSettings = AutomaticMediaDownloadSettings.defaultSettings
            }
            return PreferencesEntry(f(currentSettings))
        })
    }
}

func automaticDownloadSettings(postbox: Postbox) -> Signal<AutomaticMediaDownloadSettings, NoError> {
    return postbox.preferencesView(keys: [ApplicationSpecificPreferencesKeys.automaticMediaDownloadSettings]) |> map { value in
        return value.values[ApplicationSpecificPreferencesKeys.automaticMediaDownloadSettings]?.get(AutomaticMediaDownloadSettings.self) ?? .defaultSettings
    }
}
