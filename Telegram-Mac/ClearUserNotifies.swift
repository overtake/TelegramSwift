//
//  ClearUserNotifies.swift
//  Telegram
//
//  Created by keepcoder on 21/03/2017.
//  Copyright © 2017 Telegram. All rights reserved.
//

import Cocoa
import TelegramCoreMac
import PostboxMac
import SwiftSignalKitMac

private let queue:Queue = Queue(name: "clearUserNotifiesQueue", target: nil)

func clearNotifies(_ peerId:PeerId, maxId:MessageId) {
    queue.async {
        let deliveredNotifications = NSUserNotificationCenter.default.deliveredNotifications
        
        for notification in deliveredNotifications {
            if let encodedMessageId = notification.userInfo?["encodedMessageId"] as? Data, let namespace = notification.userInfo?["peerId.namespace"] as? Int32, let id = notification.userInfo?["peerId.id"] as? Int32 {
                let notificationMessageId = MessageId(ReadBuffer(memoryBufferNoCopy: MemoryBuffer(data: encodedMessageId)))
                let notificationPeerId = PeerId(namespace: namespace, id: id)
                
                if notificationPeerId == peerId, notificationMessageId <= maxId {
                    NSUserNotificationCenter.default.removeDeliveredNotification(notification)
                }
                
            }
        }
    }
}
