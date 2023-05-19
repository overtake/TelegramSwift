//
//  SecretChatKeyViewController.swift
//  Telegram
//
//  Created by keepcoder on 15/03/2017.
//  Copyright © 2017 Telegram. All rights reserved.
//

import Cocoa
import TGUIKit
import Postbox
import TelegramCore
import ObjcUtils
import SwiftSignalKit

class SecretChatKeyView : View {
    let imageView:ImageView = ImageView()
    let textView:TextView = TextView()
    let descriptionView =  TextView()
    required init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        addSubview(imageView)
        addSubview(textView)
        addSubview(descriptionView)
        descriptionView.userInteractionEnabled = false
        updateLocalizationAndTheme(theme: theme)
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    func update(with fingerprint: SecretChatKeyFingerprint, participant:Peer) {
        
        let keySignatureData = fingerprint.sha1.data()
        let additionalSignature = fingerprint.sha256.data()
        let image = TGIdenticonImage(keySignatureData, additionalSignature, NSMakeSize(264, 264))
        imageView.image = image.precomposed(flipVertical: true)
        imageView.sizeToFit()
        
        
        
        var data = Data()
        data.append(keySignatureData)
        data.append(additionalSignature)
        
        let s1: String = (data.subdata(in: 0 ..< 8) as NSData).stringByEncodingInHex()
        let s2: String = (data.subdata(in: 8 ..< 16) as NSData).stringByEncodingInHex()
        
        let s3: String = (additionalSignature.subdata(in: 0 ..< 8) as NSData).stringByEncodingInHex()
        let s4: String = (additionalSignature.subdata(in : 8 ..< 16) as NSData).stringByEncodingInHex()
        
        let text: String = "\(s1)\n\(s2)\n\(s3)\n\(s4)"

        let style = NSMutableParagraphStyle()
        style.lineSpacing = 3.0
        style.lineBreakMode = .byWordWrapping
        style.alignment = .center
        let attributedString = NSAttributedString(string: text, attributes: [.paragraphStyle: style, NSAttributedString.Key.font: NSFont.code(.title), .foregroundColor: theme.colors.text])
        
        let layout = TextViewLayout(attributedString, maximumNumberOfLines: 4, alignment: .center)
         
        layout.measure(width: 264)
        textView.update(layout)
        
        let attr = NSMutableAttributedString()
        _ = attr.append(string: strings().encryptionKeyDescription(participant.compactDisplayTitle, participant.compactDisplayTitle), color: theme.colors.grayText, font: .normal(.text))
    
        attr.detectBoldColorInString(with: .medium(.text))
        
        attr.detectLinks(type: [.Links])
        
        let descriptionLayout = TextViewLayout(attr, alignment: .center)
        descriptionLayout.interactions = globalLinkExecutor
        descriptionLayout.measure(width: frame.width - 60)
        descriptionView.update(descriptionLayout)
        
        needsLayout = true
    }
    
    override func updateLocalizationAndTheme(theme: PresentationTheme) {
        super.updateLocalizationAndTheme(theme: theme)
        backgroundColor = theme.colors.grayBackground
        textView.backgroundColor = theme.colors.grayBackground
        descriptionView.backgroundColor = theme.colors.grayBackground
    }
    
    override func layout() {
        super.layout()
        
        imageView.centerX(y: 30)
        textView.centerX(y: imageView.frame.maxY + 30)
        
        descriptionView.textLayout?.measure(width: frame.width - 60)
        descriptionView.centerX(y: textView.frame.maxY + 30)
    }
}

class SecretChatKeyViewController: TelegramGenericViewController<SecretChatKeyView> {

    private let peerId:PeerId
    private let disposable = MetaDisposable()
    
    override func viewDidLoad() {
        super.viewDidLoad()
        disposable.set((combineLatest(context.account.postbox.combinedView(keys: [.peerChatState(peerId: peerId)]), context.account.viewTracker.peerView( peerId), appearanceSignal) |> deliverOnMainQueue).start(next: { [weak self] view, peerView, _ in
           
            if let peerId = self?.peerId, let view = view.views[.peerChatState(peerId: peerId)] as? PeerChatStateView, let state = view.chatState as? SecretChatKeyState {
                if let keyFingerprint = state.keyFingerprint {
                    if let peer = peerViewMainPeer(peerView) {
                        self?.genericView.update(with: keyFingerprint, participant: peer)
                    }
                }
                self?.readyOnce()
            }
        }))
        
    }
    
    override var enableBack: Bool {
        return true
    }
    
    deinit {
        self.disposable.dispose()
    }
    
    init(_ context:AccountContext, peerId:PeerId) {
        self.peerId = peerId
        super.init(context)
    }
}
