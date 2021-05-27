//
//  GroupCallSpeakButton.swift
//  Telegram
//
//  Created by Mikhail Filimonov on 23/11/2020.
//  Copyright © 2020 Telegram. All rights reserved.
//

import Foundation
import TGUIKit
import TelegramCore


final class GroupCallSpeakButton : Control {
    private let animationView: LottiePlayerView
    required init(frame frameRect: NSRect) {
        animationView = LottiePlayerView(frame: NSMakeRect(0, 0, frameRect.width - 20, frameRect.height - 20))
        super.init(frame: frameRect)


        scaleOnClick = true
        addSubview(animationView)
    }

    override var mouseDownCanMoveWindow: Bool {
        return false
    }
    
    override func layout() {
        super.layout()
        update(size: bounds.size, transition: .immediate)
    }
    
    func update(size: CGSize, transition: ContainedViewLayoutTransition) {
        let newSize = NSMakeSize(size.width - 20, size.height - 20)
        transition.updateFrame(view: animationView, frame: focus(newSize))
        animationView.update(size: newSize, transition: transition)
    }
    
    private var previousState: PresentationGroupCallState?
    private var previousIsMuted: Bool?
    
    func update(with state: PresentationGroupCallState, isMuted: Bool, animated: Bool) {
        if state.scheduleTimestamp == nil {
            switch state.networkState {
            case .connecting:
                userInteractionEnabled = false
            case .connected:
                if isMuted {
                    if let _ = state.muteState {
                        userInteractionEnabled = true
                    } else {
                        userInteractionEnabled = true
                    }
                } else {
                    userInteractionEnabled = true
                }
            }
        } else {
            userInteractionEnabled = true
        }
       
 
    
        
        let scheduleState = state.scheduleState
        let previousScheduleState = previousState?.scheduleState

        
        let activeRaiseHand = state.muteState?.canUnmute == false
        let previousActiveRaiseHand = previousState?.muteState?.canUnmute == false
        let raiseHandUpdated = activeRaiseHand != previousActiveRaiseHand
        let scheduleUpdated = scheduleState != previousScheduleState
        
        let previousIsMuted = self.previousIsMuted
        let isMutedUpdated = (previousState?.muteState != nil) != (state.muteState != nil) || previousIsMuted != isMuted
                
        if previousState != nil {
            if scheduleUpdated {
                if scheduleState == nil, let previous = previousScheduleState {
                    if state.canManageCall {
                        playChangeState(.voice_chat_start_chat_to_mute)
                    } else {
                        if previous.subscribed {
                            if activeRaiseHand {
                                playChangeState(.voice_chat_cancel_reminder_to_raise_hand)
                            } else {
                                playChangeState(.voice_chat_cancel_reminder_to_mute)
                            }
                        } else {
                            if activeRaiseHand {
                                playChangeState(.voice_chat_set_reminder_to_raise_hand)
                            } else {
                                playChangeState(.voice_chat_set_reminder_to_mute)
                            }
                        }
                    }
                } else {
                    if scheduleState?.subscribed != previousScheduleState?.subscribed {
                        if let subscribed = scheduleState?.subscribed {
                            playChangeState(subscribed ? .voice_chat_cancel_reminder : .voice_chat_set_reminder)
                        }
                    }
                }
                //playChangeState(state.canManageCall ? .voice_chat_start_chat_to_mute : .voice_chat_start_chat_to_mute)
            } else if raiseHandUpdated {
                if activeRaiseHand {
                    playChangeState(previousState?.muteState != nil ? .voice_chat_hand_on_muted : .voice_chat_hand_on_unmuted)
                } else {
                    playChangeState(.voice_chat_hand_off)
                }
            } else if isMutedUpdated {
                if isMuted {
                    playChangeState(.voice_chat_mute)
                } else {
                    playChangeState(.voice_chat_unmute)
                }
            }
        } else {
            if let scheduleState = scheduleState {
                if state.canManageCall {
                    setupScheduled(.voice_chat_start_chat_to_mute)
                } else {
                    setupEndAnimation(scheduleState.subscribed ? .voice_chat_cancel_reminder : .voice_chat_set_reminder)
                }
            } else if activeRaiseHand {
                setupEndAnimation(activeRaiseHand ? .voice_chat_hand_off : .voice_chat_hand_on_muted)
            } else {
                setupEndAnimation(isMuted ? .voice_chat_mute : .voice_chat_unmute)
            }
        }
        
        
        self.previousState = state
        self.previousIsMuted = isMuted
    }
    
    private func setupScheduled(_ animation: LocalAnimatedSticker) {
        if let data = animation.data {
            animationView.set(LottieAnimation(compressed: data, key: .init(key: .bundle(animation.rawValue), size: renderSize), cachePurpose: .none, playPolicy: .framesCount(1), maximumFps: 60, runOnQueue: .mainQueue()))
        }
    }
    
    private func setupEndAnimation(_ animation: LocalAnimatedSticker) {
        if let data = animation.data {
            animationView.set(LottieAnimation(compressed: data, key: .init(key: .bundle(animation.rawValue), size: renderSize), cachePurpose: .none, playPolicy: .toEnd(from: .max), maximumFps: 60, runOnQueue: .mainQueue()))
        }
    }
    private func playChangeState(_ animation: LocalAnimatedSticker) {
        if let data = animation.data {
                           
            let animated = allHands.contains(where: { $0.rawValue == currentAnimation?.rawValue})
            
            var fromFrame: Int32 = 1
            if currentAnimation?.rawValue == animation.rawValue {
                fromFrame = self.animationView.currentFrame ?? 1
            }
            
            animationView.set(LottieAnimation(compressed: data, key: .init(key: .bundle(animation.rawValue), size: renderSize), cachePurpose: .none, playPolicy: .toEnd(from: fromFrame), maximumFps: 60, runOnQueue: .mainQueue()), animated: animated)
            
            
        }
    }
    
    private var renderSize: NSSize {
        return NSMakeSize(120, 120)
    }
    
    let allHands:[LocalAnimatedSticker] = [.voice_chat_raise_hand_1,
                                      .voice_chat_raise_hand_2,
                                      .voice_chat_raise_hand_3,
                                      .voice_chat_raise_hand_4,
                                      .voice_chat_raise_hand_5,
                                      .voice_chat_raise_hand_6,
                                      .voice_chat_raise_hand_7]
    
    private var currentAnimation: LocalAnimatedSticker?
    
    func playRaiseHand() {
        let raise_hand: LocalAnimatedSticker
        
        
        var startFrame: Int32 = 1
        if let current = currentAnimation {
            raise_hand = current
            startFrame = animationView.currentFrame ?? 1
        } else {
            var random = Int.random(in: 0 ... 6)
            loop: while random == 5 || random == 4 {
                let percent = Int.random(in: 0 ..< 100)
                if percent == 1 {
                    break loop
                } else {
                    random = Int.random(in: 0 ... 6)
                }
            }
            raise_hand = allHands[random]
        }
        
        if let data = raise_hand.data {
            let animation = LottieAnimation(compressed: data, key: .init(key: .bundle("\(arc4random())"), size: renderSize), cachePurpose: .none, playPolicy: .toStart(from: startFrame), maximumFps: 60, runOnQueue: .mainQueue())
            
            animation.onFinish = { [weak self] in
                self?.currentAnimation = nil
                self?.animationView.ignoreCachedContext()
            }
            self.currentAnimation = raise_hand
            animationView.set(animation)
        }
    }

    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}


