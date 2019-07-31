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
import TelegramCoreMac
import PostboxMac
import SwiftSignalKitMac
import Sparkle



private final class TelegramUpdater : NSObject, SUUpdaterPrivate {
    var delegate: SUUpdaterDelegate!
    
    var userAgentString: String!
    
    var basicDomain: String!
    
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
private let driver = UpdateDriver(updater: updater)!
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
              driver.install(withToolAndRelaunch: true)
            
        })
        
    case .installing:
        break
    default:
        resetUpdater()
    }
}


private final class UpdateDriver : SUBasicUpdateDriver {
    
    
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
    
    override func checkForUpdates(at URL: URL!, host aHost: SUHost!) {
        updateState {
            return $0.withUpdatedLoadingState(.initializing)
        }
        super.checkForUpdates(at: URL, host: aHost)
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
            return state.withUpdatedLoadingState(.failed(error! as NSError))
        }
    }
    
    override func abortUpdateWithError(_ error: Error!) {
        super.abortUpdateWithError(error)
        updateState { state in
            return state.withUpdatedLoadingState(.failed(error! as NSError))
        }
    }
    
    override func installer(for host: SUHost!, failedWithError error: Error!) {
        super.installer(for: host, failedWithError: error)
        updateState { state in
            return state.withUpdatedLoadingState(.failed(error! as NSError))
        }
    }
}




struct AppUpdateState : Equatable {
    let items: [SUAppcastItem]
    let loadingState: AppUpdateLoadingState
    
    fileprivate init(items: [SUAppcastItem], loadingState: AppUpdateLoadingState) {
        self.items = items
        self.loadingState = loadingState
        
    }
    fileprivate func withUpdatedItems(_ items: [SUAppcastItem]) -> AppUpdateState {
        return AppUpdateState(items: items, loadingState: self.loadingState)
    }
    fileprivate func withUpdatedLoadingState(_ loadingState: AppUpdateLoadingState) -> AppUpdateState {
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
        entries.append(.general(sectionId: sectionId, index: index, value: .none, error: nil, identifier: _id_check_for_updates, data: InputDataGeneralData(name: L10n.appUpdateCheckForUpdates, color: theme.colors.blueUI, icon: nil, type: .none, action: nil)))
        index += 1
        
        entries.append(.desc(sectionId: sectionId, index: index, text: .plain(error.localizedDescription), color: theme.colors.redUI, detectBold: false))
        index += 1
        
    case let .hasUpdate(item):
        
        entries.append(.general(sectionId: sectionId, index: index, value: .none, error: nil, identifier: _id_download_update, data: InputDataGeneralData(name: L10n.appUpdateDownloadUpdate, color: theme.colors.blueUI, icon: nil, type: .none, action: nil)))
        index += 1
        
        currentItem = item
    case .initializing:
        entries.append(.general(sectionId: sectionId, index: index, value: .none, error: nil, identifier: _id_initializing, data: InputDataGeneralData(name: L10n.appUpdateRetrievingInfo, color: theme.colors.grayText, icon: nil, type: .none, action: nil)))
        index += 1
    case let .loading(item, current, total):
        
        entries.append(.general(sectionId: sectionId, index: index, value: .none, error: nil, identifier: _id_downloading, data: InputDataGeneralData(name: "\(L10n.appUpdateDownloading)  \(String.prettySized(with: current) + " / " + String.prettySized(with: total))", color: theme.colors.grayText, icon: nil, type: .none, action: nil)))
        index += 1
        
        currentItem = item
    case .uptodate:
        entries.append(.general(sectionId: sectionId, index: index, value: .none, error: nil, identifier: _id_check_for_updates, data: InputDataGeneralData(name: L10n.appUpdateCheckForUpdates, color: theme.colors.blueUI, icon: nil, type: .none, action: nil)))
        index += 1
        
        entries.append(.desc(sectionId: sectionId, index: index, text: .plain(L10n.appUpdateUptodate), color: theme.colors.grayText, detectBold: false))
        index += 1
    case let .unarchiving(item):
        entries.append(.general(sectionId: sectionId, index: index, value: .none, error: nil, identifier: _id_unarchiving, data: InputDataGeneralData(name: L10n.appUpdateUnarchiving, color: theme.colors.grayText, icon: nil, type: .none, action: nil)))
        index += 1
        
        currentItem = item
    case let .readyToInstall(item):
        entries.append(.general(sectionId: sectionId, index: index, value: .none, error: nil, identifier: _id_install_update, data: InputDataGeneralData(name: L10n.updateUpdateTelegram, color: theme.colors.blueUI, icon: nil, type: .none, action: nil)))
        index += 1
        
        currentItem = item
    case .installing:
        break
    }
    
    
    if let item = currentItem {
        
        entries.append(.desc(sectionId: sectionId, index: index, text: .plain(L10n.appUpdateNewestAvailable), color: theme.colors.grayText, detectBold: false))
        index += 1
        
        entries.append(.sectionId(sectionId, type: .normal))
        sectionId += 1
        
        entries.append(InputDataEntry.custom(sectionId: sectionId, index: index, value: .none, identifier: InputDataIdentifier("new"), equatable: nil, item: { initialSize, stableId in
            let item = GeneralTextRowItem(initialSize, stableId: stableId, text: L10n.appUpdateTitleNew(APP_VERSION_STRING), drawCustomSeparator: true, inset: NSEdgeInsets(left: 30.0, right: 30.0, top:2, bottom:6))
            return item
        }))
    
        let text = "**" + item.versionTitle + "**" + "\n" + item.updateText
        entries.append(InputDataEntry.custom(sectionId: sectionId, index: index, value: .none, identifier: InputDataIdentifier(item.fileURL.path), equatable: nil, item: { initialSize, stableId in
            return GeneralTextRowItem(initialSize, stableId: stableId, text: text, textColor: theme.colors.text, fontSize: 13, isTextSelectable: true)
        }))
        index += 1
    }
    
    
    if !state.items.isEmpty {
        entries.append(.sectionId(sectionId, type: .normal))
        sectionId += 1
        
        
        entries.append(InputDataEntry.custom(sectionId: sectionId, index: index, value: .none, identifier: InputDataIdentifier("previous"), equatable: nil, item: { initialSize, stableId in
            let item = GeneralTextRowItem(initialSize, stableId: stableId, text: L10n.appUpdateTitlePrevious, drawCustomSeparator: true, inset: NSEdgeInsets(left: 30.0, right: 30.0, top:2, bottom:6))
            return item
        }))
        
    }
   
    
    for item in state.items {
        if item.versionString != currentItem?.versionString {
            let text = "**" + item.versionTitle + "**" + "\n" + item.updateText
            entries.append(InputDataEntry.custom(sectionId: sectionId, index: index, value: .none, identifier: InputDataIdentifier(item.fileURL.path), equatable: nil, item: { initialSize, stableId in
                return GeneralTextRowItem(initialSize, stableId: stableId, text: text, textColor: theme.colors.text, fontSize: 13, isTextSelectable: true)
            }))
            index += 1
            entries.append(.sectionId(sectionId, type: .normal))
            sectionId += 1
        }
       
    }
    
    entries.append(.sectionId(sectionId, type: .normal))
    sectionId += 1

//




    
    return entries
}



func AppUpdateViewController() -> InputDataController {
    
    let signal: Signal<InputDataSignalValue, NoError> = statePromise.get() |> map { value in
        return appUpdateEntries(state: value)
    } |> map { InputDataSignalValue(entries: $0) }
    

    return InputDataController(dataSignal: signal, title: L10n.appUpdateTitle, validateData: { data in
        
        if let _ = data[_id_download_update] {
            driver.downloadUpdate()
        }
        if let _ = data[_id_check_for_updates] {
            resetUpdater()
        }
        if let _ = data[_id_install_update] {
            driver.install(withToolAndRelaunch: true)
        }
        
        return .none
    }, afterDisappear: {

    }, hasDone: false, identifier: "app_update")
    
    
}


private let disposable = MetaDisposable()


func setAppUpdaterBaseDomain(_ basicDomain: String?) {
    updater.basicDomain = basicDomain
}

func resetUpdater() {
    
    let update:()->Void = {
        var url = Bundle.main.infoDictionary!["SUFeedURL"] as! String
        
        if let basicDomain = updater.basicDomain {
            let previous = URL(string: url)!
            let current = URL(string: basicDomain)!
            url = url.replacingOccurrences(of: previous.host!, with: current.host!)
        }
        let state = stateValue.with { $0.loadingState }
        switch state {
        case .readyToInstall, .installing, .unarchiving, .loading:
            break
        default:
            driver.checkForUpdates(at: URL(string: url)!, host: host)
        }
    }
    
    let signal: Signal<Never, NoError> = Signal { subscriber in
        update()
        subscriber.putCompletion()
        return EmptyDisposable
    } |> delay(20 * 60, queue: .mainQueue()) |> restart
    disposable.set(signal.start())
    
    update()
}

func updateAppIfNeeded() {
    let state = stateValue.with {$0.loadingState}
    
    switch state {
    case .readyToInstall:
        driver.install(withToolAndRelaunch: false, displayingUserInterface: true)
    default:
        break
    }
}
#endif
