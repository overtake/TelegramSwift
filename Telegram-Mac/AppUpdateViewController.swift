//
//  AppUpdateViewController.swift
//  Telegram
//
//  Created by Mikhail Filimonov on 01/02/2019.
//  Copyright © 2019 Telegram. All rights reserved.
//

#if !APP_STORE

import Cocoa
import TGUIKit
import TelegramCore
import SyncCore
import Postbox
import SwiftSignalKit
import Sparkle



final class TelegramUpdater : NSObject, SUUpdaterPrivate {
    var delegate: SUUpdaterDelegate!
    
    var userAgentString: String!
    
    var domain: String! = nil
    var host: String! = nil
    
    var httpHeaders: [AnyHashable : Any]!
    
    var decryptionPassword: String!
    
    var sparkleBundle: Bundle!
    
    override init() {
        self.sparkleBundle = Bundle(for: SUUpdateDriver.self)
    }
}

extension SUAppcastItem {
    var updateText: String {
        var updateText = (itemDescription.html2Attributed?.string ?? itemDescription).replacingOccurrences(of: "<[^>]+>", with: "", options: .regularExpression, range: nil)
        while let range = updateText.range(of: "   ") {
            updateText = updateText.replacingOccurrences(of: "   ", with: "  ", options: [], range: range)
        }
        updateText = updateText.replacingOccurrences(of: "•", with: "\n•", options: [], range: nil)
        
        if updateText.first == "\n" {
            updateText.removeFirst()
        }
        updateText = updateText.replacingOccurrences(of: "\t", with: "  ", options: [], range: nil)
        return updateText
    }
    
    var versionTitle: String {
        return "Version \(self.displayVersionString!) (\(self.versionString!))"
    }
}



enum AppUpdateLoadingState : Equatable {
    case initializing
    case loading(item:SUAppcastItem, current: Int, total: Int)
    case hasUpdate(SUAppcastItem)
    case readyToInstall(SUAppcastItem)
    case uptodate
    case unarchiving(SUAppcastItem)
    case installing
    case failed(NSError)
}

private let initialState = AppUpdateState(items: [], loadingState: .initializing)
private let statePromise: ValuePromise<AppUpdateState> = ValuePromise(initialState, ignoreRepeated: true)
private let stateValue = Atomic(value: initialState)

var appUpdateStateSignal: Signal<AppUpdateState, NoError> {
    return statePromise.get()
}

private let updateState:((AppUpdateState)->AppUpdateState) -> Void = { f in
    statePromise.set(stateValue.modify(f))
}
private let updater = TelegramUpdater()
private var driver:SUBasicUpdateDriver?
private let host = SUHost(bundle: Bundle.main)

func updateApplication(sharedContext: SharedAccountContext) {
    let state = stateValue.with {$0.loadingState}
    switch state {
    case let .readyToInstall(item):
        var text: String = "Telegram was updated to \(item.versionTitle.lowercased())"
        text += "\n\n"
        
        text += item.updateText
        
        _ = (sharedContext.activeAccountsWithInfo |> take(1) |> mapToSignal { _, accounts -> Signal<Never, NoError> in
            return combineLatest(accounts.map { addAppUpdateText($0.account.postbox, applyText: text) }) |> ignoreValues
        } |> deliverOnMainQueue).start(completed: { 
              driver?.install(withToolAndRelaunch: true)
            
        })
        
    case .installing:
        break
    default:
        resetUpdater()
    }
}


struct AppUpdateState : Equatable {
    let items: [SUAppcastItem]
    let loadingState: AppUpdateLoadingState
    
    fileprivate init(items: [SUAppcastItem], loadingState: AppUpdateLoadingState) {
        self.items = items
        self.loadingState = loadingState
        
    }
    func withUpdatedItems(_ items: [SUAppcastItem]) -> AppUpdateState {
        return AppUpdateState(items: items, loadingState: self.loadingState)
    }
    func withUpdatedLoadingState(_ loadingState: AppUpdateLoadingState) -> AppUpdateState {
        return AppUpdateState(items: self.items, loadingState: loadingState)
    }
}

extension String{
    var html2Attributed: NSAttributedString? {
        do {
            guard let data = data(using: String.Encoding.utf8) else {
                return nil
            }
            return try NSAttributedString(data: data,
                                          options: [.documentType: NSAttributedString.DocumentType.html,
                                                    .characterEncoding: String.Encoding.utf8.rawValue],
                                          documentAttributes: nil)
        } catch {
            print("error: ", error)
            return nil
        }
    }
}

private let _id_update_app: InputDataIdentifier = InputDataIdentifier("_id_update_app")
private let _id_initializing: InputDataIdentifier = InputDataIdentifier("_id_initializing")
private let _id_downloading: InputDataIdentifier = InputDataIdentifier("_id_downloading")
private let _id_download_update: InputDataIdentifier = InputDataIdentifier("_id_download_update")
private let _id_install_update: InputDataIdentifier = InputDataIdentifier("_id_install_update")
private let _id_check_for_updates: InputDataIdentifier = InputDataIdentifier("_id_check_for_updates")
private let _id_unarchiving: InputDataIdentifier = InputDataIdentifier("_id_unarchiving")

private func appUpdateEntries(state: AppUpdateState) -> [InputDataEntry] {
    var entries: [InputDataEntry] = []
    
    var sectionId: Int32 = 0
    var index: Int32 = 0
    
    entries.append(.sectionId(sectionId, type: .normal))
    sectionId += 1

    var currentItem: SUAppcastItem?
    
    switch state.loadingState {
    case let .failed(error):
        entries.append(.general(sectionId: sectionId, index: index, value: .none, error: nil, identifier: _id_check_for_updates, data: InputDataGeneralData(name: L10n.appUpdateCheckForUpdates, color: theme.colors.accent, icon: nil, type: .none, viewType: .singleItem, action: nil)))
        index += 1
        
        entries.append(.desc(sectionId: sectionId, index: index, text: .plain(error.localizedDescription), data: InputDataGeneralTextData(color: theme.colors.redUI, detectBold: false, viewType: .textBottomItem)))
        index += 1
        
    case let .hasUpdate(item):
        
        entries.append(.general(sectionId: sectionId, index: index, value: .none, error: nil, identifier: _id_download_update, data: InputDataGeneralData(name: L10n.appUpdateDownloadUpdate, color: theme.colors.accent, icon: nil, type: .none, viewType: .singleItem, action: nil)))
        index += 1
        
        currentItem = item
    case .initializing:
        entries.append(.general(sectionId: sectionId, index: index, value: .none, error: nil, identifier: _id_initializing, data: InputDataGeneralData(name: L10n.appUpdateRetrievingInfo, color: theme.colors.grayText, icon: nil, type: .none, viewType: .singleItem, action: nil)))
        index += 1
    case let .loading(item, current, total):
        
        entries.append(.general(sectionId: sectionId, index: index, value: .none, error: nil, identifier: _id_downloading, data: InputDataGeneralData(name: "\(L10n.appUpdateDownloading)  \(String.prettySized(with: current) + " / " + String.prettySized(with: total))", color: theme.colors.grayText, icon: nil, type: .none, viewType: .singleItem, action: nil)))
        index += 1
        
        currentItem = item
    case .uptodate:
        entries.append(.general(sectionId: sectionId, index: index, value: .none, error: nil, identifier: _id_check_for_updates, data: InputDataGeneralData(name: L10n.appUpdateCheckForUpdates, color: theme.colors.accent, icon: nil, type: .none, viewType: .singleItem, action: nil)))
        index += 1
        
        entries.append(.desc(sectionId: sectionId, index: index, text: .plain(L10n.appUpdateUptodate), data: InputDataGeneralTextData(detectBold: false, viewType: .textBottomItem)))
        index += 1
    case let .unarchiving(item):
        entries.append(.general(sectionId: sectionId, index: index, value: .none, error: nil, identifier: _id_unarchiving, data: InputDataGeneralData(name: L10n.appUpdateUnarchiving, color: theme.colors.grayText, icon: nil, type: .none, viewType: .singleItem, action: nil)))
        index += 1
        
        currentItem = item
    case let .readyToInstall(item):
        entries.append(.general(sectionId: sectionId, index: index, value: .none, error: nil, identifier: _id_install_update, data: InputDataGeneralData(name: L10n.updateUpdateTelegram, color: theme.colors.accent, icon: nil, type: .none, viewType: .singleItem, action: nil)))
        index += 1
        
        currentItem = item
    case .installing:
        break
    }
    
    
    if let item = currentItem {
        
        entries.append(.desc(sectionId: sectionId, index: index, text: .plain(L10n.appUpdateNewestAvailable), data: InputDataGeneralTextData(detectBold: false, viewType: .textTopItem)))
        index += 1
        
        entries.append(.sectionId(sectionId, type: .normal))
        sectionId += 1
    
        let text = "**" + item.versionTitle + "**" + "\n" + item.updateText
        entries.append(InputDataEntry.custom(sectionId: sectionId, index: index, value: .none, identifier: InputDataIdentifier(item.fileURL.path), equatable: nil, item: { initialSize, stableId in
            return GeneralTextRowItem(initialSize, stableId: stableId, text: text, textColor: theme.colors.listGrayText, fontSize: 13, isTextSelectable: true, viewType: .textTopItem)
        }))
        index += 1
    }
    
    
    entries.append(.sectionId(sectionId, type: .normal))
    sectionId += 1

    
    return entries
}



func AppUpdateViewController() -> InputDataController {
    
    let signal: Signal<InputDataSignalValue, NoError> = statePromise.get() |> deliverOnResourceQueue |> map { value in
        return appUpdateEntries(state: value)
    } |> map { InputDataSignalValue(entries: $0) }
    

    return InputDataController(dataSignal: signal, title: L10n.appUpdateTitle, validateData: { data in
        
        if let _ = data[_id_download_update] {
            driver?.downloadUpdate()
        }
        if let _ = data[_id_check_for_updates] {
            resetUpdater()
        }
        if let _ = data[_id_install_update] {
            driver?.install(withToolAndRelaunch: true)
        }
        
        return .none
    }, afterDisappear: {

    }, hasDone: false, identifier: "app_update")
    
    
}

private let updates_channel_xml = "macos_stable_updates_xml"



private final class InternalUpdaterDownloader : SPUDownloaderSession {
    private let context: AccountContext
    private let updateItem: SUAppcastItem
    private let disposable = MetaDisposable()
    init(context: AccountContext, updateItem: SUAppcastItem, delegate: SPUDownloaderDelegate) {
        self.context = context
        self.updateItem = updateItem
        super.init(delegate: delegate)
    }
    
    deinit {
        disposable.dispose()
    }
    
    override func suggestedFilename() -> String! {
        return "Telegram.app.zip"
    }
    
    
    
    override func moveItem(atPath fromPath: String!, toPath: String!, error: Error) -> Bool {
        try? FileManager.default.removeItem(atPath: toPath)
        do {
            try FileManager.default.copyItem(atPath: fromPath, toPath: toPath)
            return true
        } catch { 
            return false
        }
    }
    
    
    override func startDownload(with request: SPUURLRequest!) {
        if let internalUrl = self.updateItem.internalUrl {
            
            let url = inApp(for: internalUrl as NSString, context: self.context, peerId: nil, openInfo: { _, _, _, _ in }, hashtag: nil, command: nil, applyProxy: nil, confirm: false)
            switch url {
            case let .followResolvedName(_, username, messageId, context, _, _):
                if let messageId = messageId {
                    let signal = downloadAppUpdate(account: context.account, source: username, messageId: messageId) |> deliverOnMainQueue
                    disposable.set(signal.start(next: { [weak self] result in
                        guard let `self` = self else {
                            return
                        }
                        switch result {
                        case let .started(total):
                            self.delegate.downloaderDidReceiveExpectedContentLength(Int64(total))
                        case let .progress(current, _):
                            self.delegate.downloaderDidReceiveData(ofLength: UInt64(current))
                        case let .finished(path):
                            self.urlSession(URLSession(), downloadTask: URLSessionDownloadTask(), didFinishDownloadingTo: URL(fileURLWithPath: path))
                        }
                    }, error: { [weak self] error in
                            self?.delegate.downloaderDidFailWithError(NSError(domain: "Failed to download archive. Please try again.", code: 0, userInfo: nil))
                    }))
                } else {
                    self.delegate.downloaderDidFailWithError(NSError(domain: "Wrong internal link. Please try again.", code: 0, userInfo: nil))
                }
                
            default:
                self.delegate.downloaderDidFailWithError(NSError(domain: "Wrong internal link. Please try again.", code: 0, userInfo: nil))
            }
            
            
        } else {
            self.delegate.downloaderDidFailWithError(NSError(domain: "No internal link for this version. Please try again.", code: 0, userInfo: nil))
        }
        
    }
    
    
    override func cancel() {
        disposable.set(nil)
    }
    
}

private final class InternalUpdateDriver : ExternalUpdateDriver {
    
    
    private let disposabe = MetaDisposable()
    private let context: AccountContext
    
    init(updater:TelegramUpdater, context: AccountContext) {
        self.context = context
        super.init(updater: updater)
    }
    
    deinit {
        disposabe.dispose()
    }
    
    override func checkForUpdates(at URL: URL!, host aHost: SUHost!, domain: String) {
        self.host = aHost

        updateState {
            return $0.withUpdatedLoadingState(.initializing)
        }
        
        let signal = requestUpdatesXml(account: self.context.account, source: updates_channel_xml) |> deliverOnMainQueue |> timeout(20.0, queue: .mainQueue(), alternate: .fail(.xmlLoad))
        
        disposabe.set(signal.start(next: { [weak self] data in
            let appcast = SUAppcast()
            appcast.parseAppcastItems(fromXMLData: data, error: nil)
            self?.appcastDidFinishLoading(appcast)
        }, error: { [weak self] error in
            self?.abortUpdateWithError(NSError(domain: "Failed to download updating info. Please try again.", code: 0, userInfo: nil))
        }))
    }
    
    override func downloadUpdate() {
        let downloader = InternalUpdaterDownloader(context: self.context, updateItem: self.updateItem, delegate: self)
        self.download = downloader
        let fileName = "Telegram \(self.updateItem.versionString ?? "")"

        downloader.startPersistentDownload(with: SPUURLRequest(), bundleIdentifier: host.bundle.bundleIdentifier!, desiredFilename: fileName)
    }
    
    override func downloaderDidReceiveData(ofLength length: UInt64) {
        updateState { state in
            switch state.loadingState {
            case let .loading(item, _, total):
                return state.withUpdatedLoadingState(.loading(item: item, current: Int(length), total: total))
            default:
                return state
            }
        }
    }
    
    override func downloaderDidReceiveExpectedContentLength(_ expectedContentLength: Int64) {
        updateState { state in
            return state.withUpdatedLoadingState(.loading(item: self.updateItem, current: 0, total: Int(expectedContentLength)))
        }
    }
    
}

private class ExternalUpdateDriver : SUBasicUpdateDriver {
    
    override func extractUpdate() {
        super.extractUpdate()
        updateState {
            return $0.withUpdatedLoadingState(.unarchiving(self.updateItem))
        }
    }
    

    
    override func install(withToolAndRelaunch relaunch: Bool, displayingUserInterface showUI: Bool) {
        updateState {
            return $0.withUpdatedLoadingState(.installing)
        }
        resourcesQueue.async {
            super.install(withToolAndRelaunch: relaunch, displayingUserInterface: showUI)
        }
    }
    
    override func appcastDidFinishLoading(_ ac: SUAppcast!) {
        updateState {
            return $0.withUpdatedItems(ac.items?.compactMap({$0 as? SUAppcastItem}) ?? [])
        }
        super.appcastDidFinishLoading(ac)
    }
    
    override func didNotFindUpdate() {
        updateState {
            return $0.withUpdatedLoadingState(.uptodate)
        }
    }
    
    override func checkForUpdates(at url: URL!, host aHost: SUHost!, domain: String) {
        updateState {
            return $0.withUpdatedLoadingState(.initializing)
        }
        super.checkForUpdates(at: url, host: aHost, domain: domain)

    }
    
    override func downloadUpdate() {
        updateState {
            return $0.withUpdatedLoadingState(.loading(item: self.updateItem, current: 0, total: Int(self.updateItem.contentLength)))
        }
        super.downloadUpdate()
    }
    
    override func downloaderDidFinish(withTemporaryDownloadData downloadData: SPUDownloadData!) {
        super.downloaderDidFinish(withTemporaryDownloadData: downloadData)
    }
    
    override func unarchiverDidFinish(_ ua: Any!) {
        updateState {
            return $0.withUpdatedLoadingState(.readyToInstall(self.updateItem))
        }
    }
    
    override func unarchiver(_ ua: Any!, extractedProgress progress: Double) {
        
    }
    
    override func downloaderDidReceiveData(ofLength length: UInt64) {
        updateState { state in
            switch state.loadingState {
            case let .loading(item, current, total):
                return state.withUpdatedLoadingState(.loading(item: item, current: current + Int(length), total: total))
            default:
                return state
            }
        }
    }
    
    override func downloaderDidReceiveExpectedContentLength(_ expectedContentLength: Int64) {
        updateState { state in
            return state.withUpdatedLoadingState(.loading(item: self.updateItem, current: 0, total: Int(expectedContentLength)))
        }
    }
    
    override func downloaderDidFailWithError(_ error: Error!) {
        super.downloaderDidFailWithError(error)
        updateState { state in
            return state.withUpdatedLoadingState(.failed(error as NSError? ?? NSError(domain: L10n.unknownError, code: 0, userInfo: nil)))
        }
    }
    
    override func abortUpdateWithError(_ error: Error!) {
        super.abortUpdateWithError(error)
        updateState { state in
            return state.withUpdatedLoadingState(.failed(error as NSError? ?? NSError(domain: L10n.unknownError, code: 0, userInfo: nil)))
        }
        trySwitchUpdaterBetweenSources()
    }
    
    override func installer(for host: SUHost!, failedWithError error: Error!) {
        super.installer(for: host, failedWithError: error)
        updateState { state in
            return state.withUpdatedLoadingState(.failed(error as NSError? ?? NSError(domain: L10n.unknownError, code: 0, userInfo: nil)))
        }
        trySwitchUpdaterBetweenSources()
    }
}




private let disposable = MetaDisposable()

func setAppUpdaterBaseDomain(_ domain: String?) {
    updater.domain = domain
    if let domain = domain {
        updater.host = URL(string: domain)?.host
    } else {
        updater.host = nil
    }
}


func updateAppIfNeeded() {
    let state = stateValue.with {$0.loadingState}
    
    switch state {
    case .readyToInstall:
        driver?.install(withToolAndRelaunch: false, displayingUserInterface: true)
    default:
        break
    }
}


enum UpdaterSource : Equatable {
    static func == (lhs: UpdaterSource, rhs: UpdaterSource) -> Bool {
        switch lhs {
        case let .external(lhsContext):
            if case let .external(rhsContext) = rhs {
                if let lhsContext = lhsContext, let rhsContext = rhsContext {
                    return lhsContext.account.peerId == rhsContext.account.peerId
                } else if (lhsContext != nil) != (rhsContext != nil) {
                    return false
                }
                return true
            } else {
                return false
            }
        case let .internal(lhsContext):
            if case let .internal(rhsContext) = rhs {
                return lhsContext.account.peerId == rhsContext.account.peerId
            } else {
                return false
            }
        }
    }
    
    case external(context: AccountContext?)
    case `internal`(context: AccountContext)
}


private func resetUpdater() {
    
    #if !GITHUB
        let update:()->Void = {
            let url = updater.domain ?? Bundle.main.infoDictionary!["SUFeedURL"] as! String
            let state = stateValue.with { $0.loadingState }
            switch state {
            case .readyToInstall, .installing, .unarchiving, .loading:
                break
            default:
                driver?.checkForUpdates(at: URL(string: url)!, host: host, domain: updater.host)
            }
        }
    
    
        let signal: Signal<Never, NoError> = Signal { subscriber in
            update()
            subscriber.putCompletion()
            return EmptyDisposable
            } |> delay(20 * 60, queue: .mainQueue()) |> restart
        disposable.set(signal.start())
    
        update()
    #endif
    
   
}

private var updaterSource: UpdaterSource? = nil

func updater_resetWithUpdaterSource(_ source: UpdaterSource, force: Bool = true) {
    
    if updaterSource != source {
        updaterSource = source
        switch source {
        case .external:
            driver = ExternalUpdateDriver(updater: updater)
        case let .internal(context):
            driver = InternalUpdateDriver(updater: updater, context: context)
        }
    }
    if force {
        updateState {
            $0.withUpdatedLoadingState(.initializing)
        }
        resetUpdater()
    }
}


private func trySwitchUpdaterBetweenSources() {
    if let source = updaterSource {
        switch source {
        case let .external(context):
            #if STABLE || DEBUG
            if let context = context {
                updater_resetWithUpdaterSource(.internal(context: context), force: true)
            }
            #endif
        case let .internal(context):
            updater_resetWithUpdaterSource(.external(context: context), force: false)
        }
    }
}

#endif

