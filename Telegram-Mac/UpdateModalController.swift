//
//  UpdateModalController.swift
//  Telegram
//
//  Created by keepcoder on 10/07/2018.
//  Copyright © 2018 Telegram. All rights reserved.
//

import Cocoa
import TGUIKit
import Postbox
import TelegramCore
import SyncCore
import SwiftSignalKit

private class UpdateTableItem : GeneralRowItem {
    fileprivate let titleLayout: TextViewLayout
    fileprivate let descLayout: TextViewLayout
    
    init(_ initialSize: NSSize) {
        
        titleLayout = TextViewLayout(.initialize(string: "Telegram 4.2", color: theme.colors.text, font: .medium(.title)), maximumNumberOfLines: 1)
        titleLayout.measure(width: initialSize.width - 150)
        
        descLayout = TextViewLayout(.initialize(string: "You'll need to update Telegram to the latest version before you can use the app.", color: theme.colors.text, font: .normal(.text)))
        descLayout.measure(width: initialSize.width - 50)
        super.init(initialSize, height: 100 + descLayout.layoutSize.height, stableId: 0)
    }
    
    override func viewClass() -> AnyClass {
        return UpdateTableView.self
    }
}

private final class UpdateTableView : TableRowView {
    private let titleView: TextView = TextView()
    private let descView: TextView = TextView()
    private let logoView: ImageView = ImageView()
    required init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        logoView.image = theme.icons.confirmAppAccessoryIcon
        logoView.setFrameSize(50,50)
        addSubview(logoView)
        addSubview(titleView)
        addSubview(descView)
    }
    
    override func set(item: TableRowItem, animated: Bool) {
        super.set(item: item, animated: animated)
        
        guard let item = item as? UpdateTableItem else {return}
        
        titleView.update(item.titleLayout)
        descView.update(item.descLayout)
        
        needsLayout = true
    }
    
    override func layout() {
        super.layout()
        logoView.setFrameOrigin(25, 10)
        titleView.setFrameOrigin(logoView.frame.maxX + 10, floorToScreenPixels(backingScaleFactor, logoView.frame.minY + (logoView.frame.height - titleView.frame.height)/2))
        descView.setFrameOrigin(logoView.frame.minX, logoView.frame.maxY + 20)
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}

private final class UpdateView : View {
    private let headerView: View = View()
    private let titleView = TextView()
    let tableView = TableView()
    required init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        addSubview(headerView)
        addSubview(tableView)
        headerView.addSubview(titleView)
        headerView.border = [.Bottom]
        let title: TextViewLayout = TextViewLayout(.initialize(string: "Telegram Update", color: theme.colors.text, font: .medium(.title)))
        title.measure(width: frameRect.width - 20)
        titleView.update(title)
    }
    
    func update() {
        tableView.removeAll()
        _ = tableView.addItem(item: UpdateTableItem(frame.size))
    }
    
    override func layout() {
        super.layout()
        headerView.frame = NSMakeRect(0, 0, frame.width, 50)
        tableView.frame = NSMakeRect(0, 60, frame.width, frame.height - 60)
        titleView.center()
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
}

class UpdateModalController: ModalViewController {

    private let postbox: Postbox
    private let network: Network
    init(postbox: Postbox, network: Network) {
        self.postbox = postbox
        self.network = network
        super.init(frame: NSMakeRect(0, 0, 320, 350))
    }
    
    override var modalInteractions: ModalInteractions? {
        return ModalInteractions(acceptTitle: "Update Telegram", accept: {
            #if APP_STORE
            execute(inapp: inAppLink.external(link: "https://itunes.apple.com/us/app/telegram/id747648890", false))
            #else
            (NSApp.delegate as? AppDelegate)?.checkForUpdates("")
            #endif
        }, cancelTitle: L10n.modalCancel, cancel: { [weak self] in
            self?.close()
        }, drawBorder: true, height: 50, alignCancelLeft: true)
        
    }
    
    override func viewClass() -> AnyClass {
        return UpdateView.self
    }
    
    override func viewDidResized(_ size: NSSize) {
        super.viewDidResized(size)
    }
    
    override open func measure(size: NSSize) {
        self.modal?.resize(with:NSMakeSize(320, min(size.height - 70, genericView.tableView.listHeight + 70)), animated: false)
    }
    
    public func updateSize(_ animated: Bool) {
        if let contentSize = self.modal?.window.contentView?.frame.size {
            self.modal?.resize(with:NSMakeSize(320, min(contentSize.height - 70, genericView.tableView.listHeight + 70)), animated: animated)
        }
    }
    
    override var handleAllEvents: Bool {
        return true
    }
    
    private var genericView: UpdateView {
        return self.view as! UpdateView
    }
    
    override func escapeKeyAction() -> KeyHandlerResult {
        return .invoked
    }
    
    deinit {
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        readyOnce()
        
        genericView.update()
    }
    
    override var dynamicSize: Bool {
        return true
    }
    
    override var closable: Bool {
        return false
    }
    
}
