//
//  UNUserNotifications.swift
//  Telegram
//
//  Created by Mikhail Filimonov on 17.08.2021.
//  Copyright © 2021 Telegram. All rights reserved.
//

import Foundation
import UserNotifications
import SwiftSignalKit

final class UNUserNotifications {
    
    enum AuthorizationStatus : Int {
        case notDetermined = 0
        case denied = 1
        case authorized = 2
        case provisional = 3
    }
    
    init() {
        
    }
    
    static func recurrentAuthorizationStatus(_ context: AccountContext) -> Signal<AuthorizationStatus, NoError> {
        return context.window.keyWindowUpdater |> mapToSignal { _ in
            return (authorizationStatus |> then(.complete() |> suspendAwareDelay(1 * 60.0, queue: Queue.concurrentDefaultQueue()))) |> restart
        }
    }
    
    static var authorizationStatus: Signal<AuthorizationStatus, NoError> {
        return Signal { subscriber in
            if #available(macOS 10.14, *) {
                
                subscriber.putNext(.authorized)
                subscriber.putCompletion()
                
//                UNUserNotificationCenter.current().getNotificationSettings { settings in
//                    if let value = AuthorizationStatus(rawValue: settings.authorizationStatus.rawValue) {
//                        subscriber.putNext(value)
//                        subscriber.putCompletion()
//                    }
//                }
            } else {
                subscriber.putNext(.authorized)
                subscriber.putCompletion()
            }
            return EmptyDisposable
        }
    }
}
