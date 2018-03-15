//
//  PreUploadManager.swift
//  Telegram
//
//  Created by Mikhail Filimonov on 08/03/2018.
//  Copyright © 2018 Telegram. All rights reserved.
//

import Cocoa
import TelegramCoreMac
import PostboxMac
import SwiftSignalKitMac

class PreUploadManager {
    let path: String
    let id: Int64
    private var previousSize: Int? = nil
    private let resource:Promise<MediaResourceData> = Promise()
    private let queue: Queue = Queue()
    init(_ path: String, account: Account, id: Int64) {
        self.path = path
        self.id = id
        account.messageMediaPreuploadManager.add(network: account.network, postbox: account.postbox, id: id, encrypt: false, tag: nil, source: resource.get())
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
