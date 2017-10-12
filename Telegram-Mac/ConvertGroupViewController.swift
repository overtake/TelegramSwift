//
//  ConvertToSupergroupViewController.swift
//  Telegram
//
//  Created by keepcoder on 21/02/2017.
//  Copyright © 2017 Telegram. All rights reserved.
//

import Cocoa
import TGUIKit
import TelegramCoreMac
import PostboxMac
import SwiftSignalKitMac

class ConvertGroupViewController: TableViewController {
    
    private let peerId:PeerId
    private let convertDisposable:MetaDisposable = MetaDisposable()
    init(account:Account, peerId:PeerId) {
        self.peerId = peerId
        super.init(account)
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        let initialSize = atomicSize.modify({$0})
        
        let desc = NSMutableAttributedString()
        _ = desc.append(string: tr(.supergroupConvertDescription), color: theme.colors.grayText, font: .normal(.text))
        desc.detectBoldColorInString(with: .medium(.text))
        
        _ = genericView.addItem(item: GeneralRowItem(initialSize, height: 16))
        _ = genericView.addItem(item: GeneralTextRowItem(initialSize, text: desc))
        _ = genericView.addItem(item: GeneralInteractedRowItem(initialSize, name: tr(.supergroupConvertButton), nameStyle: blueActionButton, type: .none, action: { [weak self] in
            self?.convert()
        }))
        let undone = NSMutableAttributedString()
        _ = undone.append(string: tr(.supergroupConvertUndone), color: theme.colors.grayText, font: .normal(.text))
        undone.detectBoldColorInString(with: .medium(.text))
        _ = genericView.addItem(item: GeneralTextRowItem(initialSize, text: undone))
        
        readyOnce()
    }
    
    func convert() {
        
        
        confirm(for: mainWindow, with: appName, and:  tr(.convertToSuperGroupConfirm)) { [weak self] result in
            
            if let strongSelf = self {
                let signal = convertGroupToSupergroup(account: strongSelf.account, peerId: strongSelf.peerId)
                    |> map { Optional($0) }
                    |> `catch` { error -> Signal<PeerId?, ConvertGroupToSupergroupError> in
                        return .single(nil)
                    } |> mapError {_ in}
                
                
                self?.convertDisposable.set(showModalProgress(signal: signal |> deliverOnMainQueue, for: mainWindow).start(next: { [weak strongSelf] peerId in
                    if let peerId = peerId, let account = strongSelf?.account {
                        strongSelf?.navigationController?.push(ChatController(account: account, peerId: peerId))
                    } else {
                        alert(for: mainWindow, info: tr(.convertToSupergroupAlertError))
                    }
                }))
            }
            
        }
        
        
    }
    
    deinit {
        convertDisposable.dispose()
    }
    
}
