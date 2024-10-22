//
//  HLSVideoContent.swift
//  TelegramMedia
//
//  Created by Mikhail Filimonov on 15.10.2024.
//

import TelegramCore
import Postbox
import SwiftSignalKit
import TGUIKit
import Foundation
import AppKit



internal extension PixelDimensions {
    var size: CGSize {
        return CGSize(width: CGFloat(self.width), height: CGFloat(self.height))
    }
}


public enum PlatformVideoContentId: Hashable {
    case message(MessageId, UInt32, MediaId)
    case instantPage(MediaId, MediaId)
    
    public static func ==(lhs: PlatformVideoContentId, rhs: PlatformVideoContentId) -> Bool {
        switch lhs {
        case let .message(messageId, stableId, mediaId):
            if case .message(messageId, stableId, mediaId) = rhs {
                return true
            } else {
                return false
            }
        case let .instantPage(pageId, mediaId):
            if case .instantPage(pageId, mediaId) = rhs {
                return true
            } else {
                return false
            }
        }
    }
    
    public func hash(into hasher: inout Hasher) {
        switch self {
        case let .message(messageId, _, mediaId):
            hasher.combine(messageId)
            hasher.combine(mediaId)
        case let .instantPage(pageId, mediaId):
            hasher.combine(pageId)
            hasher.combine(mediaId)
        }
    }
}



public final class HLSVideoContent : UniversalVideoContent {
    public let id: AnyHashable
    public let nativeId: PlatformVideoContentId
    let userLocation: MediaResourceUserLocation
    public let fileReference: FileMediaReference
    public let dimensions: CGSize
    public let duration: Double
    let streamVideo: Bool
    let loopVideo: Bool
    let enableSound: Bool
    let baseRate: Double
    let fetchAutomatically: Bool
    
    public init(id: PlatformVideoContentId, userLocation: MediaResourceUserLocation, fileReference: FileMediaReference, streamVideo: Bool = false, loopVideo: Bool = false, enableSound: Bool = true, baseRate: Double = 1.0, fetchAutomatically: Bool = true) {
        self.id = id
        self.userLocation = userLocation
        self.nativeId = id
        self.fileReference = fileReference
        self.dimensions = self.fileReference.media.dimensions?.size ?? CGSize(width: 480, height: 320)
        self.duration = self.fileReference.media.duration ?? 0.0
        self.streamVideo = streamVideo
        self.loopVideo = loopVideo
        self.enableSound = enableSound
        self.baseRate = baseRate
        self.fetchAutomatically = fetchAutomatically
    }
    
    public func isEqual(to other: UniversalVideoContent) -> Bool {
        if let other = other as? HLSVideoContent {
            if case let .message(_, stableId, _) = self.nativeId {
                if case .message(_, stableId, _) = other.nativeId {
                    if self.fileReference.media.isInstantVideo {
                        return true
                    }
                }
            }
        }
        return false
    }
    
    public static func minimizedHLSQuality(file: FileMediaReference) -> (playlist: FileMediaReference, file: FileMediaReference)? {
        guard let qualitySet = HLSQualitySet(baseFile: file) else {
            return nil
        }
        for (quality, qualityFile) in qualitySet.qualityFiles.sorted(by: { $0.key < $1.key }) {
            if quality >= 400 {
                guard let playlistFile = qualitySet.playlistFiles[quality] else {
                    return nil
                }
                return (playlistFile, qualityFile)
            }
        }
        return nil
    }
       
    public static func minimizedHLSQualityPreloadData(postbox: Postbox, file: FileMediaReference, userLocation: MediaResourceUserLocation, prefixSeconds: Int, autofetchPlaylist: Bool) -> Signal<(FileMediaReference, Range<Int64>)?, NoError> {
        guard let fileSet = minimizedHLSQuality(file: file) else {
            return .single(nil)
        }
        
        let playlistData: Signal<Range<Int64>?, NoError> = Signal { subscriber in
            var fetchDisposable: Disposable?
            if autofetchPlaylist {
                
                
                fetchDisposable = fetchedMediaResource(mediaBox: postbox.mediaBox, userLocation: userLocation, userContentType: MediaResourceUserContentType(file: fileSet.playlist.media), reference: fileSet.playlist.resourceReference(fileSet.playlist.media.resource)).start()
            }
            let dataDisposable = postbox.mediaBox.resourceData(fileSet.playlist.media.resource).start(next: { data in
                if !data.complete {
                    return
                }
                guard let data = try? Data(contentsOf: URL(fileURLWithPath: data.path)) else {
                    subscriber.putNext(nil)
                    subscriber.putCompletion()
                    return
                }
                guard let playlistString = String(data: data, encoding: .utf8) else {
                    subscriber.putNext(nil)
                    subscriber.putCompletion()
                    return
                }
                
                var durations: [Int] = []
                var byteRanges: [Range<Int>] = []
                
                let extinfRegex = try! NSRegularExpression(pattern: "EXTINF:(\\d+)", options: [])
                let byteRangeRegex = try! NSRegularExpression(pattern: "EXT-X-BYTERANGE:(\\d+)@(\\d+)", options: [])
                
                let extinfResults = extinfRegex.matches(in: playlistString, range: NSRange(playlistString.startIndex..., in: playlistString))
                for result in extinfResults {
                    if let durationRange = Range(result.range(at: 1), in: playlistString) {
                        if let duration = Int(String(playlistString[durationRange])) {
                            durations.append(duration)
                        }
                    }
                }
                
                let byteRangeResults = byteRangeRegex.matches(in: playlistString, range: NSRange(playlistString.startIndex..., in: playlistString))
                for result in byteRangeResults {
                    if let lengthRange = Range(result.range(at: 1), in: playlistString), let upperBoundRange = Range(result.range(at: 2), in: playlistString) {
                        if let length = Int(String(playlistString[lengthRange])), let lowerBound = Int(String(playlistString[upperBoundRange])) {
                            byteRanges.append(lowerBound ..< (lowerBound + length))
                        }
                    }
                }
                
                if durations.count != byteRanges.count {
                    subscriber.putNext(nil)
                    subscriber.putCompletion()
                    return
                }
                
                var rangeUpperBound: Int64 = 0
                var remainingSeconds = prefixSeconds
                
                for i in 0 ..< durations.count {
                    if remainingSeconds <= 0 {
                        break
                    }
                    let duration = durations[i]
                    let byteRange = byteRanges[i]
                    
                    remainingSeconds -= duration
                    rangeUpperBound = max(rangeUpperBound, Int64(byteRange.upperBound))
                }
                
                if rangeUpperBound != 0 {
                    subscriber.putNext(0 ..< rangeUpperBound)
                    subscriber.putCompletion()
                } else {
                    subscriber.putNext(nil)
                    subscriber.putCompletion()
                }
                
                return
            })
            
            return ActionDisposable {
                fetchDisposable?.dispose()
                dataDisposable.dispose()
            }
        }
        
        return playlistData
        |> map { range -> (FileMediaReference, Range<Int64>)? in
            guard let range else {
                return nil
            }
            return (fileSet.file, range)
        }
    }


}
