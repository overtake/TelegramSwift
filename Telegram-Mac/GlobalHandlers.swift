//
//  GlobalHandlers.swift
//  Telegram-Mac
//
//  Created by keepcoder on 16/10/2016.
//  Copyright © 2016 Telegram. All rights reserved.
//

import Cocoa
import SwiftSignalKitMac
import PostboxMac
import TelegramCoreMac

public let globalPeerHandler:Promise<ChatLocation?> = Promise()
