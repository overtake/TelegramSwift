//
//  LocalizationPreviewModalController.swift
//  Telegram
//
//  Created by Mikhail Filimonov on 11/12/2018.
//  Copyright © 2018 Telegram. All rights reserved.
//

import Cocoa
import TGUIKit
import TelegramCoreMac

private final class LocalizationPreviewView : Control {
    private let titleView: TextView = TextView()
    private let titleContainer: View = View()
    
    private let textView: TextView = TextView()
    required init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        
        titleView.isSelectable = false
        titleView.userInteractionEnabled = false
        
        textView.isSelectable = false
        
        titleContainer.addSubview(titleView)
        addSubview(titleContainer)
        addSubview(textView)
        titleContainer.border = [.Bottom]
    }
    
    func update(with info: LocalizationInfo, width: CGFloat) -> CGFloat {
        let titleLayout = TextViewLayout(.initialize(string: L10n.applyLanguageChangeLanguageTitle, color: theme.colors.text, font: .medium(.title)), alwaysStaticItems: true)
        titleLayout.measure(width: width)
        titleView.update(titleLayout)
        
        
        let text: String
        if info.isOfficial {
            text = L10n.applyLanguageChangeLanguageOfficialText(info.title)
        } else {
            text = L10n.applyLanguageChangeLanguageUnofficialText(info.title, "\(Int(Float(info.translatedStringCount) / Float(info.totalStringCount) * 100.0))")
        }
        
        let attributedText = parseMarkdownIntoAttributedString(text, attributes: MarkdownAttributes(body: MarkdownAttributeSet(font: .normal(.text), textColor: theme.colors.text), bold: MarkdownAttributeSet(font: .bold(.text), textColor: theme.colors.text), link: MarkdownAttributeSet(font: .normal(.text), textColor: theme.colors.link), linkAttribute: { contents in
            return (NSAttributedString.Key.link.rawValue, inAppLink.callback(contents, { _ in
                execute(inapp: .external(link: info.platformUrl, false))
            }))
        })).mutableCopy() as! NSMutableAttributedString
        attributedText.detectBoldColorInString(with: .bold(.text))
        
        let textLayout = TextViewLayout(attributedText, alignment: .center, alwaysStaticItems: true)
        textLayout.measure(width: width - 40)
        
        textLayout.interactions = globalLinkExecutor
        
        textView.update(textLayout)
        
        return 50 + 40 + textLayout.layoutSize.height
    }
    
    override func layout() {
        super.layout()
        titleContainer.frame = NSMakeRect(0, 0, frame.width, 50)
        titleView.center()
        
        textView.centerX(y: titleContainer.frame.maxY + 20)
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}

class LocalizationPreviewModalController: ModalViewController {
    private let context: AccountContext
    private let info: LocalizationInfo
    init(_ context: AccountContext, info: LocalizationInfo) {
        self.info = info
        self.context = context
        super.init(frame: NSMakeRect(0, 0, 320, 200))
        bar = .init(height: 0)
    }
    private var genericView:LocalizationPreviewView {
        return self.view as! LocalizationPreviewView
    }
    
    private func applyLocalization() {
        close()
        _ = showModalProgress(signal: downloadAndApplyLocalization(accountManager: context.sharedContext.accountManager, postbox: context.account.postbox, network: context.account.network, languageCode: info.languageCode), for: mainWindow).start()
    }
    
    override var modalInteractions: ModalInteractions? {
        return ModalInteractions(acceptTitle: L10n.applyLanguageApplyLanguageAction, accept: { [weak self] in
            self?.applyLocalization()
        }, cancelTitle: L10n.modalCancel, height: 50)
    }
    
    override func viewClass() -> AnyClass {
        return LocalizationPreviewView.self
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        let value = genericView.update(with: info, width: frame.width)
        self.modal?.resize(with:NSMakeSize(genericView.frame.width, value), animated: false)
        
        readyOnce()
        
    }
}
