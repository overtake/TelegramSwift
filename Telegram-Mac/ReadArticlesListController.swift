//
//  ReadArticlesListController.swift
//  Telegram
//
//  Created by Mikhail Filimonov on 02/07/2018.
//  Copyright © 2018 Telegram. All rights reserved.
//

import Cocoa
import TelegramCoreMac
import PostboxMac
import SwiftSignalKitMac
import TGUIKit

private final class ReadArticleListArguments {
    let account: Account
    let chatInteraction: ChatInteraction
    let search:(SearchState)->Void
    init(account: Account, chatInteraction: ChatInteraction, search:@escaping(SearchState)->Void) {
        self.account = account
        self.chatInteraction = chatInteraction
        self.search = search
    }
}
private func readArticlesEntries(_ prefs: ReadArticlesListPreferences, state: SearchState?, arguments: ReadArticleListArguments) -> [InputDataEntry] {
    let sectionId:Int32 = 0
    var entries:[InputDataEntry] = []
    
//    entries.append(.sectionId(sectionId))
//    sectionId += 1
    
    var index: Int32 = 0
    
    entries.append(InputDataEntry.search(sectionId: sectionId, index: index, value: .string(""), identifier: InputDataIdentifier("search"), update: { state in
        arguments.search(state)
    }))
    
    let list = prefs.list.sorted { (lhs, rhs) -> Bool in
        let lhsIsUnread: Int = lhs.percent < 100 ? 1 : 0
        let rhsIsUnread: Int = rhs.percent < 100 ? 1 : 0
        if lhsIsUnread < rhsIsUnread {
            return false
        } else if lhsIsUnread > rhsIsUnread {
            return true
        }
        
        return lhs.date > rhs.date
    }
    
    for article in list {
        
        if case let .Loaded(content) = article.webPage.content {
            if let state = state {
                if !state.request.isEmpty {
                    if let website = content.websiteName, !website.lowercased().hasPrefix(state.request.lowercased()) {
                        continue
                    }
                }
            }
            entries.append(InputDataEntry.custom(sectionId: sectionId, index: index, value: .none, identifier: InputDataIdentifier("\(article.webPage.webpageId)"), equatable: InputDataEquatable(article), item: { initialSize, stableId -> TableRowItem in
                return PeerMediaWebpageRowItem(initialSize, arguments.chatInteraction, arguments.account, .messageEntry(Message(article.webPage, stableId: UINT32_MAX, messageId: MessageId(peerId: arguments.account.peerId, namespace: 0, id: MessageId.Id(article.webPage.webpageId.id % Int64(INT32_MAX))))), saveToRecent: false, readPercent: article.percent)
            }))
            index += 1
        }
    }
    if entries.count == 1, !list.isEmpty {
        entries.append(InputDataEntry.custom(sectionId: sectionId, index: index, value: .none, identifier: InputDataIdentifier("empty"), equatable: nil, item: { initialSize, stableId -> TableRowItem in
            return SearchEmptyRowItem(initialSize, stableId: stableId)
        }))
    }
    
    
    return entries
}


func readArticlesListController(_ account: Account) -> InputDataController {
    
    
    let promise: Promise<[InputDataEntry]> = Promise()
    
    let chatInteraction = ChatInteraction(chatLocation: ChatLocation.peer(account.peerId), account: account)

    let searchPromise:Promise<SearchState?> = Promise(nil)
    
    let arguments = ReadArticleListArguments(account: account, chatInteraction: chatInteraction, search: { search in
        searchPromise.set(.single(search))
    })
    
    
    promise.set(combineLatest(readArticlesListPreferences(account.postbox) |> deliverOnPrepareQueue, searchPromise.get() |> deliverOnPrepareQueue) |> map { readArticlesEntries($0.0, state: $0.1, arguments: arguments) })
    
    return InputDataController(dataSignal: promise.get(), title: L10n.accountSettingsReadArticles, hasDone: false, identifier: "readarticles", customRightButton: { controller in
        let back = ImageBarView(controller: controller, theme.icons.chatActions)
        
        back.set(image: theme.icons.chatActions, highlightImage: theme.icons.chatActionsActive)

        back.button.set(handler: { control in
            showPopover(for: control, with: SPopoverViewController(items: [SPopoverItem(L10n.articleReadAll, {
                _ = updateReadArticlesPreferences(postbox: account.postbox, { pref -> ReadArticlesListPreferences in
                    return pref.withReadAll()
                }).start()
            }), SPopoverItem(L10n.articleRemoveAll, {
                _ = updateReadArticlesPreferences(postbox: account.postbox, { pref -> ReadArticlesListPreferences in
                    return pref.withRemovedAll()
                }).start()
            })]), edge: .maxY, inset: NSMakePoint(0, -60))
        }, for: .Click)

        return back
    }, afterTransaction: { controller in
        if controller.genericView.count == 1 {
            controller.navigationController?.back()
        }
    })
    
}

