//
//  DataAndStorageViewController.swift
//  Telegram
//
//  Created by keepcoder on 18/04/2017.
//  Copyright © 2017 Telegram. All rights reserved.
//

import Cocoa
import TGUIKit
import PostboxMac
import TelegramCoreMac
import SwiftSignalKitMac


private enum AutomaticDownloadCategory {
    case photo
    case voice
    case instantVideo
    case gif
}

private enum AutomaticDownloadPeers {
    case privateChats
    case groupsAndChannels
}

private final class DataAndStorageControllerArguments {
    let openStorageUsage: () -> Void
    let openNetworkUsage: () -> Void
    let toggleAutomaticDownload: (AutomaticDownloadCategory, AutomaticDownloadPeers, Bool) -> Void
    let openVoiceUseLessData: () -> Void
    let toggleSaveIncomingPhotos: (Bool) -> Void
    let toggleSaveEditedPhotos: (Bool) -> Void
    
    init(openStorageUsage: @escaping () -> Void, openNetworkUsage: @escaping () -> Void, toggleAutomaticDownload: @escaping (AutomaticDownloadCategory, AutomaticDownloadPeers, Bool) -> Void, openVoiceUseLessData: @escaping () -> Void, toggleSaveIncomingPhotos: @escaping (Bool) -> Void, toggleSaveEditedPhotos: @escaping (Bool) -> Void) {
        self.openStorageUsage = openStorageUsage
        self.openNetworkUsage = openNetworkUsage
        self.toggleAutomaticDownload = toggleAutomaticDownload
        self.openVoiceUseLessData = openVoiceUseLessData
        self.toggleSaveIncomingPhotos = toggleSaveIncomingPhotos
        self.toggleSaveEditedPhotos = toggleSaveEditedPhotos
    }
}

private enum DataAndStorageSection: Int32 {
    case usage
    case automaticPhotoDownload
    case automaticVoiceDownload
    case automaticInstantVideoDownload
    case voiceCalls
    case other
}

private enum DataAndStorageEntry: TableItemListNodeEntry {

    case storageUsage(Int32, String)
    case networkUsage(Int32, String)
    case automaticPhotoDownloadHeader(Int32, String)
    case automaticPhotoDownloadPrivateChats(Int32, String, Bool)
    case automaticPhotoDownloadGroupsAndChannels(Int32, String, Bool)
    case automaticVoiceDownloadHeader(Int32, String)
    case automaticVoiceDownloadPrivateChats(Int32, String, Bool)
    case automaticVoiceDownloadGroupsAndChannels(Int32, String, Bool)
    case automaticInstantVideoDownloadHeader(Int32, String)
    case automaticInstantVideoDownloadPrivateChats(Int32, String, Bool)
    case automaticInstantVideoDownloadGroupsAndChannels(Int32, String, Bool)
    case voiceCallsHeader(Int32, String)
    case useLessVoiceData(Int32, String, String)
    case otherHeader(Int32, String)
    case saveIncomingPhotos(Int32, String, Bool)
    case saveEditedPhotos(Int32, String, Bool)
    case sectionId(Int32)
    
    var stableId: Int32 {
        switch self {
        case .storageUsage:
            return 0
        case .networkUsage:
            return 1
        case .automaticPhotoDownloadHeader:
            return 2
        case .automaticPhotoDownloadPrivateChats:
            return 3
        case .automaticPhotoDownloadGroupsAndChannels:
            return 4
        case .automaticVoiceDownloadHeader:
            return 5
        case .automaticVoiceDownloadPrivateChats:
            return 6
        case .automaticVoiceDownloadGroupsAndChannels:
            return 7
        case .automaticInstantVideoDownloadHeader:
            return 8
        case .automaticInstantVideoDownloadPrivateChats:
            return 9
        case .automaticInstantVideoDownloadGroupsAndChannels:
            return 10
        case .voiceCallsHeader:
            return 11
        case .useLessVoiceData:
            return 12
        case .otherHeader:
            return 13
        case .saveIncomingPhotos:
            return 14
        case .saveEditedPhotos:
            return 15
        case let .sectionId(sectionId):
            return (sectionId + 1) * 1000 - sectionId
        }
    }
    
    var index:Int32 {
        switch self {
        case .storageUsage(let sectionId, _):
            return (sectionId * 1000) + stableId
        case .networkUsage(let sectionId, _):
            return (sectionId * 1000) + stableId
        case .automaticPhotoDownloadHeader(let sectionId, _):
            return (sectionId * 1000) + stableId
        case .automaticPhotoDownloadPrivateChats(let sectionId, _, _):
            return (sectionId * 1000) + stableId
        case .automaticPhotoDownloadGroupsAndChannels(let sectionId, _, _):
            return (sectionId * 1000) + stableId
        case .automaticVoiceDownloadHeader(let sectionId, _):
            return (sectionId * 1000) + stableId
        case .automaticVoiceDownloadPrivateChats(let sectionId, _, _):
            return (sectionId * 1000) + stableId
        case .automaticVoiceDownloadGroupsAndChannels(let sectionId, _, _):
            return (sectionId * 1000) + stableId
        case .automaticInstantVideoDownloadHeader(let sectionId, _):
            return (sectionId * 1000) + stableId
        case .automaticInstantVideoDownloadPrivateChats(let sectionId, _, _):
            return (sectionId * 1000) + stableId
        case .automaticInstantVideoDownloadGroupsAndChannels(let sectionId, _, _):
            return (sectionId * 1000) + stableId
        case .voiceCallsHeader(let sectionId, _):
            return (sectionId * 1000) + stableId
        case .useLessVoiceData(let sectionId, _, _):
            return (sectionId * 1000) + stableId
        case .otherHeader(let sectionId, _):
            return (sectionId * 1000) + stableId
        case .saveIncomingPhotos(let sectionId, _, _):
            return (sectionId * 1000) + stableId
        case .saveEditedPhotos(let sectionId, _, _):
            return (sectionId * 1000) + stableId
        case .sectionId(let sectionId):
            return (sectionId + 1) * 1000 - sectionId
        }
    }
    
    static func ==(lhs: DataAndStorageEntry, rhs: DataAndStorageEntry) -> Bool {
        switch lhs {
        case let .storageUsage(sectionId, text):
            if case .storageUsage(sectionId, text) = rhs {
                return true
            } else {
                return false
            }
        case let .networkUsage(sectionId, text):
            if case .networkUsage(sectionId, text) = rhs {
                return true
            } else {
                return false
            }
        case let .automaticPhotoDownloadHeader(sectionId, text):
            if case .automaticPhotoDownloadHeader(sectionId, text) = rhs {
                return true
            } else {
                return false
            }
        case let .automaticPhotoDownloadPrivateChats(sectionId, text, value):
            if case .automaticPhotoDownloadPrivateChats(sectionId, text, value) = rhs {
                return true
            } else {
                return false
            }
        case let .automaticPhotoDownloadGroupsAndChannels(sectionId, text, value):
            if case .automaticPhotoDownloadGroupsAndChannels(sectionId, text, value) = rhs {
                return true
            } else {
                return false
            }
        case let .automaticVoiceDownloadHeader(sectionId, text):
            if case .automaticVoiceDownloadHeader(sectionId, text) = rhs {
                return true
            } else {
                return false
            }
        case let .automaticVoiceDownloadPrivateChats(sectionId, text, value):
            if case .automaticVoiceDownloadPrivateChats(sectionId, text, value) = rhs {
                return true
            } else {
                return false
            }
        case let .automaticVoiceDownloadGroupsAndChannels(sectionId, text, value):
            if case .automaticVoiceDownloadGroupsAndChannels(sectionId, text, value) = rhs {
                return true
            } else {
                return false
            }
        case let .automaticInstantVideoDownloadHeader(sectionId, text):
            if case .automaticInstantVideoDownloadHeader(sectionId, text) = rhs {
                return true
            } else {
                return false
            }
        case let .automaticInstantVideoDownloadPrivateChats(sectionId, text, value):
            if case .automaticInstantVideoDownloadPrivateChats(sectionId, text, value) = rhs {
                return true
            } else {
                return false
            }
        case let .automaticInstantVideoDownloadGroupsAndChannels(sectionId, text, value):
            if case .automaticInstantVideoDownloadGroupsAndChannels(sectionId, text, value) = rhs {
                return true
            } else {
                return false
            }
        case let .voiceCallsHeader(sectionId, text):
            if case .voiceCallsHeader(sectionId, text) = rhs {
                return true
            } else {
                return false
            }
        case let .useLessVoiceData(sectionId, text, value):
            if case .useLessVoiceData(sectionId, text, value) = rhs {
                return true
            } else {
                return false
            }
        case let .otherHeader(sectionId, text):
            if case .otherHeader(sectionId, text) = rhs {
                return true
            } else {
                return false
            }
        case let .saveIncomingPhotos(sectionId, text, value):
            if case .saveIncomingPhotos(sectionId, text, value) = rhs {
                return true
            } else {
                return false
            }
        case let .saveEditedPhotos(sectionId, text, value):
            if case .saveEditedPhotos(sectionId, text, value) = rhs {
                return true
            } else {
                return false
            }
        case let .sectionId(sectionId):
            if case .sectionId(sectionId) = rhs {
                return true
            } else {
                return false
            }
        }
    }
    
    static func <(lhs: DataAndStorageEntry, rhs: DataAndStorageEntry) -> Bool {
        return lhs.index < rhs.index
    }
    
    func item(_ arguments: DataAndStorageControllerArguments, initialSize: NSSize) -> TableRowItem {
        switch self {
        case let .storageUsage(_, text):
            return GeneralInteractedRowItem(initialSize, stableId: stableId, name: text, type: .next, action: {
                arguments.openStorageUsage()
            })
        case let .networkUsage(_, text):
            return GeneralInteractedRowItem(initialSize, stableId: stableId, name: text, type: .next, action: {
                arguments.openNetworkUsage()
            })
        case let .automaticPhotoDownloadHeader(_, text):
            return GeneralTextRowItem(initialSize, stableId: stableId, text: text)
        case let .automaticPhotoDownloadPrivateChats(_, text, value):
            return GeneralInteractedRowItem(initialSize, stableId: stableId, name: text, type: .switchable(stateback: {
                return value
            }), action: {
                arguments.toggleAutomaticDownload(.photo, .privateChats, value)
            })
        case let .automaticPhotoDownloadGroupsAndChannels(_, text, value):
            return GeneralInteractedRowItem(initialSize, stableId: stableId, name: text, type: .switchable(stateback: {
                return value
            }), action: {
                arguments.toggleAutomaticDownload(.photo, .groupsAndChannels, value)
            })
        case let .automaticVoiceDownloadHeader(_, text):
            return GeneralTextRowItem(initialSize, stableId: stableId, text: text)
        case let .automaticVoiceDownloadPrivateChats(_, text, value):
            return GeneralInteractedRowItem(initialSize, stableId: stableId, name: text, type: .switchable(stateback: {
                return value
            }), action: {
                arguments.toggleAutomaticDownload(.voice, .privateChats, value)
            })
        case let .automaticVoiceDownloadGroupsAndChannels(_, text, value):
            return GeneralInteractedRowItem(initialSize, stableId: stableId, name: text, type: .switchable(stateback: {
                return value
            }), action: {
                arguments.toggleAutomaticDownload(.voice, .groupsAndChannels, value)
            })
        case let .automaticInstantVideoDownloadHeader(_, text):
            return GeneralTextRowItem(initialSize, stableId: stableId, text: text)
        case let .automaticInstantVideoDownloadPrivateChats(_, text, value):
            return GeneralInteractedRowItem(initialSize, stableId: stableId, name: text, type: .switchable(stateback: {
                return value
            }), action: {
                arguments.toggleAutomaticDownload(.instantVideo, .privateChats, value)
            })
        case let .automaticInstantVideoDownloadGroupsAndChannels(_, text, value):
            return GeneralInteractedRowItem(initialSize, stableId: stableId, name: text, type: .switchable(stateback: {
                return value
            }), action: {
                arguments.toggleAutomaticDownload(.instantVideo, .groupsAndChannels, value)
            })
        case let .voiceCallsHeader(_, text):
            return GeneralTextRowItem(initialSize, stableId: stableId, text: text)
        case let .useLessVoiceData(_, text, value):
            return GeneralInteractedRowItem(initialSize, stableId: stableId, name: text, type: .context(stateback: {
                return value
            }), action: {
                arguments.openVoiceUseLessData()
            })
        case let .otherHeader(_, text):
            return GeneralTextRowItem(initialSize, stableId: stableId, text: text)
        default:
            return GeneralRowItem(initialSize, height: 20, stableId: stableId)
        }
    }
}

private struct DataAndStorageControllerState: Equatable {
    static func ==(lhs: DataAndStorageControllerState, rhs: DataAndStorageControllerState) -> Bool {
        return true
    }
}

private struct DataAndStorageData: Equatable {
    let automaticMediaDownloadSettings: AutomaticMediaDownloadSettings
    let generatedMediaStoreSettings: GeneratedMediaStoreSettings
    let voiceCallSettings: VoiceCallSettings
    
    init(automaticMediaDownloadSettings: AutomaticMediaDownloadSettings, generatedMediaStoreSettings: GeneratedMediaStoreSettings, voiceCallSettings: VoiceCallSettings) {
        self.automaticMediaDownloadSettings = automaticMediaDownloadSettings
        self.generatedMediaStoreSettings = generatedMediaStoreSettings
        self.voiceCallSettings = voiceCallSettings
    }
    
    static func ==(lhs: DataAndStorageData, rhs: DataAndStorageData) -> Bool {
        return lhs.automaticMediaDownloadSettings == rhs.automaticMediaDownloadSettings && lhs.generatedMediaStoreSettings == rhs.generatedMediaStoreSettings && lhs.voiceCallSettings == rhs.voiceCallSettings
    }
}


private func dataAndStorageControllerEntries(state: DataAndStorageControllerState, data: DataAndStorageData) -> [DataAndStorageEntry] {
    var entries: [DataAndStorageEntry] = []
    
    var sectionId:Int32 = 1
    entries.append(.sectionId(sectionId))
    sectionId += 1
    
    entries.append(.storageUsage(sectionId, tr(L10n.dataAndStorageStorageUsage)))
 //   entries.append(.networkUsage(sectionId, tr(L10n.dataAndStorageNetworkUsage)))
    
    entries.append(.sectionId(sectionId))
    sectionId += 1


    entries.append(.automaticPhotoDownloadHeader(sectionId, tr(L10n.dataAndStorageAutomaticPhotoDownloadHeader)))
  //  entries.append(.automaticPhotoDownloadPrivateChats(sectionId, tr(L10n.dataAndStorageAutomaticDownloadPrivateChats), data.automaticMediaDownloadSettings.categories.photo.privateChats))
    entries.append(.automaticPhotoDownloadGroupsAndChannels(sectionId, tr(L10n.dataAndStorageAutomaticDownloadGroupsChannels), data.automaticMediaDownloadSettings.categories.photo.groupsAndChannels))
    
    entries.append(.sectionId(sectionId))
    sectionId += 1
    
    entries.append(.automaticVoiceDownloadHeader(sectionId, tr(L10n.dataAndStorageAutomaticAudioDownloadHeader)))
   // entries.append(.automaticVoiceDownloadPrivateChats(sectionId, tr(L10n.dataAndStorageAutomaticDownloadPrivateChats), data.automaticMediaDownloadSettings.categories.voice.privateChats))
    entries.append(.automaticVoiceDownloadGroupsAndChannels(sectionId, tr(L10n.dataAndStorageAutomaticDownloadGroupsChannels), data.automaticMediaDownloadSettings.categories.voice.groupsAndChannels))
    
    entries.append(.sectionId(sectionId))
    sectionId += 1
    
    entries.append(.automaticInstantVideoDownloadHeader(sectionId, tr(L10n.dataAndStorageAutomaticVideoDownloadHeader)))
   // entries.append(.automaticInstantVideoDownloadPrivateChats(sectionId, tr(L10n.dataAndStorageAutomaticDownloadPrivateChats), data.automaticMediaDownloadSettings.categories.instantVideo.privateChats))
    entries.append(.automaticInstantVideoDownloadGroupsAndChannels(sectionId, tr(L10n.dataAndStorageAutomaticDownloadGroupsChannels), data.automaticMediaDownloadSettings.categories.instantVideo.groupsAndChannels))
    
   // entries.append(.sectionId(sectionId))
   // sectionId += 1
    
   // entries.append(.voiceCallsHeader(sectionId, tr(L10n.dataAndStorageVoiceCallsHeader)))
   // entries.append(.useLessVoiceData(sectionId, tr(L10n.dataAndStorageVoiceCallsLessData), stringForUseLessDataSetting(data.voiceCallSettings)))
    
  
    
    return entries
}

private func stringForUseLessDataSetting(_ settings: VoiceCallSettings) -> String {
    switch settings.dataSaving {
    case .never:
        return "Never"
    case .cellular:
        return "On Mobile Network"
    case .always:
        return "Always"
    }
}

private func prepareTransition(left:[AppearanceWrapperEntry<DataAndStorageEntry>], right: [AppearanceWrapperEntry<DataAndStorageEntry>], initialSize: NSSize, arguments: DataAndStorageControllerArguments) -> TableUpdateTransition {
    let (removed, inserted, updated) = proccessEntriesWithoutReverse(left, right: right) { entry -> TableRowItem in
        return entry.entry.item(arguments, initialSize: initialSize)
    }
    return TableUpdateTransition(deleted: removed, inserted: inserted, updated: updated, animated: true)
}

class DataAndStorageViewController: TableViewController {

    override func viewDidLoad() {
        super.viewDidLoad()
        
        readyOnce()
        
        let account = self.account
        let initialState = DataAndStorageControllerState()
        let initialSize = self.atomicSize
        let statePromise = ValuePromise(initialState, ignoreRepeated: true)
        let stateValue = Atomic(value: initialState)
        let updateState: ((DataAndStorageControllerState) -> DataAndStorageControllerState) -> Void = { f in
            statePromise.set(stateValue.modify { f($0) })
        }
        
        let pushControllerImpl = { [weak self] controller in
            self?.navigationController?.push(controller)
        }
        
        let previous:Atomic<[AppearanceWrapperEntry<DataAndStorageEntry>]> = Atomic(value: [])
        let actionsDisposable = DisposableSet()
        
        let dataAndStorageDataPromise = Promise<DataAndStorageData>()
        dataAndStorageDataPromise.set(account.postbox.preferencesView(keys: [ApplicationSpecificPreferencesKeys.automaticMediaDownloadSettings, ApplicationSpecificPreferencesKeys.generatedMediaStoreSettings, ApplicationSpecificPreferencesKeys.voiceCallSettings])
            |> map { view -> DataAndStorageData in
                let automaticMediaDownloadSettings: AutomaticMediaDownloadSettings
                if let value = view.values[ApplicationSpecificPreferencesKeys.automaticMediaDownloadSettings] as? AutomaticMediaDownloadSettings {
                    automaticMediaDownloadSettings = value
                } else {
                    automaticMediaDownloadSettings = AutomaticMediaDownloadSettings.defaultSettings
                }
                
                let generatedMediaStoreSettings: GeneratedMediaStoreSettings
                if let value = view.values[ApplicationSpecificPreferencesKeys.generatedMediaStoreSettings] as? GeneratedMediaStoreSettings {
                    generatedMediaStoreSettings = value
                } else {
                    generatedMediaStoreSettings = GeneratedMediaStoreSettings.defaultSettings
                }
                
                let voiceCallSettings: VoiceCallSettings
                if let value = view.values[ApplicationSpecificPreferencesKeys.voiceCallSettings] as? VoiceCallSettings {
                    voiceCallSettings = value
                } else {
                    voiceCallSettings = VoiceCallSettings.defaultSettings
                }
                
                return DataAndStorageData(automaticMediaDownloadSettings: automaticMediaDownloadSettings, generatedMediaStoreSettings: generatedMediaStoreSettings, voiceCallSettings: voiceCallSettings)
            })
        
        let arguments = DataAndStorageControllerArguments(openStorageUsage: { [weak self] in
            pushControllerImpl(StorageUsageController(account))
        }, openNetworkUsage: {
           // pushControllerImpl?(networkUsageStatsController(account: account))
        }, toggleAutomaticDownload: { category, peers, value in
            let _ = updateMediaDownloadSettingsInteractively(postbox: account.postbox, { current in
                switch category {
                case .photo:
                    switch peers {
                    case .privateChats:
                        return current.withUpdatedCategories(current.categories.withUpdatedPhoto(current.categories.photo.withUpdatedPrivateChats(value)))
                    case .groupsAndChannels:
                        return current.withUpdatedCategories(current.categories.withUpdatedPhoto(current.categories.photo.withUpdatedGroupsAndChannels(value)))
                    }
                case .voice:
                    switch peers {
                    case .privateChats:
                        return current.withUpdatedCategories(current.categories.withUpdatedVoice(current.categories.voice.withUpdatedPrivateChats(value)))
                    case .groupsAndChannels:
                        return current.withUpdatedCategories(current.categories.withUpdatedVoice(current.categories.voice.withUpdatedGroupsAndChannels(value)))
                    }
                case .instantVideo:
                    switch peers {
                    case .privateChats:
                        return current.withUpdatedCategories(current.categories.withUpdatedInstantVideo(current.categories.instantVideo.withUpdatedPrivateChats(value)))
                    case .groupsAndChannels:
                        return current.withUpdatedCategories(current.categories.withUpdatedInstantVideo(current.categories.instantVideo.withUpdatedGroupsAndChannels(value)))
                    }
                case .gif:
                    switch peers {
                    case .privateChats:
                        return current.withUpdatedCategories(current.categories.withUpdatedGif(current.categories.gif.withUpdatedPrivateChats(value)))
                    case .groupsAndChannels:
                        return current.withUpdatedCategories(current.categories.withUpdatedGif(current.categories.gif.withUpdatedGroupsAndChannels(value)))
                    }
                }
            }).start()
        }, openVoiceUseLessData: {
           // pushControllerImpl?(voiceCallDataSavingController(account: account))
        }, toggleSaveIncomingPhotos: { value in
            let _ = updateMediaDownloadSettingsInteractively(postbox: account.postbox, { current in
                return current.withUpdatedSaveIncomingPhotos(value)
            }).start()
        }, toggleSaveEditedPhotos: { value in
            let _ = updateGeneratedMediaStoreSettingsInteractively(postbox: account.postbox, { current in
                return current.withUpdatedStoreEditedPhotos(value)
            }).start()
        })
        
        self.genericView.merge(with: combineLatest(statePromise.get(), dataAndStorageDataPromise.get(), appearanceSignal) |> deliverOnMainQueue
            |> map { state, dataAndStorageData, appearance -> TableUpdateTransition in
                
                let entries = dataAndStorageControllerEntries(state: state, data: dataAndStorageData).map {AppearanceWrapperEntry(entry: $0, appearance: appearance)}
                return prepareTransition(left: previous.swap(entries), right: entries, initialSize: initialSize.modify({$0}), arguments: arguments)

            } |> afterDisposed {
                actionsDisposable.dispose()
        })
        
    }
    
    override func getRightBarViewOnce() -> BarView {
        return BarView(20, controller: self)
    }

}
