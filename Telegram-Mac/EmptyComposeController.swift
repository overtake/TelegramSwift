//
//  EmptyComposeController.swift
//  TelegramMac
//
//  Created by keepcoder on 27/11/2016.
//  Copyright © 2016 Telegram. All rights reserved.
//

import Cocoa
import TGUIKit
import SwiftSignalKitMac
import TelegramCoreMac

class ComposeState<T> {
    let result:T
    init(_ result:T) {
        self.result = result
    }
}

class EmptyComposeController<I,T,R>: TelegramGenericViewController<R> where R:NSView {
    public let onChange:Promise<T> = Promise()
    public let onComplete:Promise<T> = Promise()
    public let onCancel:Promise<Void> = Promise()
    public var previousResult:ComposeState<I>? = nil
    func restart(with result:ComposeState<I>) {
        self.previousResult = result
    }
    
}
