//
//  InputDataController.swift
//  Telegram
//
//  Created by Mikhail Filimonov on 21/03/2018.
//  Copyright © 2018 Telegram. All rights reserved.
//

import Cocoa
import TGUIKit
import TelegramCoreMac
import SwiftSignalKitMac

final class InputDataArguments {
    let select:((InputDataIdentifier, InputDataValue))->Void
    let dataUpdated:()->Void
    init(select: @escaping((InputDataIdentifier, InputDataValue))->Void, dataUpdated:@escaping()->Void) {
        self.select = select
        self.dataUpdated = dataUpdated
    }
}

fileprivate func prepareTransition(left:[AppearanceWrapperEntry<InputDataEntry>], right: [AppearanceWrapperEntry<InputDataEntry>], initialSize:NSSize, arguments: InputDataArguments) -> TableUpdateTransition {
    let (removed, inserted, updated) = proccessEntriesWithoutReverse(left, right: right) { entry -> TableRowItem in
        return entry.entry.item(arguments: arguments, initialSize: initialSize)
    }
    return TableUpdateTransition(deleted: removed, inserted: inserted, updated: updated, animated: true)
}



class InputDataController: TableViewController {

    private let values: Promise<[InputDataEntry]> = Promise()
    private let disposable = MetaDisposable()
    private let title: String
    private let validateData:([InputDataIdentifier : InputDataValue]) -> InputDataValidation
    private let afterDisappear: ()->Void
    private let updateDatas:([InputDataIdentifier : InputDataValue]) -> Void
    init(_ account: Account, dataSignal:Signal<[InputDataEntry], Void>, title: String, validateData:@escaping([InputDataIdentifier : InputDataValue]) -> InputDataValidation = {_ in return .fail(.none)}, updateDatas: @escaping([InputDataIdentifier : InputDataValue]) -> Void = {_ in}, afterDisappear: @escaping() -> Void = {}) {
        self.title = title
        self.validateData = validateData
        self.afterDisappear = afterDisappear
        self.updateDatas = updateDatas
        super.init(account)
        values.set(dataSignal)
    }
    
    override var defaultBarTitle: String {
        return title
    }
    
    override func getRightBarViewOnce() -> BarView {
        return TextButtonBarView(controller: self, text: L10n.navigationDone, style: navigationButtonStyle, alignment:.Right)
    }
    
    private func fetchData() -> [InputDataIdentifier : InputDataValue] {
        var values:[InputDataIdentifier : InputDataValue] = [:]
        genericView.enumerateItems { item -> Bool in
            if let identifier = (item.stableId.base as? InputDataEntryId)?.identifier {
                if let item = item as? InputDataRowDataValue {
                    values[identifier] = item.value
                }
            }
            return true
        }
        return values
    }
    
    private func findItem(for identifier: InputDataIdentifier) -> TableRowItem? {
        var item: TableRowItem?
        genericView.enumerateItems { current -> Bool in
            if let stableId = current.stableId.base as? InputDataEntryId {
                if  stableId.identifier == identifier {
                    item = current
                }
            }
            return item == nil
        }
        return item
    }
    
    private func proccessValidation(_ validation: InputDataValidation) {
        switch validation {
        case let .fail(fail):
            switch fail {
            case let .alert(text):
                alert(for: mainWindow, info: text)
            case let .fields(fields):
                for (identifier, action) in fields {
                    switch action {
                    case .shake:
                        findItem(for: identifier)?.view?.shakeView()
                    }
                }
            case let .doSomething(next):
                next { [weak self] validation in
                    self?.proccessValidation(validation)
                }
            default:
                //TODO IF NEEDED
                break
            }
        case let .success(behaviour):
            switch behaviour {
            case .navigationBack:
                navigationController?.back()
            case let .custom(action):
                action()
            }
        }
    }
    
    private func validateInput(data: [InputDataIdentifier : InputDataValue]) {
        proccessValidation(self.validateData(data))
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        
        let arguments = InputDataArguments(select: { [weak self] (identifier, value) in
            guard let `self` = self else {return}
            self.validateInput(data: [identifier : value])
        }, dataUpdated: { [weak self] in
            guard let `self` = self else {return}
            self.updateDatas(self.fetchData())
        })
        
        self.rightBarView.set(handler:{ [weak self] _ in
            guard let `self` = self else {return}
            self.validateInput(data: self.fetchData())
        }, for: .Click)
        
        let previous: Atomic<[AppearanceWrapperEntry<InputDataEntry>]> = Atomic(value: [])
        let initialSize = self.atomicSize
        
        let signal: Signal<TableUpdateTransition, Void> = combineLatest(appearanceSignal |> deliverOnPrepareQueue, values.get() |> deliverOnPrepareQueue) |> map { appearance, entries in
            let entries = entries.map({AppearanceWrapperEntry(entry: $0, appearance: appearance)})
            return prepareTransition(left: previous.swap(entries), right: entries, initialSize: initialSize.modify{$0}, arguments: arguments)
        } |> deliverOnMainQueue
        
        disposable.set(signal.start(next: { [weak self] transition in
            self?.genericView.merge(with: transition)
            self?.readyOnce()
        }))
    }
    
    override func returnKeyAction() -> KeyHandlerResult {
         self.validateInput(data: self.fetchData())
         return .invoked
    }
    
    override func becomeFirstResponder() -> Bool? {
        return true
    }
    
    override var canBecomeResponder: Bool {
        return true
    }
    
    override func didRemovedFromStack() {
        super.didRemovedFromStack()
        afterDisappear()
    }
    
    override func firstResponder() -> NSResponder? {
        if self.window?.firstResponder == self.window {
            var first: NSResponder? = nil
            
            genericView.enumerateViews { view -> Bool in
                if let view = view as? InputDataRowView {
                    first = view.firstResponder
                }
                return first == nil
            }
            return first
        }
        return window?.firstResponder
    }

    override func backSettings() -> (String, CGImage?) {
        return ("", theme.icons.instantViewBack)
    }
    
    
    override var haveNextResponder: Bool {
        return true
    }
    
    override func backKeyAction() -> KeyHandlerResult {
        return .invokeNext
    }
    
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        
        window?.set(mouseHandler: { [weak self] event -> KeyHandlerResult in
            guard let `self` = self else {return .rejected}
            
            let index = self.genericView.row(at: self.genericView.documentView!.convert(event.locationInWindow, from: nil))
            
            if index > 0, let view = self.genericView.item(at: index).view {
                if view.mouseInsideField {
                    self.window?.makeFirstResponder(view.firstResponder)
                    return .invoked
                }
            }
            
            return .rejected
        }, with: self, for: .leftMouseDown)
        
    }
    
    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillAppear(animated)
        window?.remove(object: self, for: .leftMouseDown)
    }
    
    override func nextResponder() -> NSResponder? {
        var next: NSResponder?
        let current = self.window?.firstResponder
        var selectNext: Bool = false
        
        var first: NSResponder? = nil
        
        genericView.enumerateViews { view -> Bool in
            if let view = view as? InputDataRowView {
                first = view.firstResponder
            }
            return first == nil
        }
        
        genericView.enumerateViews { view -> Bool in
            if let view = view as? InputDataRowView {
                if selectNext {
                    next = view.firstResponder
                } else if view.firstResponder == current || view.firstResponder == (current as? NSView)?.superview?.superview {
                    selectNext = true
                    return true
                }
            }
            return next == nil
        }
        return next ?? first
    }
    
    override var removeAfterDisapper: Bool {
        return true
    }
    
    deinit {
        disposable.dispose()
    }
    
}
