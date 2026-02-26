//
//  SuggestPostPanelModel.swift
//  Telegram
//
//  Created by Mikhail Filimonov on 12.06.2025.
//  Copyright © 2025 Telegram. All rights reserved.
//



import Cocoa
import TGUIKit
import SwiftSignalKit
import Postbox
import TelegramCore

class SuggestPostPanelModel: ChatAccessoryModel {
    
    
    let data: ChatInterfaceState.ChannelSuggestPost
    
    init(data: ChatInterfaceState.ChannelSuggestPost, editing: Bool = false, context: AccountContext) {
        self.data = data
        super.init(context: context)
        self.make()
    }
    deinit {
    }
    
    override var modelType: ChatAccessoryModel.ModelType {
        return .classic
    }
    
    func make() -> Void {
        
        let title: String
        switch data.mode {
        case .edit:
            title = strings().suggestPostPanelTitleEdit
        case .new:
            title = strings().suggestPostPanelTitleNew
        case .suggest:
            title = strings().suggestPostPanelTitleSuggest
        }

        
        self.header = .init(.initialize(string: title, color: theme.colors.accent, font: .medium(.text)), maximumNumberOfLines: 1)
        
        
        let text: NSMutableAttributedString = NSMutableAttributedString()

        if let amount = data.amount, amount.amount.value > 0 {
            let dateString = data.date.flatMap({ stringForDate(timestamp: $0) }) ?? strings().suggestPostPanelTextAnytime
            let formatted = strings().suggestPostPanelTextPriceAndDate(amount.fullyFormatted, dateString)
            text.append(string: "\(clown_space)\(formatted)", color: theme.colors.text, font: .normal(.text))

            switch amount.currency {
            case .stars:
                text.insertEmbedded(.embeddedAnimated(LocalAnimatedSticker.star_currency_new.file), for: clown)
            case .ton:
                text.insertEmbedded(.embeddedAnimated(LocalAnimatedSticker.ton_logo.file, color: theme.colors.accent), for: clown)
            }

        } else if let time = data.date {
            let dateString = stringForDate(timestamp: time)
            let formatted = strings().suggestPostPanelTextFreeAndDate(dateString)
            text.append(string: "\(clown_space)\(formatted)", color: theme.colors.text, font: .normal(.text))
            text.insertEmbedded(.embeddedAnimated(LocalAnimatedSticker.star_currency_new.file), for: clown)
        } else {
            text.append(string: strings().suggestPostPanelTextOfferPrice, color: theme.colors.text, font: .normal(.text))
        }

        
        self.message = .init(text, maximumNumberOfLines: 1)

        
        nodeReady.set(.single(true))
        self.setNeedDisplay()
    }
    

}
