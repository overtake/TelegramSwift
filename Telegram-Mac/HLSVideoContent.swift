//
//  HLSVideoContent.swift
//  Telegram
//
//  Created by Mikhail Filimonov on 24.09.2024.
//  Copyright © 2024 Telegram. All rights reserved.
//

import Foundation

import SwiftSignalKit
import Postbox
import TelegramCore
import AVFoundation
import RangeSet
import TelegramVoip
import MediaPlayer
import TelegramMediaPlayer
import TelegramMedia
import TGUIKit
import WebKit
import ManagedFile


@available(macOS 14.0, *)
private final class HLSServerSource: SharedHLSServer.Source {
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
            if path == "index.html" {
                if let path = Bundle.main.path(forResource: "HLSVideoPlayer", ofType: "html"), let data = try? Data(contentsOf: URL(fileURLWithPath: path)) {
                    subscriber.putNext((data, "text/html"))
                } else {
                    subscriber.putNext(nil)
                }
            } else if path == "hls.js" {
                if let path = Bundle.main.path(forResource: "hls", ofType: "js"), let data = try? Data(contentsOf: URL(fileURLWithPath: path)) {
                    subscriber.putNext((data, "application/javascript"))
                } else {
                    subscriber.putNext(nil)
                }
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
            self.playlistFetchDisposables[quality] = freeMediaFileResourceInteractiveFetched(postbox: self.postbox, userLocation: self.userLocation, fileReference: playlistFile, resource: playlistFile.media.resource).startStrict()
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
        let _ = quality
        guard let size = file.media.size else {
            return .single(nil)
        }
        
        let postbox = self.postbox
        let userLocation = self.userLocation
        
        let mappedRange: Range<Int64> = Int64(range.lowerBound) ..< Int64(range.upperBound)
        
        let queue = postbox.mediaBox.dataQueue
        let fetchFromRemote: Signal<(TempBoxFile, Range<Int>, Int)?, NoError> = Signal { subscriber in
            let partialFile = TempBox.shared.tempFile(fileName: "data")
            
            if let cachedData = postbox.mediaBox.internal_resourceData(id: file.media.resource.id, size: size, in: Int64(range.lowerBound) ..< Int64(range.upperBound)) {
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
            
            guard let fetchResource = postbox.mediaBox.fetchResource else {
                return EmptyDisposable
            }
            
            let location = MediaResourceStorageLocation(userLocation: userLocation, reference: file.resourceReference(file.media.resource))
            let params = MediaResourceFetchParameters(
                tag: TelegramMediaResourceFetchTag(statsCategory: .video, userContentType: .video),
                info: TelegramCloudMediaResourceFetchInfo(reference: file.resourceReference(file.media.resource), preferBackgroundReferenceRevalidation: true, continueInBackground: true),
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
                error: { _ in
                },
                completed: {
                }
            )
            
            #if DEBUG
            let startTime = CFAbsoluteTimeGetCurrent()
            #endif
            
            let dataDisposable = fileContext.data(
                range: mappedRange,
                waitUntilAfterInitialFetch: true,
                next: { result in
                    if result.complete {
                        #if DEBUG
                        let fetchTime = CFAbsoluteTimeGetCurrent() - startTime
                        print("Fetching \(quality)p part took \(fetchTime * 1000.0) ms")
                        #endif
                        subscriber.putNext((partialFile, Int(result.offset) ..< Int(result.offset + result.size), Int(size)))
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



private final class HLSQualitySet {
    let qualityFiles: [Int: FileMediaReference]
    let playlistFiles: [Int: FileMediaReference]
    
    public init?(baseFile: FileMediaReference) {
        
        func isNativeVideoCodecSupported(videoCodec: String) -> Bool {
            return videoCodec == "h264" || videoCodec == "h265" || videoCodec == "avc" || videoCodec == "hevc"
        }

        var qualityFiles: [Int: FileMediaReference] = [:]
        for alternativeRepresentation in baseFile.media.alternativeRepresentations {
            if let alternativeFile = alternativeRepresentation as? TelegramMediaFile {
                for attribute in alternativeFile.attributes {
                    if case let .Video(_, size, _, _, _, videoCodec) = attribute {
                        let _ = size
                        
                        if let videoCodec, isNativeVideoCodecSupported(videoCodec: videoCodec) {
                            qualityFiles[Int(size.height)] = baseFile.withMedia(alternativeFile)
                        }
                    }
                }
            }
        }
        
        var playlistFiles: [Int: FileMediaReference] = [:]
        for alternativeRepresentation in baseFile.media.alternativeRepresentations {
            if let alternativeFile = alternativeRepresentation as? TelegramMediaFile {
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
        }
        if !playlistFiles.isEmpty && playlistFiles.keys == qualityFiles.keys {
            self.qualityFiles = qualityFiles
            self.playlistFiles = playlistFiles
        } else {
            return nil
        }
    }
}




func isVideoCodecSupported(videoCodec: String) -> Bool {
    return videoCodec == "h264" || videoCodec == "h265" || videoCodec == "avc" || videoCodec == "hevc"
}

private func isHLSVideo(file: TelegramMediaFile) -> Bool {
    for alternativeRepresentation in file.alternativeRepresentations {
        if let alternativeFile = alternativeRepresentation as? TelegramMediaFile {
            if alternativeFile.mimeType == "application/x-mpegurl" {
                return true
            }
        }
    }
    return false
}

private func selectVideoQualityFile(file: TelegramMediaFile, quality: UniversalVideoContentVideoQuality) -> TelegramMediaFile {
    guard case let .quality(qualityHeight) = quality else {
        return file
    }
    for alternativeRepresentation in file.alternativeRepresentations {
        if let alternativeFile = alternativeRepresentation as? TelegramMediaFile {
            for attribute in alternativeFile.attributes {
                if case let .Video(_, size, _, _, _, videoCodec) = attribute {
                    if let videoCodec, isVideoCodecSupported(videoCodec: videoCodec) {
                        if size.height == qualityHeight {
                            return alternativeFile
                        }
                    }
                }
            }
        }
    }
    return file
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

@available(macOS 14.0, *)
final class HLSVideoContent : UniversalVideoContent {
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
    
    init(id: PlatformVideoContentId, userLocation: MediaResourceUserLocation, fileReference: FileMediaReference, streamVideo: Bool = false, loopVideo: Bool = false, enableSound: Bool = true, baseRate: Double = 1.0, fetchAutomatically: Bool = true) {
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
    
    func makeContentView(accountId: AccountRecordId, postbox: Postbox) -> (NSView & UniversalVideoContentView) {
        return HLSVideoJSContentView(accountId: accountId, postbox: postbox, userLocation: self.userLocation, fileReference: self.fileReference, streamVideo: self.streamVideo, loopVideo: self.loopVideo, enableSound: self.enableSound, baseRate: self.baseRate, fetchAutomatically: self.fetchAutomatically)
    }
    
    func isEqual(to other: UniversalVideoContent) -> Bool {
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
    
    static func minimizedHLSQualityFile(file: FileMediaReference) -> FileMediaReference? {
        guard let qualitySet = HLSQualitySet(baseFile: file) else {
            return nil
        }
        for (quality, qualityFile) in qualitySet.qualityFiles.sorted(by: { $0.key < $1.key }) {
            if quality >= 400 {
                return qualityFile
            }
        }
        return nil
    }

}

@available(macOS 14.0, *)
private final class HLSVideoContentView: NSView, UniversalVideoContentView {
   

    
    private let postbox: Postbox
    private let userLocation: MediaResourceUserLocation
    private let fileReference: FileMediaReference
    private let approximateDuration: Double
    private let intrinsicDimensions: CGSize

    
    private let playbackCompletedListeners = Bag<() -> Void>()
    
    private var initializedStatus = false
    private var statusValue = MediaPlayerStatus(generationTimestamp: 0.0, duration: 0.0, dimensions: CGSize(), timestamp: 0.0, baseRate: 1.0, volume: 0, seekId: 0, status: .paused)
    private var isBuffering = false
    private var seekId: Int = 0
    private let _status = ValuePromise<MediaPlayerStatus>()
    var status: Signal<MediaPlayerStatus, NoError> {
        return self._status.get()
    }
    
    private let _bufferingStatus = Promise<(RangeSet<Int64>, Int64)?>()
    var bufferingStatus: Signal<(RangeSet<Int64>, Int64)?, NoError> {
        return self._bufferingStatus.get()
    }
    
    private let _ready = Promise<Void>()
    var ready: Signal<Void, NoError> {
        return self._ready.get()
    }
    
    private let _preloadCompleted = ValuePromise<Bool>()
    var preloadCompleted: Signal<Bool, NoError> {
        return self._preloadCompleted.get()
    }
    
    private var playerSource: HLSServerSource?
    private var serverDisposable: Disposable?
    
    
    private var playerItem: AVPlayerItem?
    private let player: AVPlayer
    private let playerLayer: AVPlayerLayer
    
    private var loadProgressDisposable: Disposable?
    private var statusDisposable: Disposable?
    
    private var didPlayToEndTimeObserver: NSObjectProtocol?
    private var failureObserverId: NSObjectProtocol?
    private var errorObserverId: NSObjectProtocol?
    private var playerItemFailedToPlayToEndTimeObserver: NSObjectProtocol?
    
    private let fetchDisposable = MetaDisposable()
    
    private var dimensions: CGSize?
    private let dimensionsPromise = ValuePromise<CGSize>(CGSize())
    
    private var validLayout: CGSize?
    
    private var statusTimer: Foundation.Timer?
    
    private var preferredVideoQuality: UniversalVideoContentVideoQuality = .auto
    
    init(accountId: AccountRecordId, postbox: Postbox, userLocation: MediaResourceUserLocation, fileReference: FileMediaReference, streamVideo: Bool, loopVideo: Bool, enableSound: Bool, baseRate: Double, fetchAutomatically: Bool) {
        self.postbox = postbox
        self.fileReference = fileReference
        self.approximateDuration = fileReference.media.duration ?? 0.0
        self.userLocation = userLocation
        
        
        
        var startTime = CFAbsoluteTimeGetCurrent()
        
        let player = AVPlayer(playerItem: nil)
        self.player = player
        if !enableSound {
            player.volume = 0.0
        }
        
        print("Player created in \((CFAbsoluteTimeGetCurrent() - startTime) * 1000.0) ms")
        
        self.playerLayer = AVPlayerLayer(player: player)
        
        self.intrinsicDimensions = fileReference.media.dimensions?.size ?? CGSize(width: 480.0, height: 320.0)
        
        self.playerLayer.frame = CGRect(origin: CGPoint(), size: self.intrinsicDimensions)
        
        var qualityFiles: [Int: FileMediaReference] = [:]
        for alternativeRepresentation in fileReference.media.alternativeRepresentations {
            if let alternativeFile = alternativeRepresentation as? TelegramMediaFile {
                for attribute in alternativeFile.attributes {
                    if case let .Video(_, size, _, _, _, videoCodec) = attribute {
                        let _ = size
                        if let videoCodec, isVideoCodecSupported(videoCodec: videoCodec) {
                            qualityFiles[Int(size.height)] = fileReference.withMedia(alternativeFile)
                        }
                    }
                }
            }
        }
        var playlistFiles: [Int: FileMediaReference] = [:]
        for alternativeRepresentation in fileReference.media.alternativeRepresentations {
            if let alternativeFile = alternativeRepresentation as? TelegramMediaFile {
                if alternativeFile.mimeType == "application/x-mpegurl" {
                    if let fileName = alternativeFile.fileName {
                        if fileName.hasPrefix("mtproto:") {
                            let fileIdString = String(fileName[fileName.index(fileName.startIndex, offsetBy: "mtproto:".count)...])
                            if let fileId = Int64(fileIdString) {
                                for (quality, file) in qualityFiles {
                                    if file.media.fileId.id == fileId {
                                        playlistFiles[quality] = fileReference.withMedia(alternativeFile)
                                        break
                                    }
                                }
                            }
                        }
                    }
                }
            }
        }
        if !playlistFiles.isEmpty && playlistFiles.keys == qualityFiles.keys {
            self.playerSource = HLSServerSource(accountId: accountId.int64, fileId: fileReference.media.fileId.id, postbox: postbox, userLocation: userLocation, playlistFiles: playlistFiles, qualityFiles: qualityFiles)
        }
        
        
        super.init(frame: .zero)

        
        self.wantsLayer = true
        self.layer = self.playerLayer
        
        self.player.actionAtItemEnd = .pause
        
        self._ready.set(.single(Void()))

        
        self.player.addObserver(self, forKeyPath: "rate", options: [], context: nil)
        
        self._bufferingStatus.set(.single(nil))
        
        startTime = CFAbsoluteTimeGetCurrent()
        
        if let playerSource = self.playerSource {
            self.serverDisposable = SharedHLSServer.shared.registerPlayer(source: playerSource, completion: { })
            
            let playerItem: AVPlayerItem
            let assetUrl = "http://127.0.0.1:\(SharedHLSServer.shared.port)/\(playerSource.id)/master.m3u8"
            #if DEBUG
            print("HLSVideoContentView: playing \(assetUrl)")
            #endif
            playerItem = AVPlayerItem(url: URL(string: assetUrl)!)
            print("Player item created in \((CFAbsoluteTimeGetCurrent() - startTime) * 1000.0) ms")
            
            if #available(iOS 14.0, *) {
                playerItem.startsOnFirstEligibleVariant = true
            }
            
            startTime = CFAbsoluteTimeGetCurrent()
            self.setPlayerItem(playerItem)
            print("Set player item in \((CFAbsoluteTimeGetCurrent() - startTime) * 1000.0) ms")
        }
        
        self.didPlayToEndTimeObserver = NotificationCenter.default.addObserver(forName: NSNotification.Name.AVPlayerItemDidPlayToEndTime, object: self.player.currentItem, queue: nil, using: { [weak self] notification in
            self?.performActionAtEnd()
        })
        
        self.failureObserverId = NotificationCenter.default.addObserver(forName: AVPlayerItem.failedToPlayToEndTimeNotification, object: self.player.currentItem, queue: .main, using: { notification in
            print("Player Error: \(notification.description)")
        })
        self.errorObserverId = NotificationCenter.default.addObserver(forName: AVPlayerItem.newErrorLogEntryNotification, object: self.player.currentItem, queue: .main, using: { notification in
            print("Player Error: \(notification.description)")
        })
        
        
        if let currentItem = self.player.currentItem {
            currentItem.addObserver(self, forKeyPath: "presentationSize", options: [], context: nil)
        }
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    deinit {
        self.player.removeObserver(self, forKeyPath: "rate")
        if let currentItem = self.player.currentItem {
            currentItem.removeObserver(self, forKeyPath: "presentationSize")
        }
        
        self.setPlayerItem(nil)
        
        
        self.loadProgressDisposable?.dispose()
        self.statusDisposable?.dispose()
        
        if let didPlayToEndTimeObserver = self.didPlayToEndTimeObserver {
            NotificationCenter.default.removeObserver(didPlayToEndTimeObserver)
        }
        if let failureObserverId = self.failureObserverId {
            NotificationCenter.default.removeObserver(failureObserverId)
        }
        if let errorObserverId = self.errorObserverId {
            NotificationCenter.default.removeObserver(errorObserverId)
        }
        
        self.serverDisposable?.dispose()
        
        self.statusTimer?.invalidate()
    }
    
    private func setPlayerItem(_ item: AVPlayerItem?) {
        if let playerItem = self.playerItem {
            playerItem.removeObserver(self, forKeyPath: "playbackBufferEmpty")
            playerItem.removeObserver(self, forKeyPath: "playbackLikelyToKeepUp")
            playerItem.removeObserver(self, forKeyPath: "playbackBufferFull")
            playerItem.removeObserver(self, forKeyPath: "status")
            if let playerItemFailedToPlayToEndTimeObserver = self.playerItemFailedToPlayToEndTimeObserver {
                NotificationCenter.default.removeObserver(playerItemFailedToPlayToEndTimeObserver)
                self.playerItemFailedToPlayToEndTimeObserver = nil
            }
        }
        
        self.playerItem = item
        
        if let playerItem = self.playerItem {
            playerItem.addObserver(self, forKeyPath: "playbackBufferEmpty", options: .new, context: nil)
            playerItem.addObserver(self, forKeyPath: "playbackLikelyToKeepUp", options: .new, context: nil)
            playerItem.addObserver(self, forKeyPath: "playbackBufferFull", options: .new, context: nil)
            playerItem.addObserver(self, forKeyPath: "status", options: .new, context: nil)
            self.playerItemFailedToPlayToEndTimeObserver = NotificationCenter.default.addObserver(forName: NSNotification.Name.AVPlayerItemFailedToPlayToEndTime, object: playerItem, queue: OperationQueue.main, using: { [weak self] _ in
                guard let self else {
                    return
                }
                let _ = self
            })
        }
        
        self.player.replaceCurrentItem(with: self.playerItem)
    }
    
    private func updateStatus() {
        let isPlaying = !self.player.rate.isZero
        let status: MediaPlayerPlaybackStatus
        if self.isBuffering {
            status = .buffering(initial: false, whilePlaying: isPlaying)
        } else {
            status = isPlaying ? .playing : .paused
        }
        var timestamp = self.player.currentTime().seconds
        if timestamp.isFinite && !timestamp.isNaN {
        } else {
            timestamp = 0.0
        }
        self.statusValue = MediaPlayerStatus(generationTimestamp: CACurrentMediaTime(), duration: Double(self.approximateDuration), dimensions: CGSize(), timestamp: timestamp, baseRate: Double(self.player.rate), volume: self.player.volume, seekId: self.seekId, status: status)
        self._status.set(self.statusValue)
        
        if case .playing = status {
            if self.statusTimer == nil {
                self.statusTimer = Foundation.Timer.scheduledTimer(withTimeInterval: 1.0 / 30.0, repeats: true, block: { [weak self] _ in
                    guard let self else {
                        return
                    }
                    self.updateStatus()
                })
            }
        } else if let statusTimer = self.statusTimer {
            self.statusTimer = nil
            statusTimer.invalidate()
        }
    }
    
    override func observeValue(forKeyPath keyPath: String?, of object: Any?, change: [NSKeyValueChangeKey : Any]?, context: UnsafeMutableRawPointer?) {
        if keyPath == "rate" {
            let isPlaying = !self.player.rate.isZero
            if isPlaying {
               self.isBuffering = false
            }
            self.updateStatus()
        } else if keyPath == "playbackBufferEmpty" {
            self.isBuffering = true
            self.updateStatus()
        } else if keyPath == "playbackLikelyToKeepUp" || keyPath == "playbackBufferFull" {
            self.isBuffering = false
            self.updateStatus()
        } else if keyPath == "presentationSize" {
            if let currentItem = self.player.currentItem {
                print("Presentation size: \(Int(currentItem.presentationSize.height))")
            }
        }
    }
    
    private func performActionAtEnd() {
        for listener in self.playbackCompletedListeners.copyItems() {
            listener()
        }
    }
    
    func updateLayout(size: CGSize, transition: ContainedViewLayoutTransition) {
        transition.updateFrame(layer: self.playerLayer, frame: size.bounds)
    }
    
    func play() {
        assert(Queue.mainQueue().isCurrent())
        if !self.initializedStatus {
            self._status.set(MediaPlayerStatus(generationTimestamp: 0.0, duration: Double(self.approximateDuration), dimensions: CGSize(), timestamp: 0.0, baseRate: 1.0, volume: self.player.volume, seekId: self.seekId, status: .buffering(initial: true, whilePlaying: true)))
        }
        self.player.play()

    }
    
    func pause() {
        assert(Queue.mainQueue().isCurrent())
        self.player.pause()
    }
    
    func togglePlayPause() {
        assert(Queue.mainQueue().isCurrent())
        if self.player.rate.isZero {
            self.play()
        } else {
            self.pause()
        }
    }
    
    func setSoundEnabled(_ value: Bool) {
        assert(Queue.mainQueue().isCurrent())
        if value {
            self.player.volume = 1.0
        } else {
            self.player.volume = 0.0
        }
    }
    
    func seek(_ timestamp: Double) {
        assert(Queue.mainQueue().isCurrent())
        self.seekId += 1
        self.player.seek(to: CMTime(seconds: timestamp, preferredTimescale: 30))
    }
    
    func playOnceWithSound(playAndRecord: Bool, actionAtEnd: MediaPlayerActionAtEnd) {
        self.player.volume = 1.0
        self.play()
    }
    
    func setSoundMuted(soundMuted: Bool) {
        self.player.volume = soundMuted ? 0.0 : 1.0
    }
    
    
    func setBaseRate(_ baseRate: Double) {
        self.player.rate = Float(baseRate)
    }
    
    func setVideoQuality(_ videoQuality: UniversalVideoContentVideoQuality) {
        self.preferredVideoQuality = videoQuality
        
        guard let currentItem = self.player.currentItem else {
            return
        }
        guard let playerSource = self.playerSource else {
            return
        }
        
        switch videoQuality {
        case .auto:
            currentItem.preferredPeakBitRate = 0.0
        case let .quality(qualityValue):
            if let file = playerSource.qualityFiles[qualityValue] {
                if let size = file.media.size, let duration = file.media.duration, duration != 0.0 {
                    let bandwidth = Int(Double(size) / duration) * 8
                    currentItem.preferredPeakBitRate = Double(bandwidth)
                }
            }
        }
        
    }
    
    func videoQualityState() -> (current: Int, preferred: UniversalVideoContentVideoQuality, available: [Int])? {
        guard let currentItem = self.player.currentItem else {
            return nil
        }
        guard let playerSource = self.playerSource else {
            return nil
        }
        let current = Int(currentItem.presentationSize.height)
        var available: [Int] = Array(playerSource.qualityFiles.keys)
        available.sort(by: { $0 > $1 })
        return (current, self.preferredVideoQuality, available)
    }
    
    func addPlaybackCompleted(_ f: @escaping () -> Void) -> Int {
        return self.playbackCompletedListeners.add(f)
    }
    
    func removePlaybackCompleted(_ index: Int) {
        self.playbackCompletedListeners.remove(index)
    }
    
    func fetchControl(_ control: UniversalVideoNodeFetchControl) {
    }
    func setVolume(_ value: Float) {
        self.player.volume = value
    }
    
    func setVideoLayerGravity(_ gravity: AVLayerVideoGravity) {
        self.playerLayer.videoGravity = gravity
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

@available(macOS 14.0, *)
final class HLSVideoJSContentView: NSView, UniversalVideoContentView {
 
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
    
    private let postbox: Postbox
    private let userLocation: MediaResourceUserLocation
    private let fileReference: FileMediaReference
    private let approximateDuration: Double
    private let intrinsicDimensions: CGSize

    
    private let playerSource: HLSServerSource?
    private var serverDisposable: Disposable?
    
    private let playbackCompletedListeners = Bag<() -> Void>()
    
    private var initializedStatus = false
    private var statusValue = MediaPlayerStatus(generationTimestamp: 0.0, duration: 0.0, dimensions: CGSize(), timestamp: 0.0, baseRate: 1.0, volume: 1.0, seekId: 0, status: .paused)
    private var isBuffering = false
    private var seekId: Int = 0
    private let _status = ValuePromise<MediaPlayerStatus>()
    var status: Signal<MediaPlayerStatus, NoError> {
        return self._status.get()
    }
    
    private let _bufferingStatus = Promise<(RangeSet<Int64>, Int64)?>()
    var bufferingStatus: Signal<(RangeSet<Int64>, Int64)?, NoError> {
        return self._bufferingStatus.get()
    }
    
    private let _ready = Promise<Void>()
    var ready: Signal<Void, NoError> {
        return self._ready.get()
    }
    
    private let _preloadCompleted = ValuePromise<Bool>()
    var preloadCompleted: Signal<Bool, NoError> {
        return self._preloadCompleted.get()
    }
    
    private let webView: WKWebView
    
    private let fetchDisposable = MetaDisposable()
    
    private var dimensions: CGSize?
    private let dimensionsPromise = ValuePromise<CGSize>(CGSize())
    
    private var validLayout: (size: CGSize, actualSize: CGSize)?
    
    private var statusTimer: Foundation.Timer?
    
    private var preferredVideoQuality: UniversalVideoContentVideoQuality = .auto
    
    private var playerIsReady: Bool = false
    private var playerIsFirstFrameReady: Bool = false
    private var playerIsPlaying: Bool = false
    private var playerRate: Double = 0.0
    private var playerDefaultRate: Double = 1.0
    private var playerTime: Double = 0.0
    private var playerTimeGenerationTimestamp: Double = 0.0
    private var playerAvailableLevels: [Int: Level] = [:]
    private var playerCurrentLevelIndex: Int?
    
    private var hasRequestedPlayerLoad: Bool = false
    
    private var requestedPlaying: Bool = false
    private var requestedBaseRate: Double = 1.0
    private var requestedLevelIndex: Int?
    
    init(accountId: AccountRecordId, postbox: Postbox, userLocation: MediaResourceUserLocation, fileReference: FileMediaReference, streamVideo: Bool, loopVideo: Bool, enableSound: Bool, baseRate: Double, fetchAutomatically: Bool) {
        self.postbox = postbox
        self.fileReference = fileReference
        self.approximateDuration = fileReference.media.duration ?? 0.0
        self.userLocation = userLocation
        self.requestedBaseRate = baseRate
        
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
        
        var playerSource: HLSServerSource?
        if let qualitySet = HLSQualitySet(baseFile: fileReference) {
            let playerSourceValue = HLSServerSource(accountId: accountId.int64, fileId: fileReference.media.fileId.id, postbox: postbox, userLocation: userLocation, playlistFiles: qualitySet.playlistFiles, qualityFiles: qualitySet.qualityFiles)
            playerSource = playerSourceValue
        }
        self.playerSource = playerSource
        
        let userController = WKUserContentController()
        
        var handleScriptMessage: ((WKScriptMessage) -> Void)?
        userController.add(WeakScriptMessageHandler { message in
            handleScriptMessage?(message)
        }, name: "performAction")
        
        let isDebug: Bool
        #if DEBUG
        isDebug = true
        #else
        isDebug = false
        #endif
        
        let mediaDimensions = fileReference.media.dimensions?.size ?? CGSize(width: 480.0, height: 320.0)
        self.intrinsicDimensions = mediaDimensions.aspectFitted(CGSize(width: 1280.0, height: 1280.0))
        
        let userScriptJs = """
        playerInitialize({
            'debug': \(isDebug),
            'width': \(Int(self.intrinsicDimensions.width)),
            'height': \(Int(self.intrinsicDimensions.height))
        });
        """;
        let userScript = WKUserScript(source: userScriptJs, injectionTime: .atDocumentEnd, forMainFrameOnly: true)
        userController.addUserScript(userScript)
        
        config.userContentController = userController
        
        self.webView = WKWebView(frame: CGRect(origin: CGPoint(), size: self.intrinsicDimensions), configuration: config)
        self.webView.allowsLinkPreview = false
        self.webView.allowsBackForwardNavigationGestures = false
        

        super.init(frame: .zero)
        self.wantsLayer = true
       
        self._ready.set(.single(Void()))
        self._bufferingStatus.set(.single(nil))
        
        handleScriptMessage = { [weak self] message in
            Queue.mainQueue().async {
                guard let self else {
                    return
                }
                guard let body = message.body as? [String: Any] else {
                    return
                }
                guard let eventName = body["event"] as? String else {
                    return
                }
                
                switch eventName {
                case "playerStatus":
                    guard let eventData = body["data"] as? [String: Any] else {
                        return
                    }
                    if let isReady = eventData["isReady"] as? Bool {
                        self.playerIsReady = isReady
                    } else {
                        self.playerIsReady = false
                    }
                    if let isFirstFrameReady = eventData["isFirstFrameReady"] as? Bool {
                        self.playerIsFirstFrameReady = isFirstFrameReady
                    } else {
                        self.playerIsFirstFrameReady = false
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
                            guard let levelIndex = level["index"] as? Int else {
                                continue
                            }
                            guard let levelBitrate = level["bitrate"] as? Int else {
                                continue
                            }
                            guard let levelWidth = level["width"] as? Int else {
                                continue
                            }
                            guard let levelHeight = level["height"] as? Int else {
                                continue
                            }
                            self.playerAvailableLevels[levelIndex] = Level(
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
                        if !self.hasRequestedPlayerLoad {
                            if !self.playerAvailableLevels.isEmpty {
                                var selectedLevelIndex: Int?
                                if let minimizedQualityFile = HLSVideoContent.minimizedHLSQualityFile(file: self.fileReference) {
                                    if let dimensions = minimizedQualityFile.media.dimensions {
                                        for (index, level) in self.playerAvailableLevels {
                                            if level.height == Int(dimensions.height) {
                                                selectedLevelIndex = index
                                                break
                                            }
                                        }
                                    }
                                }
                                if selectedLevelIndex == nil {
                                    selectedLevelIndex = self.playerAvailableLevels.sorted(by: { $0.value.height > $1.value.height }).first?.key
                                }
                                if let selectedLevelIndex {
                                    self.hasRequestedPlayerLoad = true
                                    self.webView.evaluateJavaScript("playerLoad(\(selectedLevelIndex));", completionHandler: nil)
                                }
                            }
                        }
                        
                        self.webView.evaluateJavaScript("playerSetBaseRate(\(self.requestedBaseRate));", completionHandler: nil)
                        
                        if self.requestedPlaying {
                            self.requestPlay()
                        } else {
                            self.requestPause()
                        }
                    }
                    
                    self.updateStatus()
                case "playerCurrentTime":
                    guard let eventData = body["data"] as? [String: Any] else {
                        return
                    }
                    guard let value = eventData["value"] as? Double else {
                        return
                    }
                    self.playerTime = value
                    self.playerTimeGenerationTimestamp = CACurrentMediaTime()
                    self.updateStatus()
                default:
                    break
                }
            }
        }
        
        if let playerSource = self.playerSource {
            self.serverDisposable = SharedHLSServer.shared.registerPlayer(source: playerSource, completion: { [weak self] in
                Queue.mainQueue().async {
                    guard let self else {
                        return
                    }
                    
                    let htmlUrl = "http://127.0.0.1:\(SharedHLSServer.shared.port)/\(playerSource.id)/index.html"
                    self.webView.load(URLRequest(url: URL(string: htmlUrl)!))
                }
            })
        }
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    deinit {
        self.serverDisposable?.dispose()
        self.statusTimer?.invalidate()
    }
    
    private func updateStatus() {
        let isPlaying = self.requestedPlaying && self.playerRate != 0.0
        let status: MediaPlayerPlaybackStatus
        if self.requestedPlaying && !isPlaying {
            status = .buffering(initial: false, whilePlaying: self.requestedPlaying)
        } else {
            status = self.requestedPlaying ? .playing : .paused
        }
        var timestamp = self.playerTime
        if timestamp.isFinite && !timestamp.isNaN {
        } else {
            timestamp = 0.0
        }
        self.statusValue = MediaPlayerStatus(generationTimestamp: self.playerTimeGenerationTimestamp, duration: Double(self.approximateDuration), dimensions: CGSize(), timestamp: timestamp, baseRate: self.requestedBaseRate, volume: 1.0, seekId: self.seekId, status: status)
        self._status.set(self.statusValue)
        
        if case .playing = status {
            if self.statusTimer == nil {
                self.statusTimer = Foundation.Timer.scheduledTimer(withTimeInterval: 1.0 / 30.0, repeats: true, block: { [weak self] _ in
                    guard let self else {
                        return
                    }
                    self.updateStatus()
                })
            }
        } else if let statusTimer = self.statusTimer {
            self.statusTimer = nil
            statusTimer.invalidate()
        }
    }
    
    private func performActionAtEnd() {
        for listener in self.playbackCompletedListeners.copyItems() {
            listener()
        }
    }
    
    func updateLayout(size: CGSize, actualSize: CGSize, transition: ContainedViewLayoutTransition) {
        transition.updateFrame(view: self.webView, frame: size.bounds)
    }
    
    func play() {
        assert(Queue.mainQueue().isCurrent())
        if !self.initializedStatus {
            self._status.set(MediaPlayerStatus(generationTimestamp: 0.0, duration: Double(self.approximateDuration), dimensions: CGSize(), timestamp: 0.0, baseRate: self.requestedBaseRate, volume: 1, seekId: self.seekId, status: .buffering(initial: true, whilePlaying: true)))
        }
        do {
            self.requestPlay()
        }
    }
    
    private func requestPlay() {
        self.requestedPlaying = true
        if self.playerIsReady {
            self.webView.evaluateJavaScript("playerPlay();", completionHandler: nil)
        }
        self.updateStatus()
    }

    private func requestPause() {
        self.requestedPlaying = false
        if self.playerIsReady {
            self.webView.evaluateJavaScript("playerPause();", completionHandler: nil)
        }
        self.updateStatus()
    }
    
    func pause() {
        assert(Queue.mainQueue().isCurrent())
        self.requestPause()
    }
    
    func togglePlayPause() {
        assert(Queue.mainQueue().isCurrent())
        
        if self.requestedPlaying {
            self.pause()
        } else {
            self.play()
        }
    }
    
    func setSoundEnabled(_ value: Bool) {
        assert(Queue.mainQueue().isCurrent())
    }
    
    func seek(_ timestamp: Double) {
        assert(Queue.mainQueue().isCurrent())
        self.seekId += 1
        
        self.webView.evaluateJavaScript("playerSeek(\(timestamp));", completionHandler: nil)
    }
    
    func playOnceWithSound(playAndRecord: Bool, actionAtEnd: MediaPlayerActionAtEnd) {
        self.webView.evaluateJavaScript("playerSetIsMuted(false);", completionHandler: nil)
        
        self.play()
    }
    
    func setSoundMuted(soundMuted: Bool) {
        self.webView.evaluateJavaScript("playerSetIsMuted(\(soundMuted));", completionHandler: nil)
    }
    
    func updateLayout(size: CGSize, transition: ContainedViewLayoutTransition) {
        transition.updateFrame(view: self.webView, frame: size.bounds)
    }
    
    func setVolume(_ value: Float) {
            }
    
    func setVideoLayerGravity(_ gravity: AVLayerVideoGravity) {
        
    }
    

    func setBaseRate(_ baseRate: Double) {
        self.requestedBaseRate = baseRate
        if self.playerIsReady {
            self.webView.evaluateJavaScript("playerSetBaseRate(\(self.requestedBaseRate));", completionHandler: nil)
        }
        self.updateStatus()
    }
    
    func setVideoQuality(_ videoQuality: UniversalVideoContentVideoQuality) {
        self.preferredVideoQuality = videoQuality
        
        switch videoQuality {
        case .auto:
            self.requestedLevelIndex = nil
        case let .quality(quality):
            if let level = self.playerAvailableLevels.first(where: { $0.value.height == quality }) {
                self.requestedLevelIndex = level.key
            } else {
                self.requestedLevelIndex = nil
            }
        }
        
        if self.playerIsReady {
            self.webView.evaluateJavaScript("playerSetLevel(\(self.requestedLevelIndex ?? -1));", completionHandler: nil)
        }
    }
    
    func videoQualityState() -> (current: Int, preferred: UniversalVideoContentVideoQuality, available: [Int])? {
        guard let playerCurrentLevelIndex = self.playerCurrentLevelIndex else {
            return nil
        }
        guard let currentLevel = self.playerAvailableLevels[playerCurrentLevelIndex] else {
            return nil
        }
        
        var available = self.playerAvailableLevels.values.map(\.height)
        available.sort(by: { $0 > $1 })
        
        return (currentLevel.height, self.preferredVideoQuality, available)
    }
    
    func addPlaybackCompleted(_ f: @escaping () -> Void) -> Int {
        return self.playbackCompletedListeners.add(f)
    }
    
    func removePlaybackCompleted(_ index: Int) {
        self.playbackCompletedListeners.remove(index)
    }
    
    func fetchControl(_ control: UniversalVideoNodeFetchControl) {
    }
    
}
