//
//  ChatCallRowItem.swift
//  Telegram
//
//  Created by keepcoder on 05/05/2017.
//  Copyright © 2017 Telegram. All rights reserved.
//

import Cocoa
import TGUIKit
import TelegramCore
import InAppSettings
import SwiftSignalKit
import Postbox

class ChatCallRowItem: ChatRowItem {
    
    private(set) var headerLayout:TextViewLayout?
    private(set) var timeLayout:TextViewLayout?
    
    let outgoing:Bool
    let failed: Bool
    let isVideo: Bool
    private let requestSessionId = MetaDisposable()
    override func viewClass() -> AnyClass {
        return ChatCallRowView.self
    }
    
    private let callId: Int64?
    
    private var activeConferenceUpdateTimer: SwiftSignalKit.Timer?
    
    override init(_ initialSize: NSSize, _ chatInteraction: ChatInteraction, _ context: AccountContext, _ object: ChatHistoryEntry, theme: TelegramPresentationTheme) {
        
        let message = object.message!
        let action = message.media[0] as! TelegramMediaAction
        let isIncoming: Bool = message.isIncoming(context.account, object.renderType == .bubble)
        var updateConferenceTimerEndTimeout: Int32? = nil
        outgoing = !message.flags.contains(.Incoming)
        
        let video: Bool
        switch action.action {
        case let .phoneCall(callId, _, _, isVideo):
            video = isVideo
            self.callId = callId
        default:
            video = false
            self.callId = nil
        }
        self.isVideo = video
        
        switch action.action {
        case let .phoneCall(_, reason, duration, _):
            let attr = NSMutableAttributedString()
            
            headerLayout = TextViewLayout(.initialize(string: outgoing ? (video ? strings().chatVideoCallOutgoing : strings().chatCallOutgoing) : (video ? strings().chatVideoCallIncoming : strings().chatCallIncoming), color: theme.chat.textColor(isIncoming, object.renderType == .bubble), font: .medium(.text)), maximumNumberOfLines: 1)


            if let duration = duration, duration > 0 {
                _ = attr.append(string: String.stringForShortCallDurationSeconds(for: duration), color: theme.chat.grayText(isIncoming, object.renderType == .bubble), font: .normal(.text))
                failed = false
            } else if let reason = reason {
                switch reason {
                case .busy:
                    _ = attr.append(string: outgoing ? strings().chatServiceCallCancelled : strings().chatServiceCallMissed, color: theme.chat.grayText(isIncoming, object.renderType == .bubble), font: .normal(.text))
                case .disconnect:
                    _ = attr.append(string: outgoing ? strings().chatServiceCallCancelled : strings().chatServiceCallMissed, color: theme.chat.grayText(isIncoming, object.renderType == .bubble), font: .normal(.text))
                case .hangup:
                    _ = attr.append(string: outgoing ? strings().chatServiceCallCancelled : strings().chatServiceCallMissed, color: theme.chat.grayText(isIncoming, object.renderType == .bubble), font: .normal(.text))
                case .missed:
                    _ = attr.append(string: outgoing ? strings().chatServiceCallCancelled : strings().chatServiceCallMissed, color: theme.chat.grayText(isIncoming, object.renderType == .bubble), font: .normal(.text))
                }
                failed = true
            } else {
                failed = true
            }
            timeLayout = TextViewLayout(attr, maximumNumberOfLines: 1)
        case let .conferenceCall(conferenceCall):
            
            var hasMissed = false
            var conferenceIsDeclined = false

            let missedTimeout: Int32
            #if DEBUG
            missedTimeout = 5
            #else
            missedTimeout = 30
            #endif
            

            let title: String

            let currentTime = context.timestamp
            if conferenceCall.flags.contains(.isMissed) {
                title = strings().chatServiceDeclinedGroupCall//"Declined Group Call"
            } else if message.timestamp < currentTime - missedTimeout {
                title = strings().chatServiceMissedGroupCall
            } else if conferenceCall.duration != nil {
                title = strings().chatServiceCancelledGroupCall
            } else {
                if isIncoming {
                    title = strings().chatServiceIncomingGroupCall
                } else {
                    title = strings().chatServiceOutgoingGroupCall
                }
                updateConferenceTimerEndTimeout = (message.timestamp + missedTimeout) - currentTime
            }


            
            headerLayout = TextViewLayout(.initialize(string: title, color: theme.chat.textColor(isIncoming, object.renderType == .bubble), font: .medium(.text)), maximumNumberOfLines: 1)
            
            let attr = NSMutableAttributedString()
            

            
            _ = attr.append(string: outgoing ? strings().chatCallOutgoing : strings().chatCallIncoming, color: theme.chat.grayText(isIncoming, object.renderType == .bubble), font: .normal(.text))

            
            if let duration = conferenceCall.duration {
                _ = attr.append(string: ", " + String.stringForShortCallDurationSeconds(for: duration), color: theme.chat.grayText(isIncoming, object.renderType == .bubble), font: .normal(.text))
            }
            
            timeLayout = TextViewLayout(attr, maximumNumberOfLines: 1)
            failed = false
        default:
            failed = true
        }
        
        super.init(initialSize, chatInteraction, context, object, theme: theme)
        
        
        if let activeConferenceUpdateTimer = self.activeConferenceUpdateTimer {
            activeConferenceUpdateTimer.invalidate()
            self.activeConferenceUpdateTimer = nil
        }
        if let updateConferenceTimerEndTimeout, updateConferenceTimerEndTimeout >= 0 {
            self.activeConferenceUpdateTimer?.invalidate()
            self.activeConferenceUpdateTimer = SwiftSignalKit.Timer(timeout: Double(updateConferenceTimerEndTimeout) + 0.5, repeat: false, completion: { [weak self] in
                guard let self else {
                    return
                }
                self.copyAndUpdate(animated: true)
            }, queue: .mainQueue())
            self.activeConferenceUpdateTimer?.start()
        }

    }
    
    
    
    override func makeContentSize(_ width: CGFloat) -> NSSize {
        timeLayout?.measure(width: width)
        headerLayout?.measure(width: width)
        
        let widths:[CGFloat] = [timeLayout?.layoutSize.width ?? width, headerLayout?.layoutSize.width ?? width]
        
        return NSMakeSize((widths.max() ?? 0) + 60, 36)
    }
    
    func requestCall() {
        if let peerId = message?.id.peerId, let message {
            let context = self.context
            
            let action = message.media[0] as! TelegramMediaAction

            switch action.action {
            case .phoneCall:
                requestSessionId.set((phoneCall(context: context, peerId: peerId, isVideo: isVideo) |> deliverOnMainQueue).start(next: { result in
                    applyUIPCallResult(context, result)
                }))
            case let .conferenceCall(conferenceCall):
                
                if conferenceCall.duration != nil {
                    return
                }

                _ = showModalProgress(signal: context.engine.peers.joinCallInvitationInformation(messageId: message.id), for: context.window).startStandalone(next: { [weak self] info in
                    guard let self else {
                        return
                    }
                    self.requestSessionId.set(requestOrJoinConferenceCall(context: context, initialInfo: .init(id: info.id, accessHash: info.accessHash, participantCount: info.totalMemberCount, streamDcId: nil, title: nil, scheduleTimestamp: nil, subscribedToScheduled: false, recordingStartTimestamp: nil, sortAscending: false, defaultParticipantsAreMuted: nil, isVideoEnabled: false, unmutedVideoLimit: 0, isStream: false, isCreator: false), reference: .message(id: message.id)).start(next: { result in
                        switch result {
                        case let .samePeer(callContext), let .success(callContext):
                            applyGroupCallResult(context.sharedContext, callContext)
                        default:
                            alert(for: context.window, info: strings().errorAnError)
                        }
                    }))
                }, error: { error in
                    switch error {
                    case .flood:
                        showModalText(for: context.window, text: strings().loginFloodWait)
                    case .generic:
                        showModalText(for: context.window, text: strings().unknownError)
                    case .doesNotExist:
                        showModalText(for: context.window, text: strings().groupCallInviteNotAvailable)
                    }
                })
                
            default:
                break
            }
            
        }
    }
    
    
    override var lastLineContentWidth: ChatRowItem.LastLineData? {
        if let timeLayout = timeLayout {
            return .init(width: timeLayout.layoutSize.width + 60, single: true)
        } else {
            return super.lastLineContentWidth
        }
    }
    
    deinit {
        requestSessionId.dispose()
    }
}



private class ChatCallRowView : ChatRowView {
    private let fallbackControl:ImageButton = ImageButton()
    private let imageView:ImageView = ImageView()
    private let headerView: TextView = TextView()
    private let timeView:TextView = TextView()
    
    required init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        
        fallbackControl.animates = false
        
        addSubview(fallbackControl)
        addSubview(imageView)
        addSubview(headerView)
        addSubview(timeView)
        headerView.userInteractionEnabled = false
        timeView.userInteractionEnabled = false
        fallbackControl.userInteractionEnabled = false
       
    }
    
    override func mouseUp(with event: NSEvent) {
        if contentView.mouseInside() {
            if let item = item as? ChatCallRowItem {
                item.requestCall()
            }
        } else {
            super.mouseUp(with: event)
        }
    }
    
    override func set(item: TableRowItem, animated: Bool) {
        super.set(item: item, animated: animated)
        
        if let item = item as? ChatCallRowItem {
            
            fallbackControl.set(image: theme.chat.chatCallFallbackIcon(item), for: .Normal)
            _ = fallbackControl.sizeToFit()
            
            imageView.image = theme.chat.chatCallIcon(item)
            imageView.sizeToFit()
            headerView.update(item.headerLayout, origin: NSMakePoint(fallbackControl.frame.maxX + 10, 0))
            timeView.update(item.timeLayout, origin: NSMakePoint(fallbackControl.frame.maxX + 14 + imageView.frame.width, headerView.frame.height + 3))
        }
    }
    
    override func layout() {
        super.layout()
        fallbackControl.centerY(x: 0)
        imageView.setFrameOrigin(fallbackControl.frame.maxX + 10, contentView.frame.height - 4 - imageView.frame.height)
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
}
