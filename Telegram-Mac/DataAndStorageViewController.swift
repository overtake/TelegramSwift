//
//  DataAndStorageViewController.swift
//  Telegram
//
//  Created by keepcoder on 18/04/2017.
//  Copyright © 2017 Telegram. All rights reserved.
//

import Cocoa
import TGUIKit
import Postbox
import TelegramCore
import InAppSettings
import SwiftSignalKit


enum DataAndStorageEntryTag : ItemListItemTag {
    case automaticDownloadReset
    case autoplayGifs
    case autoplayVideos
    
    func isEqual(to other: ItemListItemTag) -> Bool {
        if let other = other as? DataAndStorageEntryTag, self == other {
            return true
        } else {
            return false
        }
    }
    var stableId: Int32 {
        switch self {
        case .automaticDownloadReset:
            return 10
        case .autoplayGifs:
            return 13
        case .autoplayVideos:
            return 14
        }
    }
}


public func autodownloadDataSizeString(_ size: Int64) -> String {
    if size >= 1024 * 1024 * 1024 {
        let remainder = (size % (1024 * 1024 * 1024)) / (1024 * 1024 * 102)
        if remainder != 0 {
            return "\(size / (1024 * 1024 * 1024)),\(remainder) GB"
        } else {
            return "\(size / (1024 * 1024 * 1024)) GB"
        }
    } else if size >= 1024 * 1024 {
        let remainder = (size % (1024 * 1024)) / (1024 * 102)
        if size < 10 * 1024 * 1024 {
            return "\(size / (1024 * 1024)),\(remainder) MB"
        } else {
            return "\(size / (1024 * 1024)) MB"
        }
    } else if size >= 1024 {
        return "\(size / 1024) KB"
    } else {
        return "\(size) B"
    }
}


private struct AutomaticDownloadPeers {
    let privateChats: Bool
    let groups: Bool
    let channels: Bool
    let size: Int32?
    
    init(category: AutomaticMediaDownloadCategoryPeers) {
        self.privateChats = category.privateChats
        self.groups = category.groupChats
        self.channels = category.channels
        self.size = category.fileSize
    }
}


private func stringForAutomaticDownloadPeers(peers: AutomaticDownloadPeers, category: AutomaticDownloadCategory) -> String {
    var size: String?
    if var peersSize = peers.size, category == .video || category == .file {
        if peersSize == Int32.max {
            peersSize = 1536 * 1024 * 1024
        }
        size = autodownloadDataSizeString(Int64(peersSize))
    }
    
    if peers.privateChats && peers.groups && peers.channels {
        if let size = size {
            return strings().autoDownloadSettingsUpToForAll(size)
        } else {
            return strings().autoDownloadSettingsOnForAll
        }
    } else {
        var types: [String] = []
        if peers.privateChats {
            types.append(strings().autoDownloadSettingsTypePrivateChats)
        }
        if peers.groups {
            types.append(strings().autoDownloadSettingsTypeGroupChats)
        }
        if peers.channels {
            types.append(strings().autoDownloadSettingsTypeChannels)
        }
        
        if types.isEmpty {
            return strings().autoDownloadSettingsOffForAll
        }
        
        var string: String = ""
        for i in 0 ..< types.count {
            if !string.isEmpty {
                if i == types.count - 1 {
                    string.append(strings().autoDownloadSettingsLastDelimeter)
                } else {
                    string.append(strings().autoDownloadSettingsDelimeter)
                }
            }
            string.append(types[i])
        }
        
        if let size = size {
            return strings().autoDownloadSettingsUpToFor(size, string)
        } else {
            return strings().autoDownloadSettingsOnFor(string)
        }
    }
}


enum AutomaticDownloadCategory {
    case photo
    case video
    case file
}

private enum AutomaticDownloadPeerType {
    case contact
    case otherPrivate
    case group
    case channel
}


private final class DataAndStorageControllerArguments {
    let openStorageUsage: () -> Void
    let openNetworkUsage: () -> Void
    let openCategorySettings: (AutomaticMediaDownloadCategoryPeers, String) -> Void
    let toggleAutomaticDownload:(Bool) -> Void
    let resetDownloadSettings:()->Void
    let selectDownloadFolder: ()->Void
    let toggleAutoplayGifs:(Bool) -> Void
    let toggleAutoplayVideos:(Bool) -> Void
    let toggleAutoplaySoundOnHover:(Bool) -> Void
    let openProxySettings:()->Void
    init(openStorageUsage: @escaping () -> Void, openNetworkUsage: @escaping () -> Void, openCategorySettings: @escaping(AutomaticMediaDownloadCategoryPeers, String) -> Void, toggleAutomaticDownload:@escaping(Bool) -> Void, resetDownloadSettings:@escaping()->Void, selectDownloadFolder: @escaping() -> Void, toggleAutoplayGifs: @escaping(Bool) -> Void, toggleAutoplayVideos:@escaping(Bool) -> Void, toggleAutoplaySoundOnHover:@escaping(Bool) -> Void, openProxySettings: @escaping()->Void) {
        self.openStorageUsage = openStorageUsage
        self.openNetworkUsage = openNetworkUsage
        self.openCategorySettings = openCategorySettings
        self.toggleAutomaticDownload = toggleAutomaticDownload
        self.resetDownloadSettings = resetDownloadSettings
        self.selectDownloadFolder = selectDownloadFolder
        self.toggleAutoplayGifs = toggleAutoplayGifs
        self.toggleAutoplayVideos = toggleAutoplayVideos
        self.toggleAutoplaySoundOnHover = toggleAutoplaySoundOnHover
        self.openProxySettings = openProxySettings
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

    case storageUsage(Int32, String, viewType: GeneralViewType)
    case networkUsage(Int32, String, viewType: GeneralViewType)
    case automaticMediaDownloadHeader(Int32, String, viewType: GeneralViewType)
    case automaticDownloadMedia(Int32, Bool, viewType: GeneralViewType)
    case photos(Int32, AutomaticMediaDownloadCategoryPeers, Bool, viewType: GeneralViewType)
    case videos(Int32, AutomaticMediaDownloadCategoryPeers, Bool, Int32?, viewType: GeneralViewType)
    case files(Int32, AutomaticMediaDownloadCategoryPeers, Bool, Int32?, viewType: GeneralViewType)
    case voice(Int32, AutomaticMediaDownloadCategoryPeers, Bool, viewType: GeneralViewType)
    case instantVideo(Int32, AutomaticMediaDownloadCategoryPeers, Bool, viewType: GeneralViewType)
    case gifs(Int32, AutomaticMediaDownloadCategoryPeers, Bool, viewType: GeneralViewType)
    
    case autoplayHeader(Int32, viewType: GeneralViewType)
    case autoplayGifs(Int32, Bool, viewType: GeneralViewType)
    case autoplayVideos(Int32, Bool, viewType: GeneralViewType)
    case soundOnHover(Int32, Bool, viewType: GeneralViewType)
    case soundOnHoverDesc(Int32, viewType: GeneralViewType)
    case resetDownloadSettings(Int32, Bool, viewType: GeneralViewType)
    case downloadFolder(Int32, String, viewType: GeneralViewType)
    case proxyHeader(Int32)
    case proxySettings(Int32, String, viewType: GeneralViewType)
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
        case .autoplayHeader:
            return 12
        case .autoplayGifs:
            return 13
        case .autoplayVideos:
            return 14
        case .soundOnHover:
            return 15
        case .soundOnHoverDesc:
            return 16
        case .proxyHeader:
            return 17
        case .proxySettings:
            return 18
        case let .sectionId(sectionId):
            return (sectionId + 1) * 1000 - sectionId
        }
    }
    
    var index:Int32 {
        switch self {
        case .storageUsage(let sectionId, _, _):
            return (sectionId * 1000) + stableId
        case .networkUsage(let sectionId, _, _):
            return (sectionId * 1000) + stableId
        case .automaticMediaDownloadHeader(let sectionId, _, _):
            return (sectionId * 1000) + stableId
        case .automaticDownloadMedia(let sectionId, _, _):
            return (sectionId * 1000) + stableId
        case let .photos(sectionId, _, _, _):
            return (sectionId * 1000) + stableId
        case let .videos(sectionId, _, _, _, _):
            return (sectionId * 1000) + stableId
        case let .files(sectionId, _, _, _, _):
            return (sectionId * 1000) + stableId
        case let .voice(sectionId, _, _, _):
            return (sectionId * 1000) + stableId
        case let .instantVideo(sectionId, _, _, _):
            return (sectionId * 1000) + stableId
        case let .gifs(sectionId, _, _, _):
            return (sectionId * 1000) + stableId
        case let .resetDownloadSettings(sectionId, _, _):
            return (sectionId * 1000) + stableId
        case let .autoplayHeader(sectionId, _):
            return (sectionId * 1000) + stableId
        case let .autoplayGifs(sectionId, _, _):
            return (sectionId * 1000) + stableId
        case let .autoplayVideos(sectionId, _, _):
            return (sectionId * 1000) + stableId
        case let .soundOnHover(sectionId, _, _):
            return (sectionId * 1000) + stableId
        case let .soundOnHoverDesc(sectionId, _):
            return (sectionId * 1000) + stableId
        case let .downloadFolder(sectionId, _, _):
            return (sectionId * 1000) + stableId
        case let .proxyHeader(sectionId):
            return sectionId
        case let .proxySettings(sectionId, _, _):
            return sectionId
        case let .sectionId(sectionId):
            return (sectionId + 1) * 1000 - sectionId
        }
    }
    
    static func <(lhs: DataAndStorageEntry, rhs: DataAndStorageEntry) -> Bool {
        return lhs.index < rhs.index
    }
    
    func item(_ arguments: DataAndStorageControllerArguments, initialSize: NSSize) -> TableRowItem {
        switch self {
        case let .storageUsage(_, text, viewType):
            return GeneralInteractedRowItem(initialSize, stableId: stableId, name: text, type: .next, viewType: viewType, action: {
                arguments.openStorageUsage()
            })
        case let .networkUsage(_, text, viewType):
            return GeneralInteractedRowItem(initialSize, stableId: stableId, name: text, type: .next, viewType: viewType, action: {
                arguments.openNetworkUsage()
            })
        case let .automaticMediaDownloadHeader(_, text, viewType):
            return GeneralTextRowItem(initialSize, stableId: stableId, text: text, viewType: viewType)
        case let .automaticDownloadMedia(_ , value, viewType):
            return GeneralInteractedRowItem(initialSize, stableId: stableId, name: strings().dataAndStorageAutomaticDownload, type: .switchable(value), viewType: viewType, action: {
                arguments.toggleAutomaticDownload(!value)
            })
        case let .photos(_, category, enabled, viewType):
            return GeneralInteractedRowItem(initialSize, stableId: stableId, name: strings().dataAndStorageAutomaticDownloadPhoto, description: stringForAutomaticDownloadPeers(peers: AutomaticDownloadPeers(category: category), category: .photo), type: .next, viewType: viewType, action: {
               arguments.openCategorySettings(category, strings().dataAndStorageAutomaticDownloadPhoto)
            }, enabled: enabled)
        case let .videos(_, category, enabled, _, viewType):
            
            return GeneralInteractedRowItem(initialSize, stableId: stableId, name: strings().dataAndStorageAutomaticDownloadVideo, description: stringForAutomaticDownloadPeers(peers: AutomaticDownloadPeers(category: category), category: .video), type: .next, viewType: viewType, action: {
                arguments.openCategorySettings(category, strings().dataAndStorageAutomaticDownloadVideo)
            }, enabled: enabled)
        case let .files(_, category, enabled, _, viewType):
            return GeneralInteractedRowItem(initialSize, stableId: stableId, name: strings().dataAndStorageAutomaticDownloadFiles, description: stringForAutomaticDownloadPeers(peers: AutomaticDownloadPeers(category: category), category: .file), type: .next, viewType: viewType, action: {
                arguments.openCategorySettings(category, strings().dataAndStorageAutomaticDownloadFiles)
            }, enabled: enabled)
        case let .voice(_, category, enabled, viewType):
            return GeneralInteractedRowItem(initialSize, stableId: stableId, name: strings().dataAndStorageAutomaticDownloadVoice, type: .next, viewType: viewType, action: {
                arguments.openCategorySettings(category, strings().dataAndStorageAutomaticDownloadVoice)
            }, enabled: enabled)
        case let .instantVideo(_, category, enabled, viewType):
            return GeneralInteractedRowItem(initialSize, stableId: stableId, name: strings().dataAndStorageAutomaticDownloadInstantVideo, type: .next, viewType: viewType, action: {
                arguments.openCategorySettings(category, strings().dataAndStorageAutomaticDownloadInstantVideo)
            }, enabled: enabled)
        case let .gifs(_, category, enabled, viewType):
            return GeneralInteractedRowItem(initialSize, stableId: stableId, name: strings().dataAndStorageAutomaticDownloadGIFs, type: .next, viewType: viewType, action: {
                arguments.openCategorySettings(category, strings().dataAndStorageAutomaticDownloadGIFs)
            }, enabled: enabled)
        case let .resetDownloadSettings(_, enabled, viewType):
            return GeneralInteractedRowItem(initialSize, stableId: stableId, name: strings().dataAndStorageAutomaticDownloadReset, nameStyle: ControlStyle(font: .normal(.title), foregroundColor: theme.colors.accent), type: .none, viewType: viewType, action: {
                arguments.resetDownloadSettings()
            }, enabled: enabled)
        case let .downloadFolder(_, path, viewType):
            return GeneralInteractedRowItem(initialSize, stableId: stableId, name: strings().dataAndStorageDownloadFolder, type: .context(path), viewType: viewType, action: {
                arguments.selectDownloadFolder()
            })
        case let .autoplayHeader(_, viewType):
            return GeneralTextRowItem(initialSize, stableId: stableId, text: strings().dataAndStorageAutoplayHeader, viewType: viewType)
        case let .autoplayGifs(_, value, viewType):
            return GeneralInteractedRowItem(initialSize, stableId: stableId, name: strings().dataAndStorageAutoplayGIFs, type: .switchable(value), viewType: viewType, action: {
                arguments.toggleAutoplayGifs(!value)
            })
        case let .autoplayVideos(_, value, viewType):
            return GeneralInteractedRowItem(initialSize, stableId: stableId, name: strings().dataAndStorageAutoplayVideos, type: .switchable(value), viewType: viewType, action: {
                arguments.toggleAutoplayVideos(!value)
            })
        case let .soundOnHover(_, value, viewType):
            return GeneralInteractedRowItem(initialSize, stableId: stableId, name: strings().dataAndStorageAutoplaySoundOnHover, type: .switchable(value), viewType: viewType, action: {
                arguments.toggleAutoplaySoundOnHover(!value)
            })
        case let .soundOnHoverDesc(_, viewType):
            return GeneralTextRowItem(initialSize, stableId: stableId, text: strings().dataAndStorageAutoplaySoundOnHoverDesc, viewType: viewType)
        case .proxyHeader:
            return GeneralTextRowItem(initialSize, stableId: stableId, text: strings().privacySettingsProxyHeader, viewType: .textTopItem)
        case let .proxySettings(_, text, viewType):
            return GeneralInteractedRowItem(initialSize, stableId: stableId, name: strings().privacySettingsUseProxy, type: .nextContext(text), viewType: viewType, action: {
                arguments.openProxySettings()
            })
        default:
            return GeneralRowItem(initialSize, height: 30, stableId: stableId, viewType: .separator)
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
    let voiceCallSettings: VoiceCallSettings
    
    init(automaticMediaDownloadSettings: AutomaticMediaDownloadSettings, voiceCallSettings: VoiceCallSettings) {
        self.automaticMediaDownloadSettings = automaticMediaDownloadSettings
        self.voiceCallSettings = voiceCallSettings
    }
    
    static func ==(lhs: DataAndStorageData, rhs: DataAndStorageData) -> Bool {
        return lhs.automaticMediaDownloadSettings == rhs.automaticMediaDownloadSettings && lhs.voiceCallSettings == rhs.voiceCallSettings
    }
}


private func dataAndStorageControllerEntries(state: DataAndStorageControllerState, data: DataAndStorageData, proxy: ProxySettings, autoplayMedia: AutoplayMediaPreferences) -> [DataAndStorageEntry] {
    var entries: [DataAndStorageEntry] = []
    
    var sectionId:Int32 = 1
    entries.append(.sectionId(sectionId))
    sectionId += 1
    
    entries.append(.storageUsage(sectionId, strings().dataAndStorageStorageUsage, viewType: .firstItem))
    entries.append(.networkUsage(sectionId, strings().dataAndStorageNetworkUsage, viewType: .lastItem))
    
    entries.append(.sectionId(sectionId))
    sectionId += 1


    entries.append(.automaticMediaDownloadHeader(sectionId, strings().dataAndStorageAutomaticDownloadHeader, viewType: .textTopItem))
    entries.append(.automaticDownloadMedia(sectionId, data.automaticMediaDownloadSettings.automaticDownload, viewType: .firstItem))
    entries.append(.photos(sectionId, data.automaticMediaDownloadSettings.categories.photo, data.automaticMediaDownloadSettings.automaticDownload, viewType: .innerItem))
    entries.append(.videos(sectionId, data.automaticMediaDownloadSettings.categories.video, data.automaticMediaDownloadSettings.automaticDownload, data.automaticMediaDownloadSettings.categories.video.fileSize, viewType: .innerItem))
    entries.append(.files(sectionId, data.automaticMediaDownloadSettings.categories.files, data.automaticMediaDownloadSettings.automaticDownload, data.automaticMediaDownloadSettings.categories.files.fileSize, viewType: .innerItem))
    entries.append(.resetDownloadSettings(sectionId, data.automaticMediaDownloadSettings != AutomaticMediaDownloadSettings.defaultSettings, viewType: .lastItem))
    
    entries.append(.sectionId(sectionId))
    sectionId += 1
    
    entries.append(.downloadFolder(sectionId, data.automaticMediaDownloadSettings.downloadFolder, viewType: .singleItem))

    
    entries.append(.sectionId(sectionId))
    sectionId += 1
    
    
    entries.append(.autoplayHeader(sectionId, viewType: .textTopItem))
    entries.append(.autoplayGifs(sectionId, autoplayMedia.gifs, viewType: .firstItem))
    entries.append(.autoplayVideos(sectionId, autoplayMedia.videos, viewType: .lastItem))

    
    entries.append(.sectionId(sectionId))
    sectionId += 1
    
    
    entries.append(.proxyHeader(sectionId))
    let text: String
    if let active = proxy.activeServer, proxy.enabled {
        switch active.connection {
        case .socks5:
            text = strings().proxySettingsSocks5
        case .mtp:
            text = strings().proxySettingsMTP
        }
    } else {
        text = strings().proxySettingsDisabled
    }
    entries.append(.proxySettings(sectionId, text, viewType: .singleItem))
    
    
    entries.append(.sectionId(sectionId))
    sectionId += 1
    
    return entries
}


private func prepareTransition(left:[AppearanceWrapperEntry<DataAndStorageEntry>], right: [AppearanceWrapperEntry<DataAndStorageEntry>], initialSize: NSSize, arguments: DataAndStorageControllerArguments) -> TableUpdateTransition {
    let (removed, inserted, updated) = proccessEntriesWithoutReverse(left, right: right) { entry -> TableRowItem in
        return entry.entry.item(arguments, initialSize: initialSize)
    }
    return TableUpdateTransition(deleted: removed, inserted: inserted, updated: updated, animated: true)
}

class DataAndStorageViewController: TableViewController {
    private let disposable = MetaDisposable()
    private var focusOnItemTag: DataAndStorageEntryTag?
    init(_ context: AccountContext, focusOnItemTag: DataAndStorageEntryTag? = nil) {
        self.focusOnItemTag = focusOnItemTag
        super.init(context)
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        
        let context = self.context
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
        dataAndStorageDataPromise.set(combineLatest(context.account.postbox.preferencesView(keys: [ApplicationSpecificPreferencesKeys.automaticMediaDownloadSettings]), voiceCallSettings(context.sharedContext.accountManager))
            |> map { view, voiceCallSettings  -> DataAndStorageData in
                let automaticMediaDownloadSettings: AutomaticMediaDownloadSettings = view.values[ApplicationSpecificPreferencesKeys.automaticMediaDownloadSettings]?.get(AutomaticMediaDownloadSettings.self) ?? AutomaticMediaDownloadSettings.defaultSettings
                
                return DataAndStorageData(automaticMediaDownloadSettings: automaticMediaDownloadSettings, voiceCallSettings: voiceCallSettings)
            })
        
        let arguments = DataAndStorageControllerArguments(openStorageUsage: {
            pushControllerImpl(StorageUsageController(context))
        }, openNetworkUsage: {
            pushControllerImpl(networkUsageStatsController(context: context))
        }, openCategorySettings: { category, title in
            pushControllerImpl(DownloadSettingsViewController(context, category, title, updateCategory: { category in
                _ = updateMediaDownloadSettingsInteractively(postbox: context.account.postbox, { current -> AutomaticMediaDownloadSettings in
                    switch title {
                    case strings().dataAndStorageAutomaticDownloadPhoto:
                        return current.withUpdatedCategories(current.categories.withUpdatedPhoto(category))
                    case strings().dataAndStorageAutomaticDownloadVideo:
                        return current.withUpdatedCategories(current.categories.withUpdatedVideo(category))
                    case strings().dataAndStorageAutomaticDownloadFiles:
                        return current.withUpdatedCategories(current.categories.withUpdatedFiles(category))
                    case strings().dataAndStorageAutomaticDownloadVoice:
                        return current.withUpdatedCategories(current.categories.withUpdatedVoice(category))
                    case strings().dataAndStorageAutomaticDownloadInstantVideo:
                        return current.withUpdatedCategories(current.categories.withUpdatedInstantVideo(category))
                    case strings().dataAndStorageAutomaticDownloadGIFs:
                        return current.withUpdatedCategories(current.categories.withUpdatedGif(category))
                    default:
                        return current
                    }
                }).start()
            }))
        }, toggleAutomaticDownload: { enabled in
            _ = updateMediaDownloadSettingsInteractively(postbox: context.account.postbox, { current -> AutomaticMediaDownloadSettings in
                return current.withUpdatedAutomaticDownload(enabled)
            }).start()
        }, resetDownloadSettings: {
            _ = (confirmSignal(for: context.window, header: appName, information: strings().dataAndStorageConfirmResetSettings, okTitle: strings().modalOK, cancelTitle: strings().modalCancel) |> filter {$0} |> mapToSignal { _ -> Signal<Void, NoError> in
                return updateMediaDownloadSettingsInteractively(postbox: context.account.postbox, { _ -> AutomaticMediaDownloadSettings in
                    return AutomaticMediaDownloadSettings.defaultSettings
                })
            }).start()
        }, selectDownloadFolder: {
            selectFolder(for: context.window, completion: { newPath in
                _ = updateMediaDownloadSettingsInteractively(postbox: context.account.postbox, { current -> AutomaticMediaDownloadSettings in
                    return current.withUpdatedDownloadFolder(newPath)
                }).start()
            })
            
        }, toggleAutoplayGifs: { enable in
            _ = updateAutoplayMediaSettingsInteractively(postbox: context.account.postbox, {
                return $0.withUpdatedAutoplayGifs(enable)
            }).start()
        }, toggleAutoplayVideos: { enable in
            _ = updateAutoplayMediaSettingsInteractively(postbox: context.account.postbox, {
                return $0.withUpdatedAutoplayVideos(enable)
            }).start()
        }, toggleAutoplaySoundOnHover: { enable in
            _ = updateAutoplayMediaSettingsInteractively(postbox: context.account.postbox, {
                return $0.withUpdatedAutoplaySoundOnHover(enable)
            }).start()
        }, openProxySettings: {
            let controller = proxyListController(accountManager: context.sharedContext.accountManager, network: context.account.network, share: { servers in
                var message: String = ""
                for server in servers {
                    message += server.link + "\n\n"
                }
                message = message.trimmed
                
                showModal(with: ShareModalController(ShareLinkObject(context, link: message)), for: context.window)
            }, pushController: { controller in
                pushControllerImpl(controller)
            })
            pushControllerImpl(controller)
        })
        
        let proxy:Signal<ProxySettings, NoError> = proxySettings(accountManager: context.sharedContext.accountManager)

        
        
        let signal = combineLatest(queue: .mainQueue(), statePromise.get(), dataAndStorageDataPromise.get(), appearanceSignal, proxy, autoplayMediaSettings(postbox: context.account.postbox))
        |> map { state, dataAndStorageData, appearance, proxy, autoplayMediaSettings -> TableUpdateTransition in
            let entries = dataAndStorageControllerEntries(state: state, data: dataAndStorageData, proxy: proxy, autoplayMedia: autoplayMediaSettings).map {AppearanceWrapperEntry(entry: $0, appearance: appearance)}
            return prepareTransition(left: previous.swap(entries), right: entries, initialSize: initialSize.modify({$0}), arguments: arguments)
        } |> beforeNext { [weak self] _ in
            self?.readyOnce()
        } |> afterDisposed {
            actionsDisposable.dispose()
        } |> deliverOnMainQueue
        
        
        
        self.disposable.set(signal.start(next: { [weak self] transition in
            self?.genericView.merge(with: transition)
            self?.readyOnce()
            if let focusOnItemTag = self?.focusOnItemTag {
                self?.genericView.scroll(to: .center(id: focusOnItemTag.stableId, innerId: nil, animated: true, focus: .init(focus: true), inset: 0), inset: NSEdgeInsets())
                self?.focusOnItemTag = nil
            }
        }))
        
    }
    
    deinit {
        disposable.dispose()
    }
    
    override func getRightBarViewOnce() -> BarView {
        return BarView(20, controller: self)
    }

}
