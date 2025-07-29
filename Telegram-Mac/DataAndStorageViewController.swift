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
    let toggleSensitiveContent:(Bool)->Void
    init(openStorageUsage: @escaping () -> Void, openNetworkUsage: @escaping () -> Void, openCategorySettings: @escaping(AutomaticMediaDownloadCategoryPeers, String) -> Void, toggleAutomaticDownload:@escaping(Bool) -> Void, resetDownloadSettings:@escaping()->Void, selectDownloadFolder: @escaping() -> Void, toggleAutoplayGifs: @escaping(Bool) -> Void, toggleAutoplayVideos:@escaping(Bool) -> Void, toggleAutoplaySoundOnHover:@escaping(Bool) -> Void, openProxySettings: @escaping()->Void, toggleSensitiveContent:@escaping(Bool)->Void) {
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
        self.toggleSensitiveContent = toggleSensitiveContent
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

    case storageUsage(Int32, String, Int64?, viewType: GeneralViewType)
    case networkUsage(Int32, String, Int64?, viewType: GeneralViewType)
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
    case sensitiveContent(Int32, Bool, viewType: GeneralViewType)
    case sensitiveContentInfo(Int32, viewType: GeneralViewType)
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
        case .sensitiveContent:
            return 17
        case .sensitiveContentInfo:
            return 18
        case .proxyHeader:
            return 19
        case .proxySettings:
            return 20
        case let .sectionId(sectionId):
            return (sectionId + 1) * 1000 - sectionId
        }
    }
    
    var index:Int32 {
        switch self {
        case .storageUsage(let sectionId, _, _, _):
            return (sectionId * 1000) + stableId
        case .networkUsage(let sectionId, _, _, _):
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
        case let .sensitiveContent(sectionId, _, _):
            return (sectionId * 1000) + stableId
        case let .sensitiveContentInfo(sectionId, _):
            return (sectionId * 1000) + stableId
        case let .proxyHeader(sectionId):
            return (sectionId * 1000) + stableId
        case let .proxySettings(sectionId, _, _):
            return (sectionId * 1000) + stableId
        case let .sectionId(sectionId):
            return (sectionId + 1) * 1000 - sectionId
        }
    }
    
    static func <(lhs: DataAndStorageEntry, rhs: DataAndStorageEntry) -> Bool {
        return lhs.index < rhs.index
    }
    
    func item(_ arguments: DataAndStorageControllerArguments, initialSize: NSSize) -> TableRowItem {
        switch self {
        case let .storageUsage(_, text, totalCount, viewType):
            let next: GeneralInteractedType
            if let totalCount = totalCount, totalCount > 1 * 1024 * 1024 {
                next = .nextContext(String.prettySized(with: totalCount, round: true))
            } else {
                next = .next
            }
            return GeneralInteractedRowItem(initialSize, stableId: stableId, name: text, icon: NSImage(resource: .iconStorageUsage).precomposed(flipVertical: true), type: next, viewType: viewType, action: {
                arguments.openStorageUsage()
            })
        case let .networkUsage(_, text, totalCount, viewType):
            let next: GeneralInteractedType
            if let totalCount = totalCount, totalCount > 1 * 1024 * 1024 {
                next = .nextContext(String.prettySized(with: totalCount, round: true))
            } else {
                next = .next
            }
            return GeneralInteractedRowItem(initialSize, stableId: stableId, name: text, icon: NSImage(resource: .iconNetworkUsage).precomposed(flipVertical: true), type: next, viewType: viewType, action: {
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
            return GeneralInteractedRowItem(initialSize, stableId: stableId, name: strings().dataAndStorageDownloadFolder, type: .nextContext(path), viewType: viewType, action: {
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
        case let .sensitiveContent(_, value, viewType):
            return GeneralInteractedRowItem(initialSize, stableId: stableId, name: strings().dataAndStorageSensitiveContent, type: .switchable(value), viewType: viewType, action: {
                arguments.toggleSensitiveContent(!value)
            }, autoswitch: false)
        case let .sensitiveContentInfo(_, viewType):
            return GeneralTextRowItem(initialSize, stableId: stableId, text: strings().dataAndStorageSensitiveContentInfo, viewType: viewType)
        case .proxyHeader:
            return GeneralTextRowItem(initialSize, stableId: stableId, text: strings().privacySettingsProxyHeader, viewType: .textTopItem)
        case let .proxySettings(_, text, viewType):
            return GeneralInteractedRowItem(initialSize, stableId: stableId, name: strings().privacySettingsUseProxy, type: .nextContext(text), viewType: viewType, action: {
                arguments.openProxySettings()
            })
        default:
            return GeneralRowItem(initialSize, height: 20, stableId: stableId, viewType: .separator)
        }
    }
}

private struct State: Equatable {
    var storageUsage: AllStorageUsageStats?
    var networkUsage: NetworkUsageStats?
    
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


private func entries(state: State, data: DataAndStorageData, proxy: ProxySettings, autoplayMedia: AutoplayMediaPreferences, contentSettingsConfiguration: ContentSettingsConfiguration?) -> [DataAndStorageEntry] {
    var entries: [DataAndStorageEntry] = []
    
    var sectionId:Int32 = 1
    entries.append(.sectionId(sectionId))
    sectionId += 1
    
    entries.append(.storageUsage(sectionId, strings().dataAndStorageStorageUsage, state.storageUsage?.totalStats.totalCount, viewType: .firstItem))
    entries.append(.networkUsage(sectionId, strings().dataAndStorageNetworkUsage, state.networkUsage?.totalCount, viewType: .lastItem))
    
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
    
    
    
    if let contentSettingsConfiguration = contentSettingsConfiguration, contentSettingsConfiguration.canAdjustSensitiveContent {
        entries.append(.sectionId(sectionId))
        sectionId += 1
        entries.append(.sensitiveContent(sectionId, contentSettingsConfiguration.sensitiveContentEnabled, viewType: .singleItem))
        entries.append(.sensitiveContentInfo(sectionId, viewType: .textBottomItem))
    }
    
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
    private let actionsDisposable = DisposableSet()
    init(_ context: AccountContext, focusOnItemTag: DataAndStorageEntryTag? = nil) {
        self.focusOnItemTag = focusOnItemTag
        super.init(context)
    }
    
    private let statePromise = ValuePromise(State(), ignoreRepeated: true)
    private let stateValue = Atomic(value: State())
    private func updateState(_ f:(State) -> State) {
        statePromise.set(stateValue.modify(f))
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        let signal = combineLatest(context.engine.resources.collectStorageUsageStats(), accountNetworkUsageStats(account: context.account, reset: [])) |> deliverOnMainQueue
        
        actionsDisposable.add(signal.start(next: { [weak self] storageUsage, networkUsage in
            self?.updateState { current in
                var current = current
                current.networkUsage = networkUsage
                current.storageUsage = storageUsage
                return current
            }
        }))

    }
    
    private var enableSensitiveContent:(()->Void)? = nil
    @objc private func enableExternalSensitiveContent() {
        enableSensitiveContent?()
    }
    
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        

        
        let context = self.context
        let initialSize = self.atomicSize
        
        
        let updateSensitiveContentDisposable = MetaDisposable()
        actionsDisposable.add(updateSensitiveContentDisposable)
        
        let pushControllerImpl:(ViewController)->Void = { [weak self] controller in
            self?.navigationController?.push(controller)
        }
        
        let previous:Atomic<[AppearanceWrapperEntry<DataAndStorageEntry>]> = Atomic(value: [])
        let actionsDisposable = self.actionsDisposable
        
        
        let updatedContentSettingsConfiguration = contentSettingsConfiguration(network: context.account.network)
          |> map(Optional.init)
          let contentSettingsConfiguration = Promise<ContentSettingsConfiguration?>()
          contentSettingsConfiguration.set(.single(nil)
          |> then(updatedContentSettingsConfiguration))
        
        
        let updateSensitiveContent:(Bool)->Void = { value in
            let _ = (contentSettingsConfiguration.get()
            |> take(1)
            |> deliverOnMainQueue).start(next: { [weak contentSettingsConfiguration] settings in
                if var settings = settings {
                    settings.sensitiveContentEnabled = value
                    contentSettingsConfiguration?.set(.single(settings))
                }
            })
            updateSensitiveContentDisposable.set(updateRemoteContentSettingsConfiguration(postbox: context.account.postbox, network: context.account.network, sensitiveContentEnabled: value).start())
            
            context.contentConfig.sensitiveContentEnabled = true

        }
        
        enableSensitiveContent = {
            updateSensitiveContent(true)
        }
        
        NotificationCenter.default.addObserver(self, selector: #selector(enableExternalSensitiveContent), name: NSNotification.Name("external_age_verify"), object: nil)

        
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
            _ = (verifyAlertSignal(for: context.window, header: appName, information: strings().dataAndStorageConfirmResetSettings, ok: strings().modalOK, cancel: strings().modalCancel) |> filter { $0 == .basic } |> mapToSignal { _ -> Signal<Void, NoError> in
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
        }, toggleSensitiveContent: { value in
            
            if value {
                
                let lastAgeVerification = FastSettings.lastAgeVerification
                
                if let lastAgeVerification, lastAgeVerification + .day > Date().timeIntervalSince1970 {
                    showModalText(
                        for: context.window,
                        text: strings().dataAndStorageVerifyAgainError(stringForMediumDate(timestamp: Int32(lastAgeVerification + .day)))
                    )
                } else {
                    let need_verification = context.appConfiguration.getBoolValue("need_age_video_verification", orElse: false)
                    
                    if need_verification {
                        showModal(with: VerifyAgeAlertController(context: context), for: context.window)
                    } else {
                        verifyAlert(for: context.window, header: strings().dataAndStorageSensitiveContentConfirmHeader, information: strings().dataAndStorageSensitiveContentConfirmText, ok: strings().dataAndStorageSensitiveContentConfirmOk, successHandler: { _ in
                            updateSensitiveContent(true)
                        })
                    }
                }
                
                
            } else {
                updateSensitiveContent(value)
            }
        })
        
        let proxy:Signal<ProxySettings, NoError> = proxySettings(accountManager: context.sharedContext.accountManager)

        
     
        
        
        let signal = combineLatest(queue: .mainQueue(), statePromise.get(), dataAndStorageDataPromise.get(), appearanceSignal, proxy, autoplayMediaSettings(postbox: context.account.postbox), contentSettingsConfiguration.get())
        |> map { state, dataAndStorageData, appearance, proxy, autoplayMediaSettings, contentSettingsConfiguration -> TableUpdateTransition in
            let entries = entries(state: state, data: dataAndStorageData, proxy: proxy, autoplayMedia: autoplayMediaSettings, contentSettingsConfiguration: contentSettingsConfiguration).map { AppearanceWrapperEntry(entry: $0, appearance: appearance) }
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
        NotificationCenter.default.removeObserver(self)
    }
    
    override func getRightBarViewOnce() -> BarView {
        return BarView(20, controller: self)
    }

}
