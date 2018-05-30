//
//  ChatInputRecordingView.swift
//  TelegramMac
//
//  Created by keepcoder on 02/12/2016.
//  Copyright © 2016 Telegram. All rights reserved.
//

import Cocoa
import TGUIKit
import SwiftSignalKitMac
enum ChatInputRecodingState {
    case none
    case recoding(TimeInterval)
    case canceling
}


class ChatInputRecordingView: View {

    private let descView:TextView = TextView()
    private let timerView:TextView = TextView()
    private let statusImage:ImageView = ImageView()
    private let recView: View = View(frame: NSMakeRect(0, 0, 14, 14))
    
    private let chatInteraction:ChatInteraction
    private let recorder:ChatRecordingState
    
    private let disposable:MetaDisposable = MetaDisposable()
    
    private let overlayController: ChatRecorderOverlayWindowController
    init(frame frameRect: NSRect, chatInteraction:ChatInteraction, recorder:ChatRecordingState) {
        self.chatInteraction = chatInteraction
        self.recorder = recorder
        overlayController = ChatRecorderOverlayWindowController(account: chatInteraction.account, parent: mainWindow, chatInteraction: chatInteraction)
        super.init(frame: frameRect)
        
        
        
      //  peakLayer.frame = NSMakeRect(0, 0, 14, 14)
      //  peakLayer.cornerRadius = peakLayer.frame.width / 2
        
        statusImage.image = FastSettings.recordingState == .voice ? theme.icons.chatVoiceRecording : theme.icons.chatVideoRecording
        statusImage.animates = true
        statusImage.sizeToFit()
        
        
        
      //  layer?.addSublayer(peakLayer)
        addSubview(descView)
        addSubview(timerView)
      //  addSubview(statusImage)
        addSubview(recView)
        
        recView.layer?.cornerRadius = recView.frame.width / 2
        
        disposable.set(combineLatest(recorder.status |> deliverOnMainQueue, recorder.holdpromise.get() |> deliverOnMainQueue).start(next: { [weak self] state, hold in
            if case let .recording(duration) = state {
                self?.update(duration, true, hold)
            }
        }))
        
        
        updateLocalizationAndTheme()
    }
    
    override func updateLocalizationAndTheme() {
        super.updateLocalizationAndTheme()
        statusImage.image = FastSettings.recordingState == .voice ? theme.icons.chatVoiceRecording : theme.icons.chatVideoRecording
        backgroundColor = theme.colors.background
        descView.backgroundColor = theme.colors.background
        timerView.backgroundColor = theme.colors.background
        recView.backgroundColor = theme.colors.blueUI
      //  peakLayer.backgroundColor = theme.colors.redUI.cgColor

    }
    
    override func viewWillMove(toWindow newWindow: NSWindow?) {
        if let _ = newWindow as? Window {
            overlayController.show(animated: true)
            let animate = CABasicAnimation(keyPath: "opacity")
            animate.fromValue = 1.0
            animate.toValue = 0.3
            animate.repeatCount = 10000
            animate.duration = 1.5
            
            animate.timingFunction = CAMediaTimingFunction(name: kCAMediaTimingFunctionLinear)
            recView.layer?.add(animate, forKey: "opacity")
        } else {
            (window as? Window)?.removeAllHandlers(for: self)
            overlayController.hide(animated: true)
            recView.layer?.removeAllAnimations()
        }
    }
    
    override func viewDidMoveToWindow() {
        update(0, false, false)
    }


    
    func update(_ duration:TimeInterval, _ animated:Bool, _ hold: Bool) {
        
        let intDuration:Int = Int(duration)
        let ms = duration - TimeInterval(intDuration);
        let transformed:String = String.durationTransformed(elapsed: intDuration)
        let timerLayout = TextViewLayout(.initialize(string:transformed  + ",\(Int(ms * 100))", color: theme.colors.text, font: .normal(.text)), maximumNumberOfLines: 1, alignment: .left)
        timerLayout.measure(width: .greatestFiniteMagnitude)
        timerView.update(timerLayout)
        
        let descLayout = TextViewLayout(.initialize(string: hold ? L10n.audioRecordHelpFixed : L10n.audioRecordHelpPlain, color: theme.colors.text, font: .normal(.text)), maximumNumberOfLines: 2, truncationType: .middle, alignment: .center)
        descLayout.measure(width: frame.width - 50 - 100 - 60)
        descView.update(descLayout)
        
        self.needsLayout = true
        
    }
    
    deinit {
        disposable.dispose()
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    required init(frame frameRect: NSRect) {
        fatalError("init(frame:) has not been implemented")
    }
    
    override func layout() {
        super.layout()
        recView.centerY(x: 20)
        timerView.centerY(x: recView.frame.maxX + 10)
        statusImage.centerY(x: frame.width - statusImage.frame.width - 20)
        
        let max = (frame.width - (statusImage.frame.width + 20 + 50))
        descView.centerY(x:60 + floorToScreenPixels(scaleFactor: backingScaleFactor, (max - descView.frame.width)/2))

    }
    
}
