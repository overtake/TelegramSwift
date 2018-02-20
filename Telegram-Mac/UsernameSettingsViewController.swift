//
//  UsernameSettingsViewController.swift
//  TelegramMac
//
//  Created by keepcoder on 15/11/2016.
//  Copyright © 2016 Telegram. All rights reserved.
//

import Cocoa
import TGUIKit
import TelegramCoreMac
import PostboxMac
import SwiftSignalKitMac


fileprivate enum UsernameEntries : Comparable, Identifiable {
    case whiteSpace(Int64, CGFloat)
    case inputEntry(placeholder:String, state:AddressNameAvailabilityState)
    case stateEntry(text:String, color:NSColor)
    case descEntry(String)
    
    var index:Int64 {
        switch self {
        case let .whiteSpace(index, _):
            return index
        case .inputEntry:
            return 1000
        case .stateEntry:
            return 2000
        case .descEntry:
            return 3000
        }
    }
    
    fileprivate var stableId:Int64 {
        return index
    }

}

fileprivate func <(lhs:UsernameEntries, rhs:UsernameEntries) ->Bool {
    return lhs.index < rhs.index
}

fileprivate func ==(lhs:UsernameEntries, rhs:UsernameEntries) ->Bool {
    switch lhs {
    case let .whiteSpace(lhsIndex, lhsHeight):
        if case let .whiteSpace(rhsIndex, rhsHeight) = rhs {
            return lhsIndex == rhsIndex && lhsHeight == rhsHeight
        }
        return false
    case let .inputEntry(lhsState):
        if case let .inputEntry(rhsState) = rhs , lhsState.state == rhsState.state {
            return true
        }
        return false
    case let .stateEntry(lhsState):
        if case let .stateEntry(rhsState) = rhs, lhsState == rhsState {
            return true
        }
        return false
    case let .descEntry(lhsDesc):
        if case let .descEntry(rhsDesc) = rhs, lhsDesc == rhsDesc {
            return true
        }
        return false
    }
}

fileprivate func prepareEntries(from:[AppearanceWrapperEntry<UsernameEntries>], to:[AppearanceWrapperEntry<UsernameEntries>], account:Account, initialSize:NSSize, animated:Bool, availability:ValuePromise<String>) -> Signal<TableUpdateTransition,Void> {
    return Signal { subscriber in
    
        let (removed, inserted, updated) = proccessEntriesWithoutReverse(from, right: to, { entry -> TableRowItem in
            switch entry.entry {
            case let .whiteSpace(index, height):
                return GeneralRowItem(initialSize, height: height, stableId: index)
            case let .inputEntry(inputState):
                
                return UsernameInputRowItem(initialSize, stableId: entry.stableId, placeholder: inputState.placeholder, limit: 30, status: nil, text: inputState.state.username ?? "", changeHandler: { value in
                    availability.set(value)
                })
            case let .stateEntry(state):
                return GeneralTextRowItem(initialSize, stableId: entry.stableId, text: NSAttributedString.initialize(string: state.text, color: state.color, font: .normal(.text)), alignment: .left, inset:NSEdgeInsets(left: 30.0, right: 30.0, top:6, bottom:4))
            case let .descEntry(desc):
                return GeneralTextRowItem(initialSize, stableId: entry.stableId, text: desc)
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
        let button = TextButtonBarView(controller: self, text: tr(L10n.usernameSettingsDone))
        
        button.set(handler: { [weak self] _ in
            self?.saveUsername()
        }, for: .Click)
        
        return button
    }
    
 
    
    func saveUsername() {
        if let item = genericView.item(stableId: Int64(1000)) as? UsernameInputRowItem, let window = window {
            updateDisposable.set(showModalProgress(signal: updateAddressName(account: account, domain: .account, name: item.text) |> mapError({_ in}), for: window).start())
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
        

    
        let previous:Atomic<[AppearanceWrapperEntry<UsernameEntries>]> = Atomic(value:[])
        let entries:Promise<[UsernameEntries]> = Promise()
        let initialSize = self.atomicSize.modify({$0})
        let account = self.account
        let availability = self.availability
        var mutableItems:[UsernameEntries] = [.whiteSpace(0, 16),
                                              .inputEntry(placeholder: tr(L10n.usernameSettingsInputPlaceholder), state:.none(username: nil)),
                                              .descEntry(tr(L10n.usernameSettingsChangeDescription))]
        
        

        username.set(account.viewTracker.peerView( account.peerId) |> deliverOnMainQueue |> mapToSignal { peerView -> Signal<String, Void> in
            if let peer = peerView.peers[account.peerId] {
                return .single(peer.username ?? "")
            }
            return .complete()
        })
        
        
        self.genericView.merge(with: combineLatest(entries.get(),username.get() |> distinctUntilChanged |> mapToSignal {username -> Signal<String,Void> in
            availability.set(username)
            return .single(username)
        }, appearanceSignal)
        |> deliverOnMainQueue
        |> mapToSignal { items, username, appearance -> Signal<TableUpdateTransition, Void> in
            let items = items.map{AppearanceWrapperEntry(entry: $0, appearance: appearance)}
            return prepareEntries(from: previous.swap(items), to: items, account: account, initialSize: initialSize, animated: true, availability:availability)
        })

        let availabilityChecker = combineLatest(availability.get(), username.get()
            |> distinctUntilChanged)
            |> mapToSignal { (value,username) -> Signal<(AddressNameAvailabilityState,String),Void> in
                if let error = checkAddressNameFormat(value) {
                    return .single((AddressNameAvailabilityState.fail(username: value, formatError: error, availability: .available), username))
                } else {
                    return .single((AddressNameAvailabilityState.progress(username: value), username)) |> then(addressNameAvailability(account: account, domain: .account, name: value)
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
            |> mapToSignal { [weak self] (availability,address) -> Signal<Void, Void> in
                mutableItems[1] = .inputEntry(placeholder: tr(L10n.usernameSettingsInputPlaceholder), state:availability)
                
                switch availability {
                case .none:
                    if case .stateEntry = mutableItems[2] {
                        mutableItems.remove(at: 2)
                    }
                    self?.doneButton?.isEnabled = true
                    break
                case .progress:
                    self?.doneButton?.isEnabled = false
                    break
                case let .success(username:username):
                    if case .stateEntry = mutableItems[2] {
                        mutableItems.remove(at: 2)
                    }
                    if address != username {
                        if username?.length != 0 {
                            mutableItems.insert(.stateEntry(text:tr(L10n.usernameSettingsAvailable(username ?? "")), color: theme.colors.blueUI), at: 2)
                        }
                    }
                    self?.doneButton?.isEnabled = address != username
                case let .fail(fail):
                    if case .stateEntry = mutableItems[2] {
                        mutableItems.remove(at: 2)
                    }
                    
                    let enabled = fail.username?.length == 0 && address.length != 0
                    
                    let stateEntry:UsernameEntries
                    if let error = fail.formatError {
                        stateEntry = .stateEntry(text: error.description, color: theme.colors.redUI)
                    } else {
                        stateEntry = .stateEntry(text: fail.availability.description(for: address), color: theme.colors.redUI)
                    }
                    if fail.username?.length != 0 {
                        mutableItems.insert(stateEntry, at: 2)
                    }
                    self?.doneButton?.isEnabled = enabled
                }
                entries.set(.single(mutableItems))
                
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
        if let item = genericView.item(stableId: Int64(1000)), let view = genericView.viewNecessary(at: item.index) as? GeneralInputRowView {
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


