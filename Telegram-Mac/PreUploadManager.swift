//
//  PreUploadManager.swift
//  Telegram
//
//  Created by Mikhail Filimonov on 08/03/2018.
//  Copyright © 2018 Telegram. All rights reserved.
//

import Cocoa
import TelegramCore

import Postbox
import SwiftSignalKit

class PreUploadManager {
    let path: String
    let id: Int64
    private var previousSize: Int64? = nil
    private let resource:Promise<MediaResourceData> = Promise()
    private let queue: Queue = Queue()
    init(_ path: String, context: AccountContext, id: Int64) {
        self.path = path
        self.id = id
        
        context.engine.resources.preUpload(id: id, encrypt: false, tag: nil, source: resource.get(), onComplete: {
            unlink(path)
        })
    }
    
    
    func fileDidChangedSize(_ complete: Bool) {
        self.queue.async {
            if let size = fileSize(self.path), self.previousSize != size || complete {
                self.previousSize = size
                self.resource.set(.single(MediaResourceData(path: self.path, offset: 0, size: size, complete: complete)))
            }
        }
    }
    
    
}
