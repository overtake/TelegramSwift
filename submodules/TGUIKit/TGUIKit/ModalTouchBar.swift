//
//  ModalTouchBar.swift
//  TGUIKit
//
//  Created by Mikhail Filimonov on 19/09/2018.
//  Copyright © 2018 Telegram. All rights reserved.
//

import Cocoa

@available(OSX 10.12.2, *)
private extension NSTouchBarItem.Identifier {
    static let modalOK = NSTouchBarItem.Identifier("\(Bundle.main.bundleIdentifier!).touchBar.modal.OK")
    static let modalCancel = NSTouchBarItem.Identifier("\(Bundle.main.bundleIdentifier!).touchBar.modal.Cancel")

}

@available(OSX 10.12.2, *)
class ModalTouchBar: NSTouchBar, NSTouchBarDelegate {
    private let interactions: ModalInteractions
    private let modal:Modal
    init(_ interactions: ModalInteractions, modal: Modal) {
        self.interactions = interactions
        self.modal = modal
        super.init()
        self.delegate = self
        
        var items: [NSTouchBarItem.Identifier] = []
        items.append(.flexibleSpace)
        if let _ = interactions.cancelTitle {
            items.append(.modalCancel)
        }
        
        items.append(.modalOK)
        items.append(.flexibleSpace)
        self.defaultItemIdentifiers = items
    }
    
    @objc private func modalOKAction() {
        if let accept = interactions.accept {
            accept()
        } else {
            modal.close()
        }
    }

    @objc private func modalCancelAction() {
        if let cancel = interactions.cancel {
            cancel()
        } else {
            modal.close()
        }
    }
    
    func touchBar(_ touchBar: NSTouchBar, makeItemForIdentifier identifier: NSTouchBarItem.Identifier) -> NSTouchBarItem? {
        switch identifier {
        case .modalOK:
            let item = NSCustomTouchBarItem(identifier: identifier)
            let button = NSButton(title: interactions.acceptTitle, target: self, action: #selector(modalOKAction))
            button.addWidthConstraint(size: 200)
            item.view = button
            item.customizationLabel = button.title
            return item
        case .modalCancel:
            let item = NSCustomTouchBarItem(identifier: identifier)
            let button = NSButton(title: interactions.cancelTitle!, target: self, action: #selector(modalCancelAction))
            button.addWidthConstraint(size: 200)
            item.view = button
            item.customizationLabel = button.title
            return item
        default:
            return nil
        }
    }
    
    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
}
