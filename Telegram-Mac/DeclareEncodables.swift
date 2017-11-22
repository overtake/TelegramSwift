//
//  DeclareEncodables.swift
//  Telegram-Mac
//
//  Created by keepcoder on 04/11/2016.
//  Copyright © 2016 Telegram. All rights reserved.
//

import Cocoa
import PostboxMac

private var telegramUIDeclaredEncodables: Void = {
    declareEncodable(ChatInterfaceState.self, f: { ChatInterfaceState(decoder: $0) })
    declareEncodable(InAppNotificationSettings.self, f: { InAppNotificationSettings(decoder: $0) })
    declareEncodable(BaseApplicationSettings.self, f: { BaseApplicationSettings(decoder: $0) })
    declareEncodable(ThemePalleteSettings.self, f: { ThemePalleteSettings(decoder: $0) })
    declareEncodable(LocalFileGifMediaResource.self, f: { LocalFileGifMediaResource(decoder: $0) })
    declareEncodable(RecentUsedEmoji.self, f: { RecentUsedEmoji(decoder: $0) })
    declareEncodable(InstantViewAppearance.self, f: { InstantViewAppearance(decoder: $0) })
    declareEncodable(IVReadState.self, f: { IVReadState(decoder: $0) })
    declareEncodable(AdditionalSettings.self, f: { AdditionalSettings(decoder: $0) })
    return
}()

public func telegramUIDeclareEncodables() {
    let _ = telegramUIDeclaredEncodables
}
