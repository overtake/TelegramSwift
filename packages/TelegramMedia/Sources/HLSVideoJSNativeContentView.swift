//
//  HLSJSServerSource.swift
//  TelegramMedia
//
//  Created by Mikhail Filimonov on 15.10.2024.
//

import Foundation
import AVFoundation
import SwiftSignalKit
import Postbox
import TelegramCore
import WebKit
import TelegramVoip
import RangeSet
import ManagedFile
import FFMpegBinding
import RangeSet
import TGUIKit
import TelegramMediaPlayer

private func parseRange(from rangeString: String) -> Range<Int>? {
    guard rangeString.hasPrefix("bytes=") else {
        return nil
    }
    
    let rangeValues = rangeString.dropFirst("bytes=".count).split(separator: "-")
    
    guard rangeValues.count == 2,
          let start = Int(rangeValues[0]),
          let end = Int(rangeValues[1]) else {
        return nil
    }
    return start ..< end
}

private protocol SharedHLSServerSource: AnyObject {
    var id: String { get }
    
    func masterPlaylistData() -> Signal<String, NoError>
    func playlistData(quality: Int) -> Signal<String, NoError>
    func partData(index: Int, quality: Int) -> Signal<Data?, NoError>
    func fileData(id: Int64, range: Range<Int>) -> Signal<(TempBoxFile, Range<Int>, Int)?, NoError>
    func arbitraryFileData(path: String) -> Signal<(data: Data, contentType: String)?, NoError>
}

private final class HLSJSServerSource: SharedHLSServerSource {
    let id: String
    let postbox: Postbox
    let userLocation: MediaResourceUserLocation
    let playlistFiles: [Int: FileMediaReference]
    let qualityFiles: [Int: FileMediaReference]
    
    private var playlistFetchDisposables: [Int: Disposable] = [:]
    
    init(accountId: Int64, fileId: Int64, postbox: Postbox, userLocation: MediaResourceUserLocation, playlistFiles: [Int: FileMediaReference], qualityFiles: [Int: FileMediaReference]) {
        self.id = "\(UInt64(bitPattern: accountId))_\(fileId)"
        self.postbox = postbox
        self.userLocation = userLocation
        self.playlistFiles = playlistFiles
        self.qualityFiles = qualityFiles
    }
    
    deinit {
        for (_, disposable) in self.playlistFetchDisposables {
            disposable.dispose()
        }
    }
    
    func arbitraryFileData(path: String) -> Signal<(data: Data, contentType: String)?, NoError> {
        return Signal { subscriber in
            let bundlePath = Bundle.main.path(forResource: path, ofType: nil)
            if let path = bundlePath, let data = try? Data(contentsOf: URL(fileURLWithPath: path)) {
                let mimeType: String
                let pathExtension = (path as NSString).pathExtension
                if pathExtension == "html" {
                    mimeType = "text/html"
                } else if pathExtension == "html" {
                    mimeType = "application/javascript"
                } else {
                    mimeType = "application/octet-stream"
                }
                subscriber.putNext((data, mimeType))
            } else {
                subscriber.putNext(nil)
            }
            
            subscriber.putCompletion()
            return EmptyDisposable
        }
    }
    
    func masterPlaylistData() -> Signal<String, NoError> {
        var playlistString: String = ""
        playlistString.append("#EXTM3U\n")
        
        for (quality, file) in self.qualityFiles.sorted(by: { $0.key > $1.key }) {
            let width = file.media.dimensions?.width ?? 1280
            let height = file.media.dimensions?.height ?? 720
            
            let bandwidth: Int
            if let size = file.media.size, let duration = file.media.duration, duration != 0.0 {
                bandwidth = Int(Double(size) / duration) * 8
            } else {
                bandwidth = 1000000
            }
            
            playlistString.append("#EXT-X-STREAM-INF:BANDWIDTH=\(bandwidth),RESOLUTION=\(width)x\(height)\n")
            playlistString.append("hls_level_\(quality).m3u8\n")
        }
        return .single(playlistString)
    }
    
    func playlistData(quality: Int) -> Signal<String, NoError> {
        guard let playlistFile = self.playlistFiles[quality] else {
            return .never()
        }
        if self.playlistFetchDisposables[quality] == nil {
            // Keep your existing "fetchedMediaResource" logic on macOS:
            self.playlistFetchDisposables[quality] = fetchedMediaResource(
                mediaBox: postbox.mediaBox,
                userLocation: userLocation,
                userContentType: MediaResourceUserContentType(file: playlistFile.media),
                reference: playlistFile.resourceReference(playlistFile.media.resource)
            ).startStrict()
        }
        
        return self.postbox.mediaBox.resourceData(playlistFile.media.resource)
        |> filter { data in
            return data.complete
        }
        |> map { data -> String in
            guard data.complete else {
                return ""
            }
            guard let data = try? Data(contentsOf: URL(fileURLWithPath: data.path)) else {
                return ""
            }
            guard var playlistString = String(data: data, encoding: .utf8) else {
                return ""
            }
            let partRegex = try! NSRegularExpression(pattern: "mtproto:([\\d]+)", options: [])
            let results = partRegex.matches(in: playlistString, range: NSRange(playlistString.startIndex..., in: playlistString))
            for result in results.reversed() {
                if let range = Range(result.range, in: playlistString) {
                    if let fileIdRange = Range(result.range(at: 1), in: playlistString) {
                        let fileId = String(playlistString[fileIdRange])
                        playlistString.replaceSubrange(range, with: "partfile\(fileId).mp4")
                    }
                }
            }
            return playlistString
        }
    }
    
    func partData(index: Int, quality: Int) -> Signal<Data?, NoError> {
        return .never()
    }
    
    func fileData(id: Int64, range: Range<Int>) -> Signal<(TempBoxFile, Range<Int>, Int)?, NoError> {
        guard let (quality, file) = self.qualityFiles.first(where: { $0.value.media.fileId.id == id }) else {
            return .single(nil)
        }
        // quality is unused at the moment, but we keep it for clarity
        guard let size = file.media.size else {
            return .single(nil)
        }
        
        let postbox = self.postbox
        let userLocation = self.userLocation
        let mappedRange: Range<Int64> = Int64(range.lowerBound) ..< Int64(range.upperBound)
        
        let queue = postbox.mediaBox.dataQueue
        let fetchFromRemote: Signal<(TempBoxFile, Range<Int>, Int)?, NoError> = Signal { subscriber in
            let partialFile = TempBox.shared.tempFile(fileName: "data")
            
            // 1) Check if we already have a cached subrange
            if let cachedData = postbox.mediaBox.internal_resourceData(
                id: file.media.resource.id,
                size: size,
                in: Int64(range.lowerBound) ..< Int64(range.upperBound)
            ) {
                #if DEBUG
                print("Fetched \(quality)p part from cache")
                #endif
                
                let outputFile = ManagedFile(queue: nil, path: partialFile.path, mode: .readwrite)
                if let outputFile {
                    let blockSize = 128 * 1024
                    var tempBuffer = Data(count: blockSize)
                    var blockOffset = 0
                    while blockOffset < cachedData.length {
                        let currentBlockSize = min(cachedData.length - blockOffset, blockSize)
                        
                        tempBuffer.withUnsafeMutableBytes { bytes -> Void in
                            let _ = cachedData.file.read(bytes.baseAddress!, currentBlockSize)
                            let _ = outputFile.write(bytes.baseAddress!, count: currentBlockSize)
                        }
                        
                        blockOffset += blockSize
                    }
                    outputFile._unsafeClose()
                    subscriber.putNext((partialFile, 0 ..< cachedData.length, Int(size)))
                    subscriber.putCompletion()
                } else {
                    #if DEBUG
                    print("Error writing cached file to disk")
                    #endif
                }
                
                return EmptyDisposable
            }
            
            // 2) Otherwise, we fetch from the network
            guard let fetchResource = postbox.mediaBox.fetchResource else {
                return EmptyDisposable
            }
            
            let location = MediaResourceStorageLocation(
                userLocation: userLocation,
                reference: file.resourceReference(file.media.resource)
            )
            let params = MediaResourceFetchParameters(
                tag: TelegramMediaResourceFetchTag(statsCategory: .video, userContentType: .video),
                info: TelegramCloudMediaResourceFetchInfo(
                    reference: file.resourceReference(file.media.resource),
                    preferBackgroundReferenceRevalidation: true,
                    continueInBackground: true
                ),
                location: location,
                contentType: .video,
                isRandomAccessAllowed: true
            )
            
            let completeFile = TempBox.shared.tempFile(fileName: "data")
            let metaFile = TempBox.shared.tempFile(fileName: "data")
            
            guard let fileContext = MediaBoxFileContextV2Impl(
                queue: queue,
                manager: postbox.mediaBox.dataFileManager,
                storageBox: nil,
                resourceId: file.media.resource.id.stringRepresentation.data(using: .utf8)!,
                path: completeFile.path,
                partialPath: partialFile.path,
                metaPath: metaFile.path
            ) else {
                return EmptyDisposable
            }
            
            let fetchDisposable = fileContext.fetched(
                range: mappedRange,
                priority: .default,
                fetch: { intervals in
                    return fetchResource(file.media.resource, intervals, params)
                },
                error: { _ in },
                completed: {}
            )
            
            #if DEBUG
            let startTime = CFAbsoluteTimeGetCurrent()
            #endif
            
            let dataDisposable = fileContext.data(
                range: mappedRange,
                waitUntilAfterInitialFetch: true,
                next: { result in
                    // Once we have the entire requested chunk, let's finalize
                    if result.complete {
                        #if DEBUG
                        let fetchTime = CFAbsoluteTimeGetCurrent() - startTime
                        print("Fetching \(quality)p part took \(fetchTime * 1000.0) ms")
                        #endif
                        
                        // >>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>
                        // The missing piece from the iOS refactor:
                        // Write back the partial chunk to our MediaBox
                        if let data = try? Data(
                            contentsOf: URL(fileURLWithPath: partialFile.path),
                            options: .alwaysMapped
                        ) {
                            let subData = data.subdata(
                                in: Int(result.offset) ..< Int(result.offset + result.size)
                            )
                            postbox.mediaBox.storeResourceData(
                                file.media.resource.id,
                                range: Int64(range.lowerBound) ..< Int64(range.upperBound),
                                data: subData
                            )
                        }
                        // <<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<
                        
                        subscriber.putNext((partialFile,
                                            Int(result.offset) ..< Int(result.offset + result.size),
                                            Int(size)))
                        subscriber.putCompletion()
                    }
                }
            )
            
            return ActionDisposable {
                queue.async {
                    fetchDisposable.dispose()
                    dataDisposable.dispose()
                    fileContext.cancelFullRangeFetches()
                    
                    TempBox.shared.dispose(completeFile)
                    TempBox.shared.dispose(metaFile)
                }
            }
        }
        |> runOn(queue)
        
        return fetchFromRemote
    }
}


public final class HLSQualitySet {
    public let qualityFiles: [Int: FileMediaReference]
    public let playlistFiles: [Int: FileMediaReference]
    public let thumbnails: [Int: (file: FileMediaReference, fileMap: FileMediaReference)]
    
    public init?(baseFile: FileMediaReference) {
        
        
        func isNativeVideoCodecSupported(videoCodec: String) -> Bool {
            return videoCodec == "h264" || videoCodec == "h265" || videoCodec == "avc" || videoCodec == "hevc"
        }
        
        var qualityFiles: [Int: FileMediaReference] = [:]
        var thumbnailFiles: [FileMediaReference] = []
        var thumbnailFileMaps: [Int: (mapFile: FileMediaReference, thumbnailFileId: Int64)] = [:]
        
        for alternativeRepresentation in baseFile.media.alternativeRepresentations {
            let alternativeFile = alternativeRepresentation
            if alternativeFile.mimeType == "application/x-tgstoryboard" {
                thumbnailFiles.append(baseFile.withMedia(alternativeFile))
            } else if alternativeFile.mimeType == "application/x-tgstoryboardmap" {
                var qualityId: Int?
                for attribute in alternativeFile.attributes {
                    switch attribute {
                    case let .ImageSize(size):
                        qualityId = Int(min(size.width, size.height))
                    default:
                        break
                    }
                }
                
                if let qualityId, let fileName = alternativeFile.fileName {
                    if fileName.hasPrefix("mtproto:") {
                        if let fileId = Int64(fileName[fileName.index(fileName.startIndex, offsetBy: "mtproto:".count)...]) {
                            thumbnailFileMaps[qualityId] = (mapFile: baseFile.withMedia(alternativeFile), thumbnailFileId: fileId)
                        }
                    }
                }
            } else {
                for attribute in alternativeFile.attributes {
                    if case let .Video(_, size, _, _, _, videoCodec) = attribute {
                        if let videoCodec, isNativeVideoCodecSupported(videoCodec: videoCodec) {
                            let key = Int(min(size.width, size.height))
                            if let currentFile = qualityFiles[key] {
                                var currentCodec: String?
                                for attribute in currentFile.media.attributes {
                                    if case let .Video(_, _, _, _, _, videoCodec) = attribute {
                                        currentCodec = videoCodec
                                    }
                                }
                                if let currentCodec, (currentCodec == "av1" || currentCodec == "av01") {
                                } else {
                                    qualityFiles[key] = baseFile.withMedia(alternativeFile)
                                }
                            } else {
                                qualityFiles[key] = baseFile.withMedia(alternativeFile)
                            }
                        }
                    }
                }
            }
        }
        
        var playlistFiles: [Int: FileMediaReference] = [:]
        for alternativeRepresentation in baseFile.media.alternativeRepresentations {
            let alternativeFile = alternativeRepresentation
            if alternativeFile.mimeType == "application/x-mpegurl" {
                if let fileName = alternativeFile.fileName {
                    if fileName.hasPrefix("mtproto:") {
                        let fileIdString = String(fileName[fileName.index(fileName.startIndex, offsetBy: "mtproto:".count)...])
                        if let fileId = Int64(fileIdString) {
                            for (quality, file) in qualityFiles {
                                if file.media.fileId.id == fileId {
                                    playlistFiles[quality] = baseFile.withMedia(alternativeFile)
                                    break
                                }
                            }
                        }
                    }
                }
            }
        }
        if !playlistFiles.isEmpty && playlistFiles.keys == qualityFiles.keys {
            self.qualityFiles = qualityFiles
            self.playlistFiles = playlistFiles
            
            var thumbnails: [Int: (file: FileMediaReference, fileMap: FileMediaReference)] = [:]
            for (quality, thubmailMap) in thumbnailFileMaps {
                for file in thumbnailFiles {
                    if file.media.fileId.id == thubmailMap.thumbnailFileId {
                        thumbnails[quality] = (
                            file: file,
                            fileMap: thubmailMap.mapFile
                        )
                    }
                }
            }
            self.thumbnails = thumbnails
        } else {
            return nil
        }
    }
}



/**
 Everything below is unchanged from your macOS version, except that
 it uses the same SharedHLSVideoJSContext logic and references
 the updated fileData code above.
 (HLSVideoJSNativeContentView, SourceBuffer, etc. remain as you had them.)
*/

private final class SharedHLSVideoJSContext: NSObject {
    private final class ContextReference {
        weak var contentNode: HLSVideoJSNativeContentView?
        
        init(contentNode: HLSVideoJSNativeContentView?) {
            self.contentNode = contentNode
        }
    }
    
    private enum ResponseError {
       case badRequest
       case notFound
       case internalServerError
       
       var httpStatus: (Int, String) {
           switch self {
           case .badRequest:
               return (400, "Bad Request")
           case .notFound:
               return (404, "Not Found")
           case .internalServerError:
               return (500, "Internal Server Error")
           }
       }
    }
    
    static let shared: SharedHLSVideoJSContext = SharedHLSVideoJSContext()
    
    private var contextReferences: [Int: ContextReference] = [:]
    
    var jsContext: HLSJSContext?
    
    var videoElements: [Int: VideoElement] = [:]
    var mediaSources: [Int: MediaSource] = [:]
    var sourceBuffers: [Int: SourceBuffer] = [:]
    
    private var isJsContextReady: Bool = false
    private var pendingInitializeInstanceIds: [(id: Int, urlPrefix: String)] = []
    
    private var tempTasks: [Int: URLSessionTask] = [:]
    private var emptyTimer: Foundation.Timer?
    
    override init() {
        super.init()
    }
    
    deinit {
        self.emptyTimer?.invalidate()
    }
    
    private func createJsContext() {
        let handleScriptMessage: ([String: Any]) -> Void = {  [weak self] message in
            Queue.mainQueue().async {
                guard let self else {
                    return
                }
                
                guard let eventName = message["event"] as? String else {
                    return
                }
                
                switch eventName {
                case "windowOnLoad":
                    self.isJsContextReady = true
                    self.initializePendingInstances()
                case "bridgeInvoke":
                    guard let eventData = message["data"] as? [String: Any] else {
                        return
                    }
                    guard let bridgeId = eventData["bridgeId"] as? Int else {
                        return
                    }
                    guard let callbackId = eventData["callbackId"] as? Int else {
                        return
                    }
                    guard let className = eventData["className"] as? String else {
                        return
                    }
                    guard let methodName = eventData["methodName"] as? String else {
                        return
                    }
                    guard let params = eventData["params"] as? [String: Any] else {
                        return
                    }
                    self.bridgeInvoke(
                        bridgeId: bridgeId,
                        className: className,
                        methodName: methodName,
                        params: params,
                        completion: { [weak self] result in
                            guard let self else {
                                return
                            }
                            let jsonResult = try! JSONSerialization.data(withJSONObject: result)
                            let jsonResultString = String(data: jsonResult, encoding: .utf8)!
                            self.jsContext?.evaluateJavaScript("window.bridgeInvokeCallback(\(callbackId), \(jsonResultString));")
                        }
                    )
                case "playerStatus":
                    guard let instanceId = message["instanceId"] as? Int else {
                        return
                    }
                    guard let instance = self.contextReferences[instanceId]?.contentNode else {
                        self.contextReferences.removeValue(forKey: instanceId)
                        return
                    }
                    guard let eventData = message["data"] as? [String: Any] else {
                        return
                    }
                    
                    instance.onPlayerStatusUpdated(eventData: eventData)
                case "playerCurrentTime":
                    guard let instanceId = message["instanceId"] as? Int else {
                        return
                    }
                    guard let instance = self.contextReferences[instanceId]?.contentNode else {
                        self.contextReferences.removeValue(forKey: instanceId)
                        return
                    }
                    guard let eventData = message["data"] as? [String: Any] else {
                        return
                    }
                    guard let value = eventData["value"] as? Double else {
                        return
                    }
                    
                    instance.onPlayerUpdatedCurrentTime(currentTime: value)
                    
                    var bandwidthEstimate = eventData["bandwidthEstimate"] as? Double
                    if let bandwidthEstimateValue = bandwidthEstimate, bandwidthEstimateValue.isNaN || bandwidthEstimateValue.isInfinite {
                        bandwidthEstimate = nil
                    }
                    HLSVideoJSNativeContentView.sharedBandwidthEstimate = bandwidthEstimate
                default:
                    break
                }
            }
        }
        
        self.isJsContextReady = false
        
        // This matches how you said you set up your JS context
        self.jsContext = WebViewNativeJSContextImpl(handleScriptMessage: handleScriptMessage)
    }
    
    private func disposeJsContext() {
        if self.jsContext != nil {
            self.jsContext = nil
        }
        self.isJsContextReady = false
    }
    
    private func bridgeInvoke(
        bridgeId: Int,
        className: String,
        methodName: String,
        params: [String: Any],
        completion: @escaping ([String: Any]) -> Void
    ) {
        if (className == "VideoElement") {
            if (methodName == "constructor") {
                guard let instanceId = params["instanceId"] as? Int else {
                    assertionFailure()
                    return
                }
                let videoElement = VideoElement(instanceId: instanceId)
                SharedHLSVideoJSContext.shared.videoElements[bridgeId] = videoElement
                completion([:])
            } else if (methodName == "setMediaSource") {
                guard let instanceId = params["instanceId"] as? Int else {
                    assertionFailure()
                    return
                }
                guard let mediaSourceId = params["mediaSourceId"] as? Int else {
                    assertionFailure()
                    return
                }
                guard let (_, videoElement) = SharedHLSVideoJSContext.shared.videoElements.first(where: { $0.value.instanceId == instanceId }) else {
                    return
                }
                videoElement.mediaSourceId = mediaSourceId
            } else if (methodName == "setCurrentTime") {
                guard let instanceId = params["instanceId"] as? Int else {
                    assertionFailure()
                    return
                }
                guard let currentTime = params["currentTime"] as? Double else {
                    assertionFailure()
                    return
                }
                
                if let instance = self.contextReferences[instanceId]?.contentNode {
                    instance.onSetCurrentTime(timestamp: currentTime)
                }
                
                completion([:])
            } else if (methodName == "setPlaybackRate") {
                guard let instanceId = params["instanceId"] as? Int else {
                    assertionFailure()
                    return
                }
                guard let playbackRate = params["playbackRate"] as? Double else {
                    assertionFailure()
                    return
                }
                
                if let instance = self.contextReferences[instanceId]?.contentNode {
                    instance.onSetPlaybackRate(playbackRate: playbackRate)
                }
                
                completion([:])
            } else if (methodName == "play") {
                guard let instanceId = params["instanceId"] as? Int else {
                    assertionFailure()
                    return
                }
                if let instance = self.contextReferences[instanceId]?.contentNode {
                    instance.onPlay()
                }
                completion([:])
            } else if (methodName == "pause") {
                guard let instanceId = params["instanceId"] as? Int else {
                    assertionFailure()
                    return
                }
                if let instance = self.contextReferences[instanceId]?.contentNode {
                    instance.onPause()
                }
                completion([:])
            }
        } else if (className == "MediaSource") {
            if (methodName == "constructor") {
                let mediaSource = MediaSource()
                SharedHLSVideoJSContext.shared.mediaSources[bridgeId] = mediaSource
                completion([:])
            } else if (methodName == "setDuration") {
                guard let duration = params["duration"] as? Double else {
                    assertionFailure()
                    return
                }
                guard let mediaSource = SharedHLSVideoJSContext.shared.mediaSources[bridgeId] else {
                    assertionFailure()
                    return
                }
                var durationUpdated = false
                if mediaSource.duration != duration {
                    mediaSource.duration = duration
                    durationUpdated = true
                }
                
                guard let (_, videoElement) = SharedHLSVideoJSContext.shared.videoElements.first(where: { $0.value.mediaSourceId == bridgeId }) else {
                    return
                }
                
                if let instance = self.contextReferences[videoElement.instanceId]?.contentNode {
                    if durationUpdated {
                        instance.onMediaSourceDurationUpdated()
                    }
                }
                completion([:])
            } else if (methodName == "updateSourceBuffers") {
                guard let ids = params["ids"] as? [Int] else {
                    assertionFailure()
                    return
                }
                guard let mediaSource = SharedHLSVideoJSContext.shared.mediaSources[bridgeId] else {
                    assertionFailure()
                    return
                }
                mediaSource.sourceBufferIds = ids
                
                guard let (_, videoElement) = SharedHLSVideoJSContext.shared.videoElements.first(where: { $0.value.mediaSourceId == bridgeId }) else {
                    return
                }
                
                if let instance = self.contextReferences[videoElement.instanceId]?.contentNode {
                    instance.onMediaSourceBuffersUpdated()
                }
            }
        } else if (className == "SourceBuffer") {
            if (methodName == "constructor") {
                guard let mediaSourceId = params["mediaSourceId"] as? Int else {
                    assertionFailure()
                    return
                }
                guard let mimeType = params["mimeType"] as? String else {
                    assertionFailure()
                    return
                }
                let sourceBuffer = SourceBuffer(mediaSourceId: mediaSourceId, mimeType: mimeType)
                SharedHLSVideoJSContext.shared.sourceBuffers[bridgeId] = sourceBuffer
                
                completion([:])
            } else if (methodName == "appendBuffer") {
                guard let base64Data = params["data"] as? String else {
                    assertionFailure()
                    return
                }
                guard let data = Data(base64Encoded: base64Data.data(using: .utf8)!) else {
                    assertionFailure()
                    return
                }
                guard let sourceBuffer = SharedHLSVideoJSContext.shared.sourceBuffers[bridgeId] else {
                    assertionFailure()
                    return
                }
                sourceBuffer.appendBuffer(data: data, completion: { bufferedRanges in
                    completion(["ranges": serializeRanges(bufferedRanges)])
                })
            } else if methodName == "remove" {
                guard let start = params["start"] as? Double, let end = params["end"] as? Double else {
                    assertionFailure()
                    return
                }
                guard let sourceBuffer = SharedHLSVideoJSContext.shared.sourceBuffers[bridgeId] else {
                    assertionFailure()
                    return
                }
                sourceBuffer.remove(start: start, end: end, completion: { bufferedRanges in
                    completion(["ranges": serializeRanges(bufferedRanges)])
                })
            } else if methodName == "abort" {
                guard let sourceBuffer = SharedHLSVideoJSContext.shared.sourceBuffers[bridgeId] else {
                    assertionFailure()
                    return
                }
                sourceBuffer.abortOperation()
                completion([:])
            }
        } else if className == "XMLHttpRequest" {
            if methodName == "load" {
                guard let id = params["id"] as? Int else {
                    assertionFailure()
                    return
                }
                guard let url = params["url"] as? String else {
                    assertionFailure()
                    return
                }
                guard let requestHeaders = params["requestHeaders"] as? [String: String] else {
                    assertionFailure()
                    return
                }
                guard let parsedUrl = URL(string: url) else {
                    assertionFailure()
                    return
                }
                guard let host = parsedUrl.host, host == "server" else {
                    completion(["error": 1])
                    return
                }
                
                var requestPath = parsedUrl.path
                if requestPath.hasPrefix("/") {
                    requestPath = String(requestPath[requestPath.index(after: requestPath.startIndex)..<requestPath.endIndex])
                }
                
                guard let firstSlash = requestPath.range(of: "/") else {
                    completion(["error": 1])
                    return
                }
                
                var requestRange: Range<Int>?
                if let rangeString = requestHeaders["Range"] {
                    requestRange = parseRange(from: rangeString)
                }
                
                let streamId = String(requestPath[requestPath.startIndex..<firstSlash.lowerBound])
                
                var handlerFound = false
                for (_, contextReference) in self.contextReferences {
                    if let context = contextReference.contentNode, let source = context.playerSource, source.id == streamId {
                        handlerFound = true
                        
                        let filePath = String(requestPath[firstSlash.upperBound...])
                        if filePath == "master.m3u8" {
                            let _ = (source.masterPlaylistData()
                            |> take(1)).start(next: { result in
                                SharedHLSVideoJSContext.sendResponseAndClose(id: id, data: result.data(using: .utf8)!) {
                                    completion($0)
                                }
                            })
                        } else if filePath.hasPrefix("hls_level_") && filePath.hasSuffix(".m3u8") {
                            guard let levelIndex = Int(String(filePath[filePath.index(filePath.startIndex, offsetBy: "hls_level_".count)..<filePath.index(filePath.endIndex, offsetBy: -".m3u8".count)])) else {
                                SharedHLSVideoJSContext.sendErrorAndClose(id: id, error: .notFound, completion: completion)
                                return
                            }
                            
                            let _ = (source.playlistData(quality: levelIndex)
                            |> deliverOn(.mainQueue())
                            |> take(1)).start(next: { result in
                                SharedHLSVideoJSContext.sendResponseAndClose(id: id, data: result.data(using: .utf8)!) {
                                    completion($0)
                                }
                            })
                        } else if filePath.hasPrefix("partfile") && filePath.hasSuffix(".mp4") {
                            let fileId = String(filePath[filePath.index(filePath.startIndex, offsetBy: "partfile".count)..<filePath.index(filePath.endIndex, offsetBy: -".mp4".count)])
                            guard let fileIdValue = Int64(fileId) else {
                                SharedHLSVideoJSContext.sendErrorAndClose(id: id, error: .notFound, completion: completion)
                                return
                            }
                            guard let requestRange else {
                                SharedHLSVideoJSContext.sendErrorAndClose(id: id, error: .badRequest, completion: completion)
                                return
                            }
                            let _ = (source.fileData(id: fileIdValue, range: requestRange.lowerBound ..< requestRange.upperBound + 1)
                            |> deliverOn(.mainQueue())
                            |> take(1)).start(next: { result in
                                if let (tempFile, tempFileRange, totalSize) = result {
                                    SharedHLSVideoJSContext.sendResponseFileAndClose(
                                        id: id,
                                        file: tempFile,
                                        fileRange: tempFileRange,
                                        range: requestRange,
                                        totalSize: totalSize
                                    ) {
                                        completion($0)
                                    }
                                } else {
                                    SharedHLSVideoJSContext.sendErrorAndClose(id: id, error: .internalServerError, completion: completion)
                                }
                            })
                        }
                        break
                    }
                }
                
                if (!handlerFound) {
                    completion(["error": 1])
                }
            } else if methodName == "abort" {
                guard let id = params["id"] as? Int else {
                    assertionFailure()
                    return
                }
                
                if let task = self.tempTasks.removeValue(forKey: id) {
                    task.cancel()
                }
                
                completion([:])
            }
        }
    }
    
    private static func sendErrorAndClose(id: Int, error: ResponseError, completion: @escaping ([String: Any]) -> Void) {
        let (code, status) = error.httpStatus
        completion([
            "status": code,
            "statusText": status,
            "responseData": "",
            "responseHeaders": [
                "Content-Type": "text/html"
            ] as [String: String]
        ])
    }
    
    private static func sendResponseAndClose(id: Int, data: Data, contentType: String = "application/octet-stream", completion: @escaping ([String: Any]) -> Void) {
        completion([
            "status": 200,
            "statusText": "OK",
            "responseData": data.base64EncodedString(),
            "responseHeaders": [
                "Content-Type": contentType,
                "Content-Length": "\(data.count)"
            ] as [String: String]
        ])
    }
    
    private static func sendResponseFileAndClose(id: Int, file: TempBoxFile, fileRange: Range<Int>, range: Range<Int>, totalSize: Int, completion: @escaping ([String: Any]) -> Void) {
        Queue.concurrentDefaultQueue().async {
            if let data = try? Data(contentsOf: URL(fileURLWithPath: file.path), options: .mappedIfSafe).subdata(in: fileRange) {
                completion([
                    "status": 200,
                    "statusText": "OK",
                    "responseData": data.base64EncodedString(),
                    "responseHeaders": [
                        "Content-Type": "application/octet-stream",
                        "Content-Range": "bytes \(range.lowerBound)-\(range.upperBound)/\(totalSize)",
                        "Content-Length": "\(fileRange.upperBound - fileRange.lowerBound)"
                    ] as [String: String]
                ])
            } else {
                SharedHLSVideoJSContext.sendErrorAndClose(id: id, error: .internalServerError, completion: completion)
            }
        }
    }
    
    func register(context: HLSVideoJSNativeContentView) -> Disposable {
        let contextInstanceId = context.instanceId
        self.contextReferences[contextInstanceId] = ContextReference(contentNode: context)
        
        if self.jsContext == nil {
            self.createJsContext()
        }
        
        if let emptyTimer = self.emptyTimer {
            self.emptyTimer = nil
            emptyTimer.invalidate()
        }
        
        return ActionDisposable { [weak self, weak context] in
            Queue.mainQueue().async {
                guard let self else {
                    return
                }
                self.pendingInitializeInstanceIds.removeAll(where: { $0.id == contextInstanceId })
                
                if let current = self.contextReferences[contextInstanceId] {
                    if let value = current.contentNode {
                        if let context, context === value {
                            self.contextReferences.removeValue(forKey: contextInstanceId)
                        }
                    } else {
                        self.contextReferences.removeValue(forKey: contextInstanceId)
                    }
                }
                
                self.jsContext?.evaluateJavaScript("window.hlsPlayer_destroyInstance(\(contextInstanceId));")
                
                if self.contextReferences.isEmpty {
                    if self.emptyTimer == nil {
                        self.emptyTimer = Foundation.Timer.scheduledTimer(withTimeInterval: 10.0, repeats: false, block: { [weak self] timer in
                            guard let self else {
                                return
                            }
                            if self.emptyTimer === timer {
                                self.emptyTimer = nil
                            }
                            if self.contextReferences.isEmpty {
                                self.disposeJsContext()
                            }
                        })
                    }
                }
            }
        }
    }
    
    func initializeWhenReady(context: HLSVideoJSNativeContentView, urlPrefix: String) {
        self.pendingInitializeInstanceIds.append((context.instanceId, urlPrefix))
        
        if self.isJsContextReady {
            self.initializePendingInstances()
        }
    }
    
    private func initializePendingInstances() {
        let pendingInitializeInstanceIds = self.pendingInitializeInstanceIds
        self.pendingInitializeInstanceIds.removeAll()
        
        if pendingInitializeInstanceIds.isEmpty {
            return
        }
        
        let isDebug: Bool
        #if DEBUG
        isDebug = true
        #else
        isDebug = false
        #endif
        
        var userScriptJs = ""
        for (instanceId, urlPrefix) in pendingInitializeInstanceIds {
            guard let _ = self.contextReferences[instanceId]?.contentNode else {
                self.contextReferences.removeValue(forKey: instanceId)
                continue
            }
            userScriptJs.append("window.hlsPlayer_makeInstance(\(instanceId));\n")
            userScriptJs.append("""
            window.hlsPlayer_instances[\(instanceId)].playerInitialize({
                'debug': \(isDebug),
                'bandwidthEstimate': \(HLSVideoJSNativeContentView.sharedBandwidthEstimate ?? 500000.0),
                'urlPrefix': '\(urlPrefix)'
            });\n
            """)
        }
        
        self.jsContext?.evaluateJavaScript(userScriptJs)
    }
}

private class WeakScriptMessageHandler: NSObject, WKScriptMessageHandler {
    private let f: (WKScriptMessage) -> ()
    
    init(_ f: @escaping (WKScriptMessage) -> ()) {
        self.f = f
        super.init()
    }
    
    func userContentController(_ controller: WKUserContentController, didReceive scriptMessage: WKScriptMessage) {
        self.f(scriptMessage)
    }
}

public final class HLSVideoJSNativeContentView: NSView, UniversalVideoContentView {
    private struct Level {
        let bitrate: Int
        let width: Int
        let height: Int
        
        init(bitrate: Int, width: Int, height: Int) {
            self.bitrate = bitrate
            self.width = width
            self.height = height
        }
    }
    
    fileprivate static var sharedBandwidthEstimate: Double?
    
    private let postbox: Postbox
    private let userLocation: MediaResourceUserLocation
    private let fileReference: FileMediaReference
    private let approximateDuration: Double
    private let intrinsicDimensions: CGSize
    
    fileprivate let playerSource: HLSJSServerSource?
    private var serverDisposable: Disposable?
    
    private let playbackCompletedListeners = Bag<() -> Void>()
    
    private var initializedStatus = false
    private var statusValue = MediaPlayerStatus(
        generationTimestamp: 0.0,
        duration: 0.0,
        dimensions: CGSize(),
        timestamp: 0.0,
        baseRate: 1.0,
        volume: 1.0,
        seekId: 0,
        status: .paused
    )
    private var isBuffering = false
    private var seekId: Int = 0
    private let _status = ValuePromise<MediaPlayerStatus>()
    public var status: Signal<MediaPlayerStatus, NoError> {
        return self._status.get()
    }
    
    private let _bufferingStatus = Promise<(RangeSet<Int64>, Int64)?>()
    public var bufferingStatus: Signal<(RangeSet<Int64>, Int64)?, NoError> {
        return self._bufferingStatus.get()
    }
    
    private let _isNativePictureInPictureActive = ValuePromise<Bool>(false, ignoreRepeated: true)
    public var isNativePictureInPictureActive: Signal<Bool, NoError> {
        return self._isNativePictureInPictureActive.get()
    }
    
    private let _ready = Promise<Void>()
    public var ready: Signal<Void, NoError> {
        return self._ready.get()
    }
    
    private let _preloadCompleted = ValuePromise<Bool>()
    var preloadCompleted: Signal<Bool, NoError> {
        return self._preloadCompleted.get()
    }
    
    public var fileRef: FileMediaReference {
        return self.fileReference
    }
    
    private let player: ChunkMediaPlayer
    private let playerView: MediaPlayerView
    
    private let fetchDisposable = MetaDisposable()
    
    private var dimensions: CGSize?
    private let dimensionsPromise = ValuePromise<CGSize>(CGSize())
    
    private var validLayout: CGSize?
    
    private var statusTimer: Foundation.Timer?
    
    private var preferredVideoQuality: UniversalVideoContentVideoQuality = .auto
    
    private var playerIsReady: Bool = false
    private var playerIsFirstFrameReady: Bool = false
    private var playerIsPlaying: Bool = false
    private var playerRate: Double = 0.0
    private var playerDefaultRate: Double = 1.0
    private var playerTime: Double = 0.0
    private var playerAvailableLevels: [Int: Level] = [:]
    private var playerCurrentLevelIndex: Int?
    
    private var hasRequestedPlayerLoad: Bool = false
    
    private var requestedBaseRate: Double = 1.0
    private var requestedLevelIndex: Int?
    
    private var volume: Float = 1.0
    
    private static var nextInstanceId: Int = 0
    fileprivate let instanceId: Int
    
    private var videoElements: [Int: VideoElement] = [:]
    private var mediaSources: [Int: MediaSource] = [:]
    private var sourceBuffers: [Int: SourceBuffer] = [:]
    
    private let chunkPlayerPartsState = Promise<ChunkMediaPlayerPartsState>(
        ChunkMediaPlayerPartsState(duration: nil, content: .parts([]))
    )
    private var sourceBufferStateDisposable: Disposable?
    private var playerStatusDisposable: Disposable?
    private var contextDisposable: Disposable?
    private let initialQuality: UniversalVideoContentVideoQuality

    public init(
        accountId: AccountRecordId,
        postbox: Postbox,
        userLocation: MediaResourceUserLocation,
        fileReference: FileMediaReference,
        streamVideo: Bool,
        loopVideo: Bool,
        enableSound: Bool,
        baseRate: Double,
        fetchAutomatically: Bool,
        volume: Float,
        initialQuality: UniversalVideoContentVideoQuality
    ) {
        self.postbox = postbox
        self.fileReference = fileReference
        self.approximateDuration = fileReference.media.duration ?? 0.0
        self.userLocation = userLocation
        self.requestedBaseRate = baseRate
        self.volume = volume
        self.preferredVideoQuality = initialQuality
        self.initialQuality = initialQuality
        
        self.instanceId = HLSVideoJSNativeContentView.nextInstanceId
        HLSVideoJSNativeContentView.nextInstanceId += 1
        
        if var dimensions = fileReference.media.dimensions {
            if let thumbnail = fileReference.media.previewRepresentations.first {
                let dimensionsVertical = dimensions.width < dimensions.height
                let thumbnailVertical = thumbnail.dimensions.width < thumbnail.dimensions.height
                if dimensionsVertical != thumbnailVertical {
                    dimensions = PixelDimensions(width: dimensions.height, height: dimensions.width)
                }
            }
            self.dimensions = dimensions.size
        } else {
            self.dimensions = CGSize(width: 128.0, height: 128.0)
        }
        
        let config = WKWebViewConfiguration()
        config.mediaTypesRequiringUserActionForPlayback = []
        
        var playerSource: HLSJSServerSource?
        if let qualitySet = HLSQualitySet(baseFile: fileReference) {
            let playerSourceValue = HLSJSServerSource(
                accountId: accountId.int64,
                fileId: fileReference.media.fileId.id,
                postbox: postbox,
                userLocation: userLocation,
                playlistFiles: qualitySet.playlistFiles,
                qualityFiles: qualitySet.qualityFiles
            )
            playerSource = playerSourceValue
        }
        self.playerSource = playerSource
        
        let mediaDimensions = fileReference.media.dimensions?.size ?? CGSize(width: 480.0, height: 320.0)
        var intrinsicDimensions = mediaDimensions.aspectFitted(CGSize(width: 1280.0, height: 1280.0))
        
        intrinsicDimensions.width = floor(intrinsicDimensions.width)
        intrinsicDimensions.height = floor(intrinsicDimensions.height)
        self.intrinsicDimensions = intrinsicDimensions
        
        self.playerView = MediaPlayerView()
        
        var onSeeked: (() -> Void)?
        self.player = ChunkMediaPlayerV2(
            params: ChunkMediaPlayerV2.MediaDataReaderParams(useV2Reader: true),
            source: .externalParts(self.chunkPlayerPartsState.get()),
            video: true,
            enableSound: true,
            baseRate: baseRate,
            volume: volume,
            onSeeked: {
                onSeeked?()
            },
            playerNode: playerView
        )
        
        super.init(frame: .zero)
        
        self.contextDisposable = SharedHLSVideoJSContext.shared.register(context: self)
        
        self.playerView.frame = CGRect(origin: .zero, size: self.intrinsicDimensions)
        self.addSubview(self.playerView)
        
        self._ready.set(.single(()))
        self._bufferingStatus.set(.single(nil))
        
        self.playerStatusDisposable = (self.player.status
        |> deliverOnMainQueue).startStrict(next: { [weak self] status in
            guard let self = self else { return }
            self.updatePlayerStatus(status: status)
        })
        
        self.statusTimer = Foundation.Timer.scheduledTimer(
            withTimeInterval: 1.0 / 25.0,
            repeats: true,
            block: { [weak self] _ in
                self?.updateStatus()
            }
        )
        
        onSeeked = { [weak self] in
            Queue.mainQueue().async {
                guard let strongSelf = self else { return }
                SharedHLSVideoJSContext.shared.jsContext?.evaluateJavaScript(
                    "window.hlsPlayer_instances[\(strongSelf.instanceId)].playerNotifySeekedOnNextStatusUpdate();"
                )
            }
        }
        
        if let playerSource {
            SharedHLSVideoJSContext.shared.initializeWhenReady(
                context: self,
                urlPrefix: "http://server/\(playerSource.id)/"
            )
        }
        
        // Decide what to do when the video ends
        player.actionAtEnd = .action { [weak self] in
            self?.performActionAtEnd()
        }
    }
    
    fileprivate func onPlayerStatusUpdated(eventData: [String: Any]) {
        if let isReady = eventData["isReady"] as? Bool {
            self.playerIsReady = isReady
        } else {
            self.playerIsReady = false
        }
        if let isPlaying = eventData["isPlaying"] as? Bool {
            self.playerIsPlaying = isPlaying
        } else {
            self.playerIsPlaying = false
        }
        if let rate = eventData["rate"] as? Double {
            self.playerRate = rate
        } else {
            self.playerRate = 0.0
        }
        if let defaultRate = eventData["defaultRate"] as? Double {
            self.playerDefaultRate = defaultRate
        } else {
            self.playerDefaultRate = 0.0
        }
        if let levels = eventData["levels"] as? [[String: Any]] {
            self.playerAvailableLevels.removeAll()
            for level in levels {
                guard let levelIndex = level["index"] as? Int else { continue }
                guard let levelBitrate = level["bitrate"] as? Int else { continue }
                guard let levelWidth = level["width"] as? Int else { continue }
                guard let levelHeight = level["height"] as? Int else { continue }
                self.playerAvailableLevels[levelIndex] = HLSVideoJSNativeContentView.Level(
                    bitrate: levelBitrate,
                    width: levelWidth,
                    height: levelHeight
                )
            }
        } else {
            self.playerAvailableLevels.removeAll()
        }
        
        if let currentLevel = eventData["currentLevel"] as? Int {
            if self.playerAvailableLevels[currentLevel] != nil {
                self.playerCurrentLevelIndex = currentLevel
            } else {
                self.playerCurrentLevelIndex = nil
            }
        } else {
            self.playerCurrentLevelIndex = nil
        }
        
        if self.playerIsReady {
            if !self.hasRequestedPlayerLoad, !self.playerAvailableLevels.isEmpty {
                var selectedLevelIndex: Int?
                if let minimizedQualityFile = HLSVideoContent.minimizedHLSQuality(file: self.fileReference, initialQuality: self.initialQuality)?.file,
                   let dims = minimizedQualityFile.media.dimensions
                {
                    for (index, level) in self.playerAvailableLevels {
                        if level.height == Int(dims.height) {
                            selectedLevelIndex = index
                            break
                        }
                    }
                }
                if selectedLevelIndex == nil {
                    selectedLevelIndex = self.playerAvailableLevels
                        .sorted(by: { $0.value.height > $1.value.height })
                        .first?.key
                }
                if let selectedLevelIndex {
                    self.hasRequestedPlayerLoad = true
                    SharedHLSVideoJSContext.shared.jsContext?.evaluateJavaScript(
                        "window.hlsPlayer_instances[\(self.instanceId)].playerLoad(\(selectedLevelIndex));"
                    )
                }
            }
            SharedHLSVideoJSContext.shared.jsContext?.evaluateJavaScript(
                "window.hlsPlayer_instances[\(self.instanceId)].playerSetBaseRate(\(self.requestedBaseRate));"
            )
        }
        
        self.updateStatus()
    }
    
    fileprivate func onPlayerUpdatedCurrentTime(currentTime: Double) {
        self.playerTime = currentTime
        self.updateStatus()
    }
    
    fileprivate func onSetPlaybackRate(playbackRate: Double) {
        self.player.setBaseRate(playbackRate)
    }
    
    fileprivate func onSetCurrentTime(timestamp: Double) {
        self.player.seek(timestamp: timestamp, play: nil)
    }
    
    fileprivate func onPlay() {
        self.player.play()
    }
    
    fileprivate func onPause() {
        self.player.pause()
    }
    
    fileprivate func onMediaSourceDurationUpdated() {
        guard let (_, videoElement) = SharedHLSVideoJSContext.shared.videoElements.first(where: { $0.value.instanceId == self.instanceId }) else {
            return
        }
        guard let mediaSourceId = videoElement.mediaSourceId,
              let mediaSource = SharedHLSVideoJSContext.shared.mediaSources[mediaSourceId]
        else {
            return
        }
        guard let sourceBufferId = mediaSource.sourceBufferIds.first,
              let sourceBuffer = SharedHLSVideoJSContext.shared.sourceBuffers[sourceBufferId]
        else {
            return
        }
        
        self.chunkPlayerPartsState.set(
            .single(ChunkMediaPlayerPartsState(duration: mediaSource.duration, content: .parts(sourceBuffer.items)))
        )
    }
    
    fileprivate func onMediaSourceBuffersUpdated() {
        guard let (_, videoElement) = SharedHLSVideoJSContext.shared.videoElements.first(where: { $0.value.instanceId == self.instanceId }) else {
            return
        }
        guard let mediaSourceId = videoElement.mediaSourceId,
              let mediaSource = SharedHLSVideoJSContext.shared.mediaSources[mediaSourceId]
        else {
            return
        }
        guard let sourceBufferId = mediaSource.sourceBufferIds.first,
              let sourceBuffer = SharedHLSVideoJSContext.shared.sourceBuffers[sourceBufferId]
        else {
            return
        }
        
        self.chunkPlayerPartsState.set(
            .single(ChunkMediaPlayerPartsState(duration: mediaSource.duration, content: .parts(sourceBuffer.items)))
        )
        if self.sourceBufferStateDisposable == nil {
            self.sourceBufferStateDisposable = (sourceBuffer.updated.signal()
            |> deliverOnMainQueue).startStrict(next: { [weak self, weak sourceBuffer] _ in
                guard let self, let sourceBuffer else {
                    return
                }
                guard let mediaSource = SharedHLSVideoJSContext.shared.mediaSources[sourceBuffer.mediaSourceId] else {
                    return
                }
                self.chunkPlayerPartsState.set(
                    .single(ChunkMediaPlayerPartsState(duration: mediaSource.duration, content: .parts(sourceBuffer.items)))
                )
                self.updateBuffered()
            })
        }
    }
    
    private func updateBuffered() {
        guard let (_, videoElement) = SharedHLSVideoJSContext.shared.videoElements.first(where: { $0.value.instanceId == self.instanceId }) else {
            return
        }
        guard let mediaSourceId = videoElement.mediaSourceId,
              let mediaSource = SharedHLSVideoJSContext.shared.mediaSources[mediaSourceId]
        else {
            return
        }
        guard let sourceBufferId = mediaSource.sourceBufferIds.first,
              let sourceBuffer = SharedHLSVideoJSContext.shared.sourceBuffers[sourceBufferId]
        else {
            return
        }
        
        let bufferedRanges = sourceBuffer.ranges
        if let duration = mediaSource.duration {
            var mappedRanges = RangeSet<Int64>()
            for range in bufferedRanges.ranges {
                let rangeLower = max(0.0, range.lowerBound - 0.2)
                let rangeUpper = min(duration, range.upperBound + 0.2)
                mappedRanges.formUnion(
                    RangeSet<Int64>(Int64(rangeLower * 1000.0) ..< Int64(rangeUpper * 1000.0))
                )
            }
            self._bufferingStatus.set(.single((mappedRanges, Int64(duration * 1000.0))))
        }
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    deinit {
        self.serverDisposable?.dispose()
        self.contextDisposable?.dispose()
        self.statusTimer?.invalidate()
        self.sourceBufferStateDisposable?.dispose()
        self.playerStatusDisposable?.dispose()
    }
    
    private func updatePlayerStatus(status: MediaPlayerStatus) {
        self._status.set(status)
        
        if let (bridgeId, _) = SharedHLSVideoJSContext.shared.videoElements.first(where: { $0.value.instanceId == self.instanceId }) {
            var isPlaying: Bool = false
            var isBuffering = false
            switch status.status {
            case .playing:
                isPlaying = true
            case .paused:
                break
            case let .buffering(_, whilePlaying):
                isPlaying = whilePlaying
                isBuffering = true
            }
            
            let result: [String: Any] = [
                "isPlaying": isPlaying,
                "isWaiting": isBuffering,
                "currentTime": status.timestamp
            ]
            
            let jsonResult = try! JSONSerialization.data(withJSONObject: result)
            let jsonResultString = String(data: jsonResult, encoding: .utf8)!
            SharedHLSVideoJSContext.shared.jsContext?.evaluateJavaScript(
                "window.bridgeObjectMap[\(bridgeId)].bridgeUpdateStatus(\(jsonResultString));"
            )
        }
    }
    
    private func updateStatus() {
        // You can keep any timer-based updates here
    }
    
    private func performActionAtEnd() {
        for listener in self.playbackCompletedListeners.copyItems() {
            listener()
        }
    }
    
    public var duration: Double {
        return self.statusValue.duration
    }
    
    public func playOnceWithSound(playAndRecord: Bool, actionAtEnd: MediaPlayerActionAtEnd) {
        self.player.playOnceWithSound(playAndRecord: playAndRecord, seek: .none)
    }
    
    public func setVolume(_ value: Float) {
        self.volume = value
        self.player.setVolume(volume: value)
    }
    
    public func setVideoLayerGravity(_ gravity: AVLayerVideoGravity) {
        self.playerView.setVideoLayerGravity(gravity)
    }
    
    public func updateLayout(size: CGSize, transition: ContainedViewLayoutTransition) {
        self.validLayout = size
        transition.updateFrame(view: self.playerView, frame: CGRect(origin: .zero, size: size))
    }
    
    public func play() {
        if !self.initializedStatus {
            self._status.set(
                MediaPlayerStatus(
                    generationTimestamp: 0.0,
                    duration: Double(self.approximateDuration),
                    dimensions: CGSize(),
                    timestamp: 0.0,
                    baseRate: self.requestedBaseRate,
                    volume: self.volume,
                    seekId: self.seekId,
                    status: .buffering(initial: true, whilePlaying: true)
                )
            )
        }
        self.player.play()
    }
    
    public func pause() {
        self.player.pause()
    }
    
    public func togglePlayPause() {
        self.player.togglePlayPause(faded: false)
    }
    
    public func setSoundEnabled(_ value: Bool) {
        // On macOS you might do something different, or just no-op here
    }
    
    public func seek(_ timestamp: Double) {
        self.seekId += 1
        SharedHLSVideoJSContext.shared.jsContext?.evaluateJavaScript(
            "window.hlsPlayer_instances[\(self.instanceId)].playerSeek(\(timestamp));"
        )
    }
    
    public func setSoundMuted(soundMuted: Bool) {
        SharedHLSVideoJSContext.shared.jsContext?.evaluateJavaScript(
            "window.hlsPlayer_instances[\(self.instanceId)].playerSetIsMuted(\(soundMuted));"
        )
    }
    
    public func setBaseRate(_ baseRate: Double) {
        self.requestedBaseRate = baseRate
        if self.playerIsReady {
            SharedHLSVideoJSContext.shared.jsContext?.evaluateJavaScript(
                "window.hlsPlayer_instances[\(self.instanceId)].playerSetBaseRate(\(self.requestedBaseRate));"
            )
        }
        self.updateStatus()
    }
    
    public func setVideoQuality(_ videoQuality: UniversalVideoContentVideoQuality) {
        self.preferredVideoQuality = videoQuality
        
        switch videoQuality {
        case .auto:
            self.requestedLevelIndex = nil
        case let .quality(quality):
            if let level = self.playerAvailableLevels.first(where: { min($0.value.width, $0.value.height) == quality }) {
                self.requestedLevelIndex = level.key
            } else {
                self.requestedLevelIndex = nil
            }
        }
        
        if self.playerIsReady {
            SharedHLSVideoJSContext.shared.jsContext?.evaluateJavaScript(
                "window.hlsPlayer_instances[\(self.instanceId)].playerSetLevel(\(self.requestedLevelIndex ?? -1));"
            )
        }
    }
    
    public func videoQualityState() -> (current: Int, preferred: UniversalVideoContentVideoQuality, available: [Int])? {
        guard let playerCurrentLevelIndex = self.playerCurrentLevelIndex,
              let currentLevel = self.playerAvailableLevels[playerCurrentLevelIndex]
        else {
            return nil
        }
        
        var available = self.playerAvailableLevels.values.map { min($0.width, $0.height) }
        available.sort(by: { $0 > $1 })
        
        return (
            min(currentLevel.width, currentLevel.height),
            self.preferredVideoQuality,
            available
        )
    }
    
    public func addPlaybackCompleted(_ f: @escaping () -> Void) -> Int {
        return self.playbackCompletedListeners.add(f)
    }
    
    public func removePlaybackCompleted(_ index: Int) {
        self.playbackCompletedListeners.remove(index)
    }
    
    public func fetchControl(_ control: UniversalVideoNodeFetchControl) {
    }
    
    func notifyPlaybackControlsHidden(_ hidden: Bool) {
    }
    
    func setCanPlaybackWithoutHierarchy(_ canPlaybackWithoutHierarchy: Bool) {
    }
    
    func enterNativePictureInPicture() -> Bool {
        return false
    }
    
    func exitNativePictureInPicture() {
    }
}

private final class VideoElement {
    let instanceId: Int
    var mediaSourceId: Int?
    
    init(instanceId: Int) {
        self.instanceId = instanceId
    }
}

private final class MediaSource {
    var duration: Double?
    var sourceBufferIds: [Int] = []
    init() {}
}

private func serializeRanges(_ ranges: RangeSet<Double>) -> [Double] {
    var result: [Double] = []
    for range in ranges.ranges {
        result.append(range.lowerBound)
        result.append(range.upperBound)
    }
    return result
}

private final class SourceBuffer {
    private static let sharedQueue = Queue(name: "SourceBuffer")
    
    final class Item {
        let tempFile: TempBoxFile
        let asset: AVURLAsset
        let startTime: Double
        let endTime: Double
        let rawData: Data
        
        var clippedStartTime: Double
        var clippedEndTime: Double
        
        init(tempFile: TempBoxFile, asset: AVURLAsset, startTime: Double, endTime: Double, rawData: Data) {
            self.tempFile = tempFile
            self.asset = asset
            self.startTime = startTime
            self.endTime = endTime
            self.rawData = rawData
            
            self.clippedStartTime = startTime
            self.clippedEndTime = endTime
        }
        
        func removeRange(start: Double, end: Double) {
            // TODO: implement if needed
        }
    }
    
    let mediaSourceId: Int
    let mimeType: String
    var initializationData: Data?
    var items: [ChunkMediaPlayerPart] = []
    var ranges = RangeSet<Double>()
    
    let updated = ValuePipe<Void>()
    private var currentUpdateId: Int = 0
    
    init(mediaSourceId: Int, mimeType: String) {
        self.mediaSourceId = mediaSourceId
        self.mimeType = mimeType
    }
    
    func abortOperation() {
        self.currentUpdateId += 1
    }
    
    func appendBuffer(data: Data, completion: @escaping (RangeSet<Double>) -> Void) {
        let initializationData = self.initializationData
        self.currentUpdateId += 1
        let updateId = self.currentUpdateId
        
        SourceBuffer.sharedQueue.async { [weak self] in
            let tempFile = TempBox.shared.tempFile(fileName: "data.mp4")
            
            var combinedData = Data()
            if let initializationData {
                combinedData.append(initializationData)
            }
            combinedData.append(data)
            guard (try? combinedData.write(to: URL(fileURLWithPath: tempFile.path), options: .atomic)) != nil else {
                Queue.mainQueue().async {
                    guard let strongSelf = self else {
                        completion(RangeSet())
                        return
                    }
                    if strongSelf.currentUpdateId != updateId {
                        return
                    }
                    completion(strongSelf.ranges)
                }
                return
            }
            
            if let fragmentInfoSet = extractFFMpegMediaInfo(path: tempFile.path),
               let fragmentInfo = fragmentInfoSet.audio ?? fragmentInfoSet.video
            {
                Queue.mainQueue().async {
                    guard let strongSelf = self else {
                        completion(RangeSet())
                        return
                    }
                    if strongSelf.currentUpdateId != updateId {
                        return
                    }
                    if fragmentInfo.duration.value == 0 {
                        strongSelf.initializationData = data
                        completion(strongSelf.ranges)
                    } else {
                        let videoCodecName: String? = fragmentInfoSet.video?.codecName
                        let item = ChunkMediaPlayerPart(
                            startTime: fragmentInfo.startTime.seconds,
                            endTime: fragmentInfo.startTime.seconds + fragmentInfo.duration.seconds,
                            content: ChunkMediaPlayerPart.TempFile(file: tempFile),
                            codecName: videoCodecName,
                            offsetTime: 0
                        )
                        strongSelf.items.append(item)
                        strongSelf.updateRanges()
                        
                        completion(strongSelf.ranges)
                        strongSelf.updated.putNext(Void())
                    }
                }
            } else {
                assertionFailure()
                Queue.mainQueue().async {
                    guard let strongSelf = self else {
                        completion(RangeSet())
                        return
                    }
                    if strongSelf.currentUpdateId != updateId {
                        return
                    }
                    completion(strongSelf.ranges)
                }
                return
            }
        }
    }
    
    func remove(start: Double, end: Double, completion: @escaping (RangeSet<Double>) -> Void) {
        self.items.removeAll { item in
            (item.startTime >= start && item.endTime <= end)
        }
        self.updateRanges()
        completion(self.ranges)
        self.updated.putNext(Void())
    }
    
    private func updateRanges() {
        self.ranges = RangeSet()
        for item in self.items {
            let itemStartTime = round(item.startTime * 1000.0) / 1000.0
            let itemEndTime = round(item.endTime * 1000.0) / 1000.0
            self.ranges.formUnion(RangeSet<Double>(itemStartTime ..< itemEndTime))
        }
    }
}

private func parseFragment(filePath: String) -> (offset: CMTime, duration: CMTime)? {
    let source = SoftwareVideoSource(path: filePath, hintVP9: false, unpremultiplyAlpha: false)
    return source.readTrackInfo()
}
