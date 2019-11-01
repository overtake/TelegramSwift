//
//  FetchVideoMediaResource.swift
//  Telegram
//
//  Created by keepcoder on 27/04/2017.
//  Copyright © 2017 Telegram. All rights reserved.
//

import Cocoa
import TelegramCore
import SyncCore
import Postbox
import SwiftSignalKit

func fetchGifMediaResource(resource: LocalFileGifMediaResource) -> Signal<MediaResourceDataFetchResult, MediaResourceDataFetchError> {
    return Signal { subscriber in
        subscriber.putNext(.reset)
        
        let queue: Queue = Queue()
        var cancelled: Bool = false
        let exportPath = NSTemporaryDirectory() + "\(resource.randomId).mp4"
        if let data = try? Data(contentsOf: URL(fileURLWithPath: resource.path)) {
            queue.async {
                TGGifConverter.convertGif(toMp4: data, exportPath: exportPath, completionHandler: { path in
                    let remuxedPath = NSTemporaryDirectory() + "\(arc4random()).mp4"
//                    let remuxed = FFMpegRemuxer.remux(path, to: remuxedPath)
//                    if remuxed {
//                        try? FileManager.default.removeItem(atPath: path)
//                        try? FileManager.default.moveItem(atPath: remuxedPath, toPath: path)
//                    }
                    subscriber.putNext(.moveLocalFile(path: path))
                    subscriber.putCompletion()
                }, errorHandler: {
                    subscriber.putError(.generic)
                }, cancelHandler: { () -> Bool in
                    return cancelled
                })
            }
        }
        
        return ActionDisposable {
            cancelled = true
        }
    }
}


func fetchMovMediaResource(resource: LocalFileVideoMediaResource) -> Signal<MediaResourceDataFetchResult, MediaResourceDataFetchError> {
    return Signal { subscriber in
        subscriber.putNext(.reset)
        
        
        
//        var cancelled: Bool = false
//        let queue: Queue = Queue()
//
//        let avAsset = AVURLAsset(url: URL(fileURLWithPath: resource.path))
        
        let exportPath = NSTemporaryDirectory() + "\(resource.randomId).mp4"

        
        if FileManager.default.fileExists(atPath: exportPath) {
            removeFile(at: exportPath)
        }
        
        try? FileManager.default.copyItem(atPath: resource.path, toPath: exportPath)

        subscriber.putNext(.moveLocalFile(path: exportPath))

        subscriber.putCompletion()
        
//        var timer: SwiftSignalKit.Timer?
//
//        let exportSession = AVAssetExportSession(asset: avAsset, presetName: AVAssetExportPreset1280x720)
//        if let exportSession = exportSession {
//
//            exportSession.outputURL = URL(fileURLWithPath: exportPath)
//            exportSession.outputFileType = .mp4
//            exportSession.canPerformMultiplePassesOverSourceMediaData = true
//            exportSession.shouldOptimizeForNetworkUse = true
//            let start = CMTimeMakeWithSeconds(0.0, preferredTimescale: 0)
//            let range = CMTimeRangeMake(start: start, duration: avAsset.duration)
//            exportSession.timeRange = range
//
//            exportSession.exportAsynchronously {
//                if cancelled {
//                    subscriber.putCompletion()
//                    exportSession.cancelExport()
//                    return
//                }
//                switch exportSession.status {
//                case .failed:
//                    timer?.invalidate()
//                    subscriber.putError(.generic)
//                case .cancelled:
//                    timer?.invalidate()
//                    subscriber.putCompletion()
//                case .completed:
//                    //let remuxedPath = NSTemporaryDirectory() + "\(arc4random()).mp4"
////                    let remuxed = FFMpegRemuxer.remux(exportPath, to: remuxedPath)
////                    if remuxed {
////                        try? FileManager.default.removeItem(atPath: exportPath)
////                        try? FileManager.default.moveItem(atPath: remuxedPath, toPath: exportPath)
////                    }
//                    subscriber.putNext(.moveLocalFile(path: exportPath))
//                    timer?.invalidate()
//                    subscriber.putCompletion()
//                case .exporting:
//                    break
//                default:
//                    break
//                }
//            }
//
//            timer = SwiftSignalKit.Timer(timeout: 0.05, repeat: true, completion: {
//                subscriber.putNext(.progressUpdated(exportSession.progress))
//            }, queue: queue)
//
//            timer?.start()
//        }
        
        
        
        return ActionDisposable {
//            cancelled = true
//            exportSession?.cancelExport()
//            timer?.invalidate()
        }
    }
}

func fetchArchiveMediaResource(account: Account, resource: LocalFileArchiveMediaResource) -> Signal<MediaResourceDataFetchResult, MediaResourceDataFetchError> {
    return Signal { subscriber in
        subscriber.putNext(.reset)
        let source: ArchiveSource = .resource(resource)
        let disposable = archiver.archive(source, startIfNeeded: true).start(next: { status in
            switch status {
            case let .done(url):
                if resource.path.contains("tg_temp_archive_") {
                    try? FileManager.default.removeItem(atPath: resource.path)
                }
                subscriber.putNext(.moveLocalFile(path: url.path))
                subscriber.putCompletion()
                archiver.remove(source)
            case .fail:
                subscriber.putError(.generic)
                subscriber.putCompletion()
            default:
                break
            }
        }, error: { error in
            subscriber.putError(.generic)
        }, completed: {
            subscriber.putCompletion()
        })
        
        return ActionDisposable {
            disposable.dispose()
        }
    }
}
