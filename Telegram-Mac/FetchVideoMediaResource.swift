//
//  FetchVideoMediaResource.swift
//  Telegram
//
//  Created by keepcoder on 27/04/2017.
//  Copyright © 2017 Telegram. All rights reserved.
//

import Cocoa
import TelegramCoreMac
import PostboxMac
import SwiftSignalKitMac

func fetchGifMediaResource(resource: LocalFileGifMediaResource) -> Signal<MediaResourceDataFetchResult, MediaResourceDataFetchError> {
    return Signal { subscriber in
        subscriber.putNext(.reset)
        
        let queue: Queue = Queue()
        var cancelled: Bool = false
        let exportPath = NSTemporaryDirectory() + "\(resource.randomId).mp4"
        if let data = try? Data(contentsOf: URL(fileURLWithPath: resource.path)) {
            queue.async {
                TGGifConverter.convertGif(toMp4: data, exportPath: exportPath, completionHandler: { path in
                    subscriber.putNext(.moveLocalFile(path: path))
                    subscriber.putCompletion()
                }, errorHandler: {
                    subscriber.putCompletion()
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

func fetchArchiveMediaResource(account: Account, resource: LocalFileArchiveMediaResource) -> Signal<MediaResourceDataFetchResult, MediaResourceDataFetchError> {
    return Signal { subscriber in
        subscriber.putNext(.reset)
        let source: ArchiveSource = .resource(resource)
        let disposable = account.context.archiver.archive(source, startIfNeeded: true).start(next: { status in
            switch status {
            case let .done(url):
                if resource.path.contains("tg_temp_archive_") {
                    try? FileManager.default.removeItem(atPath: resource.path)
                }
                subscriber.putNext(.moveLocalFile(path: url.path))
                subscriber.putCompletion()
                account.context.archiver.remove(source)
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
