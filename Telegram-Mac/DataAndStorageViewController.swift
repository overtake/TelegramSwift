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
    let openCategorySettings: (AutomaticMediaDownloadCategoryPeers, String) -> Void
    let toggleAutomaticDownload:(Bool) -> Void
    let resetDownloadSettings:()->Void
    let selectDownloadFolder: ()->Void
    let toggleAutomaticCopyToDownload:(Bool)->Void
    init(openStorageUsage: @escaping () -> Void, openNetworkUsage: @escaping () -> Void, openCategorySettings: @escaping(AutomaticMediaDownloadCategoryPeers, String) -> Void, toggleAutomaticDownload:@escaping(Bool) -> Void, resetDownloadSettings:@escaping()->Void, selectDownloadFolder: @escaping() -> Void, toggleAutomaticCopyToDownload:@escaping(Bool)->Void) {
        self.openStorageUsage = openStorageUsage
        self.openNetworkUsage = openNetworkUsage
        self.openCategorySettings = openCategorySettings
        self.toggleAutomaticDownload = toggleAutomaticDownload
        self.resetDownloadSettings = resetDownloadSettings
        self.selectDownloadFolder = selectDownloadFolder
        self.toggleAutomaticCopyToDownload = toggleAutomaticCopyToDownload
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
    case automaticMediaDownloadHeader(Int32, String)
    case automaticDownloadMedia(Int32, Bool)
    case photos(Int32, AutomaticMediaDownloadCategoryPeers, Bool)
    case videos(Int32, AutomaticMediaDownloadCategoryPeers, Bool)
    case files(Int32, AutomaticMediaDownloadCategoryPeers, Bool)
    case voice(Int32, AutomaticMediaDownloadCategoryPeers, Bool)
    case instantVideo(Int32, AutomaticMediaDownloadCategoryPeers, Bool)
    case gifs(Int32, AutomaticMediaDownloadCategoryPeers, Bool)
    case resetDownloadSettings(Int32, Bool)
    case downloadFolder(Int32, String)
    case automaticCopyToDownload(Int32, Bool)
    case sectionId(Int32)
    
    var stableId: Int32 {
        switch self {
        case .storageUsage:
            return 0
        case .networkUsage:
            return 1
        case .automaticMediaDownloadHeader:
            return 2
        case .automaticDownloadMedia:
            return 3
        case .photos:
            return 4
        case .videos:
            return 5
        case .files:
            return 6
        case .voice:
            return 7
        case .instantVideo:
            return 8
        case .gifs:
            return 9
        case .resetDownloadSettings:
            return 10
        case .downloadFolder:
            return 11
        case .automaticCopyToDownload:
            return 12
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
        case .automaticMediaDownloadHeader(let sectionId, _):
            return (sectionId * 1000) + stableId
        case .automaticDownloadMedia(let sectionId, _):
            return (sectionId * 1000) + stableId
        case let .photos(sectionId, _, _):
            return (sectionId * 1000) + stableId
        case let .videos(sectionId, _, _):
            return (sectionId * 1000) + stableId
        case let .files(sectionId, _, _):
            return (sectionId * 1000) + stableId
        case let .voice(sectionId, _, _):
            return (sectionId * 1000) + stableId
        case let .instantVideo(sectionId, _, _):
            return (sectionId * 1000) + stableId
        case let .gifs(sectionId, _, _):
            return (sectionId * 1000) + stableId
        case let .resetDownloadSettings(sectionId, _):
            return (sectionId * 1000) + stableId
        case let .downloadFolder(sectionId, _):
            return (sectionId * 1000) + stableId
        case let .automaticCopyToDownload(sectionId, _):
            return (sectionId * 1000) + stableId
        case let .sectionId(sectionId):
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
        case let .automaticMediaDownloadHeader(sectionId, text):
            if case .automaticMediaDownloadHeader(sectionId, text) = rhs {
                return true
            } else {
                return false
            }
        case let .automaticDownloadMedia(sectionId, value):
            if case .automaticDownloadMedia(sectionId, value) = rhs {
                return true
            } else {
                return false
            }
        case let .photos(sectionId, category, enabled):
            if case .photos(sectionId, category, enabled) = rhs {
                return true
            } else {
                return false
            }
        case let .videos(sectionId, category, enabled):
            if case .videos(sectionId, category, enabled) = rhs {
                return true
            } else {
                return false
            }
        case let .files(sectionId, category, enabled):
            if case .files(sectionId, category, enabled) = rhs {
                return true
            } else {
                return false
            }
        case let .voice(sectionId, category, enabled):
            if case .voice(sectionId, category, enabled) = rhs {
                return true
            } else {
                return false
            }
        case let .instantVideo(sectionId, category, enabled):
            if case .instantVideo(sectionId, category, enabled) = rhs {
                return true
            } else {
                return false
            }
        case let .gifs(sectionId, category, enabled):
            if case .gifs(sectionId, category, enabled) = rhs {
                return true
            } else {
                return false
            }
        case let .resetDownloadSettings(sectionId, value):
            if case .resetDownloadSettings(sectionId, value) = rhs {
                return true
            } else {
                return false
            }
        case let .downloadFolder(sectionId, value):
            if case .downloadFolder(sectionId, value) = rhs {
                return true
            } else {
                return false
            }
        case let .automaticCopyToDownload(sectionId, value):
            if case .automaticCopyToDownload(sectionId, value) = rhs {
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
        case let .automaticMediaDownloadHeader(_, text):
            return GeneralTextRowItem(initialSize, stableId: stableId, text: text, drawCustomSeparator: true, inset: NSEdgeInsets(left: 30.0, right: 30.0, top:2, bottom:6))
        case let .automaticDownloadMedia(_ , value):
            return GeneralInteractedRowItem(initialSize, stableId: stableId, name: L10n.dataAndStorageAutomaticDownload, type: .switchable(value), action: {
                arguments.toggleAutomaticDownload(!value)
            })
        case let .photos(_, category, enabled):
            return GeneralInteractedRowItem(initialSize, stableId: stableId, name: L10n.dataAndStorageAutomaticDownloadPhoto, type: .next, action: {
               arguments.openCategorySettings(category, L10n.dataAndStorageAutomaticDownloadPhoto)
            }, enabled: enabled)
        case let .videos(_, category, enabled):
            return GeneralInteractedRowItem(initialSize, stableId: stableId, name: L10n.dataAndStorageAutomaticDownloadVideo, type: .next, action: {
                arguments.openCategorySettings(category, L10n.dataAndStorageAutomaticDownloadVideo)
            }, enabled: enabled)
        case let .files(_, category, enabled):
            return GeneralInteractedRowItem(initialSize, stableId: stableId, name: L10n.dataAndStorageAutomaticDownloadFiles, type: .next, action: {
                arguments.openCategorySettings(category, L10n.dataAndStorageAutomaticDownloadFiles)
            }, enabled: enabled)
        case let .voice(_, category, enabled):
            return GeneralInteractedRowItem(initialSize, stableId: stableId, name: L10n.dataAndStorageAutomaticDownloadVoice, type: .next, action: {
                arguments.openCategorySettings(category, L10n.dataAndStorageAutomaticDownloadVoice)
            }, enabled: enabled)
        case let .instantVideo(_, category, enabled):
            return GeneralInteractedRowItem(initialSize, stableId: stableId, name: L10n.dataAndStorageAutomaticDownloadInstantVideo, type: .next, action: {
                arguments.openCategorySettings(category, L10n.dataAndStorageAutomaticDownloadInstantVideo)
            }, enabled: enabled)
        case let .gifs(_, category, enabled):
            return GeneralInteractedRowItem(initialSize, stableId: stableId, name: L10n.dataAndStorageAutomaticDownloadGIFs, type: .next, action: {
                arguments.openCategorySettings(category, L10n.dataAndStorageAutomaticDownloadGIFs)
            }, enabled: enabled)
        case let .resetDownloadSettings(_, enabled):
            return GeneralInteractedRowItem(initialSize, stableId: stableId, name: L10n.dataAndStorageAutomaticDownloadReset, nameStyle: ControlStyle(font: .normal(.title), foregroundColor: theme.colors.blueUI), type: .none, action: {
                arguments.resetDownloadSettings()
            }, enabled: enabled)
        case let .downloadFolder(_, path):
            return GeneralInteractedRowItem(initialSize, stableId: stableId, name: L10n.dataAndStorageDownloadFolder, type: .context(path), action: {
                arguments.selectDownloadFolder()
            })
        case let .automaticCopyToDownload(_, value):
            return GeneralInteractedRowItem(initialSize, stableId: stableId, name: "L10n.dataAndStorageAutomaticDownloadToDownloadFolder", type: .switchable(value), action: {
                arguments.toggleAutomaticDownload(!value)
            })
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
    entries.append(.networkUsage(sectionId, tr(L10n.dataAndStorageNetworkUsage)))
    
    entries.append(.sectionId(sectionId))
    sectionId += 1


    entries.append(.automaticMediaDownloadHeader(sectionId, L10n.dataAndStorageAutomaticDownloadHeader))
    entries.append(.automaticDownloadMedia(sectionId, data.automaticMediaDownloadSettings.automaticDownload))
    entries.append(.photos(sectionId, data.automaticMediaDownloadSettings.categories.photo, data.automaticMediaDownloadSettings.automaticDownload))
    entries.append(.videos(sectionId, data.automaticMediaDownloadSettings.categories.video, data.automaticMediaDownloadSettings.automaticDownload))
    entries.append(.files(sectionId, data.automaticMediaDownloadSettings.categories.files, data.automaticMediaDownloadSettings.automaticDownload))
    entries.append(.voice(sectionId, data.automaticMediaDownloadSettings.categories.voice, data.automaticMediaDownloadSettings.automaticDownload))
    entries.append(.instantVideo(sectionId, data.automaticMediaDownloadSettings.categories.instantVideo, data.automaticMediaDownloadSettings.automaticDownload))
    entries.append(.gifs(sectionId, data.automaticMediaDownloadSettings.categories.gif, data.automaticMediaDownloadSettings.automaticDownload))
    entries.append(.resetDownloadSettings(sectionId, data.automaticMediaDownloadSettings != AutomaticMediaDownloadSettings.defaultSettings))
    
    entries.append(.sectionId(sectionId))
    sectionId += 1
    
    entries.append(.downloadFolder(sectionId, data.automaticMediaDownloadSettings.downloadFolder))
    //entries.append(.automaticCopyToDownload(sectionId, data.automaticMediaDownloadSettings.automaticSaveDownloadedFiles))

    return entries
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
        
        let pushControllerImpl:(ViewController)->Void = { [weak self] controller in
            self?.navigationController?.push(controller)
        }
        
        let previous:Atomic<[AppearanceWrapperEntry<DataAndStorageEntry>]> = Atomic(value: [])
        let actionsDisposable = DisposableSet()
        
        let dataAndStorageDataPromise = Promise<DataAndStorageData>()
        dataAndStorageDataPromise.set(account.postbox.preferencesView(keys: [ApplicationSpecificPreferencesKeys.automaticMediaDownloadSettings, ApplicationSpecificPreferencesKeys.generatedMediaStoreSettings, ApplicationSpecificPreferencesKeys.voiceCallSettings])
            |> map { view -> DataAndStorageData in
                let automaticMediaDownloadSettings: AutomaticMediaDownloadSettings = view.values[ApplicationSpecificPreferencesKeys.automaticMediaDownloadSettings] as? AutomaticMediaDownloadSettings ?? AutomaticMediaDownloadSettings.defaultSettings

                
                let generatedMediaStoreSettings: GeneratedMediaStoreSettings = view.values[ApplicationSpecificPreferencesKeys.generatedMediaStoreSettings] as? GeneratedMediaStoreSettings ?? GeneratedMediaStoreSettings.defaultSettings
                
                let voiceCallSettings: VoiceCallSettings = view.values[ApplicationSpecificPreferencesKeys.voiceCallSettings] as? VoiceCallSettings ?? VoiceCallSettings.defaultSettings
                
                return DataAndStorageData(automaticMediaDownloadSettings: automaticMediaDownloadSettings, generatedMediaStoreSettings: generatedMediaStoreSettings, voiceCallSettings: voiceCallSettings)
            })
        
        let arguments = DataAndStorageControllerArguments(openStorageUsage: {
            pushControllerImpl(StorageUsageController(account))
        }, openNetworkUsage: {
            networkUsageStatsController(account: account, f: pushControllerImpl)
        }, openCategorySettings: { category, title in
            pushControllerImpl(DownloadSettingsViewController(account, category, title, updateCategory: { category in
                _ = updateMediaDownloadSettingsInteractively(postbox: account.postbox, { current -> AutomaticMediaDownloadSettings in
                    switch title {
                    case L10n.dataAndStorageAutomaticDownloadPhoto:
                        return current.withUpdatedCategories(current.categories.withUpdatedPhoto(category))
                    case L10n.dataAndStorageAutomaticDownloadVideo:
                        return current.withUpdatedCategories(current.categories.withUpdatedVideo(category))
                    case L10n.dataAndStorageAutomaticDownloadFiles:
                        return current.withUpdatedCategories(current.categories.withUpdatedFiles(category))
                    case L10n.dataAndStorageAutomaticDownloadVoice:
                        return current.withUpdatedCategories(current.categories.withUpdatedVoice(category))
                    case L10n.dataAndStorageAutomaticDownloadInstantVideo:
                        return current.withUpdatedCategories(current.categories.withUpdatedInstantVideo(category))
                    case L10n.dataAndStorageAutomaticDownloadGIFs:
                        return current.withUpdatedCategories(current.categories.withUpdatedGif(category))
                    default:
                        return current
                    }
                }).start()
            }))
        }, toggleAutomaticDownload: { enabled in
            _ = updateMediaDownloadSettingsInteractively(postbox: account.postbox, { current -> AutomaticMediaDownloadSettings in
                return current.withUpdatedAutomaticDownload(enabled)
            }).start()
        }, resetDownloadSettings: {
            _ = (confirmSignal(for: mainWindow, header: appName, information: L10n.dataAndStorageConfirmResetSettings, okTitle: L10n.modalOK, cancelTitle: L10n.modalCancel) |> filter {$0} |> mapToSignal { _ -> Signal<Void, Void> in
                return updateMediaDownloadSettingsInteractively(postbox: account.postbox, { _ -> AutomaticMediaDownloadSettings in
                    return AutomaticMediaDownloadSettings.defaultSettings
                })
            }).start()
        }, selectDownloadFolder: {
            selectFolder(for: mainWindow, completion: { newPath in
                _ = updateMediaDownloadSettingsInteractively(postbox: account.postbox, { current -> AutomaticMediaDownloadSettings in
                    return current.withUpdatedDownloadFolder(newPath)
                }).start()
            })
            
        }, toggleAutomaticCopyToDownload: { value in
            _ = updateMediaDownloadSettingsInteractively(postbox: account.postbox, { current -> AutomaticMediaDownloadSettings in
                return current.withUpdatedAutomaticSaveDownloadedFiles(value)
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
