//
//  ExternalVideoLoader.swift
//  TelegramMac
//
//  Created by keepcoder on 19/12/2016.
//  Copyright © 2016 Telegram. All rights reserved.
//

import Cocoa
import TelegramCoreMac
import PostboxMac
import SwiftSignalKitMac

let sharedVideoLoader:ExternalVideoLoader = {
    let shared = ExternalVideoLoader()
    return shared
}()



final class ExternalVideo : Equatable {
    let dimensions:NSSize
    let quality:NSSize
    let stream:String
    let date: TimeInterval
    fileprivate init(dimensions:NSSize, stream:String, quality:NSSize, date: TimeInterval) {
        self.dimensions = dimensions
        self.stream = stream
        self.quality = quality
        self.date = date
    }
}

func ==(lhs:ExternalVideo, rhs:ExternalVideo) -> Bool {
    return lhs.stream == rhs.stream && lhs.date == rhs.date
}

enum ExternalVideoStatus {
    case fetching
    case fail
    case loaded(ExternalVideo)
}

class WrappedExternalVideoId : Hashable {
    public let id: String
    
    public init(_ id: String) {
        self.id = id
    }
    
    public static func ==(lhs: WrappedExternalVideoId, rhs: WrappedExternalVideoId) -> Bool {
        return lhs.id == rhs.id
    }
    
    public var hashValue: Int {
        return self.id.hashValue
    }
}

private final class ExternalVideoStatusContext {
    var status: ExternalVideoStatus?
    let subscribers = Bag<(ExternalVideoStatus?) -> Void>()
}

private let youtubeName = "YouTube"
private let vimeoName = "Vimeo"

fileprivate let youtubeIcon = #imageLiteral(resourceName: "icon_YouTubePlay").precomposed()
fileprivate let vimeoIcon = #imageLiteral(resourceName: "Icon_VimeoPlay").precomposed()

class ExternalVideoLoader {
    
    private let statusQueue = Queue()
    private let concurrentQueue = Queue.concurrentDefaultQueue()
    private var statusContexts: [WrappedExternalVideoId: ExternalVideoStatusContext] = [:]
   
    private var dataContexts:[WrappedExternalVideoId: ExternalVideo] = [:]
    
    private var cancelTokensYT:[WrappedExternalVideoId: XCDYouTubeOperation] = [:]
    private var cancelTokensVimeo:[WrappedExternalVideoId: Any] = [:]
    
    static func isPlayable(_ content:TelegramMediaWebpageLoadedContent) -> Bool {
        return (content.websiteName == youtubeName || content.websiteName == vimeoName) && content.image != nil
    }
    
    static func playIcon(_ content:TelegramMediaWebpageLoadedContent) -> CGImage? {
        if content.websiteName == vimeoName  {
            return vimeoIcon
        } else if content.websiteName == youtubeName {
            return youtubeIcon
        }
        return nil
    }
    
    
    func status(for content:TelegramMediaWebpageLoadedContent) -> Signal<ExternalVideoStatus?, Void> {
        return Signal { subscriber in
            let disposable = MetaDisposable()
            self.statusQueue.async {
                
                let statusContext: ExternalVideoStatusContext
                if let current = self.statusContexts[WrappedExternalVideoId(content.displayUrl)] {
                    statusContext = current
                } else {
                    statusContext = ExternalVideoStatusContext()
                    self.statusContexts[WrappedExternalVideoId(content.displayUrl)] = statusContext
                }
                
                let index = statusContext.subscribers.add({ status in
                    subscriber.putNext(status)
                })
                
                if let status = statusContext.status {
                    subscriber.putNext(status)
                }
                
                disposable.set(ActionDisposable {
                    self.statusQueue.async {
                        if let current = self.statusContexts[WrappedExternalVideoId(content.displayUrl)] {
                            current.subscribers.remove(index)
                        }
                    }
                })
            }
            
            return disposable
        }
        
    }
    
    func fetch(for content:TelegramMediaWebpageLoadedContent) -> Signal<ExternalVideo?,Void> {
        if content.websiteName?.lowercased() == youtubeName.lowercased() {
            return fetchYoutubeContent(for: content.displayUrl)
        }
        if content.websiteName?.lowercased() == vimeoName.lowercased() {
            return fetchVimeoContent(for: content.displayUrl)
        }
        return .fail(Void())
    }
    
    private func fetchYoutubeContent(for embed:String) -> Signal<ExternalVideo?,Void> {
        return Signal { subscriber in
            
            let disposable:MetaDisposable = MetaDisposable()
            
            self.statusQueue.async {
                if let video = self.dataContexts[WrappedExternalVideoId(embed)], Date().timeIntervalSince1970 - 30 * 60 < video.date  {
                    subscriber.putNext(video)
                    subscriber.putCompletion()
                } else if let statusContext = self.statusContexts[WrappedExternalVideoId(embed)], statusContext.status != nil {
                    subscriber.putCompletion()
                } else if self.cancelTokensYT[WrappedExternalVideoId(embed)] == nil  {
                    
                    if let statusContext = self.statusContexts[WrappedExternalVideoId(embed)] {
                        statusContext.status = .fetching
                        
                        for subscriber in statusContext.subscribers.copyItems() {
                            subscriber(statusContext.status)
                        }
                    }
                    
                    self.cancelTokensYT[WrappedExternalVideoId(embed)] = XCDYouTubeClient.default().getVideoWithIdentifier(ObjcUtils.youtubeIdentifier(embed), completionHandler: { (video, error) in
                        
                        self.statusQueue.async {
                            var status:ExternalVideoStatus
                            var externalVideo:ExternalVideo?
                            if let video = video {
                                
                                var quality:NSSize? = nil
                                var stream:String? = nil
                                if let url = video.streamURLs[XCDYouTubeVideoQualityHTTPLiveStreaming] {
                                    quality = NSMakeSize(1280, 720)
                                    stream = url.absoluteString
                                } else if let url = video.streamURLs[22 as NSNumber] {
                                    quality = NSMakeSize(1280, 720)
                                    stream = url.absoluteString
                                } else if let url = video.streamURLs[18 as NSNumber] {
                                    quality = NSMakeSize(480, 360)
                                    stream = url.absoluteString
                                } else if let url = video.streamURLs[36 as NSNumber] {
                                    quality = NSMakeSize(320, 240)
                                    stream = url.absoluteString
                                }
                                if let quality = quality, let stream = stream {
                                    externalVideo = ExternalVideo(dimensions: NSMakeSize(1280, 720), stream: stream, quality: quality, date: Date().timeIntervalSince1970)
                                    self.dataContexts[WrappedExternalVideoId(embed)] = externalVideo!
                                    status = .loaded(externalVideo!)
                                } else {
                                    status = .fail
                                }
                            } else {
                                status = .fail
                            }
                            
                            if self.statusContexts[WrappedExternalVideoId(embed)] == nil {
                                self.statusContexts[WrappedExternalVideoId(embed)] = ExternalVideoStatusContext()
                            }
                            
                            if let statusContext = self.statusContexts[WrappedExternalVideoId(embed)] {
                                statusContext.status = status
                                
                                for subscriber in statusContext.subscribers.copyItems() {
                                    subscriber(status)
                                }
                            }
                            
                            subscriber.putNext(externalVideo)
                            subscriber.putCompletion()
                        }
                        
                    })
                }
                disposable.set(ActionDisposable {
                    self.statusQueue.async {
                        if let operation = self.cancelTokensYT[WrappedExternalVideoId(embed)] {
                            operation.cancel()
                            self.cancelTokensYT.removeValue(forKey: WrappedExternalVideoId(embed))
                            
                            if let statusContext = self.statusContexts[WrappedExternalVideoId(embed)], let status = statusContext.status, case .fetching = status {
                                statusContext.status = nil
                                
                                for subscriber in statusContext.subscribers.copyItems() {
                                    subscriber(statusContext.status)
                                }
                            }
                        }
                    }
                })
            }
            
            
            return disposable
        }
    }
    
    private func fetchVimeoContent(for embed:String) -> Signal<ExternalVideo?,Void> {
        return Signal { subscriber in
            
            let disposable:MetaDisposable = MetaDisposable()
            
            self.statusQueue.async {
                
                var canceled:Bool = false
                
                if let video = self.dataContexts[WrappedExternalVideoId(embed)], Date().timeIntervalSince1970 - 30 * 60 < video.date {
                    subscriber.putNext(video)
                    subscriber.putCompletion()
                } else if self.cancelTokensVimeo[WrappedExternalVideoId(embed)] == nil  {
                    
                    if let statusContext = self.statusContexts[WrappedExternalVideoId(embed)] {
                        statusContext.status = .fetching
                        
                        for subscriber in statusContext.subscribers.copyItems() {
                            subscriber(statusContext.status)
                        }
                    }
                    
                    self.cancelTokensVimeo[WrappedExternalVideoId(embed)] = 1
                    
                    YTVimeoExtractor.shared().fetchVideo(withVimeoURL: embed, withReferer: nil, completionHandler: { (video, error) in
                        if !canceled {
                            self.statusQueue.async {
                                var status:ExternalVideoStatus
                                var externalVideo:ExternalVideo?
                                if let video = video {
                                    
                                    let quality:NSSize = NSMakeSize(1280, 720)
                                    let stream:String = video.highestQualityStreamURL().absoluteString
                                   
                                    externalVideo = ExternalVideo(dimensions: NSMakeSize(1280, 720), stream: stream, quality: quality, date: Date().timeIntervalSince1970)
                                    self.dataContexts[WrappedExternalVideoId(embed)] = externalVideo!
                                    status = .loaded(externalVideo!)
                                } else {
                                    status = .fail
                                }
                                
                                if let statusContext = self.statusContexts[WrappedExternalVideoId(embed)] {
                                    statusContext.status = status
                                    
                                    for subscriber in statusContext.subscribers.copyItems() {
                                        subscriber(status)
                                    }
                                }
                                
                                subscriber.putNext(externalVideo)
                                subscriber.putCompletion()
                            }

                        }
                    })

                }
                disposable.set(ActionDisposable {
                    self.statusQueue.async {
                        if let _ = self.cancelTokensVimeo[WrappedExternalVideoId(embed)] {
                            self.cancelTokensVimeo.removeValue(forKey: WrappedExternalVideoId(embed))
                            canceled = true
                            if let statusContext = self.statusContexts[WrappedExternalVideoId(embed)], let status = statusContext.status, case .fetching = status {
                                statusContext.status = nil
                                
                                for subscriber in statusContext.subscribers.copyItems() {
                                    subscriber(statusContext.status)
                                }
                            }
                        }
                    }
                })
            }
            
            
            return disposable
        }

    }
}


