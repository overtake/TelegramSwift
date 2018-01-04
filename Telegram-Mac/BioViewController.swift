//
//  BioViewController.swift
//  Telegram
//
//  Created by keepcoder on 12/07/2017.
//  Copyright © 2017 Telegram. All rights reserved.
//

import Cocoa
import TGUIKit
import PostboxMac
import TelegramCoreMac
import SwiftSignalKitMac

private let bioLimit: Int32 = 70
private final class BioArguments {
    let account: Account
    let updateText:(String)->Void
    init(account:Account, updateText:@escaping(String)->Void) {
        self.account = account
        self.updateText = updateText
    }
}

private enum BioEntry : TableItemListNodeEntry {
    case section(Int32)
    case text(Int32, String)
    case description(Int32)
    
    var stableId: Int32 {
        switch self {
        case .section(let id):
            return (id + 1) * 1000 - id
        case .text:
            return 1
        case .description:
            return 2
        }
    }
    
    var index:Int32 {
        switch self {
        case .section(let id):
            return (id + 1) * 1000 - id
        case .text(let sectionId, _):
            return (sectionId * 1000) + stableId
        case .description(let sectionId):
            return (sectionId * 1000) + stableId
        }
    }
    
    func item(_ arguments: BioArguments, initialSize: NSSize) -> TableRowItem {
        switch self {
        case .section:
            return GeneralRowItem(initialSize, height: 20, stableId: stableId)
        case .text(_, let text):
            return GeneralInputRowItem(initialSize, stableId: stableId, placeholder: tr(L10n.bioPlaceholder), text: text, limit: bioLimit, textChangeHandler: { updated in
                arguments.updateText(updated)
            })
        case .description:
            return GeneralTextRowItem(initialSize, stableId: stableId, text: tr(L10n.bioDescription))
        }
    }
}

private func <(lhs: BioEntry, rhs: BioEntry) -> Bool {
    return lhs.index < rhs.index
}

private func ==(lhs: BioEntry, rhs: BioEntry) -> Bool {
    return lhs.index == rhs.index
}

private func BioEntries(_ cachedData: CachedUserData?, state: BioState) -> [BioEntry] {
    var entries:[BioEntry] = []
    
    var sectionId:Int32 = 1
    entries.append(.section(sectionId))
    sectionId += 1
    
    entries.append(.text(sectionId, state.updatedText ?? cachedData?.about ?? ""))
    entries.append(.description(sectionId))
    return entries
}

private final class BioState : Equatable {
    let updatedText:String?
    let updating: Bool
    let initiated: Bool
    init(updatedText: String? = nil, updating: Bool = false, initiated: Bool = false) {
        self.updatedText = updatedText
        self.updating = updating
        self.initiated = initiated
    }
    func withUpdateUpdating(_ updating: Bool) -> BioState {
        return BioState(updatedText: self.updatedText, updating: updating, initiated: self.initiated)
    }
    
    func withUpdatedInitiated(_ initiated:Bool) -> BioState {
        return BioState(updatedText: self.updatedText, updating: self.updating, initiated: initiated)
    }
    
    func withUpdatedText(_ updatedText:String) -> BioState {
        return BioState(updatedText: updatedText, updating: self.updating, initiated: self.initiated)
    }
}
private func ==(lhs:BioState, rhs: BioState) -> Bool {
    return lhs.updatedText == rhs.updatedText && lhs.updating == rhs.updating && lhs.initiated == rhs.initiated
}

fileprivate func prepareTransition(left:[AppearanceWrapperEntry<BioEntry>], right: [AppearanceWrapperEntry<BioEntry>], initialSize:NSSize, arguments:BioArguments) -> TableUpdateTransition {
    let (removed, inserted, updated) = proccessEntriesWithoutReverse(left, right: right) { entry -> TableRowItem in
        return entry.entry.item(arguments, initialSize: initialSize)
    }
    
    return TableUpdateTransition(deleted: removed, inserted: inserted, updated: updated, animated: true)
}

class BioViewController: EditableViewController<TableView> {
    private let disposable = MetaDisposable()
    private let stateValue = Atomic(value: BioState())
    private let statePromise = ValuePromise<BioState>(BioState())
    
    override var removeAfterDisapper:Bool {
        return true
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        let previous:Atomic<[AppearanceWrapperEntry<BioEntry>]> = Atomic(value: [])
        let initialSize = atomicSize
        
        let arguments = BioArguments(account: account, updateText: { [weak self] text in
            _ = self?.updateState({$0.withUpdatedText(text).withUpdatedInitiated(true)})
            
        })
        
        genericView.merge(with:  combineLatest(account.viewTracker.peerView( account.peerId) |> deliverOnMainQueue, statePromise.get() |> deliverOnMainQueue, appearanceSignal |> deliverOnMainQueue) |> map { [weak self] view, state, appearance in
            
            
            let userData = view.cachedData as? CachedUserData
            let about = userData?.about ?? ""
            self?.set(enabled: !state.updating && state.updatedText != about && state.initiated)
            if state.updatedText == nil {
                _ = self?.stateValue.modify({$0.withUpdatedText(about)})
            }
            self?.requestUpdateCenterBar()
            let entries = BioEntries(userData, state: state).map{AppearanceWrapperEntry(entry: $0, appearance: appearance)}
            return prepareTransition(left: previous.swap(entries), right: entries, initialSize: initialSize.modify{$0}, arguments: arguments)
            
        } |> deliverOnMainQueue)
        readyOnce()
    }
    
    override func requestUpdateCenterBar() {
        super.requestUpdateCenterBar()
        let length = stateValue.modify({$0}).updatedText?.length ?? 0
        setCenterTitle(defaultBarTitle + " (\(bioLimit - Int32(length)))")
    }
    
    private func updateState(_ f:(BioState)->BioState) -> BioState {
        let updatedState = stateValue.modify(f)
        statePromise.set(updatedState)
        return updatedState
    }
    override func backKeyAction() -> KeyHandlerResult {
        return .invokeNext
    }
    
    override func firstResponder() -> NSResponder? {
        if let item = genericView.item(stableId: AnyHashable(Int32(1))) {
            if let view = genericView.viewNecessary(at: item.index) as? GeneralInputRowView {
                return view.textView.inputView
            }
        }
        return nil
    }
    
    override func returnKeyAction() -> KeyHandlerResult {
        changeState()
        return .invoked
    }
    
    override func becomeFirstResponder() -> Bool? {
        return true
    }
    
    override var normalString: String {
        return tr(L10n.bioSave)
    }
    
    override func changeState() {
        
        let state = updateState { state -> BioState in
            return state.withUpdateUpdating(true)
        }
        
        disposable.set(showModalProgress(signal: (updateAbout(account: account, about: state.updatedText) |> deliverOnMainQueue), for: mainWindow).start(error: { [weak self] error in
            _ = self?.updateState({$0.withUpdateUpdating(false).withUpdatedInitiated(true)})
        }, completed: { [weak self] in
            _ = self?.updateState({$0.withUpdateUpdating(false).withUpdatedInitiated(false)})
        }))
    }
    
}
