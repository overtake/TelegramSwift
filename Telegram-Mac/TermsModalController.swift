//
//  TermsModalController.swift
//  Telegram
//
//  Created by Mikhail Filimonov on 04/06/2018.
//  Copyright © 2018 Telegram. All rights reserved.
//

import Cocoa
import TGUIKit
import TelegramCoreMac
import PostboxMac
import SwiftSignalKitMac

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
        let title: TextViewLayout = TextViewLayout.init(NSAttributedString.initialize(string: L10n.termsOfServiceTitle, color: theme.colors.text, font: .medium(.title)))
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
    
    override var handleAllEvents: Bool {
        return true
    }
    
    override var modalInteractions: ModalInteractions? {
        let network = self.account.network
        let terms = self.terms
        let account = self.account
        let accept:()->Void = { [weak self] in
            guard let `self` = self else {return}
            
            _ = showModalProgress(signal: acceptTermsOfService(account: account, id: terms.id) |> deliverOnMainQueue, for: mainWindow).start(next: { [weak self] in
                self?.close()
            })
            if let botname = self.proceedBotAfterAgree {
                _ = (resolvePeerByName(account: self.account, name: botname) |> deliverOnMainQueue).start(next: { [weak self] peerId in
                    guard let `self` = self else {return}
                    if let peerId = peerId {
                        self.account.context.mainNavigation?.push(ChatController(account: self.account, chatLocation: .peer(peerId)))
                    }
                })
            }
        }
        return ModalInteractions(acceptTitle: L10n.termsOfServiceAccept, accept: {
            if let age = terms.ageConfirmation {
                confirm(for: mainWindow, header: L10n.termsOfServiceTitle, information: L10n.termsOfServiceConfirmAge("\(age)"), okTitle: L10n.termsOfServiceDisagreeOK, successHandler: { _ in
                   accept()
                })
            } else {
                accept()
            }
        }, cancelTitle: L10n.termsOfServiceDisagree, cancel: {
            confirm(for: mainWindow, header: L10n.termsOfServiceTitle, information: L10n.termsOfServiceDisagreeText, okTitle: L10n.termsOfServiceDisagreeOK, successHandler: { _ in
                confirm(for: mainWindow, header: L10n.termsOfServiceTitle, information: L10n.termsOfServiceDisagreeTextLast, okTitle: L10n.termsOfServiceDisagreeTextLastOK, successHandler: { _ in
                     _ = resetAccountDueTermsOfService(network: network).start()
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
    
   
    private let account: Account
    private let terms: TermsOfServiceUpdate
    private var proceedBotAfterAgree: String? = nil
    init(_ account: Account, terms: TermsOfServiceUpdate) {
        self.account = account
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
    
    override func viewDidLoad() {
        super.viewDidLoad()
        let attributedString: NSMutableAttributedString = NSMutableAttributedString()
        
        _ = attributedString.append(string: terms.text, color: theme.colors.text, font: .normal(.text))
        
        for entity in terms.entities {
            switch entity.type {
            case .Bold:
                attributedString.addAttribute(NSAttributedStringKey.font, value: NSFont.bold(.text), range: NSMakeRange(entity.range.lowerBound, entity.range.upperBound - entity.range.lowerBound))
            case .Italic:
                attributedString.addAttribute(NSAttributedStringKey.font, value: NSFont.italic(.text), range: NSMakeRange(entity.range.lowerBound, entity.range.upperBound - entity.range.lowerBound))
            case let .TextUrl(url):
                attributedString.addAttribute(NSAttributedStringKey.link, value: url, range: NSMakeRange(entity.range.lowerBound, entity.range.upperBound - entity.range.lowerBound))
                attributedString.addAttribute(NSAttributedStringKey.foregroundColor, value: theme.colors.link, range: NSMakeRange(entity.range.lowerBound, entity.range.upperBound - entity.range.lowerBound))
            case .Mention:
                attributedString.addAttribute(NSAttributedStringKey.link, value: terms.text.nsstring.substring(with: NSMakeRange(entity.range.lowerBound, entity.range.upperBound - entity.range.lowerBound)), range: NSMakeRange(entity.range.lowerBound, entity.range.upperBound - entity.range.lowerBound))
                attributedString.addAttribute(NSAttributedStringKey.foregroundColor, value: theme.colors.link, range: NSMakeRange(entity.range.lowerBound, entity.range.upperBound - entity.range.lowerBound))
            default:
                break
            }
        }
        
        genericView.updateText(attributedString, openBot: { [weak self] botname in
            guard let `self` = self else {return}
            self.proceedBotAfterAgree = botname
            self.show(toaster: ControllerToaster(text: L10n.termsOfServiceProceedBot(botname)))
        })
        
        
        
        updateSize(false)
        readyOnce()
    }
    
    deinit {
    }
    
    override var dynamicSize: Bool {
        return true
    }
    
    override var closable: Bool {
        return false
    }
}
