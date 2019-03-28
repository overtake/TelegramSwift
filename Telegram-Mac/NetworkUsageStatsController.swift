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
    
    entries.append(.desc(sectionId: sectionId, index: index, text: .plain(L10n.networkUsageHeaderGeneric), color: theme.colors.grayText, detectBold: true))
    index += 1
    entries.append(.general(sectionId: sectionId, index: index, value: .none, error: nil, identifier: .init("messagesSent"), data: InputDataGeneralData(name: L10n.networkUsageBytesSent, color: theme.colors.text, icon: nil, type: .context(.prettySized(with: Int(stats.generic.wifi.outgoing + stats.generic.cellular.outgoing))), action: nil)))
    index += 1
    entries.append(.general(sectionId: sectionId, index: index, value: .none, error: nil, identifier: .init("messagesReceived"), data: InputDataGeneralData(name: L10n.networkUsageBytesReceived, color: theme.colors.text, icon: nil, type: .context(.prettySized(with: Int(stats.generic.wifi.incoming + stats.generic.cellular.incoming))), action: nil)))
    index += 1
    
    entries.append(.sectionId(sectionId))
    sectionId += 1
    
    entries.append(.desc(sectionId: sectionId, index: index, text: .plain(L10n.networkUsageHeaderImages), color: theme.colors.grayText, detectBold: true))
    index += 1
    entries.append(.general(sectionId: sectionId, index: index, value: .none, error: nil, identifier: .init("imagesSent"), data: InputDataGeneralData(name: L10n.networkUsageBytesSent, color: theme.colors.text, icon: nil, type: .context(.prettySized(with: Int(stats.image.wifi.outgoing + stats.image.cellular.outgoing))), action: nil)))
    index += 1
    entries.append(.general(sectionId: sectionId, index: index, value: .none, error: nil, identifier: .init("imagesReceived"), data: InputDataGeneralData(name: L10n.networkUsageBytesReceived, color: theme.colors.text, icon: nil, type: .context(.prettySized(with: Int(stats.image.wifi.incoming + stats.image.cellular.incoming))), action: nil)))
    index += 1
    
    entries.append(.sectionId(sectionId))
    sectionId += 1
    
    entries.append(.desc(sectionId: sectionId, index: index, text: .plain(L10n.networkUsageHeaderVideos), color: theme.colors.grayText, detectBold: true))
    index += 1
    entries.append(.general(sectionId: sectionId, index: index, value: .none, error: nil, identifier: .init("videosSent"), data: InputDataGeneralData(name: L10n.networkUsageBytesSent, color: theme.colors.text, icon: nil, type: .context(.prettySized(with: Int(stats.video.wifi.outgoing + stats.video.cellular.outgoing))), action: nil)))
    index += 1
    entries.append(.general(sectionId: sectionId, index: index, value: .none, error: nil, identifier: .init("videosReceived"), data: InputDataGeneralData(name: L10n.networkUsageBytesReceived, color: theme.colors.text, icon: nil, type: .context(.prettySized(with: Int(stats.video.wifi.incoming + stats.video.cellular.incoming))), action: nil)))
    index += 1
    
    entries.append(.sectionId(sectionId))
    sectionId += 1
    
    entries.append(.desc(sectionId: sectionId, index: index, text: .plain(L10n.networkUsageHeaderAudio), color: theme.colors.grayText, detectBold: true))
    index += 1
    entries.append(.general(sectionId: sectionId, index: index, value: .none, error: nil, identifier: .init("audioSent"), data: InputDataGeneralData(name: L10n.networkUsageBytesSent, color: theme.colors.text, icon: nil, type: .context(.prettySized(with: Int(stats.audio.wifi.outgoing + stats.audio.cellular.outgoing))), action: nil)))
    index += 1
    entries.append(.general(sectionId: sectionId, index: index, value: .none, error: nil, identifier: .init("audioReceived"), data: InputDataGeneralData(name: L10n.networkUsageBytesReceived, color: theme.colors.text, icon: nil, type: .context(.prettySized(with: Int(stats.audio.wifi.incoming + stats.audio.cellular.incoming))), action: nil)))
    index += 1
    
    entries.append(.sectionId(sectionId))
    sectionId += 1
    
    entries.append(.desc(sectionId: sectionId, index: index, text: .plain(L10n.networkUsageHeaderFiles), color: theme.colors.grayText, detectBold: true))
    index += 1
    entries.append(.general(sectionId: sectionId, index: index, value: .none, error: nil, identifier: .init("filesSent"), data: InputDataGeneralData(name: L10n.networkUsageBytesSent, color: theme.colors.text, icon: nil, type: .context(.prettySized(with: Int(stats.file.wifi.outgoing + stats.file.cellular.outgoing))), action: nil)))
    index += 1
    entries.append(.general(sectionId: sectionId, index: index, value: .none, error: nil, identifier: .init("filesReceived"), data: InputDataGeneralData(name: L10n.networkUsageBytesReceived, color: theme.colors.text, icon: nil, type: .context(.prettySized(with: Int(stats.file.wifi.incoming + stats.file.cellular.incoming))), action: nil)))
    index += 1
    
    entries.append(.sectionId(sectionId))
    sectionId += 1
    
    entries.append(.general(sectionId: sectionId, index: index, value: .none, error: nil, identifier: .init("reset"), data: InputDataGeneralData(name: L10n.networkUsageReset, color: theme.colors.blueUI, icon: nil, type: .none, action: nil)))
    index += 1
    
    if stats.resetWifiTimestamp != 0 {
        let formatter = DateFormatter()
        formatter.dateFormat = "E, d MMM yyyy HH:mm"
        let dateStringPlain = formatter.string(from: Date(timeIntervalSince1970: Double(stats.resetWifiTimestamp)))
        
        entries.append(.desc(sectionId: sectionId, index: index, text: .plain(L10n.networkUsageNetworkUsageSince(dateStringPlain)), color: theme.colors.grayText, detectBold: true))
    }

    entries.append(.sectionId(sectionId))
    sectionId += 1
    
    
    return entries
}

func networkUsageStatsController(context: AccountContext, f: @escaping((ViewController)) -> Void) -> Void {
    
    let promise: Promise<NetworkUsageStats> = Promise()
    promise.set(combineLatest(accountNetworkUsageStats(account: context.account, reset: []) |> deliverOnPrepareQueue, appearanceSignal |> deliverOnPrepareQueue) |> map {$0.0})
    
    f(InputDataController(dataSignal: promise.get() |> deliverOnPrepareQueue |> map {networkUsageStatsControllerEntries(stats: $0)} |> map {($0, true)}, title: L10n.networkUsageNetworkUsage, validateData: { data in
        if data[.init("reset")] != nil {
            let reset: ResetNetworkUsageStats = [.wifi]
            promise.set(accountNetworkUsageStats(account: context.account, reset: reset))
        }
        return .fail(.none)
    }, removeAfterDisappear: true, hasDone: false, identifier: "networkUsage"))
}
