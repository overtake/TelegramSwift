//
//  File.swift
//  
//
//  Created by Mikhail Filimonov on 11.02.2024.
//

import Foundation
import TGUIKit
import AppKit
import ColorPalette
import Localization

internal final class PeerCallRevealedSecretKeyView : NSVisualEffectView, CallViewUpdater {
   
    
    private let headerView = TextView()
    private let textView = TextView()
    private let ok = TextButton(frame: NSMakeRect(0, 0, 260, 40))
    
    private var arguments: Arguments?
    
    
    required override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        addSubview(headerView)
        addSubview(textView)
        addSubview(ok)
        
        wantsLayer = true
        state = .active
        blendingMode = .withinWindow
        material = .ultraDark
        
        layer?.cornerRadius = 10
        
//        layer?.masksToBounds = false

        headerView.userInteractionEnabled = false
        headerView.isSelectable = false
        
        textView.userInteractionEnabled = false
        textView.isSelectable = false
        //TODOLANG
        let header = TextViewLayout(.initialize(string: L10n.peerCallScreenE2E, color: .white, font: .medium(.title)), alignment: .center)

        header.measure(width: 300 - 40)
        headerView.update(header)
        
        ok.autoSizeToFit = false
        ok.scaleOnClick = true
        
        ok.layer?.cornerRadius = 10
        ok.set(background: darkPalette.grayIcon.withAlphaComponent(0.35), for: .Normal)
        ok.set(font: .medium(.title), for: .Normal)
        ok.set(text: L10n.modalOK, for: .Normal)
        ok.set(color: NSColor.white, for: .Normal)
        ok.sizeToFit(.zero, NSMakeSize(260, 40), thatFit: true)
        
        ok.set(handler: { [weak self] _ in
            self?.arguments?.toggleSecretKey()
        }, for: .Click)
        
//        let shadow = NSShadow()
//        shadow.shadowBlurRadius = 4
//        shadow.shadowColor = NSColor.black.withAlphaComponent(0.6)
//        shadow.shadowOffset = NSMakeSize(0, 0)
//        self.shadow = shadow
//        
//        
        
        let layer = self.layer!
        
        if #available(macOS 10.15, *) {
            layer.cornerCurve = .continuous
        }
        
        layer.masksToBounds = false
        layer.shadowColor = NSColor(white: 0.0, alpha: 1.0).cgColor
        layer.shadowOffset = CGSize(width: 0.0, height: 0)
        layer.shadowRadius = 10
        layer.shadowOpacity = 0.35
////        layer.fillColor = presentation.colors.background.cgColor

    }
    
    override func updateLayer() {
        super.updateLayer()
        
        let sublayers = self.layer?.sublayers ?? []
        
        for sublayer in sublayers {
            sublayer.cornerRadius = 10
        }
    }
    
    override var isFlipped: Bool {
        return true
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    func updateState(_ state: PeerCallState, arguments: Arguments, transition: ContainedViewLayoutTransition) {
        
        self.arguments = arguments
        
        let text = L10n.peerCallScreenE2EInfo(state.compactTitle, "100%")
        let textLayout = TextViewLayout(.initialize(string: text, color: NSColor.white.withAlphaComponent(0.8), font: .normal(.text)).detectBold(with: .medium(.text)), alignment: .center)
        textLayout.measure(width: 300 - 40)
        
        textView.update(textLayout)
        
        self.setFrameSize(NSMakeSize(300, 20 + headerView.frame.height + 20 + 40 + 20 + textLayout.layoutSize.height + 20 + ok.frame.height + 20))
        
        updateLayout(size: self.frame.size, transition: transition)
    }
    
    override func layout() {
        super.layout()
        self.updateLayout(size: self.frame.size, transition: .immediate)
    }
    
    func updateLayout(size: NSSize, transition: ContainedViewLayoutTransition) {
        transition.updateFrame(view: headerView, frame: headerView.centerFrameX(y: 20))
        transition.updateFrame(view: ok, frame: ok.centerFrameX(y: size.height - ok.frame.height - 20))
        transition.updateFrame(view: textView, frame: textView.centerFrameX(y: size.height - textView.frame.height - 20 - 40 - 20))
    }
}
