//
//  GroupCallSpeakButton.swift
//  Telegram
//
//  Created by Mikhail Filimonov on 23/11/2020.
//  Copyright © 2020 Telegram. All rights reserved.
//

import Foundation
import TGUIKit

final class GroupCallSpeakButton : Control {
    private let button: LAnimationButton = LAnimationButton(animation: "group_call_speaker_mute", size: NSMakeSize(50, 50))
    private var connectingView: InfiniteProgressView?
    required init(frame frameRect: NSRect) {
        
        super.init(frame: frameRect)
        addSubview(button)

        button.userInteractionEnabled = false
        layer?.cornerRadius = frameRect.height / 2
        backgroundColor = GroupCallTheme.speakActiveColor
    }
    
    override func layout() {
        super.layout()
        button.center()
    }
    
    private var isMuted: Bool?
    func update(with state: PresentationGroupCallState, audioLevel: Float?, animated: Bool) {
        switch state.networkState {
        case .connecting:
            backgroundColor = GroupCallTheme.speakDisabledColor
            userInteractionEnabled = false
        case .connected:
            backgroundColor = state.isMuted ? GroupCallTheme.speakInactiveColor : GroupCallTheme.speakActiveColor
            userInteractionEnabled = true
        }
       
        
        if animated && isMuted != state.isMuted {
            button.setAnimationName(!state.isMuted ? "group_call_speaker_unmute" : "group_call_speaker_mute")
            layer?.animateBackground()
            button.loop()
        }
        if !animated {
            button.setAnimationName(state.isMuted ? "group_call_speaker_unmute" : "group_call_speaker_mute")
        }
        isMuted = state.isMuted
        
        switch state.networkState {
        case .connecting:
            if connectingView == nil {
                connectingView = InfiniteProgressView(color: GroupCallTheme.speakInactiveColor, lineWidth: 3)
                connectingView?.frame = bounds
                connectingView?.progress = nil
                addSubview(connectingView!)
                
                if animated {
                    connectingView?.layer?.animateAlpha(from: 0, to: 1, duration: 0.2)
                }
            }
        case .connected:
            if let connectingView = connectingView {
                self.connectingView = nil
                if animated {
                    connectingView.layer?.animateAlpha(from: 1, to: 0, duration: 0.2, removeOnCompletion: false, completion: { [weak connectingView] _ in
                        connectingView?.removeFromSuperview()
                    })
                } else {
                    connectingView.removeFromSuperview()
                }
            }
        }
        
    }
    
    private var previousState: ControlState?
    
    override func stateDidUpdated( _ state: ControlState) {
        switch controlState {
        case .Highlight:
            self.layer?.animateScaleCenter(from: 1, to: 0.95, duration: 0.2, removeOnCompletion: false)
        default:
            if let previousState = previousState, previousState == .Highlight {
                self.layer?.animateScaleCenter(from: 0.95, to: 1.0, duration: 0.2)
            }
        }
        previousState = state
    }
    
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}
