//
//  DownloadedFilesPaths.swift
//  Telegram
//
//  Created by Mikhail Filimonov on 13/03/2019.
//  Copyright © 2019 Telegram. All rights reserved.
//

import Cocoa
import Postbox
import SwiftSignalKit
import TelegramCore

public struct DownloadedPath : Codable, Equatable {
    public let id: MediaId
    public let downloadedPath: String
    public let size: Int32
    public let lastModified: Int32
    public init(id: MediaId, downloadedPath: String, size: Int32, lastModified: Int32) {
        self.id = id
        self.downloadedPath = downloadedPath
        self.size = size
        self.lastModified = lastModified
    }

    
    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: StringCodingKey.self)
        
        self.id = try container.decode(MediaId.self, forKey: "id")
        self.downloadedPath = try container.decode(String.self, forKey: "dp")
        self.size = try container.decode(Int32.self, forKey: "s")
        self.lastModified = try container.decode(Int32.self, forKey: "lm")
    }
    
    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: StringCodingKey.self)        
        
        try container.encode(self.id, forKey: "id")
        try container.encode(self.downloadedPath, forKey: "dp")
        try container.encode(self.size, forKey: "s")
        try container.encode(self.lastModified, forKey: "lm")
    }
}

public struct DownloadedFilesPaths: Codable, Equatable {
    
    private let paths: [DownloadedPath]
    
    public static var defaultValue: DownloadedFilesPaths {
        return DownloadedFilesPaths(paths: [])
    }
    
    public init(paths: [DownloadedPath]) {
        self.paths = paths
    }
    
    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: StringCodingKey.self)
        self.paths = try container.decode([DownloadedPath].self, forKey: "p")
    }
    
    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: StringCodingKey.self)
        try container.encode(self.paths, forKey: "p")
    }
    
    public func path(for mediaId: MediaId) -> DownloadedPath? {
        for path in paths {
            if path.id == mediaId {
                return path
            }
        }
        return nil
    }
    
    public func withAddedPath(_ path: DownloadedPath) -> DownloadedFilesPaths {
        var paths = self.paths
        if let index = paths.firstIndex(where: {$0.id == path.id}) {
            paths[index] = path
        } else {
            paths.append(path)
        }
        return DownloadedFilesPaths(paths: paths)
    }
}


public func downloadedFilePaths(_ postbox: Postbox) -> Signal<DownloadedFilesPaths, NoError> {
    return postbox.transaction { transaction in
        return transaction.getPreferencesEntry(key: ApplicationSpecificPreferencesKeys.downloadedPaths)?.get(DownloadedFilesPaths.self) ?? DownloadedFilesPaths.defaultValue
    }
}

public func updateDownloadedFilePaths(_ postbox: Postbox, _ f: @escaping(DownloadedFilesPaths) -> DownloadedFilesPaths) -> Signal<Never, NoError> {
    return postbox.transaction { transaction in
        transaction.updatePreferencesEntry(key: ApplicationSpecificPreferencesKeys.downloadedPaths, { entry in
            let current = entry?.get(DownloadedFilesPaths.self) ?? DownloadedFilesPaths.defaultValue

            return PreferencesEntry(f(current))
        })
    }  |> ignoreValues
}
