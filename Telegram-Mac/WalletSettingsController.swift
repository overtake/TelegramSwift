//
//  WalletSettingsController.swift
//  Telegram
//
//  Created by Mikhail Filimonov on 01/10/2019.
//  Copyright © 2019 Telegram. All rights reserved.
//

import Cocoa
import TelegramCoreMac
import PostboxMac
import SwiftSignalKitMac
import TGUIKit

private final class WalletSettingsArguments {
    let context: AccountContext
    let deleteWallet:()->Void
    init(context: AccountContext, deleteWallet: @escaping()->Void) {
        self.context = context
        self.deleteWallet = deleteWallet
    }
}

private let _id_delete_wallet = InputDataIdentifier("_id_delete_wallet")

private func walletSettingsEntries(arguments: WalletSettingsArguments) -> [InputDataEntry] {
    var entries:[InputDataEntry] = []
    var sectionId:Int32 = 0
    var index:Int32 = 0
    
    entries.append(.sectionId(sectionId, type: .normal))
    sectionId += 1
    
    entries.append(.general(sectionId: sectionId, index: index, value: .none, error: nil, identifier: _id_delete_wallet, data: InputDataGeneralData.init(name: L10n.walletSettingsDeleteWallet, color: theme.colors.redUI, viewType: .singleItem, action: arguments.deleteWallet)))
    index += 1
    
    entries.append(.desc(sectionId: sectionId, index: index, text: .plain(L10n.walletSettingsDeleteWalletDesc), data: InputDataGeneralTextData(color: theme.colors.listGrayText, viewType: .textBottomItem)))
    index += 1
    
    entries.append(.sectionId(sectionId, type: .normal))
    sectionId += 1
    
    
    return entries
}
@available(OSX 10.12, *)
func WalletSettingsController(context: AccountContext, tonContext: TonContext, walletInfo: WalletInfo) -> InputDataModalController {

    var getController:(()->InputDataController?)? = nil
    var getModalController:(()->InputDataModalController?)? = nil

    let arguments = WalletSettingsArguments(context: context, deleteWallet: {
        confirm(for: context.window, header: L10n.walletSettingsDeleteConfirmHeader, information: L10n.walletSettingsDeleteConfirmText, okTitle: L10n.walletSettingsDeleteConfirmOK, successHandler: { _ in
            
            let signals = combineLatest(TONKeychain.delete(account: context.account) |> castError(DeleteAllLocalWalletsDataError.self) |> ignoreValues, deleteAllLocalWalletsData(postbox: context.account.postbox, network: context.account.network, tonInstance: tonContext.instance))
            
            let _ = showModalProgress(signal: signals
                |> deliverOnMainQueue, for: context.window).start(error: { error in
                    let text: String
                    switch error {
                    case .generic:
                        text = L10n.unknownError
                    }
                    alert(for: context.window, info: text)
                }, completed: {
                    getModalController?()?.close()
                    context.sharedContext.bindings.rootNavigation().push(WalletSplashController(context: context, tonContext: tonContext, mode: .intro))
                })
       })
    })
    
    let signal:Signal<[InputDataEntry], NoError> = .single(walletSettingsEntries(arguments: arguments))
    
    let dataSignal = signal |> map { entries in
        return InputDataSignalValue(entries: entries)
    }
    
    
    let controller = InputDataController(dataSignal: dataSignal, title: L10n.walletSettingsTitle, hasDone: false)
    
    
    controller.rightModalHeader = ModalHeaderData(image: theme.icons.wallet_close, handler: {
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
