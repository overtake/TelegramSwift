//
//  WebviewHLS.swift
//  Telegram
//
//  Created by Mikhail Filimonov on 24.09.2024.
//  Copyright © 2024 Telegram. All rights reserved.
//

import Foundation
import WebKit
import TelegramVoip
import TGUIKit
import Postbox
import TelegramCore
import SwiftSignalKit
import RangeSet
import FFMpegBinding

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
    return start..<end + 1
}

final class HLSServerSource {
    let id: UUID
    let postbox: Postbox
    let userLocation: MediaResourceUserLocation
    let playlistFiles: [Int: FileMediaReference]
    let qualityFiles: [Int: FileMediaReference]
    
    private var playlistFetchDisposables: [Int: Disposable] = [:]
    
    init(id: UUID, postbox: Postbox, userLocation: MediaResourceUserLocation, playlistFiles: [Int: FileMediaReference], qualityFiles: [Int: FileMediaReference]) {
        self.id = id
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
    
    func fileData(id: Int64, range: Range<Int>) -> Signal<(Data, Int)?, NoError> {
        guard let file = self.qualityFiles.values.first(where: { $0.media.fileId.id == id }) else {
            return .single(nil)
        }
        guard let size = file.media.size else {
            return .single(nil)
        }
        
        let postbox = self.postbox
        let userLocation = self.userLocation
        
        let mappedRange: Range<Int64> = Int64(range.lowerBound) ..< Int64(range.upperBound)
        
        return Signal { subscriber in
            if let fetchResource = postbox.mediaBox.fetchResource {
                let location = MediaResourceStorageLocation(userLocation: userLocation, reference: file.resourceReference(file.media.resource))
                let params = MediaResourceFetchParameters(
                    tag: TelegramMediaResourceFetchTag(statsCategory: .video, userContentType: .video),
                    info: TelegramCloudMediaResourceFetchInfo(reference: file.resourceReference(file.media.resource), preferBackgroundReferenceRevalidation: true, continueInBackground: true),
                    location: location,
                    contentType: .video,
                    isRandomAccessAllowed: true
                )
                
                final class StoredState {
                    let range: Range<Int64>
                    var data: Data
                    var ranges: RangeSet<Int64>
                    
                    init(range: Range<Int64>) {
                        self.range = range
                        self.data = Data(count: Int(range.upperBound - range.lowerBound))
                        self.ranges = RangeSet(range)
                    }
                }
                let storedState = Atomic<StoredState>(value: StoredState(range: mappedRange))
                
                return fetchResource(file.media.resource, .single([(mappedRange, .elevated)]), params).start(next: { result in
                    switch result {
                    case let .dataPart(resourceOffset, data, _, _):
                        if !data.isEmpty {
                            let partRange = resourceOffset ..< (resourceOffset + Int64(data.count))
                            var isReady = false
                            storedState.with { storedState in
                                let overlapRange = partRange.clamped(to: storedState.range)
                                guard !overlapRange.isEmpty else {
                                    return
                                }
                                let innerRange = (overlapRange.lowerBound - storedState.range.lowerBound) ..< (overlapRange.upperBound - storedState.range.lowerBound)
                                let dataStart = overlapRange.lowerBound - partRange.lowerBound
                                let dataEnd = overlapRange.upperBound - partRange.lowerBound
                                let innerData = data.subdata(in: Int(dataStart) ..< Int(dataEnd))
                                storedState.data.replaceSubrange(Int(innerRange.lowerBound) ..< Int(innerRange.upperBound), with: innerData)
                                storedState.ranges.subtract(RangeSet(overlapRange))
                                if storedState.ranges.isEmpty {
                                    isReady = true
                                }
                            }
                            if isReady {
                                subscriber.putNext((storedState.with({ $0.data }), Int(size)))
                                subscriber.putCompletion()
                            }
                        }
                    default:
                        break
                    }
                })
            } else {
                return EmptyDisposable
            }
            
        }
    }
}

private class LocalVideoSchemeHandler: NSObject, WKURLSchemeHandler {
    
    private let source: HLSServerSource
    init(source: HLSServerSource) {
        self.source = source
    }
    
    private var hshs: Set<Int> = Set()
    private var ongoingTasks = [URL: Disposable]()
    
    // Called when a request is made for a custom scheme
    func webView(_ webView: WKWebView, start urlSchemeTask: WKURLSchemeTask) {
        guard let url = urlSchemeTask.request.url else {
            return
        }
        
        var requestRange: Range<Int>?
        if let rangeString = urlSchemeTask.request.allHTTPHeaderFields?["Range"] {
            requestRange = parseRange(from: rangeString)
        }
                
        let filePath = url.absoluteString.nsstring.lastPathComponent

        // Handle HLS request based on URL
        if filePath == "master.m3u8" {
            // Serve master playlist
            ongoingTasks[url] = source.masterPlaylistData()
                .start(next: { [weak self] data in
                    self?.sendResponseAndClose(urlSchemeTask: urlSchemeTask, data: data.data(using: .utf8)!)
                })
        }  else if filePath.hasPrefix("hls_level_") && filePath.hasSuffix(".m3u8") {
            guard let levelIndex = Int(String(filePath[filePath.index(filePath.startIndex, offsetBy: "hls_level_".count) ..< filePath.index(filePath.endIndex, offsetBy: -".m3u8".count)])) else {
                self.sendErrorAndClose(urlSchemeTask)
                return
            }
            
            ongoingTasks[url] = (source.playlistData(quality: levelIndex)
            |> deliverOnMainQueue
            |> take(1)).start(next: { [weak self] result in
                guard let self else {
                    return
                }
                
                self.sendResponseAndClose(urlSchemeTask: urlSchemeTask, data: result.data(using: .utf8)!)
            })
        } else if filePath.hasPrefix("hls_stream") && filePath.hasSuffix(".ts") {
            let fileId = String(filePath[filePath.index(filePath.startIndex, offsetBy: "hls_stream".count) ..< filePath.index(filePath.endIndex, offsetBy: -".ts".count)])
            guard let underscoreRange = fileId.range(of: "_") else {
                self.sendErrorAndClose(urlSchemeTask)
                return
            }
            guard let levelIndex = Int(String(fileId[fileId.startIndex ..< underscoreRange.lowerBound])) else {
                self.sendErrorAndClose(urlSchemeTask)
                return
            }
            guard let partIndex = Int(String(fileId[underscoreRange.upperBound...])) else {
                self.sendErrorAndClose(urlSchemeTask)
                return
            }
            ongoingTasks[url] = (source.partData(index: partIndex, quality: levelIndex)
                     |> deliverOnMainQueue
            |> take(1)).start(next: { [weak self] result in
                guard let self else {
                    return
                }
                
                if let result {
                    let sourceTempFile = TempBox.shared.tempFile(fileName: "part.mp4")
                    let tempFile = TempBox.shared.tempFile(fileName: "part.ts")
                    defer {
                        TempBox.shared.dispose(sourceTempFile)
                        TempBox.shared.dispose(tempFile)
                    }
                    
                    guard let _ = try? result.write(to: URL(fileURLWithPath: sourceTempFile.path)) else {
                        self.sendErrorAndClose(urlSchemeTask)
                        return
                    }
                    
                    let sourcePath = sourceTempFile.path
                    FFMpegLiveMuxer.remux(sourcePath, to: tempFile.path, offsetSeconds: Double(partIndex))
                    
                    if let data = try? Data(contentsOf: URL(fileURLWithPath: tempFile.path)) {
                        self.sendResponseAndClose(urlSchemeTask: urlSchemeTask, data: data)
                    } else {
                        self.sendErrorAndClose(urlSchemeTask)
                    }
                } else {
                    self.sendErrorAndClose(urlSchemeTask)
                }
            })
        } else if filePath.hasPrefix("partfile") && filePath.hasSuffix(".mp4") {
            let fileId = String(filePath[filePath.index(filePath.startIndex, offsetBy: "partfile".count) ..< filePath.index(filePath.endIndex, offsetBy: -".mp4".count)])
            guard let fileIdValue = Int64(fileId) else {
                self.sendErrorAndClose(urlSchemeTask)
                return
            }
            guard let requestRange else {
                self.sendErrorAndClose(urlSchemeTask)
                return
            }
            ongoingTasks[url] = (source.fileData(id: fileIdValue, range: requestRange.lowerBound ..< requestRange.upperBound + 1)
            |> deliverOnMainQueue
            |> take(1)).start(next: { [weak self] result in
                guard let self else {
                    return
                }
                
                if let (data, totalSize) = result {
                    self.sendResponseAndClose(urlSchemeTask: urlSchemeTask, data: data, range: requestRange, totalSize: totalSize)
                } else {
                    self.sendErrorAndClose(urlSchemeTask)
                }
            })
        } else {
            self.sendErrorAndClose(urlSchemeTask)
        }
    }
    
    func webView(_ webView: WKWebView, stop urlSchemeTask: WKURLSchemeTask) {
        if let url = urlSchemeTask.request.url {
            ongoingTasks[url]?.dispose()
            ongoingTasks.removeValue(forKey: url)
        }
    }
    
    func sendErrorAndClose(_ urlSchemeTask: WKURLSchemeTask) {
        urlSchemeTask.didFailWithError(NSError(domain: "LocalVideoError", code: 404, userInfo: nil))
        if let url = urlSchemeTask.request.url {
            ongoingTasks[url]?.dispose()
            ongoingTasks.removeValue(forKey: url)
        }
    }
    
    private func sendResponseAndClose(urlSchemeTask: WKURLSchemeTask, data: Data, range: Range<Int>? = nil, totalSize: Int? = nil) {
        // Create the response with the appropriate content-type and content-length
        let mimeType = "application/octet-stream"
        let responseLength = data.count
        
        // Construct URLResponse with optional range headers (for partial content responses)
        var headers: [String: String] = [
            "Content-Length": "\(responseLength)",
            "Connection": "close",
            "Access-Control-Allow-Origin": "*"
        ]
        
        if let range = range, let totalSize = totalSize {
            headers["Content-Range"] = "bytes \(range.lowerBound)-\(range.upperBound)/\(totalSize)"
        }
        
        // Create the URLResponse object
        let response = HTTPURLResponse(url: urlSchemeTask.request.url!,
                                       statusCode: 200,
                                       httpVersion: "HTTP/1.1",
                                       headerFields: headers)
        
        // Send the response headers
        urlSchemeTask.didReceive(response!)
        
        // Send the response data
        urlSchemeTask.didReceive(data)
        
        // Complete the task
        urlSchemeTask.didFinish()
        
        if let url = urlSchemeTask.request.url {
            ongoingTasks[url]?.dispose()
            ongoingTasks.removeValue(forKey: url)
        }

    }
}

final class WebviewHLSView : View {
    private let webView: WKWebView
    init(frame frameRect: NSRect, source: HLSServerSource) {
        let config = WKWebViewConfiguration()
        
        // Register the custom scheme handler
        let schemeHandler = LocalVideoSchemeHandler(source: source)
        config.setURLSchemeHandler(schemeHandler, forURLScheme: "local-hls")
        
        // Initialize the WKWebView with the custom config
        webView = WKWebView(frame: frameRect.size.bounds, configuration: config)
        
        super.init(frame: frameRect)
        
        self.addSubview(webView)
        
        // Load HTML that uses the custom scheme
        let html = """
        <!DOCTYPE html>
        <html>
        <head>
         <style>
            /* Make the body and HTML take up all the available space */
            html, body {
                margin: 0;
                padding: 0;
                height: 100%;
                width: 100%;
                overflow: hidden; /* Prevent any unwanted scrolling */
            }

            /* Ensure the parent container (body) takes up the full space */
            #videoContainer {
                width: 100%;
                height: 100%;
                position: relative; /* To position video inside it */
            }

            /* Apply the aspect-fill effect using object-fit and make the video take all space */
            #videoPlayer, #videoPlaceholder {
                width: 100%;
                height: 100%;
                object-fit: cover; /* Mimic resizeAspectFill by cropping the video */
                position: absolute; /* Position it absolutely inside the container */
                top: 0;
                left: 0;
            }

            /* Initially hide the placeholder */
            #videoPlaceholder {
                display: none;
            }
        </style>
        <script type="text/javascript">
            var videoElement;
            var placeholder;

            function initPlayer() {
                videoElement = document.getElementById('videoPlayer');
                placeholder = document.getElementById('videoPlaceholder');

                videoElement.src = 'local-hls://master.m3u8';
                videoElement.play();
            }

            function setQuality(levelIndex) {
                if (videoElement) {
                    var currentTime = videoElement.currentTime;
                    var isPlaying = !videoElement.paused;

                    // Capture current frame as a data URL
                    var canvas = document.createElement('canvas');
                    canvas.width = videoElement.videoWidth;
                    canvas.height = videoElement.videoHeight;
                    var ctx = canvas.getContext('2d');
                    ctx.drawImage(videoElement, 0, 0, canvas.width, canvas.height);
                    var dataURL = canvas.toDataURL();

                    // Set the placeholder image
                    placeholder.src = dataURL;
                    placeholder.style.display = 'block';

                    // Hide the video element
                    videoElement.style.display = 'none';

                    // Change the video source
                    videoElement.src = 'local-hls://hls_level_' + levelIndex + '.m3u8';
                    videoElement.load();
                    videoElement.currentTime = currentTime;

                    videoElement.addEventListener('canplay', function onCanPlay() {
                        videoElement.removeEventListener('canplay', onCanPlay);
                        // Show the video element
                        videoElement.style.display = 'block';
                        // Hide the placeholder
                        placeholder.style.display = 'none';

                        if (isPlaying) {
                            videoElement.play();
                        }
                    });
                }
            }

            function resetQuality() {
                if (videoElement) {
                    var currentTime = videoElement.currentTime;
                    var isPlaying = !videoElement.paused;

                    // Capture current frame as a data URL
                    var canvas = document.createElement('canvas');
                    canvas.width = videoElement.videoWidth;
                    canvas.height = videoElement.videoHeight;
                    var ctx = canvas.getContext('2d');
                    ctx.drawImage(videoElement, 0, 0, canvas.width, canvas.height);
                    var dataURL = canvas.toDataURL();

                    // Set the placeholder image
                    placeholder.src = dataURL;
                    placeholder.style.display = 'block';

                    // Hide the video element
                    videoElement.style.display = 'none';

                    // Change the video source back to master playlist
                    videoElement.src = 'local-hls://master.m3u8';
                    videoElement.load();
                    videoElement.currentTime = currentTime;

                    videoElement.addEventListener('canplay', function onCanPlay() {
                        videoElement.removeEventListener('canplay', onCanPlay);
                        // Show the video element
                        videoElement.style.display = 'block';
                        // Hide the placeholder
                        placeholder.style.display = 'none';

                        if (isPlaying) {
                            videoElement.play();
                        }
                    });
                }
            }

            window.onload = function() {
                initPlayer();
            }
        </script>
        </head>
        <body>
             <div id="videoContainer">
                <video id="videoPlayer" controls autoplay type="application/x-mpegURL"></video>
                <img id="videoPlaceholder" alt="Video Placeholder" />
            </div>
        </body>
        </html>
        """
        
        webView.loadHTMLString(html, baseURL: nil)
    }
    
    private var quality: Int? = nil
    
    func updateVideoQuality(to quality: Int?) {
        if self.quality != quality {
            let jsFunction: String
            if let quality = quality {
                jsFunction = "setQuality(\(quality));"
            } else {
                jsFunction = "resetQuality();"
            }
            webView.evaluateJavaScript(jsFunction) { result, error in
                if let error = error {
                    print("Error executing JavaScript: \(error)")
                } else {
                    print("Successfully updated video quality to level \(quality ?? -1)")
                }
            }
        }
        self.quality = quality
    }
    
    override func layout() {
        super.layout()
        backgroundColor = .random
        webView.frame = bounds
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    required init(frame frameRect: NSRect) {
        fatalError("init(frame:) has not been implemented")
    }
}
