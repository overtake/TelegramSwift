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

    let descView:TextView = TextView()
    let timerView:TextView = TextView()
    let peakLayer:CALayer = CALayer()
    
    let statusImage:ImageView = ImageView()
    
    var state:ChatInputRecodingState = .none
    let chatInteraction:ChatInteraction
    let recorder:ChatRecordingState
    var inside:Bool = false
    var currentLevel:CGFloat = 1
    
    let disposable:MetaDisposable = MetaDisposable()
    
    init(frame frameRect: NSRect, chatInteraction:ChatInteraction, recorder:ChatRecordingState) {
        self.chatInteraction = chatInteraction
        self.recorder = recorder
        super.init(frame: frameRect)
        
        peakLayer.frame = NSMakeRect(0, 0, 14, 14)
        peakLayer.cornerRadius = peakLayer.frame.width / 2
        
        statusImage.image = FastSettings.recordingState == .voice ? theme.icons.chatVoiceRecording : theme.icons.chatVideoRecording
        statusImage.animates = true
        statusImage.sizeToFit()
        
        
        
        layer?.addSublayer(peakLayer)
        addSubview(descView)
        addSubview(timerView)
        addSubview(statusImage)
        
        disposable.set((combineLatest(recorder.micLevel, recorder.status) |> deliverOnMainQueue).start(next: { [weak self] (micLevel, state) in
            if case let .recording(duration) = state {
                self?.update(duration, CGFloat(micLevel), true)
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
        peakLayer.backgroundColor = theme.colors.redUI.cgColor

    }
    
    override func viewWillMove(toWindow newWindow: NSWindow?) {
        if let window = newWindow as? Window {
            window.set(mouseHandler: { [weak self] event -> KeyHandlerResult in
                self?.updateInside()
                return .rejected
            }, with: self, for: .leftMouseDragged, priority: .modal)
        } else {
            (window as? Window)?.removeAllHandlers(for: self)
        }
    }
    
    override func viewDidMoveToWindow() {
        update(0, 0, false)
    }


    private func updateInside() {
        guard let superview = superview, let window = window else {
            return;
        }
        let mouse = superview.convert(window.mouseLocationOutsideOfEventStream, from: nil)
        let inside = mouse.x > 0 && mouse.y > 0 && (mouse.x < superview.frame.width && mouse.y < superview.frame.height)
        

        if inside != self.inside {
            self.inside = inside
            let descLayout = TextViewLayout(.initialize(string:tr(L10n.audioRecordReleaseOut), color: inside ? theme.colors.text : theme.colors.redUI, font: .normal(.text)), maximumNumberOfLines: 2, truncationType: .middle, alignment: .center)
            descLayout.measure(width: frame.width - 50 - 100 - 60)
            descView.update(descLayout)
        }
    }
    
    func update(_ duration:TimeInterval, _ peakLevel:CGFloat, _ animated:Bool) {
        
        let intDuration:Int = Int(duration)
        let ms = duration - TimeInterval(intDuration);
        let transformed:String = String.durationTransformed(elapsed: intDuration)
        let timerLayout = TextViewLayout(.initialize(string:transformed  + ",\(Int(ms * 100))", color: theme.colors.text, font: .normal(.text)), maximumNumberOfLines: 1, alignment: .left)
        timerLayout.measure(width: .greatestFiniteMagnitude)
        timerView.update(timerLayout)
        
        
        updateInside()
        
        
        //let scale = min(max(currentLevel * 0.8 + peakLevel * 0.2,1),2);
        let power = min(mappingRange(Double(peakLevel), 0, 1, 1, 1.5),1.5);
       // mappingRange(<#T##x: Double##Double#>, <#T##in_min: Double##Double#>, <#T##in_max: Double##Double#>, <#T##out_min: Double##Double#>, <#T##out_max: Double##Double#>)
        
        
        //if peakLayer.presentation()?.animation(forKey: "transform") == nil {
            peakLayer.animateScale(from:currentLevel, to: CGFloat(power), duration: 0.1, removeOnCompletion:false)
            self.currentLevel = CGFloat(power)
       // }
      
        
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
        peakLayer.frame = NSMakeRect(20, floorToScreenPixels(scaleFactor: backingScaleFactor, (frame.height - peakLayer.frame.height) / 2), 14, 14)
        timerView.centerY(x:peakLayer.frame.maxX + 10)
        statusImage.centerY(x: frame.width - statusImage.frame.width - 20)
        
        let max = (frame.width - (statusImage.frame.width + 20 + 50))
        descView.centerY(x:60 + floorToScreenPixels(scaleFactor: backingScaleFactor, (max - descView.frame.width)/2))

    }
    
}
