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

func fetchGifMediaResource(resource: LocalFileGifMediaResource) -> Signal<MediaResourceDataFetchResult, NoError> {
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
                    subscriber.putError(Void())
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
