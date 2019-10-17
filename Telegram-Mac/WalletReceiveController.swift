//
//  WalletReceiveController.swift
//  Telegram
//
//  Created by Mikhail Filimonov on 23/09/2019.
//  Copyright © 2019 Telegram. All rights reserved.
//

import Cocoa
import TelegramCoreMac
import SwiftSignalKitMac
import TGUIKit


private final class WalletReceiveArguments {
    let context: AccountContext
    let copy:()->Void
    let share:()->Void
    let createInvoice: ()->Void
    init(context: AccountContext, copy: @escaping()->Void, share: @escaping()->Void, createInvoice: @escaping()->Void) {
        self.context = context
        self.copy = copy
        self.share = share
        self.createInvoice = createInvoice
    }
}

private struct WalletReceiveState : Equatable {
    let address: String
    init(address: String) {
        self.address = address
    }
}
private let _id_address = InputDataIdentifier("_id_address")
private let _id_copy = InputDataIdentifier("_id_copy")
private let _id_share = InputDataIdentifier("_id_share")
private let _id_create_invoice = InputDataIdentifier("_id_create_invoice")
private func walletReceiveEntries(state: WalletReceiveState, arguments: WalletReceiveArguments) -> [InputDataEntry] {
    var entries:[InputDataEntry] = []
    
    var sectionId:Int32 = 0
    var index:Int32 = 0
    
    entries.append(.sectionId(sectionId, type: .normal))
    sectionId += 1
    
    
    entries.append(.desc(sectionId: sectionId, index: index, text: .plain(L10n.walletReceiveYourWalletAddress), data: InputDataGeneralTextData(viewType: .textTopItem)))
    index += 1
    
    
    entries.append(.custom(sectionId: sectionId, index: index, value: .none, identifier: _id_address, equatable: InputDataEquatable(state.address), item: { initialSize, stableId in
        let addressString: String
        if state.address.count % 2 == 0 {
            addressString = String(state.address.prefix(state.address.count / 2) + "\n" + state.address.suffix(state.address.count / 2))
        } else {
            addressString = state.address
        }
        return GeneralBlockTextRowItem(initialSize, stableId: stableId, viewType: .firstItem, text: addressString, font: .code(.text))
    }))
    index += 1

    entries.append(.general(sectionId: sectionId, index: index, value: .none, error: nil, identifier: _id_copy, data: InputDataGeneralData(name: L10n.walletReceiveCopyWalletAddress, color: theme.colors.accent, type: .none, viewType: .innerItem, action: arguments.copy)))
    index += 1

    entries.append(.general(sectionId: sectionId, index: index, value: .none, error: nil, identifier: _id_share, data: InputDataGeneralData(name: L10n.walletReceiveShareWalletAddress, color: theme.colors.accent, type: .none, viewType: .lastItem, action: arguments.share)))
    index += 1

    entries.append(.desc(sectionId: sectionId, index: index, text: .plain(L10n.walletReceiveShareWalletDesc), data: InputDataGeneralTextData(viewType: .textBottomItem)))
    index += 1
    
    entries.append(.sectionId(sectionId, type: .normal))
    sectionId += 1
    
    entries.append(.general(sectionId: sectionId, index: index, value: .none, error: nil, identifier: _id_create_invoice, data: InputDataGeneralData(name: L10n.walletReceiveCreateInvoice, color: theme.colors.accent, type: .none, viewType: .singleItem, action: arguments.createInvoice)))
    index += 1
    
    entries.append(.desc(sectionId: sectionId, index: index, text: .plain(L10n.walletReceiveCreateInvoiceDesc), data: InputDataGeneralTextData(viewType: .textBottomItem)))
    index += 1
    
    entries.append(.sectionId(sectionId, type: .normal))
    sectionId += 1
    
    return entries
}

func WalletReceiveController(context: AccountContext, tonContext: TonContext, address: String) -> InputDataModalController {
    let initialState = WalletReceiveState(address: address)
    let state: ValuePromise<WalletReceiveState> = ValuePromise(initialState)
    let stateValue: Atomic<WalletReceiveState> = Atomic(value: initialState)
    
    let updateState:((WalletReceiveState)->WalletReceiveState) -> Void = { f in
        state.set(stateValue.modify(f))
    }
    
    var getController:(()->InputDataController?)? = nil
    
    let arguments = WalletReceiveArguments(context: context, copy: {
        copyToClipboard(address)
        getController?()?.show(toaster: ControllerToaster(text: L10n.shareLinkCopied))
    }, share: {
        showModal(with: ShareModalController(ShareLinkObject(context, link: "ton://transfer/\(escape(with: address, addPercent: true))")), for: context.window)
    }, createInvoice: {
        showModal(with: WalletInvoiceController(context: context, tonContext: tonContext, address: address), for: context.window)
    })
    
    let dataSignal = state.get() |> deliverOnPrepareQueue |> map { state in
        return walletReceiveEntries(state: state, arguments: arguments)
    } |> map { entries in
        return InputDataSignalValue(entries: entries)
    }
    
    var getModalController:(()->InputDataModalController?)? = nil

    
    let controller = InputDataController(dataSignal: dataSignal, title: L10n.walletReceiveTitle)
    
    controller.leftModalHeader = ModalHeaderData(image: theme.icons.wallet_close, handler: {
        getModalController?()?.close()
    })
    
    getController = { [weak controller] in
        return controller
    }
    
    let modalController = InputDataModalController(controller, closeHandler: { f in
        f()
    }, size: NSMakeSize(350, 350))
    
    getModalController = { [weak modalController] in
        return modalController
    }
    
    
    return modalController
}
