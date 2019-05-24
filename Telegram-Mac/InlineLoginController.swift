//
//  InlineLoginController.swift
//  Telegram
//
//  Created by Mikhail Filimonov on 22/05/2019.
//  Copyright © 2019 Telegram. All rights reserved.
//

import Cocoa
import TGUIKit
import TelegramCoreMac
import SwiftSignalKitMac
import PostboxMac

public struct InlineLoginOption: OptionSet {
    public var rawValue: Int32
    
    public init() {
        self.rawValue = 0
    }
    
    public init(rawValue: Int32) {
        self.rawValue = rawValue
    }
    
    public static let login = InlineLoginOption(rawValue: 1 << 0)
    public static let allowMessages = InlineLoginOption(rawValue: 1 << 1)

}



private struct InlineLoginState : Equatable {
    let options:InlineLoginOption
    init(options: InlineLoginOption) {
        self.options = options
    }
    
    func withUpdatedOption(_ option: InlineLoginOption) -> InlineLoginState {
        var options = self.options
        if options.contains(option) {
            options.remove(option)
        } else {
            options.insert(option)
        }
        return InlineLoginState(options: options)
    }
    
    func withRemovedOption(_ option: InlineLoginOption, _ dependsOn: InlineLoginOption) -> InlineLoginState {
        var options = self.options
        if !options.contains(dependsOn) {
            options.remove(option)
        }
        return InlineLoginState(options: options)
    }
}

private let _id_option_login = InputDataIdentifier("_id_option_login")
private let _id_option_allow_send_messages = InputDataIdentifier("_id_option_allow_send_messages")

private func inlineLoginEntries(_ state: InlineLoginState, url: String, accountPeer: Peer, botPeer: Peer, writeAllowed: Bool, toggleOption:@escaping(InlineLoginOption)->Void, removeOption:@escaping(InlineLoginOption, InlineLoginOption)->Void) -> [InputDataEntry] {
    var entries:[InputDataEntry] = []
    
    var sectionId: Int32 = 0
    var index: Int32 = 0
    
    let host = URL(string: url)?.host ?? url
    
    entries.append(.sectionId(sectionId))
    sectionId += 1
    
    entries.append(InputDataEntry.custom(sectionId: sectionId, index: index, value: .none, identifier: InputDataIdentifier("title"), equatable: nil, item: { initialSize, stableId in
        
        let attributedString = NSMutableAttributedString()
        let string = L10n.botInlineAuthTitle(url)
        let _ = attributedString.append(string: string, color: theme.colors.text, font: .normal(.text))
        let range = string.nsstring.range(of: url)
        attributedString.addAttribute(.font, value: NSFont.medium(.text), range: range)
        
        return GeneralTextRowItem(initialSize, stableId: stableId, text: attributedString, alignment: .center, drawCustomSeparator: false, centerViewAlignment: true, isTextSelectable: false, detectLinks: false)
    }))
    index += 1
    
    entries.append(.sectionId(sectionId))
    sectionId += 1
    
    let loginEnabled = state.options.contains(.login)
    let allowMessagesEnabled = state.options.contains(.allowMessages)

    entries.append(InputDataEntry.custom(sectionId: sectionId, index: index, value: .none, identifier: _id_option_login, equatable: InputDataEquatable(loginEnabled), item: { initialSize, stableId in
        
        let attributeString = NSMutableAttributedString()
        let string = L10n.botInlineAuthOptionLogin(host, accountPeer.displayTitle)
        let hostRange = string.nsstring.range(of: host)
        _ = attributeString.append(string: string, color: theme.colors.text, font: .normal(.text))
        attributeString.addAttribute(.font, value: NSFont.medium(.text), range: hostRange)
        
        return InlineAuthOptionRowItem(initialSize, stableId: stableId, attributedString: attributeString, selected: loginEnabled, action: {
            toggleOption(.login)
            removeOption(.allowMessages, .login)
        })
    }))
    index += 1
    
    
    if writeAllowed {
        entries.append(InputDataEntry.custom(sectionId: sectionId, index: index, value: .none, identifier: _id_option_allow_send_messages, equatable: InputDataEquatable(allowMessagesEnabled), item: { initialSize, stableId in
            
            let attributeString = NSMutableAttributedString()
            let string = L10n.botInlineAuthOptionAllowSendMessages(botPeer.displayTitle)
            let titleRange = string.nsstring.range(of: botPeer.displayTitle)
            _ = attributeString.append(string: string, color: theme.colors.text, font: .normal(.text))
            attributeString.addAttribute(.font, value: NSFont.medium(.text), range: titleRange)
            
            return InlineAuthOptionRowItem(initialSize, stableId: stableId, attributedString: attributeString, selected: allowMessagesEnabled, action: {
                toggleOption(.allowMessages)
            })
        }))
        index += 1
    }
    
    
    entries.append(.sectionId(sectionId))
    sectionId += 1
    
    return entries
}

func InlineLoginController(context: AccountContext, url: String, writeAllowed: Bool, botPeer: Peer, authorize: @escaping(Bool)->Void) -> InputDataModalController {
    
    
    let initialState = writeAllowed ? InlineLoginState(options: [.login, .allowMessages]) : InlineLoginState(options: [.login])
    
    let statePromise = ValuePromise(initialState, ignoreRepeated: true)
    let stateValue = Atomic(value: initialState)
    let updateState: ((InlineLoginState) -> InlineLoginState) -> Void = { f in
        statePromise.set(stateValue.modify (f))
    }
    
    let signal = combineLatest(statePromise.get(), context.account.postbox.loadedPeerWithId(context.peerId)) |> map { state, accountPeer in
        return inlineLoginEntries(state, url: url, accountPeer: accountPeer, botPeer: botPeer, writeAllowed: writeAllowed, toggleOption: { option in
            updateState { current in
                return current.withUpdatedOption(option)
            }
        }, removeOption: { option, dependsOn in
            updateState { current in
                return current.withRemovedOption(option, dependsOn)
            }
        })
    } |> map { ($0, true) }
    
    var close:(()->Void)?
    
    let interactions = ModalInteractions(acceptTitle: L10n.botInlineAuthOpen, accept: {
        let state = stateValue.with { $0 }
        
        if state.options.isEmpty {
            execute(inapp: inAppLink.external(link: url, false))
        } else {
            authorize(state.options.contains(.allowMessages))
        }
        close?()
    }, cancelTitle: L10n.modalCancel, drawBorder: true, height: 50)
    
    let controller = InputDataController(dataSignal: signal, title: L10n.botInlineAuthHeader)
    
    let modalController = InputDataModalController(controller, modalInteractions: interactions)
    
    close = { [weak modalController] in
        modalController?.close()
    }
    
    return modalController
}
