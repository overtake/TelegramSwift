//
//  Report.swift
//  Telegram
//
//  Created by Mikhail Filimonov on 25.09.2024.
//  Copyright © 2024 Telegram. All rights reserved.
//

import Foundation
import TelegramCore
import Postbox
import SwiftSignalKit
import TGUIKit


/*
 _ = showModalProgress(signal: context.engine.messages.reportAdMessage(peerId: data.peerId, opaqueId: adAttribute.opaqueId, option: nil), for: context.window).startStandalone(next: { result in
     switch result {
     case .reported:
         showModalText(for: context.window, text: strings().chatMessageSponsoredReportAready)
     case .adsHidden:
         break
     case let .options(title, options):
         showComplicatedReport(context: context, title: title, info: strings().chatMessageSponsoredReportLearnMore, data: .init(list: options.map { .init(string: $0.text, id: $0.option) }, title: strings().chatMessageSponsoredReportOptionTitle), report: { report in
             return context.engine.messages.reportAdMessage(peerId: data.peerId, opaqueId: adAttribute.opaqueId, option: report.id) |> `catch` { error in
                 return .single(.reported)
             } |> deliverOnMainQueue |> map { result in
                 switch result {
                 case let .options(_, options):
                     return .init(list: options.map { .init(string: $0.text, id: $0.option) }, title: report.string)
                 case .reported:
                     showModalText(for: context.window, text: strings().chatMessageSponsoredReportSuccess)
                     chatInteraction.removeAd(adAttribute.opaqueId)
                     return nil
                 case .adsHidden:
                     return nil
                 }
             }
             
         })
     }
 }, error: { error in
     switch error {
     case .premiumRequired:
         prem(with: PremiumBoardingController(context: context, source: .no_ads, openFeatures: true), for: context.window)
     case .generic:
         break
     }
 })
 */

func reportComplicated(context: AccountContext, subject: ReportContentSubject, title: String) {
    
    _ = showModalProgress(signal: context.engine.messages.reportContent(subject: subject, option: nil, message: nil), for: context.window).start(next: { result in
        switch result {
        case .reported:
            showModalText(for: context.window, text: strings().chatMessageSponsoredReportSuccess)
        case let .options(titleInfo, options):
            showComplicatedReport(context: context, title: titleInfo, info: nil, header: title, data: .init(subject: .list(options.map { .init(string: $0.text, id: $0.option) }), title: strings().chatMessageSponsoredReportOptionTitle), report: { report in
                return context.engine.messages.reportContent(subject: subject, option: report.id, message: report.string) |> `catch` { error in
                    return .single(.reported)
                } |> deliverOnMainQueue |> map { result in
                    switch result {
                    case let .options(_, options):
                        return .init(subject: .list(options.map { .init(string: $0.text, id: $0.option) }), title: report.string)
                    case .reported:
                        showModalText(for: context.window, text: strings().chatMessageSponsoredReportSuccess)
                        return nil
                    case let .addComment(optional, option):
                        return .init(subject: .comment(optional: optional, id: option), title: report.string)
                    }
                }
            })
        case .addComment:
            break
        }
        
    })
    
}
