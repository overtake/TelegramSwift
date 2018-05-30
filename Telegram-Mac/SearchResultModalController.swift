//
//  SearchResultModalController.swift
//  TelegramMac
//
//  Created by keepcoder on 28/12/2016.
//  Copyright © 2016 Telegram. All rights reserved.
//

import Cocoa
import TGUIKit
import TelegramCoreMac
import PostboxMac
import SwiftSignalKitMac

fileprivate enum SearchResultEntry : Comparable, Identifiable {
    case message(Message)
    
    var stableId: MessageIndex {
        switch self {
        case let .message(message):
            return MessageIndex(message)
        }
    }
}

fileprivate func ==(lhs:SearchResultEntry, rhs:SearchResultEntry) -> Bool {
    switch lhs {
    case let .message(lhsMessage):
        if case let .message(rhsMessage) = rhs {
            if lhsMessage.id != rhsMessage.id {
                return false
            }
            if lhsMessage.stableVersion != rhsMessage.stableVersion {
                return false
            }
            return true
        } else {
            return false
        }
        
    }
}

fileprivate func <(lhs:SearchResultEntry, rhs:SearchResultEntry) -> Bool {
    return lhs.stableId < rhs.stableId
}

fileprivate class SearchResultModalView : View {
    let table = TableView()
    let textView:TextView = TextView()
    let separator:View = View()
    required init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        
        separator.backgroundColor = theme.colors.border
        textView.backgroundColor = theme.colors.background
        addSubview(table)
        addSubview(textView)
        addSubview(separator)
    }
    
    func updateTitle(_ string:String) {
        textView.set(layout: TextViewLayout(.initialize(string: string, color: theme.colors.text, font: .medium(.title)), maximumNumberOfLines: 1, truncationType:.middle))
        self.needsLayout = true
    }
    
    fileprivate override func layout() {
        super.layout()
        textView.layout?.measure(width: frame.width - 40)
        textView.update(textView.layout)
        textView.centerX(y:floorToScreenPixels(scaleFactor: backingScaleFactor, (50 - textView.frame.height)/2.0))
        separator.frame = NSMakeRect(0, 50 - .borderSize, frame.width, .borderSize)
        table.frame = NSMakeRect(0, 50, frame.width, frame.height - 50)
        
    }
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}

fileprivate func prepareEntries(from:[SearchResultEntry], to:[SearchResultEntry], initialSize:NSSize, account:Account) -> TableUpdateTransition {
    let (removed,inserted,updated) = proccessEntriesWithoutReverse(from, right: to) { entry -> TableRowItem in
        switch entry {
        case let .message(message):
            return ChatListMessageRowItem(initialSize, account: account, message: message, renderedPeer: RenderedPeer(message: message))
        }
    }
    return TableUpdateTransition(deleted: removed, inserted: inserted, updated: updated)
}

class SearchResultModalController: ModalViewController, TableViewDelegate {
    
    func findGroupStableId(for stableId: AnyHashable) -> AnyHashable? {
        return nil
    }
    
    private let account:Account
    private let entries:Atomic<[SearchResultEntry]> = Atomic(value:[])
    private let promise:Promise<[Message]> = Promise()
    private let query:String
    private let chatInteraction:ChatInteraction
    init(_ account:Account, messages:[Message] = [], query:String, chatInteraction:ChatInteraction) {
        self.account = account
        self.query = query
        self.chatInteraction = chatInteraction
        promise.set(.single(messages))
        super.init(frame: NSMakeRect(0, 0, 300, 360))
    }
    
    init(_ account:Account, request:Signal<[Message],Void>, query:String, chatInteraction:ChatInteraction) {
        self.account = account
        self.query = query
        promise.set(request)
        self.chatInteraction = chatInteraction
        super.init(frame: NSMakeRect(0, 0, 300, 360))
    }
    
    
    override func viewClass() -> AnyClass {
        return SearchResultModalView.self
    }
    
    fileprivate var genericView:SearchResultModalView {
        return self.view as! SearchResultModalView
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        genericView.updateTitle(query)
        let entries = self.entries
        let initialSize = self.atomicSize
        let account = self.account
        genericView.table.delegate = self
        
        genericView.table.merge(with: promise.get()
        |> map { messages -> [SearchResultEntry] in
            return messages.map({.message($0)})
        } |> map { [weak self] new -> TableUpdateTransition in
            self?.readyOnce()
            return prepareEntries(from: entries.swap(new), to: entries.modify({$0}), initialSize: initialSize.modify({$0}), account: account)
        })
    }
    
    func selectionDidChange(row:Int, item:TableRowItem, byClick:Bool, isNew:Bool) -> Void {
        if let item = item as? ChatListMessageRowItem, let message = item.message {
            chatInteraction.focusMessageId(nil, message.id, .center(id: 0, innerId: nil, animated: true, focus: true, inset: 0))
        }
        close()
    }
    func selectionWillChange(row:Int, item:TableRowItem) -> Bool {
        return true
    }
    func isSelectable(row:Int, item:TableRowItem) -> Bool {
        return true
    }
}
