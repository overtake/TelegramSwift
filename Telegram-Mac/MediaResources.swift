//
//  MediaResources.swift
//  Telegram
//
//  Created by keepcoder on 27/04/2017.
//  Copyright © 2017 Telegram. All rights reserved.
//

import Cocoa

import Postbox
import TelegramCore


public final class VideoMediaResourceAdjustments: PostboxCoding, Equatable {
    let data: MemoryBuffer
    let digest: MemoryBuffer
    
    init(data: MemoryBuffer, digest: MemoryBuffer) {
        self.data = data
        self.digest = digest
    }
    
    public init(decoder: PostboxDecoder) {
        self.data = decoder.decodeBytesForKey("d")!
        self.digest = decoder.decodeBytesForKey("h")!
    }
    
    public func encode(_ encoder: PostboxEncoder) {
        encoder.encodeBytes(self.data, forKey: "d")
        encoder.encodeBytes(self.digest, forKey: "h")
    }
    
    public static func ==(lhs: VideoMediaResourceAdjustments, rhs: VideoMediaResourceAdjustments) -> Bool {
        return lhs.data == rhs.data && lhs.digest == rhs.digest
    }
}

public struct VideoLibraryMediaResourceId {
    public let localIdentifier: String
    public let adjustmentsDigest: MemoryBuffer?
    
    public var uniqueId: String {
        if let adjustmentsDigest = self.adjustmentsDigest {
            return "vi-\(self.localIdentifier.replacingOccurrences(of: "/", with: "_"))-\(adjustmentsDigest.description)"
        } else {
            return "vi-\(self.localIdentifier.replacingOccurrences(of: "/", with: "_"))"
        }
    }
    
    public var hashValue: Int {
        return self.localIdentifier.hashValue
    }
}

public final class VideoLibraryMediaResource: TelegramMediaResource {
    public func isEqual(to: MediaResource) -> Bool {
        return to.id == self.id
    }
    
    public let localIdentifier: String
    public let adjustments: VideoMediaResourceAdjustments?
    
    public var headerSize: Int32 {
        return 32 * 1024
    }
    
    public var size: Int64? {
        return nil
    }
    
    public init(localIdentifier: String, adjustments: VideoMediaResourceAdjustments?) {
        self.localIdentifier = localIdentifier
        self.adjustments = adjustments
    }
    
    public required init(decoder: PostboxDecoder) {
        self.localIdentifier = decoder.decodeStringForKey("i", orElse: "")
        self.adjustments = decoder.decodeObjectForKey("a", decoder: { VideoMediaResourceAdjustments(decoder: $0) }) as? VideoMediaResourceAdjustments
    }
    
    public func encode(_ encoder: PostboxEncoder) {
        encoder.encodeString(self.localIdentifier, forKey: "i")
        if let adjustments = self.adjustments {
            encoder.encodeObject(adjustments, forKey: "a")
        } else {
            encoder.encodeNil(forKey: "a")
        }
    }
    
    public var id: MediaResourceId {
        return .init(VideoLibraryMediaResourceId(localIdentifier: self.localIdentifier, adjustmentsDigest: self.adjustments?.digest).uniqueId)
    }

}

public struct LocalFileGifMediaResourceId {
    public let randomId: Int64
    
    public var uniqueId: String {
        return "lgif-\(self.randomId)"
    }
    
    public var hashValue: Int {
        return self.randomId.hashValue
    }

}



public final class LocalFileGifMediaResource: TelegramMediaResource {
    public func isEqual(to: MediaResource) -> Bool {
        return to.id == self.id
    }
    
    public var size: Int64? {
        return nil
    }
    
    public let randomId: Int64
    public let path: String
    
    public init(randomId: Int64, path: String) {
        self.randomId = randomId
        self.path = path
    }
    
    public required init(decoder: PostboxDecoder) {
        self.randomId = decoder.decodeInt64ForKey("i", orElse: 0)
        self.path = decoder.decodeStringForKey("p", orElse: "")
    }
    
    public func encode(_ encoder: PostboxEncoder) {
        encoder.encodeInt64(self.randomId, forKey: "i")
        encoder.encodeString(self.path, forKey: "p")
    }
    
    public var id: MediaResourceId {
        return .init(LocalFileGifMediaResourceId(randomId: self.randomId).uniqueId)
    }
    
}

public struct LocalFileVideoMediaResourceId {
    public let randomId: Int64
    
    public var uniqueId: String {
        return "lmov-\(self.randomId)"
    }
    
    public var hashValue: Int {
        return self.randomId.hashValue
    }
    
}

public final class LocalFileVideoMediaResource: TelegramMediaResource {
    
    public func isEqual(to: MediaResource) -> Bool {
        if let to = to as? LocalFileVideoMediaResource {
            return self.randomId == to.randomId && self.path == to.path
        } else {
            return false
        }
    }
    public var headerSize: Int32 {
        return 32 * 1024
    }

    public var size: Int64? {
        return nil
    }

    public let randomId: Int64
    public let path: String
    
    public init(randomId: Int64, path: String) {
        self.randomId = randomId
        self.path = path
    }
    
    public required init(decoder: PostboxDecoder) {
        self.randomId = decoder.decodeInt64ForKey("i", orElse: 0)
        self.path = decoder.decodeStringForKey("p", orElse: "")
    }
    
    public func encode(_ encoder: PostboxEncoder) {
        encoder.encodeInt64(self.randomId, forKey: "i")
        encoder.encodeString(self.path, forKey: "p")
    }
    
    public var id: MediaResourceId {
        return .init(LocalFileVideoMediaResourceId(randomId: self.randomId).uniqueId)
    }
    
}

public struct LottieSoundMediaResourceId {
    public let randomId: Int64
    
    public var uniqueId: String {
        return "lottie-sound-\(self.randomId)"
    }
    
    public var hashValue: Int {
        return self.randomId.hashValue
    }
    
}

public final class LottieSoundMediaResource: TelegramMediaResource {
    public func isEqual(to: MediaResource) -> Bool {
        return to.id == self.id
    }
    public let randomId: Int64
    public let data: Data
    
    public init(randomId: Int64, data: Data) {
        self.randomId = randomId
        self.data = data
    }
    
    public var size: Int64? {
        return nil
    }
    
    public required init(decoder: PostboxDecoder) {
        self.randomId = decoder.decodeInt64ForKey("i", orElse: 0)
        self.data = decoder.decodeDataForKey("d") ?? Data()
    }
    
    public func encode(_ encoder: PostboxEncoder) {
        encoder.encodeInt64(self.randomId, forKey: "i")
        encoder.encodeData(self.data, forKey: "d")
    }
    
    public var id: MediaResourceId {
        return .init(LottieSoundMediaResourceId(randomId: self.randomId).uniqueId)
    }
    
}



public struct LocalFileArchiveMediaResourceId {
    public let randomId: Int64
    
    public var uniqueId: String {
        return "larchive-\(self.randomId)"
    }
    
    public var hashValue: Int {
        return self.randomId.hashValue
    }
}

public final class LocalFileArchiveMediaResource: TelegramMediaResource {
    public func isEqual(to: MediaResource) -> Bool {
        return to.id == self.id
    }
    public let randomId: Int64
    public let path: String
    
    public var headerSize: Int32 {
        return 32 * 1024
    }
    
    public var size: Int64? {
        return nil
    }
    
    public init(randomId: Int64, path: String) {
        self.randomId = randomId
        self.path = path
    }
    
    public required init(decoder: PostboxDecoder) {
        self.randomId = decoder.decodeInt64ForKey("i", orElse: 0)
        self.path = decoder.decodeStringForKey("p", orElse: "")
    }
    
    public func encode(_ encoder: PostboxEncoder) {
        encoder.encodeInt64(self.randomId, forKey: "i")
        encoder.encodeString(self.path, forKey: "p")
    }
    
    public var id: MediaResourceId {
        return .init(LocalFileArchiveMediaResourceId(randomId: self.randomId).uniqueId)
    }

}


public struct ExternalMusicAlbumArtResourceId {
    public let title: String
    public let performer: String
    public let isThumbnail: Bool
    
    public var uniqueId: String {
        return "ext-album-art-\(isThumbnail ? "thump" : "full")-\(self.title.replacingOccurrences(of: "/", with: "_"))-\(self.performer.replacingOccurrences(of: "/", with: "_"))"
    }
    
    public var hashValue: Int {
        return self.title.hashValue &* 31 &+ self.performer.hashValue
    }
}


public class ExternalMusicAlbumArtResource: TelegramMediaResource {
    public func isEqual(to: MediaResource) -> Bool {
        return to.id == self.id
    }
    public let title: String
    public let performer: String
    public let isThumbnail: Bool
    
    public init(title: String, performer: String, isThumbnail: Bool) {
        self.title = title
        self.performer = performer
        self.isThumbnail = isThumbnail
    }
    
    public var size: Int64? {
        return nil
    }
    
    public required init(decoder: PostboxDecoder) {
        self.title = decoder.decodeStringForKey("t", orElse: "")
        self.performer = decoder.decodeStringForKey("p", orElse: "")
        self.isThumbnail = decoder.decodeInt32ForKey("th", orElse: 1) != 0
    }
    
    public func encode(_ encoder: PostboxEncoder) {
        encoder.encodeString(self.title, forKey: "t")
        encoder.encodeString(self.performer, forKey: "p")
        encoder.encodeInt32(self.isThumbnail ? 1 : 0, forKey: "th")
    }
    
    public var id: MediaResourceId {
        return .init(ExternalMusicAlbumArtResourceId(title: self.title, performer: self.performer, isThumbnail: self.isThumbnail).uniqueId)
    }

}


public struct LocalBundleResourceId {
    public let name: String
    public let ext: String
    
    public var uniqueId: String {
        return "local-bundle-\(self.name)-\(self.ext)"
    }
    
    public var hashValue: Int {
        return self.name.hashValue
    }

}

public class LocalBundleResource: TelegramMediaResource {
    
    
    public let name: String
    public let ext: String
    public let color: NSColor?
    public let resize: Bool
    public init(name: String, ext: String, color: NSColor? = nil, resize: Bool = true) {
        self.name = name
        self.ext = ext
        self.color = color
        self.resize = resize
    }
    
    public var size: Int64? {
        return nil
    }
    
    public required init(decoder: PostboxDecoder) {
        self.name = decoder.decodeStringForKey("n", orElse: "")
        self.ext = decoder.decodeStringForKey("e", orElse: "")
        if let hexColor = decoder.decodeOptionalStringForKey("c") {
            self.color = NSColor(hexString: hexColor)
        } else {
            self.color = nil
        }
        self.resize = decoder.decodeBoolForKey("nr", orElse: true)
    }
    
    public func encode(_ encoder: PostboxEncoder) {
        encoder.encodeString(self.name, forKey: "n")
        encoder.encodeString(self.ext, forKey: "e")
        if let color = self.color {
            encoder.encodeString(color.hexString, forKey: "c")
        } else {
            encoder.encodeNil(forKey: "c")
        }
        encoder.encodeBool(self.resize, forKey: "nr")
    }
    
    public var id: MediaResourceId {
        return .init(LocalBundleResourceId(name: self.name, ext: self.ext).uniqueId)
    }
    
    public func isEqual(to: MediaResource) -> Bool {
        return to.id == self.id
    }

}


public struct ForumTopicIconResourceId {
    public let title: String
    public let bgColors: [NSColor]
    public let strokeColors: [NSColor]
    public let iconColor: Int32
    public var uniqueId: String {
        return "forum-topic-icon-\(self.title)-\(self.bgColors.map { $0.hexString })-\(self.strokeColors.map { $0.hexString })"
    }
    

}
public class ForumTopicIconResource: TelegramMediaResource {
    
    
    public let title: String
    public let iconColor: Int32
    public let bgColors: [NSColor]
    public let strokeColors: [NSColor]

    public init(title: String, bgColors: [NSColor], strokeColors: [NSColor], iconColor: Int32) {
        self.title = title
        self.bgColors = bgColors
        self.strokeColors = strokeColors
        self.iconColor = iconColor
    }
    
    public var size: Int64? {
        return nil
    }
    
    public required init(decoder: PostboxDecoder) {
        self.title = decoder.decodeStringForKey("t", orElse: "")
        self.iconColor = decoder.decodeInt32ForKey("i", orElse: 0)
        self.bgColors = decoder.decodeStringArrayForKey("b").compactMap {
            .init(hexString: $0)
        }
        self.strokeColors = decoder.decodeStringArrayForKey("s").compactMap {
            .init(hexString: $0)
        }
    }
    
    public func encode(_ encoder: PostboxEncoder) {
        encoder.encodeString(self.title, forKey: "t")
        encoder.encodeInt32(self.iconColor, forKey: "i")
        encoder.encodeStringArray(self.bgColors.map { $0.hexString }, forKey: "b")
        encoder.encodeStringArray(self.strokeColors.map { $0.hexString }, forKey: "s")
    }
    
    public var id: MediaResourceId {
        return .init(ForumTopicIconResourceId(title: title, bgColors: bgColors, strokeColors: self.strokeColors, iconColor: iconColor).uniqueId)
    }
    
    public func isEqual(to: MediaResource) -> Bool {
        return to.id == self.id
    }

}
