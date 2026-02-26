//
//  SEModalProgressView.swift
//  TelegramMac
//
//  Created by keepcoder on 04/01/2017.
//  Copyright © 2017 Telegram. All rights reserved.
//

import Cocoa
import Localization
import TGUIKit

class SEModalProgressView: View {
    private let progress:LinearProgressControl = LinearProgressControl(progressHeight: 8)
    private let cancel:ImageButton = ImageButton()
    private let header:TextView = TextView()
    private let borderView:View = View()
    private let containerView:View = View()
    private let animationView: SE_LottiePlayerView = SE_LottiePlayerView(frame: NSMakeRect(0, 0, 150, 150))
    override init() {
        super.init()
        containerView.addSubview(animationView)
        containerView.addSubview(progress)
        containerView.addSubview(cancel)
        containerView.addSubview(borderView)
        containerView.addSubview(header)
        addSubview(containerView)
        self.containerView.backgroundColor = theme.colors.background
        
        

        let path = Bundle.main.path(forResource: "duck_uploads", ofType: "tgs")
        if let path = path {
            let data = try? Data(contentsOf: URL(fileURLWithPath: path))
            if let data = data {
                animationView.set(SE_LottieAnimation(compressed: data, key: .init(key: .bundle("duck_uploads"), size: NSMakeSize(150, 150)), playPolicy: .loop))
            }
        }
        
        
        progress.style = ControlStyle(foregroundColor: theme.colors.accent, backgroundColor: theme.colors.grayBackground)
        progress.setFrameSize(250, 8)
        
        progress.layer?.cornerRadius = 4
        
        
        cancel.set(image: theme.icons.modalClose, for: .Normal)
        cancel.scaleOnClick = true
        _ = cancel.sizeToFit(.zero, NSMakeSize(30, 30), thatFit: true)
        
        cancel.set(handler: { [weak self] _ in
            self?.cancelImpl?()
        }, for: .Click)
        
        progress.set(progress: 0.5)
    }
    
    var cancelImpl:(()->Void)? = nil
    
    func set(progress: CGFloat) {
        self.progress.set(progress: progress, animated: true)
        
        let percent = Int(ceil(progress * 100))
        
       
        let layout = TextViewLayout(.initialize(string:  strings().shareExtensionUploading("\(strings().bullet) \(percent)%"), color: theme.colors.text, font: .normal(.title)))
        layout.measure(width: .greatestFiniteMagnitude)
        header.update(layout)
        
        needsLayout = true
    }
    
    func markComplete() {
        let path = Bundle.main.path(forResource: "duck_upload_complete", ofType: "tgs")
        if let path = path {
            let data = try? Data(contentsOf: URL(fileURLWithPath: path))
            if let data = data {
                animationView.set(SE_LottieAnimation(compressed: data, key: .init(key: .bundle("duck_upload_complete"), size: NSMakeSize(150, 150)), playPolicy: .toEnd(from: self.animationView.currentFrame ?? 0)))
            }
        }
    }
    
    override func layout() {
        super.layout()
        containerView.frame = bounds
        cancel.setFrameOrigin(NSMakePoint(10, 10))

        animationView.centerX(y: 90)
        header.centerX(y: animationView.frame.maxY + 20)
        
        progress.centerX(y: header.frame.maxY + 20)
    }
    
    required init(frame frameRect: NSRect) {
        fatalError("init(frame:) has not been implemented")
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
}
