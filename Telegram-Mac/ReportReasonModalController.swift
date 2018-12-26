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


private class ReportReasonView: View {
    let tableView: TableView = TableView(frame: NSZeroRect)
    private let title: TextView = TextView()
    private let separator : View = View()
    required init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        addSubview(title)
        addSubview(tableView)
        addSubview(separator)
        separator.backgroundColor = theme.colors.border
        
        self.title.update(TextViewLayout(.initialize(string: L10n.peerInfoReport, color: theme.colors.text, font: .medium(.title)), maximumNumberOfLines: 1))
        needsLayout = true
    }
    
 
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override func layout() {
        super.layout()
        tableView.frame = NSMakeRect(0, 50, frame.width, frame.height - 50)
        title.layout?.measure(width: frame.width - 60)
        title.update(title.layout)
        title.centerX(y: floorToScreenPixels(scaleFactor: backingScaleFactor, (50 - title.frame.height) / 2))
        separator.frame = NSMakeRect(0, 49, frame.width, .borderSize)
    }
}


fileprivate class ReportReasonModalController: ModalViewController {

    fileprivate var onComplete:Signal<ReportReason, NoError> {
        return _complete.get() |> take(1)
    }
    private let _complete:Promise<ReportReason> = Promise()
    private var current:ReportReason = .spam
    override func viewClass() -> AnyClass {
        return ReportReasonView.self
    }
    
    var genericView:ReportReasonView {
        return self.view as! ReportReasonView
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        
        
        reload()
        
        readyOnce()
    }
    
    private func reload() {
        
        let updateState:(ReportReason) -> Void = { [weak self] reason in
            self?.current = reason
            self?.reload()
        }
        
        genericView.tableView.removeAll()
        
        let initialSize = atomicSize.modify {$0}
        _ = genericView.tableView.addItem(item: GeneralInteractedRowItem(initialSize, name: L10n.reportReasonSpam, type: .selectable(current == .spam), action: {
            updateState(.spam)
        }))
        
        _ = genericView.tableView.addItem(item: GeneralInteractedRowItem(initialSize, name: L10n.reportReasonViolence, type: .selectable(current == .violence), action: {
            updateState(.violence)
        }))
        
        _ = genericView.tableView.addItem(item: GeneralInteractedRowItem(initialSize, name: L10n.reportReasonPorno, type: .selectable(current == .porno), action: {
            updateState(.porno)
        }))
        
        _ = genericView.tableView.addItem(item: GeneralInteractedRowItem(initialSize, name: L10n.reportReasonChildAbuse, type: .selectable(current == .childAbuse), action: {
            updateState(.childAbuse)
        }))
        
        _ = genericView.tableView.addItem(item: GeneralInteractedRowItem(initialSize, name: L10n.reportReasonCopyright, type: .selectable(current == .copyright), action: {
            updateState(.copyright)
        }, drawCustomSeparator: false))

    }
    
    override var modalInteractions: ModalInteractions? {
        return ModalInteractions(acceptTitle: L10n.modalOK, accept: { [weak self] in
            if let strongSelf = self {
                self?._complete.set(.single(strongSelf.current))
                _ = showModalSuccess(for: mainWindow, icon: theme.icons.successModalProgress, delay: 0.5).start()
                self?.close()
            }
        }, cancelTitle: L10n.modalCancel, drawBorder: true, height: 40)
    }
    
    override init() {
        super.init(frame: NSMakeRect(0, 0, 260, 260))
        bar = .init(height: 0)
    }
    
}

func reportReasonSelector() -> Signal<ReportReason, NoError> {
    let reportModalView = ReportReasonModalController()
    showModal(with: reportModalView, for: mainWindow)
    
    return reportModalView.onComplete
}
