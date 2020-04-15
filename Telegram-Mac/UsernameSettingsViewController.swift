//
//  UsernameSettingsViewController.swift
//  TelegramMac
//
//  Created by keepcoder on 15/11/2016.
//  Copyright © 2016 Telegram. All rights reserved.
//

import Cocoa
import TGUIKit
import TelegramCore
import SyncCore
import Postbox
import SwiftSignalKit

fileprivate enum UsernameEntryId : Hashable {
    case section(Int32)
    case inputEntry
    case stateEntry
    case descEntry
    
}

fileprivate enum UsernameEntry : Comparable, Identifiable {
    case section(Int32)
    case inputEntry(sectionId: Int32, placeholder:String, state:AddressNameAvailabilityState, viewType: GeneralViewType)
    case stateEntry(sectionId:Int32, text:String, color:NSColor, viewType: GeneralViewType)
    case descEntry(sectionId:Int32, text: String, viewType: GeneralViewType)
    
    var index:Int32 {
        switch self {
        case let .section(sectionId):
            return (sectionId + 1) * 1000 - sectionId
        case let .inputEntry(sectionId, _, _, _):
             return (sectionId * 1000) + 1
        case let .stateEntry(sectionId, _, _, _):
             return (sectionId * 1000) + 2
        case let .descEntry(sectionId, _, _):
             return (sectionId * 1000) + 3
        }
    }
    
    fileprivate var stableId:UsernameEntryId {
        switch self {
        case let .section(index):
            return .section(index)
        case .inputEntry:
            return .inputEntry
        case .stateEntry:
            return .stateEntry
        case .descEntry:
            return .descEntry
        }
    }

}

fileprivate func <(lhs:UsernameEntry, rhs:UsernameEntry) ->Bool {
    return lhs.index < rhs.index
}

fileprivate func prepareEntries(from:[AppearanceWrapperEntry<UsernameEntry>], to:[AppearanceWrapperEntry<UsernameEntry>], initialSize:NSSize, animated:Bool, availability:ValuePromise<String>) -> Signal<TableUpdateTransition, NoError> {
    return Signal { subscriber in
    
        let (removed, inserted, updated) = proccessEntriesWithoutReverse(from, right: to, { entry -> TableRowItem in
            switch entry.entry {
            case .section:
                return GeneralRowItem(initialSize, height: 30, stableId: entry.stableId, viewType: .separator)
            case let .inputEntry(inputState):
                return InputDataRowItem(initialSize, stableId: entry.stableId, mode: .plain, error: nil, viewType: inputState.viewType, currentText: inputState.state.username ?? "", placeholder: nil, inputPlaceholder: inputState.placeholder, filter: { $0 }, updated: { value in
                     availability.set(value)
                }, limit: 30)
            case let .stateEntry(_, text, color, viewType):
                return GeneralTextRowItem(initialSize, stableId: entry.stableId, text: NSAttributedString.initialize(string: text, color: color, font: .normal(.text)), viewType: viewType)
            case let .descEntry(_, text, viewType):
                return GeneralTextRowItem(initialSize, stableId: entry.stableId, text: text, viewType: viewType)
            }
        })
        
        subscriber.putNext(TableUpdateTransition(deleted: removed, inserted: inserted, updated: updated, animated: animated))
        subscriber.putCompletion()
        return EmptyDisposable
    }
}

class UsernameSettingsViewController: TableViewController {

    private let disposable:MetaDisposable = MetaDisposable()
    
    private let availability:ValuePromise<String> = ValuePromise(ignoreRepeated: true)
    private let availabilityDisposable:MetaDisposable = MetaDisposable()
    
    private let username:Promise<String> = Promise()
    
    private let updateDisposable:MetaDisposable = MetaDisposable()
    
    override var removeAfterDisapper:Bool {
        return true
    }
    
    var doneButton:Control? {
        return rightBarView
    }
    
    override func backKeyAction() -> KeyHandlerResult {
        return .invokeNext
    }
    
    override func getRightBarViewOnce() -> BarView {
        let button = TextButtonBarView(controller: self, text: L10n.usernameSettingsDone)
        
        button.set(handler: { [weak self] _ in
            self?.saveUsername()
        }, for: .Click)
        
        return button
    }
    
 
    
    func saveUsername() {
        if let item = genericView.item(stableId: AnyHashable(UsernameEntryId.inputEntry)) as? InputDataRowItem, let window = window {
            updateDisposable.set(showModalProgress(signal: updateAddressName(account: context.account, domain: .account, name: item.currentText), for: window).start(error: { error in
                switch error {
                case .generic:
                    alert(for: mainWindow, info: L10n.unknownError)
                }
            }, completed: { [weak self] in
                self?.navigationController?.back()
                _ = showModalSuccess(for: mainWindow, icon: theme.icons.successModalProgress, delay: 0.5).start()
            }))
        }
    }
    
    
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        self.window?.set(handler: { [weak self] () -> KeyHandlerResult in
            if let rightView = self?.rightBarView as? TextButtonBarView, rightView.isEnabled  {
                self?.saveUsername()
                return .rejected
            }
            return .rejected
        }, with: self, for: .Return, priority: .high)
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        

    
        let previous:Atomic<[AppearanceWrapperEntry<UsernameEntry>]> = Atomic(value:[])
        let entries:Promise<[UsernameEntry]> = Promise()
        let initialSize = self.atomicSize.modify({$0})
        let context = self.context
        let availability = self.availability
        
        

        username.set(context.account.viewTracker.peerView( context.peerId) |> deliverOnMainQueue |> mapToSignal { peerView -> Signal<String, NoError> in
            if let peer = peerView.peers[context.peerId] {
                return .single(peer.username ?? "")
            }
            return .complete()
        })
        
        
        self.genericView.merge(with: combineLatest(entries.get(),username.get() |> distinctUntilChanged |> mapToSignal {username -> Signal<String, NoError> in
            availability.set(username)
            return .single(username)
        }, appearanceSignal)
        |> deliverOnMainQueue
        |> mapToSignal { items, username, appearance -> Signal<TableUpdateTransition, NoError> in
            let items = items.map{AppearanceWrapperEntry(entry: $0, appearance: appearance)}
            return prepareEntries(from: previous.swap(items), to: items, initialSize: initialSize, animated: true, availability:availability)
        })

        let availabilityChecker = combineLatest(availability.get(), username.get()
            |> distinctUntilChanged)
            |> mapToSignal { (value,username) -> Signal<(AddressNameAvailabilityState,String), NoError> in
                if let error = checkAddressNameFormat(value) {
                    return .single((AddressNameAvailabilityState.fail(username: value, formatError: error, availability: .available), username))
                } else {
                    return .single((AddressNameAvailabilityState.progress(username: value), username)) |> then(addressNameAvailability(account: context.account, domain: .account, name: value)
                        |> map { availability -> (AddressNameAvailabilityState,String) in
                        switch availability {
                        case .available:
                            return (AddressNameAvailabilityState.success(username: value), username)
                        case .invalid:
                            return (AddressNameAvailabilityState.fail(username: value, formatError: .invalidCharacters, availability: availability), username)
                        case .taken:
                            return (AddressNameAvailabilityState.fail(username: value, formatError: nil, availability: availability), username)
                        }
                    })
                }
            }
            |> deliverOnMainQueue
            |> mapToSignal { [weak self] (availability,address) -> Signal<Void, NoError> in
                //        var mutableItems:[UsernameEntry] = [.whiteSpace(0, 16),
 //               .inputEntry(placeholder: tr(L10n.usernameSettingsInputPlaceholder), state:.none(username: nil)),
//                .descEntry(tr(L10n.usernameSettingsChangeDescription))]

                var items:[UsernameEntry] = []
                var sectionId: Int32 = 0
                
                items.append(.section(sectionId))
                sectionId += 1
                
                items.append(.inputEntry(sectionId: sectionId, placeholder: L10n.usernameSettingsInputPlaceholder, state: availability, viewType: .singleItem))
                
                switch availability {
                case .none:
                    self?.doneButton?.isEnabled = true
                    break
                case .progress:
                    self?.doneButton?.isEnabled = false
                    break
                case let .success(username:username):
                    if address != username {
                        if username?.length != 0 {
                            items.append(.stateEntry(sectionId: sectionId, text: L10n.usernameSettingsAvailable(username ?? ""), color: theme.colors.accent, viewType: .textBottomItem))
                        }
                    }
                    self?.doneButton?.isEnabled = address != username
                case let .fail(fail):
                    let enabled = fail.username?.length == 0 && address.length != 0
                     let stateEntry:UsernameEntry
                    if let error = fail.formatError {
                        stateEntry = .stateEntry(sectionId: sectionId, text: error.description, color: theme.colors.redUI, viewType: .textBottomItem)
                    } else {
                        stateEntry = .stateEntry(sectionId: sectionId, text: fail.availability.description(for: address), color: theme.colors.redUI, viewType: .textBottomItem)
                    }
                    if fail.username?.length != 0 {
                        items.append(stateEntry)
                    }
                    self?.doneButton?.isEnabled = enabled
                }
                
                items.append(.descEntry(sectionId: sectionId, text: L10n.usernameSettingsChangeDescription, viewType: .textBottomItem))

                
                items.append(.section(sectionId))
                sectionId += 1
                
                entries.set(.single(items))
                
                self?.readyOnce()
                return .single(Void())
            }
        
     
        availabilityDisposable.set(availabilityChecker.start())
        
       
    }
    
    override func viewWillDisappear(_ animated: Bool) {
        self.window?.remove(object: self, for: .Return)
    }
    
    override var canBecomeResponder: Bool {
        return true
    }
    
    override func becomeFirstResponder() -> Bool? {
        return true
    }
    
    override func firstResponder() -> NSResponder? {
        if let view = genericView.item(at: 1).view as? InputDataRowView {
            return view.textView
        }
        return nil
    }
    

    
    deinit {
        disposable.dispose()
        availabilityDisposable.dispose()
        updateDisposable.dispose()
    }
    
}


