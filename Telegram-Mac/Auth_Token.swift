//
//  Auth_QRCode.swift
//  Telegram
//
//  Created by Mike Renoir on 14.02.2022.
//  Copyright © 2022 Telegram. All rights reserved.
//

import Foundation
import TGUIKit
import TelegramCore
import SwiftSignalKit


enum QRTokenState {
    case qr(CGImage)
}

private final class ExportTokenOptionView : View {
    private let textView: TextView = TextView()
    private let optionText = TextView()
    private let cap = View(frame: NSMakeRect(0, 0, 20, 20))
    required init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        
        cap.layer?.cornerRadius = cap.frame.height / 2
        
        textView.isSelectable = false
        textView.userInteractionEnabled = false
        
        optionText.isSelectable = false
        optionText.userInteractionEnabled = false
        addSubview(cap)
        addSubview(self.textView)
        addSubview(self.optionText)
    }
    
    func update(title: String, number: String) {
        let textAttr = NSMutableAttributedString()
        _ = textAttr.append(string: title, color: theme.colors.text, font: .normal(.text))
        textAttr.detectBoldColorInString(with: .medium(.text))
        let text = TextViewLayout(textAttr, maximumNumberOfLines: 2)
        text.measure(width: frame.width - cap.frame.width - 10)
        textView.update(text)
        
        let option = TextViewLayout(.initialize(string: number, color: theme.colors.underSelectedColor, font: .code(.text)), maximumNumberOfLines: 2)
        option.measure(width: frame.width)
        optionText.update(option)
        
        cap.backgroundColor = theme.colors.accent
        
        setFrameSize(NSMakeSize(cap.frame.width + 10 + text.layoutSize.width, max(cap.frame.height, 4 + text.layoutSize.height + 4)))
    }
    
    override func layout() {
        super.layout()
        
        cap.setFrameOrigin(NSZeroPoint)
        let offset: CGFloat = optionText.frame.width == 6 ? 7 : 6
        optionText.setFrameOrigin(NSMakePoint(offset, 2))
        textView.setFrameOrigin(NSMakePoint(cap.frame.maxX + 10, 2))
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}

final class Auth_TokenView : View {
    fileprivate let imageView: ImageView = ImageView(frame: Auth_Insets.qrSize.bounds)
    private let animation: LottiePlayerView = LottiePlayerView(frame: Auth_Insets.qrAnimSize.bounds)
    fileprivate let logoView = LottiePlayerView(frame: NSMakeRect(0, 0, 40, 40))
    private let containerView = View()
    private let titleView = TextView()
    fileprivate let cancelButton = TitleButton()
    
    private let firstHelp: ExportTokenOptionView
    private let secondHelp: ExportTokenOptionView
    private let thridHelp: ExportTokenOptionView
    private let helpView = View()
    
    private let shimmeringView = ShimmerEffectView()

    fileprivate var cancel:(()->Void)?

    required init(frame frameRect: NSRect) {
        firstHelp = ExportTokenOptionView(frame: NSMakeRect(0, 0, frameRect.width, 0))
        secondHelp = ExportTokenOptionView(frame: NSMakeRect(0, 0, frameRect.width, 0))
        thridHelp = ExportTokenOptionView(frame: NSMakeRect(0, 0, frameRect.width, 0))
        super.init(frame: frameRect)
        
        self.imageView.layer?.opacity = 0
        self.imageView.isHidden = true
        
        containerView.addSubview(self.imageView)
        containerView.addSubview(self.animation)
        containerView.addSubview(self.logoView)
        containerView.addSubview(self.titleView)
        containerView.addSubview(self.cancelButton)
        
        containerView.addSubview(helpView)
        
        helpView.addSubview(self.firstHelp)
        helpView.addSubview(self.secondHelp)
        helpView.addSubview(self.thridHelp)

        
        addSubview(containerView)
        titleView.isSelectable = false
        titleView.userInteractionEnabled = false
        updateLocalizationAndTheme(theme: theme)
        
        cancelButton.set(handler: { [weak self] _ in
            self?.cancel?()
        }, for: .Click)
    }
    
    private func measure() {
        let titleLayout = TextViewLayout(.initialize(string: strings().loginQRTitle, color: theme.colors.text, font: .medium(18)), maximumNumberOfLines: 2, alignment: .center)
        titleLayout.measure(width: frame.width)
        titleView.update(titleLayout)
        
        firstHelp.update(title: strings().loginQR1Help1, number: "1")
        secondHelp.update(title: strings().loginQR2Help2, number: "2")
        thridHelp.update(title: strings().loginQR1Help3, number: "3")
        
        cancelButton.set(font: Auth_Insets.infoFontBold, for: .Normal)
        cancelButton.set(color: theme.colors.accent, for: .Normal)
        cancelButton.set(text: strings().loginQRCancel, for: .Normal)
        _ = cancelButton.sizeToFit()
    }
    
    override func updateLocalizationAndTheme(theme: PresentationTheme) {
        let theme = theme as! TelegramPresentationTheme
        super.updateLocalizationAndTheme(theme: theme)
        self.backgroundColor = theme.colors.background
        
        measure()
        
        
        if let data = LocalAnimatedSticker.qrcode_matrix.data {
            let colors:[LottieColor] = [.init(keyPath: "", color: theme.colors.text)]
            self.animation.set(LottieAnimation(compressed: data, key: .init(key: .bundle("qrcode_matrix"), size: Auth_Insets.qrAnimSize, backingScale: Int(System.backingScale), fitzModifier: nil), playPolicy: .loop, colors: colors))
        }

        if let data = LocalAnimatedSticker.login_airplane.data {
            let colors:[LottieColor] = []
            self.logoView.set(LottieAnimation(compressed: data, key: .init(key: .bundle("login_airplane"), size: NSMakeSize(40, 40), backingScale: Int(System.backingScale), fitzModifier: nil), playPolicy: .loop, colors: colors))
        }
        
       needsLayout = true
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    private var first: Bool = true
    private var startTime: TimeInterval = 0
    func update(state: QRTokenState, isLoading: Bool) {
        switch state {
        case let .qr(image):
            self.imageView.animates = true
            self.imageView.image = image
            imageView.sizeToFit()
        }
        
        if !isLoading {
            
            let timeout = max(1, 3 - (Date().timeIntervalSince1970 - startTime))
            
            delay(timeout, closure: { [weak self] in
                self?.imageView.isHidden = false
                self?.imageView.change(opacity: 1, animated: true, duration: 1.2, timingFunction: .spring)
                self?.animation.change(opacity: 0, animated: true, duration: 1.2, timingFunction: .spring, completion: { [weak self] _ in
                    self?.animation.set(nil)
                })
            })
        } else {
            startTime = Date().timeIntervalSince1970
        }
        first = false
        needsLayout = true
    }
    
    override func layout() {
            
        firstHelp.setFrameOrigin(NSMakePoint(0, 0))
        secondHelp.setFrameOrigin(NSMakePoint(0, firstHelp.frame.maxY + 10))
        thridHelp.setFrameOrigin(NSMakePoint(0, secondHelp.frame.maxY + 10))
        
        helpView.setFrameSize(NSMakeSize(max(firstHelp.frame.width, secondHelp.frame.width, thridHelp.frame.width), thridHelp.frame.maxY))

        
        containerView.setFrameSize(NSMakeSize(frame.width, imageView.frame.height + Auth_Insets.betweenHeader + self.titleView.frame.height + Auth_Insets.betweenHeader + helpView.frame.height + Auth_Insets.betweenHeader + cancelButton.frame.height))
        containerView.center()
        
        imageView.centerX(y: 0)
        animation.centerX(y: 12)
        logoView.centerX(y: floor((imageView.frame.height - logoView.frame.height) / 2))
        titleView.updateWithNewWidth(containerView.frame.width)
        titleView.centerX(y: imageView.frame.maxY + Auth_Insets.betweenHeader)

        helpView.centerX(y: titleView.frame.maxY + Auth_Insets.betweenHeader)
       
        cancelButton.centerX(y: helpView.frame.maxY + Auth_Insets.betweenHeader)
        
    }
}


final class Auth_TokenController : GenericViewController<Auth_TokenView> {
    private let temp:Data
    required override init(frame: NSRect) {
        var data = Data(count: 34)
        let _ = data.withUnsafeMutableBytes {
            SecRandomCopyBytes(kSecRandomDefault, 34, $0)
        }
        self.temp = data
        super.init(frame: frame)
    }
    
    func update(_ token: AuthTransferExportedToken?, cancel:@escaping()->Void) {
        
        let tokenString = (token?.value ?? temp).base64EncodedString()
        let urlString = "tg://login?token=\(tokenString)"
        
        let signal = (qrCode(string: urlString, color: theme.colors.text, backgroundColor: theme.colors.background, icon: .custom(theme.icons.login_qr_empty_cap))
                      |> deliverOnMainQueue)
        
        let _ = signal.start(next: { [weak self] _, generate in
                guard let strongSelf = self else {
                    return
                }
                let context = generate(TransformImageArguments(corners: ImageCorners(), imageSize: Auth_Insets.qrSize, boundingSize: Auth_Insets.qrSize, intrinsicInsets: NSEdgeInsets(), scale: 2.0))
                if let image = context?.generateImage() {
                    strongSelf.genericView.update(state: .qr(image), isLoading: token == nil)
                }
            })
        
        genericView.cancel = cancel
    }
    
    
    override func viewDidLoad() {
        super.viewDidLoad()
    }
}
