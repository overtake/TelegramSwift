//
//  ReportReasonModalController.swift
//  Telegram
//
//  Created by keepcoder on 01/03/2017.
//  Copyright © 2017 Telegram. All rights reserved.
//

import Cocoa
import TGUIKit
import SwiftSignalKitMac
import PostboxMac
import TelegramCoreMac



fileprivate class ReportReasonModalController: ModalViewController {

    fileprivate var onComplete:Signal<ReportReason, Void> {
        return _complete.get() |> take(1)
    }
    private let _complete:Promise<ReportReason> = Promise()
    private var current:ReportReason = .spam
    override func viewClass() -> AnyClass {
        return TableView.self
    }
    
    var genericView:TableView {
        return self.view as! TableView
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        let updateState:(ReportReason) -> Void = { [weak self] reason in
            self?.current = reason
            self?.genericView.reloadData()
        }
        
        let initialSize = atomicSize.modify {$0}
        _ = genericView.addItem(item: GeneralInteractedRowItem(initialSize, name: tr(L10n.reportReasonSpam), type: .selectable(current == .spam), action: {
            updateState(.spam)
        }))
        
        _ = genericView.addItem(item: GeneralInteractedRowItem(initialSize, name: tr(L10n.reportReasonViolence), type: .selectable(current == .violence), action: {
            updateState(.violence)
        }))
        
        _ = genericView.addItem(item: GeneralInteractedRowItem(initialSize, name: tr(L10n.reportReasonPorno), type: .selectable(current == .porno), action: {
            updateState(.porno)
        }, drawCustomSeparator: false))

        readyOnce()
    }
    
    override var modalInteractions: ModalInteractions? {
        return ModalInteractions(acceptTitle: tr(L10n.modalOK), accept: { [weak self] in
            if let strongSelf = self {
                self?._complete.set(.single(strongSelf.current))
                self?.close()
            }
        }, cancelTitle: tr(L10n.modalCancel), drawBorder: true, height: 40)
    }
    
    override init() {
        super.init(frame: NSMakeRect(0, 0, 260, 130))
        bar = .init(height: 0)
    }
    
}

func reportReasonSelector() -> Signal<ReportReason, Void> {
    let reportModalView = ReportReasonModalController()
    showModal(with: reportModalView, for: mainWindow)
    
    return reportModalView.onComplete
}
