//
//  NetworkUsageStatsController.swift
//  Telegram
//
//  Created by Mikhail Filimonov on 11/05/2018.
//  Copyright © 2018 Telegram. All rights reserved.
//

import Cocoa
import TelegramCoreMac
import SwiftSignalKitMac
import PostboxMac
import TGUIKit


private func networkUsageStatsControllerEntries(stats: NetworkUsageStats) -> [InputDataEntry] {
    var entries: [InputDataEntry] = []
    
    var sectionId: Int32 = 0
    var index: Int32 = 0
    
    entries.append(.sectionId(sectionId))
    sectionId += 1
    
    entries.append(.desc(sectionId: sectionId, index: index, text: L10n.networkUsageHeaderGeneric, color: theme.colors.grayText, detectBold: true))
    index += 1
    entries.append(.general(sectionId: sectionId, index: index, value: .none, error: nil, identifier: .init("messagesSent"), name: L10n.networkUsageBytesSent, color: theme.colors.text, icon: nil, type: .context(.prettySized(with: Int(stats.generic.wifi.outgoing + stats.generic.cellular.outgoing)))))
    index += 1
    entries.append(.general(sectionId: sectionId, index: index, value: .none, error: nil, identifier: .init("messagesReceived"), name: L10n.networkUsageBytesReceived, color: theme.colors.text, icon: nil, type: .context(.prettySized(with: Int(stats.generic.wifi.incoming + stats.generic.cellular.incoming)))))
    index += 1
    
    entries.append(.sectionId(sectionId))
    sectionId += 1
    
    entries.append(.desc(sectionId: sectionId, index: index, text: L10n.networkUsageHeaderImages, color: theme.colors.grayText, detectBold: true))
    index += 1
    entries.append(.general(sectionId: sectionId, index: index, value: .none, error: nil, identifier: .init("imagesSent"), name: L10n.networkUsageBytesSent, color: theme.colors.text, icon: nil, type: .context(.prettySized(with: Int(stats.image.wifi.outgoing + stats.image.cellular.outgoing)))))
    index += 1
    entries.append(.general(sectionId: sectionId, index: index, value: .none, error: nil, identifier: .init("imagesReceived"), name: L10n.networkUsageBytesReceived, color: theme.colors.text, icon: nil, type: .context(.prettySized(with: Int(stats.image.wifi.incoming + stats.image.cellular.incoming)))))
    index += 1
    
    entries.append(.sectionId(sectionId))
    sectionId += 1
    
    entries.append(.desc(sectionId: sectionId, index: index, text: L10n.networkUsageHeaderVideos, color: theme.colors.grayText, detectBold: true))
    index += 1
    entries.append(.general(sectionId: sectionId, index: index, value: .none, error: nil, identifier: .init("videosSent"), name: L10n.networkUsageBytesSent, color: theme.colors.text, icon: nil, type: .context(.prettySized(with: Int(stats.video.wifi.outgoing + stats.video.cellular.outgoing)))))
    index += 1
    entries.append(.general(sectionId: sectionId, index: index, value: .none, error: nil, identifier: .init("videosReceived"), name: L10n.networkUsageBytesReceived, color: theme.colors.text, icon: nil, type: .context(.prettySized(with: Int(stats.video.wifi.incoming + stats.video.cellular.incoming)))))
    index += 1
    
    entries.append(.sectionId(sectionId))
    sectionId += 1
    
    entries.append(.desc(sectionId: sectionId, index: index, text: L10n.networkUsageHeaderAudio, color: theme.colors.grayText, detectBold: true))
    index += 1
    entries.append(.general(sectionId: sectionId, index: index, value: .none, error: nil, identifier: .init("audioSent"), name: L10n.networkUsageBytesSent, color: theme.colors.text, icon: nil, type: .context(.prettySized(with: Int(stats.audio.wifi.outgoing + stats.audio.cellular.outgoing)))))
    index += 1
    entries.append(.general(sectionId: sectionId, index: index, value: .none, error: nil, identifier: .init("audioReceived"), name: L10n.networkUsageBytesReceived, color: theme.colors.text, icon: nil, type: .context(.prettySized(with: Int(stats.audio.wifi.incoming + stats.audio.cellular.incoming)))))
    index += 1
    
    entries.append(.sectionId(sectionId))
    sectionId += 1
    
    entries.append(.desc(sectionId: sectionId, index: index, text: L10n.networkUsageHeaderFiles, color: theme.colors.grayText, detectBold: true))
    index += 1
    entries.append(.general(sectionId: sectionId, index: index, value: .none, error: nil, identifier: .init("filesSent"), name: L10n.networkUsageBytesSent, color: theme.colors.text, icon: nil, type: .context(.prettySized(with: Int(stats.file.wifi.outgoing + stats.file.cellular.outgoing)))))
    index += 1
    entries.append(.general(sectionId: sectionId, index: index, value: .none, error: nil, identifier: .init("filesReceived"), name: L10n.networkUsageBytesReceived, color: theme.colors.text, icon: nil, type: .context(.prettySized(with: Int(stats.file.wifi.incoming + stats.file.cellular.incoming)))))
    index += 1
    
    entries.append(.sectionId(sectionId))
    sectionId += 1
    
    entries.append(.general(sectionId: sectionId, index: index, value: .none, error: nil, identifier: .init("reset"), name: L10n.networkUsageReset, color: theme.colors.blueUI, icon: nil, type: .none))
    index += 1
    
    if stats.resetWifiTimestamp != 0 {
        let formatter = DateFormatter()
        formatter.dateFormat = "E, d MMM yyyy HH:mm"
        let dateStringPlain = formatter.string(from: Date(timeIntervalSince1970: Double(stats.resetWifiTimestamp)))
        
        entries.append(.desc(sectionId: sectionId, index: index, text: L10n.networkUsageNetworkUsageSince(dateStringPlain), color: theme.colors.grayText, detectBold: true))
    }

    entries.append(.sectionId(sectionId))
    sectionId += 1
    
    
    return entries
}

func networkUsageStatsController(account: Account, f: @escaping((ViewController)) -> Void) -> Void {
    
    let promise: Promise<NetworkUsageStats> = Promise()
    promise.set(accountNetworkUsageStats(account: account, reset: []))
    
    f(InputDataController(dataSignal: promise.get() |> deliverOnPrepareQueue |> map {networkUsageStatsControllerEntries(stats: $0)}, title: L10n.networkUsageNetworkUsage, validateData: { data in
        if data[.init("reset")] != nil {
            let reset: ResetNetworkUsageStats = [.wifi]
            promise.set(accountNetworkUsageStats(account: account, reset: reset))
        }
        return .fail(.none)
    }, removeAfterDisappear: true, hasDone: false, identifier: "networkUsage"))
}
