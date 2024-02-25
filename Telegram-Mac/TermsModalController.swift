//
//  TermsModalController.swift
//  Telegram
//
//  Created by Mikhail Filimonov on 04/06/2018.
//  Copyright © 2018 Telegram. All rights reserved.
//

import Cocoa
import TGUIKit
import TelegramCore

import Postbox
import SwiftSignalKit

private final class TermsView : View {
    private let headerView: View = View()
    private let titleView = TextView()
    let tableView = TableView()
    required init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        addSubview(headerView)
        addSubview(tableView)
        headerView.addSubview(titleView)
        headerView.border = [.Bottom]
        let title: TextViewLayout = TextViewLayout.init(NSAttributedString.initialize(string: strings().termsOfServiceTitle, color: theme.colors.text, font: .medium(.title)))
        title.measure(width: frameRect.width - 20)
        titleView.update(title)
    }
    
    override func layout() {
        super.layout()
        headerView.frame = NSMakeRect(0, 0, frame.width, 50)
        tableView.frame = NSMakeRect(0, 60, frame.width, frame.height - 60)
        titleView.center()
    }
    
    func updateText(_ text: NSAttributedString, openBot:@escaping(String)->Void)  {
        tableView.removeAll()
        let initialSize = NSMakeSize(380, tableView.frame.height)
        let item = GeneralTextRowItem(initialSize, text: text, linkExecutor: TextViewInteractions(processURL: { url in
            if let url = url as? String, !url.isEmpty {
                if url.hasPrefix("@") {
                    openBot(url)
                } else {
                    execute(inapp: .external(link: url, false))
                }
            }
        }))
        _ = tableView.addItem(item: item)
        

        needsLayout = true
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}
class TermsModalController: ModalViewController {

    override func viewClass() -> AnyClass {
        return TermsView.self
    }
    
    override open func measure(size: NSSize) {
        self.modal?.resize(with:NSMakeSize(380, min(size.height - 70, genericView.tableView.listHeight + 70)), animated: false)
    }
    
    public func updateSize(_ animated: Bool) {
        if let contentSize = self.modal?.window.contentView?.frame.size {
            self.modal?.resize(with:NSMakeSize(380, min(contentSize.height - 70, genericView.tableView.listHeight + 70)), animated: animated)
        }
    }
    override var dynamicSize: Bool {
        return true
    }
    
    
    override var handleAllEvents: Bool {
        return true
    }
    
    override var modalInteractions: ModalInteractions? {
        let network = self.context.account.network
        let terms = self.terms
        let context = self.context
        let accept:()->Void = { [weak self] in
            guard let `self` = self else {return}
            
            
            
            _ = showModalProgress(signal: context.engine.accountData.acceptTermsOfService(id: terms.id) |> deliverOnMainQueue, for: context.window).start(next: { [weak self] in
                self?.close()
            })
            if let botname = self.proceedBotAfterAgree {
                _ = (self.context.engine.peers.resolvePeerByName(name: botname) |> deliverOnMainQueue).start(next: { [weak self] result in
                    guard let `self` = self else {return}
                    switch result {
                    case .progress:
                        break
                    case let .result(peer):
                        if let peer = peer {
                            self.context.bindings.rootNavigation().push(ChatController(context: self.context, chatLocation: .peer(peer._asPeer().id)))
                        }
                    }
                })
            }
        }
        return ModalInteractions(acceptTitle: strings().termsOfServiceAccept, accept: {
            if let age = terms.ageConfirmation {
                verifyAlert_button(for: mainWindow, header: strings().termsOfServiceTitle, information: strings().termsOfServiceConfirmAge("\(age)"), ok: strings().termsOfServiceAcceptConfirmAge, successHandler: { _ in
                   accept()
                })
            } else {
                accept()
            }
        }, cancelTitle: strings().termsOfServiceDisagree, cancel: {
            verifyAlert_button(for: context.window, header: strings().termsOfServiceTitle, information: strings().termsOfServiceDisagreeText, ok: strings().termsOfServiceDisagreeOK, successHandler: { _ in
                verifyAlert_button(for: context.window, header: strings().termsOfServiceTitle, information: strings().termsOfServiceDisagreeTextLast, ok: strings().termsOfServiceDisagreeTextLastOK, successHandler: { _ in
                    _ = showModalProgress(signal: context.engine.auth.deleteAccount(reason: "GDPR", password: nil), for: context.window).start(error: { _ in
                        showModalText(for: context.window, text: strings().unknownError)
                    }, completed: {
                        _ = logoutFromAccount(id: context.account.id, accountManager: context.sharedContext.accountManager, alreadyLoggedOutRemotely: true).start()
                    })
                })
            })
        }, drawBorder: true, height: 50, alignCancelLeft: true)
        
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        modal?.interactions?.updateCancel { control in
            control.set(color: theme.colors.redUI, for: .Normal)
        }
    }
    
   
    private let context: AccountContext
    private let terms: TermsOfServiceUpdate
    private var proceedBotAfterAgree: String? = nil
    init(_ context: AccountContext, terms: TermsOfServiceUpdate) {
        self.context = context
        self.terms = terms
        super.init(frame: NSMakeRect(0, 0, 380, 380))
    }
    
    override func viewDidResized(_ size: NSSize) {
        super.viewDidResized(size)
    }
    
    private var genericView: TermsView {
        return self.view as! TermsView
    }
    
    override func escapeKeyAction() -> KeyHandlerResult {
        return .invoked
    }
    
    deinit {
    }
    

    override var closable: Bool {
        return false
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        let attributedString: NSMutableAttributedString = NSMutableAttributedString()
        
        _ = attributedString.append(string: terms.text, color: theme.colors.text, font: .normal(.text))
        
        for entity in terms.entities {
            switch entity.type {
            case .Bold:
                attributedString.addAttribute(NSAttributedString.Key.font, value: NSFont.bold(.text), range: NSMakeRange(entity.range.lowerBound, entity.range.upperBound - entity.range.lowerBound))
            case .Italic:
                attributedString.addAttribute(NSAttributedString.Key.font, value: NSFont.italic(.text), range: NSMakeRange(entity.range.lowerBound, entity.range.upperBound - entity.range.lowerBound))
            case let .TextUrl(url):
                attributedString.addAttribute(NSAttributedString.Key.link, value: url, range: NSMakeRange(entity.range.lowerBound, entity.range.upperBound - entity.range.lowerBound))
                attributedString.addAttribute(NSAttributedString.Key.foregroundColor, value: theme.colors.link, range: NSMakeRange(entity.range.lowerBound, entity.range.upperBound - entity.range.lowerBound))
            case .Mention:
                attributedString.addAttribute(NSAttributedString.Key.link, value: terms.text.nsstring.substring(with: NSMakeRange(entity.range.lowerBound, entity.range.upperBound - entity.range.lowerBound)), range: NSMakeRange(entity.range.lowerBound, entity.range.upperBound - entity.range.lowerBound))
                attributedString.addAttribute(NSAttributedString.Key.foregroundColor, value: theme.colors.link, range: NSMakeRange(entity.range.lowerBound, entity.range.upperBound - entity.range.lowerBound))
            default:
                break
            }
        }
        
        genericView.updateText(attributedString, openBot: { [weak self] botname in
            guard let `self` = self else {return}
            self.proceedBotAfterAgree = botname
            self.show(toaster: ControllerToaster(text: strings().termsOfServiceProceedBot(botname)))
        })
        
        
        
        updateSize(false)
        readyOnce()
    }
    
 
}
