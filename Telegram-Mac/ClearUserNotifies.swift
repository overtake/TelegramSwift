//
//  ClearUserNotifies.swift
//  Telegram
//
//  Created by keepcoder on 21/03/2017.
//  Copyright © 2017 Telegram. All rights reserved.
//

import Cocoa
import TelegramCore
import SyncCore
import Postbox
import SwiftSignalKit

private let queue:Queue = Queue(name: "clearUserNotifiesQueue")

func clearNotifies(_ peerId:PeerId, maxId:MessageId) {
    Queue.concurrentDefaultQueue().async {
        let deliveredNotifications = NSUserNotificationCenter.default.deliveredNotifications
        
        
        
        for notification in deliveredNotifications {
            if let msgId = notification.userInfo?["message.id"] as? Int32, let msgNamespace = notification.userInfo?["message.namespace"] as? Int32, let namespace = notification.userInfo?["peer.namespace"] as? Int32, let id = notification.userInfo?["peer.id"] as? Int32 {
                
                let timestamp = notification.userInfo?["timestamp"] as? Int32 ?? 0
                
                let notificationPeerId = PeerId(namespace: namespace, id: id)

                let notificationMessageId = MessageId(peerId: notificationPeerId, namespace: msgNamespace, id: msgId)
                
                if notificationPeerId == peerId, notificationMessageId <= maxId {
                    NSUserNotificationCenter.default.removeDeliveredNotification(notification)
                } else if timestamp == 0 || timestamp + 24 * 60 * 60 < Int32(Date().timeIntervalSince1970) {
                    NSUserNotificationCenter.default.removeDeliveredNotification(notification)
                }
                
            }
        }
    }
}


func clearNotifies(by msgIds: [MessageId]) {
    queue.async {
        let deliveredNotifications = NSUserNotificationCenter.default.deliveredNotifications
        
        for notification in deliveredNotifications {
            if let msgId = notification.userInfo?["message.id"] as? Int32, let msgNamespace = notification.userInfo?["message.namespace"] as? Int32, let namespace = notification.userInfo?["peer.namespace"] as? Int32, let id = notification.userInfo?["peer.id"] as? Int32 {
                
                let notificationPeerId = PeerId(namespace: namespace, id: id)
                
                let notificationMessageId = MessageId(peerId: notificationPeerId, namespace: msgNamespace, id: msgId)
                
                for msgId in msgIds {
                    if notificationMessageId == msgId {
                        NSUserNotificationCenter.default.removeDeliveredNotification(notification)
                    }
                }
            }
        }
    }
}
