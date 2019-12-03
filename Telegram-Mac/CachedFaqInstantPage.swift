//
//  CachedFaqInstantPage.swift
//  Telegram
//
//  Created by Mikhail Filimonov on 02.12.2019.
//  Copyright © 2019 Telegram. All rights reserved.
//

import Cocoa
import SwiftSignalKit
import Postbox
import TelegramCore
import SyncCore


private func extractAnchor(string: String) -> (String, String?) {
    var anchorValue: String?
    if let anchorRange = string.range(of: "#") {
        let anchor = string[anchorRange.upperBound...]
        if !anchor.isEmpty {
            anchorValue = String(anchor)
        }
    }
    var trimmedUrl = string
    if let anchor = anchorValue, let anchorRange = string.range(of: "#\(anchor)") {
        let url = string[..<anchorRange.lowerBound]
        if !url.isEmpty {
            trimmedUrl = String(url)
        }
    }
    return (trimmedUrl, anchorValue)
}

private let refreshTimeout: Int32 = 60 * 60 * 12

func cachedFaqInstantPage(context: AccountContext) -> Signal<inAppLink, NoError> {
    let faqUrl = "https://telegram.org/faq#general-questions"

    
    let (cachedUrl, anchor) = extractAnchor(string: faqUrl)
    
    return cachedInstantPage(postbox: context.account.postbox, url: cachedUrl)
        |> mapToSignal { cachedInstantPage -> Signal<inAppLink, NoError> in
            let updated = resolveInstantViewUrl(account: context.account, url: faqUrl)
                |> afterNext { result in
                    if case let .instantView(_, webPage, _) = result, case let .Loaded(content) = webPage.content, let instantPage = content.instantPage {
                        if instantPage.isComplete {
                            let _ = updateCachedInstantPage(postbox: context.account.postbox, url: cachedUrl, webPage: webPage).start()
                        } else {
                            let _ = (actualizedWebpage(postbox: context.account.postbox, network: context.account.network, webpage: webPage)
                                |> mapToSignal { webPage -> Signal<Void, NoError> in
                                    if case let .Loaded(content) = webPage.content, let instantPage = content.instantPage, instantPage.isComplete {
                                        return updateCachedInstantPage(postbox: context.account.postbox, url: cachedUrl, webPage: webPage)
                                    } else {
                                        return .complete()
                                    }
                                }).start()
                        }
                    }
            }
            
            let now = Int32(CFAbsoluteTimeGetCurrent())
            if let cachedInstantPage = cachedInstantPage, case let .Loaded(content) = cachedInstantPage.webPage.content, let instantPage = content.instantPage, instantPage.isComplete {
                let current: Signal<inAppLink, NoError> = .single(.instantView(link: faqUrl, webpage: cachedInstantPage.webPage, anchor: anchor))
                if now > cachedInstantPage.timestamp + refreshTimeout {
                    return current
                        |> then(updated)
                } else {
                    return current
                }
            } else {
                return updated
            }
    }
}

func faqSearchableItems(context: AccountContext) -> Signal<[SettingsSearchableItem], NoError> {
    return cachedFaqInstantPage(context: context)
        |> map { resolvedUrl -> [SettingsSearchableItem] in
            var results: [SettingsSearchableItem] = []
            var nextIndex: Int32 = 2
            if case let .instantView(_, webPage, _) = resolvedUrl {
                if case let .Loaded(content) = webPage.content, let instantPage = content.instantPage {
                    var processingQuestions = false
                    var currentSection: String?
                    outer: for block in instantPage.blocks {
                        if !processingQuestions {
                            switch block {
                            case .blockQuote:
                                if results.isEmpty {
                                    processingQuestions = true
                                }
                            default:
                                break
                            }
                        } else {
                            switch block {
                            case let .paragraph(text):
                                if case .bold = text {
                                    currentSection = text.plainText
                                } else if case .concat = text {
                                    processingQuestions = false
                                }
                            case let .list(items, false):
                                if let currentSection = currentSection {
                                    for item in items {
                                        if case let .text(itemText, _) = item, case let .url(text, url, _) = itemText {
                                            let (_, anchor) = extractAnchor(string: url)
                                            var index = nextIndex
                                            if anchor?.contains("delete-my-account") ?? false {
                                                index = 1
                                            } else {
                                                nextIndex += 1
                                            }
                                            let item = SettingsSearchableItem(id: .faq(index), title: text.plainText, alternate: [], icon: .faq, breadcrumbs: [L10n.accountSettingsFAQ, currentSection], present: { context, _, present in
                                                showInstantPage(InstantPageViewController(context, webPage: webPage, message: nil, anchor: anchor))
                                            })
                                            if index == 1 {
                                                results.insert(item, at: 0)
                                            } else {
                                                results.append(item)
                                            }
                                        }
                                    }
                                }
                            default:
                                break
                            }
                        }
                    }
                }
            }
            return results
    }
}
