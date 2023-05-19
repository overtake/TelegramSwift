//
//  NetworkUsageStatsController.swift
//  Telegram
//
//  Created by Mikhail Filimonov on 11/05/2018.
//  Copyright © 2018 Telegram. All rights reserved.
//

import Cocoa
import TelegramCore

import SwiftSignalKit
import Postbox
import TGUIKit


private func networkUsageStatsControllerEntries(stats: NetworkUsageStats) -> [InputDataEntry] {
    var entries: [InputDataEntry] = []
    
    var sectionId: Int32 = 0
    var index: Int32 = 0
    
    entries.append(.sectionId(sectionId, type: .normal))
    sectionId += 1
    
    entries.append(.desc(sectionId: sectionId, index: index, text: .plain(strings().networkUsageHeaderGeneric), data: InputDataGeneralTextData(viewType: .textTopItem)))
    index += 1
    entries.append(.general(sectionId: sectionId, index: index, value: .none, error: nil, identifier: .init("messagesSent"), data: InputDataGeneralData(name: strings().networkUsageBytesSent, color: theme.colors.text, icon: nil, type: .context(.prettySized(with: Int(stats.generic.wifi.outgoing + stats.generic.cellular.outgoing))), viewType: .firstItem, action: nil)))
    index += 1
    entries.append(.general(sectionId: sectionId, index: index, value: .none, error: nil, identifier: .init("messagesReceived"), data: InputDataGeneralData(name: strings().networkUsageBytesReceived, color: theme.colors.text, icon: nil, type: .context(.prettySized(with: Int(stats.generic.wifi.incoming + stats.generic.cellular.incoming))), viewType: .lastItem, action: nil)))
    index += 1
    
    entries.append(.sectionId(sectionId, type: .normal))
    sectionId += 1
    
    entries.append(.desc(sectionId: sectionId, index: index, text: .plain(strings().networkUsageHeaderImages), data: InputDataGeneralTextData(viewType: .textTopItem)))
    index += 1
    entries.append(.general(sectionId: sectionId, index: index, value: .none, error: nil, identifier: .init("imagesSent"), data: InputDataGeneralData(name: strings().networkUsageBytesSent, color: theme.colors.text, icon: nil, type: .context(.prettySized(with: Int(stats.image.wifi.outgoing + stats.image.cellular.outgoing))), viewType: .firstItem, action: nil)))
    index += 1
    entries.append(.general(sectionId: sectionId, index: index, value: .none, error: nil, identifier: .init("imagesReceived"), data: InputDataGeneralData(name: strings().networkUsageBytesReceived, color: theme.colors.text, icon: nil, type: .context(.prettySized(with: Int(stats.image.wifi.incoming + stats.image.cellular.incoming))), viewType: .lastItem, action: nil)))
    index += 1
    
    entries.append(.sectionId(sectionId, type: .normal))
    sectionId += 1
    
    entries.append(.desc(sectionId: sectionId, index: index, text: .plain(strings().networkUsageHeaderVideos), data: InputDataGeneralTextData(viewType: .textTopItem)))
    index += 1
    entries.append(.general(sectionId: sectionId, index: index, value: .none, error: nil, identifier: .init("videosSent"), data: InputDataGeneralData(name: strings().networkUsageBytesSent, color: theme.colors.text, icon: nil, type: .context(.prettySized(with: Int(stats.video.wifi.outgoing + stats.video.cellular.outgoing))), viewType: .firstItem, action: nil)))
    index += 1
    entries.append(.general(sectionId: sectionId, index: index, value: .none, error: nil, identifier: .init("videosReceived"), data: InputDataGeneralData(name: strings().networkUsageBytesReceived, color: theme.colors.text, icon: nil, type: .context(.prettySized(with: Int(stats.video.wifi.incoming + stats.video.cellular.incoming))), viewType: .lastItem, action: nil)))
    index += 1
    
    entries.append(.sectionId(sectionId, type: .normal))
    sectionId += 1
    
    entries.append(.desc(sectionId: sectionId, index: index, text: .plain(strings().networkUsageHeaderAudio), data: InputDataGeneralTextData(viewType: .textTopItem)))
    index += 1
    entries.append(.general(sectionId: sectionId, index: index, value: .none, error: nil, identifier: .init("audioSent"), data: InputDataGeneralData(name: strings().networkUsageBytesSent, color: theme.colors.text, icon: nil, type: .context(.prettySized(with: Int(stats.audio.wifi.outgoing + stats.audio.cellular.outgoing))), viewType: .firstItem, action: nil)))
    index += 1
    entries.append(.general(sectionId: sectionId, index: index, value: .none, error: nil, identifier: .init("audioReceived"), data: InputDataGeneralData(name: strings().networkUsageBytesReceived, color: theme.colors.text, icon: nil, type: .context(.prettySized(with: Int(stats.audio.wifi.incoming + stats.audio.cellular.incoming))), viewType: .lastItem, action: nil)))
    index += 1
    
    entries.append(.sectionId(sectionId, type: .normal))
    sectionId += 1
    
    entries.append(.desc(sectionId: sectionId, index: index, text: .plain(strings().networkUsageHeaderFiles), data: InputDataGeneralTextData(viewType: .textTopItem)))
    index += 1
    entries.append(.general(sectionId: sectionId, index: index, value: .none, error: nil, identifier: .init("filesSent"), data: InputDataGeneralData(name: strings().networkUsageBytesSent, color: theme.colors.text, icon: nil, type: .context(.prettySized(with: Int(stats.file.wifi.outgoing + stats.file.cellular.outgoing))), viewType: .firstItem, action: nil)))
    index += 1
    entries.append(.general(sectionId: sectionId, index: index, value: .none, error: nil, identifier: .init("filesReceived"), data: InputDataGeneralData(name: strings().networkUsageBytesReceived, color: theme.colors.text, icon: nil, type: .context(.prettySized(with: Int(stats.file.wifi.incoming + stats.file.cellular.incoming))), viewType: .lastItem, action: nil)))
    index += 1
    
    entries.append(.sectionId(sectionId, type: .normal))
    sectionId += 1
    
    entries.append(.general(sectionId: sectionId, index: index, value: .none, error: nil, identifier: .init("reset"), data: InputDataGeneralData(name: strings().networkUsageReset, color: theme.colors.accent, icon: nil, type: .none, viewType: .singleItem, action: nil)))
    index += 1
    
    if stats.resetWifiTimestamp != 0 {
        let formatter = DateFormatter()
        formatter.dateFormat = "E, d MMM yyyy HH:mm"
        let dateStringPlain = formatter.string(from: Date(timeIntervalSince1970: Double(stats.resetWifiTimestamp)))
        
        entries.append(.desc(sectionId: sectionId, index: index, text: .plain(strings().networkUsageNetworkUsageSince(dateStringPlain)), data: InputDataGeneralTextData(viewType: .textTopItem)))
    }

    entries.append(.sectionId(sectionId, type: .normal))
    sectionId += 1
    
    
    return entries
}

func networkUsageStatsController(context: AccountContext) -> ViewController {
    
    let promise: Promise<NetworkUsageStats> = Promise()
    promise.set(combineLatest(accountNetworkUsageStats(account: context.account, reset: []) |> deliverOnPrepareQueue, appearanceSignal |> deliverOnPrepareQueue) |> map {$0.0})
    
    return InputDataController(dataSignal: promise.get() |> deliverOnPrepareQueue |> map {networkUsageStatsControllerEntries(stats: $0)} |> map { InputDataSignalValue(entries: $0) }, title: strings().networkUsageNetworkUsage, validateData: { data in
        if data[.init("reset")] != nil {
            let reset: ResetNetworkUsageStats = [.wifi, .cellular]
            promise.set(accountNetworkUsageStats(account: context.account, reset: reset))
        }
        return .fail(.none)
    }, removeAfterDisappear: true, hasDone: false, identifier: "networkUsage")
}
