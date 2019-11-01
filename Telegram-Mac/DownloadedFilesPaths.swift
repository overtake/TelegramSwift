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

struct DownloadedPath : PostboxCoding, Equatable {
    let id: MediaId
    let downloadedPath: String
    let size: Int32
    let lastModified: Int32
    init(id: MediaId, downloadedPath: String, size: Int32, lastModified: Int32) {
        self.id = id
        self.downloadedPath = downloadedPath
        self.size = size
        self.lastModified = lastModified
    }

    
    init(decoder: PostboxDecoder) {
        self.id = decoder.decodeObjectForKey("id", decoder: { MediaId(decoder: $0) }) as! MediaId
        self.downloadedPath = decoder.decodeStringForKey("dp", orElse: "")
        self.size = decoder.decodeInt32ForKey("s", orElse: 0)
        self.lastModified = decoder.decodeInt32ForKey("lm", orElse: 0)
    }
    
    func encode(_ encoder: PostboxEncoder) {
        encoder.encodeObject(self.id, forKey: "id")
        encoder.encodeString(self.downloadedPath, forKey: "dp")
        encoder.encodeInt32(self.size, forKey: "s")
        encoder.encodeInt32(self.lastModified, forKey: "lm")
    }
}

struct DownloadedFilesPaths: PreferencesEntry, Equatable {
    
    private let paths: [DownloadedPath]
    
    static var defaultValue: DownloadedFilesPaths {
        return DownloadedFilesPaths(paths: [])
    }
    
    init(paths: [DownloadedPath]) {
        self.paths = paths
    }
    
    func isEqual(to: PreferencesEntry) -> Bool {
        if let other = to as? DownloadedFilesPaths {
            return other == self
        } else {
            return false
        }
    }
    
    init(decoder: PostboxDecoder) {
        self.paths = decoder.decodeObjectArrayForKey("p")
    }
    
    func encode(_ encoder: PostboxEncoder) {
        encoder.encodeObjectArray(self.paths, forKey: "p")
    }
    
    func path(for mediaId: MediaId) -> DownloadedPath? {
        for path in paths {
            if path.id == mediaId {
                return path
            }
        }
        return nil
    }
    
    func withAddedPath(_ path: DownloadedPath) -> DownloadedFilesPaths {
        var paths = self.paths
        if let index = paths.firstIndex(where: {$0.id == path.id}) {
            paths[index] = path
        } else {
            paths.append(path)
        }
        return DownloadedFilesPaths(paths: paths)
    }
}


func downloadedFilePaths(_ postbox: Postbox) -> Signal<DownloadedFilesPaths, NoError> {
    return postbox.transaction { transaction in
        return transaction.getPreferencesEntry(key: ApplicationSpecificPreferencesKeys.downloadedPaths) as? DownloadedFilesPaths ?? DownloadedFilesPaths.defaultValue
    }
}

func updateDownloadedFilePaths(_ postbox: Postbox, _ f: @escaping(DownloadedFilesPaths) -> DownloadedFilesPaths) -> Signal<Never, NoError> {
    return postbox.transaction { transaction in
        transaction.updatePreferencesEntry(key: ApplicationSpecificPreferencesKeys.downloadedPaths, { entry in
            let current = entry as? DownloadedFilesPaths ?? DownloadedFilesPaths.defaultValue

            return f(current)
        })
    }  |> ignoreValues
}
