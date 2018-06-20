//
//  ChatTitleView.swift
//  Telegram-Mac
//
//  Created by keepcoder on 08/11/2016.
//  Copyright © 2016 Telegram. All rights reserved.
//

import Cocoa
import TGUIKit
import PostboxMac
import TelegramCoreMac
import SwiftSignalKitMac

private class ConnectionStatusView : View {
    private var textViewLayout:TextViewLayout?
    private var disableProxyButton: TitleButton?
    
    var disableProxy:(()->Void)?
    
    var status:ConnectionStatus = .online(proxyAddress: nil) {
        didSet {
            let attr:NSAttributedString
            
            if case let .connecting(proxy, _) = status {
                if let _ = proxy {
                    if disableProxyButton == nil {
                        disableProxyButton = TitleButton()
                    }
                    disableProxyButton?.set(color: theme.colors.grayText, for: .Normal)
                    disableProxyButton?.set(font: .medium(.text), for: .Normal)
                    disableProxyButton?.set(text: tr(L10n.connectingStatusDisableProxy), for: .Normal)
                    _ = disableProxyButton?.sizeToFit()
                    addSubview(disableProxyButton!)
                    
                    disableProxyButton?.set(handler: { [weak self] _ in
                        self?.disableProxy?()
                        }, for: .Click)
                } else {
                    disableProxyButton?.removeFromSuperview()
                    disableProxyButton = nil
                }
            } else {
                disableProxyButton?.removeFromSuperview()
                disableProxyButton = nil
            }
            
            switch status {
            case let .connecting(proxy, _):
                attr = .initialize(string: proxy != nil ? L10n.chatConnectingStatusConnectingToProxy : L10n.chatConnectingStatusConnecting, color: theme.colors.text, font: .medium(.header))
            case .updating:
                attr = .initialize(string: L10n.chatConnectingStatusUpdating, color: theme.colors.text, font: .medium(.header))
            case .waitingForNetwork:
                attr = .initialize(string: L10n.chatConnectingStatusWaitingNetwork, color: theme.colors.text, font: .medium(.header))
            case .online:
                attr = NSAttributedString()
            }
            textViewLayout = TextViewLayout(attr, maximumNumberOfLines: 1)
            needsLayout = true
           // indicator.animates = true
        }
    }
    private let textView:TextView = TextView()
    private let indicator:ProgressIndicator = ProgressIndicator()
    required init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
       // indicator.setFrameSize(18,18)
//        indicator.numberOfLines = 8
//        indicator.innerMargin = 3
//        indicator.widthOfLine = 3
//        indicator.lengthOfLine = 6
        textView.userInteractionEnabled = false
        textView.isSelectable = false
        addSubview(textView)
        addSubview(indicator)
        
        updateLocalizationAndTheme()
    }
    
    override func updateLocalizationAndTheme() {
        super.updateLocalizationAndTheme()
        backgroundColor = theme.colors.background
        textView.backgroundColor = theme.colors.background
        disableProxyButton?.set(background: theme.colors.background, for: .Normal)
     //   indicator.color = theme.colors.indicatorColor
        let status = self.status
        self.status = status
    }

    deinit {
        //indicator.animates = false
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    fileprivate override func layout() {
        super.layout()
        
        if let textViewLayout = textViewLayout {
            textViewLayout.measure(width: frame.width)
            let f = focus(textViewLayout.layoutSize, inset:NSEdgeInsets(left: 12, top: 3))
            indicator.centerY(x:0)
            
            
            textView.update(textViewLayout)
            
            if let disableProxyButton = disableProxyButton {
                disableProxyButton.setFrameOrigin(indicator.frame.maxX + 2, floorToScreenPixels(scaleFactor: backingScaleFactor, frame.height / 2) + 2)
                textView.setFrameOrigin(indicator.frame.maxX + 8, floorToScreenPixels(scaleFactor: backingScaleFactor, frame.height / 2) - textView.frame.height + 2)
            } else {
                textView.setFrameOrigin(NSMakePoint(indicator.frame.maxX + 4, f.origin.y))
            }
            
        }
        
    }
    
}


class ChatTitleBarView: TitledBarView {
    
    private var isSingleLayout:Bool = false
    private var connectionStatusView:ConnectionStatusView? = nil
    private let activities:ChatActivitiesModel
    private let searchButton:ImageButton = ImageButton()
    private let callButton:ImageButton = ImageButton()
    private let chatInteraction:ChatInteraction
    private let avatarControl:AvatarControl = AvatarControl(font: .avatar(.header))
    private let badgeNode:GlobalBadgeNode
    private let disposable = MetaDisposable()
    private let closeButton = ImageButton()
    var connectionStatus:ConnectionStatus = .online(proxyAddress: nil) {
        didSet {
            if connectionStatus != oldValue {
                if case .online = connectionStatus {
                    
                    //containerView.change(pos: NSMakePoint(0, 0), animated: true)
                    if let connectionStatusView = connectionStatusView {
                        
                        connectionStatusView.change(pos: NSMakePoint(0, -frame.height), animated: true)
                        connectionStatusView.layer?.animateAlpha(from: 1, to: 0, duration: 0.2, removeOnCompletion:false, completion:{ [weak self] completed in
                            self?.connectionStatusView?.removeFromSuperview()
                            self?.connectionStatusView = nil
                        })
                        
                    }
                    
                } else {
                    if connectionStatusView == nil {
                        connectionStatusView = ConnectionStatusView(frame: NSMakeRect(0, -frame.height, frame.width, frame.height))
                        connectionStatusView?.disableProxy = chatInteraction.disableProxy
                        addSubview(connectionStatusView!)
                        connectionStatusView?.change(pos: NSMakePoint(0,0), animated: true)
                      //  containerView.change(pos: NSMakePoint(0, frame.height), animated: true)
                    }
                    
                    connectionStatusView?.status = connectionStatus

                }
            }
        }
    }
   
    var postboxView:PostboxView? {
        didSet {
           updateStatus()
        }
    }
    
    var inputActivities:(PeerId, [(Peer, PeerInputActivity)])? {
        didSet {
            if let inputActivities = inputActivities  {
                activities.update(with: inputActivities, for: max(frame.width - 80, 160), theme:theme.activity(key: 4, foregroundColor: theme.colors.blueUI, backgroundColor: theme.colors.background), layout: { [weak self] show in
                    self?.needsLayout = true
                    self?.hiddenStatus = show
                    self?.setNeedsDisplay()
                    self?.activities.view?.isHidden = !show
                })
            } else {
                activities.clean()
            }
        }
    }
    
    
    var presenceManager:PeerPresenceStatusManager?
    
    init(controller: ViewController, _ chatInteraction:ChatInteraction) {
        activities = ChatActivitiesModel()
        self.chatInteraction = chatInteraction
        
        searchButton.disableActions()
        callButton.disableActions()
        
        var layoutChanged:(()->Void)?
        
        badgeNode = GlobalBadgeNode(chatInteraction.account, excludePeerId: self.chatInteraction.peerId, layoutChanged: {
            layoutChanged?()
        })

        super.init(controller: controller, textInset: 46)
        
        layoutChanged = {
            //self?.needsLayout = true
        }
        
        
        searchButton.set(handler: { [weak self] _ in
            self?.chatInteraction.update({$0.updatedSearchMode(!$0.isSearchMode)})
        }, for: .Click)
        
        addSubview(searchButton)
        self.presenceManager = PeerPresenceStatusManager(update: { [weak self] in
            self?.updateStatus()
        })
        
        callButton.set(handler: { _ in
           chatInteraction.call()
        }, for: .Click)
        
        addSubview(activities.view!)
        activities.view?.isHidden = true
        callButton.isHidden = true
        addSubview(callButton)
        
        avatarControl.setFrameSize(36,36)
        addSubview(avatarControl)
        
        disposable.set(chatInteraction.account.context.layoutHandler.get().start(next: { [weak self] state in
            if let strongSelf = self {
                switch state {
                case .single:
                    strongSelf.isSingleLayout = true
                    strongSelf.badgeNode.view?.isHidden = false
                    strongSelf.closeButton.isHidden = false
                default:
                    strongSelf.isSingleLayout = strongSelf.controller is ChatAdditionController
                    strongSelf.badgeNode.view?.isHidden = true
                    strongSelf.closeButton.isHidden = !(strongSelf.controller is ChatAdditionController)
                }
                strongSelf.textInset = strongSelf.isSingleLayout ? 66 : 46
                strongSelf.needsLayout = true
            }
        }))
            
        
        closeButton.autohighlight = false
        closeButton.set(image: theme.icons.chatNavigationBack, for: .Normal)
        closeButton.set(handler: { [weak self] _ in
            self?.chatInteraction.account.context.mainNavigation?.back()
        }, for: .Click)
        _ = closeButton.sizeToFit()
        closeButton.setFrameSize(closeButton.frame.width, frame.height)
        addSubview(closeButton)
        
        avatarControl.userInteractionEnabled = false
        
        addSubview(badgeNode.view!)
        
        updateLocalizationAndTheme()
    }
    
    override func setFrameSize(_ newSize: NSSize) {
        super.setFrameSize(newSize)
        self.connectionStatusView?.setFrameSize(newSize)
        let input = self.inputActivities
        self.inputActivities = input
        
    }
    
    override func mouseUp(with event: NSEvent) {
        if isSingleLayout {
            let point = convert(event.locationInWindow, from: nil)
            if point.x > 20 {
                if chatInteraction.peerId == chatInteraction.account.peerId {
                    chatInteraction.account.context.mainNavigation?.push(PeerMediaController(account: chatInteraction.account, peerId: chatInteraction.peerId, tagMask: .photoOrVideo))
                } else {
                    switch chatInteraction.chatLocation {
                    case let .group(groupId):
                        chatInteraction.openFeedInfo(groupId)
                    case let .peer(peerId):
                        chatInteraction.openInfo(peerId, false, nil, nil)
                    }
                }
            } else {
                chatInteraction.account.context.mainNavigation?.back()
            }
        } else {
            if chatInteraction.peerId == chatInteraction.account.peerId {
                chatInteraction.account.context.mainNavigation?.push(PeerMediaController(account: chatInteraction.account, peerId: chatInteraction.peerId, tagMask: .photoOrVideo))
            } else {
                switch chatInteraction.chatLocation {
                case let .group(groupId):
                    chatInteraction.openFeedInfo(groupId)
                case let .peer(peerId):
                    chatInteraction.openInfo(peerId, false, nil, nil)
                }
            }
        }
    }
    
    deinit {
        disposable.dispose()
    }
    
    override func layout() {
        super.layout()
        
        let additionInset:CGFloat = isSingleLayout ? 20 : 0
        
        avatarControl.centerY(x: additionInset)
        searchButton.centerY(x:frame.width - searchButton.frame.width)
        callButton.centerY(x: searchButton.isHidden ? frame.width - callButton.frame.width : searchButton.frame.minX - callButton.frame.width - 20)
        activities.view?.setFrameOrigin(avatarControl.frame.maxX + 8, 25)
        badgeNode.view!.setFrameOrigin(6,4)
        
        closeButton.centerY()
    }
    
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    required init(frame frameRect: NSRect) {
        fatalError("init(frame:) has not been implemented")
    }

    override var inset:CGFloat {
        return 36 + 50 + (callButton.isHidden ? 20 : callButton.frame.width + 30)
    }
    


    func updateStatus(_ force:Bool = false) {
        var shouldUpdateLayout = false
        if let peerView = self.postboxView as? PeerView {
            
            if let peer = peerViewMainPeer(peerView) {
                callButton.isHidden = !peer.canCall || chatInteraction.peerId == chatInteraction.account.peerId
            } else {
                callButton.isHidden = true
            }
            
            if let peer = peerViewMainPeer(peerView) {
                if peer.id == chatInteraction.account.peerId {
                    let icon = theme.icons.peerSavedMessages
                    avatarControl.setSignal(generateEmptyPhoto(avatarControl.frame.size, type: .icon(colors: theme.colors.peerColors(5), icon: icon, iconSize: icon.backingSize.aspectFitted(NSMakeSize(avatarControl.frame.size.width - 20, avatarControl.frame.size.height - 20)))) |> map {($0, false)})
                } else {
                    avatarControl.setPeer(account: chatInteraction.account, peer: peer)
                }
            }
            
            if peerView.peers[peerView.peerId] is TelegramSecretChat {
                titleImage = theme.icons.chatSecretTitle
            } else {
                titleImage = nil
            }
            
            var result = stringStatus(for: peerView, theme: PeerStatusStringTheme(titleFont: .medium(.title)))
            
            if chatInteraction.account.peerId == peerView.peerId  {
                result = result.withUpdatedTitle(tr(L10n.peerSavedMessages))
            }
            if chatInteraction.account.peerId == peerView.peerId {
                status = nil
            } else if status == nil || !status!.isEqual(to: result.status) || force {
                status = result.status
                shouldUpdateLayout = true
            }
            
            if text == nil || !text!.isEqual(to: result.title) || force {
                text = result.title
                shouldUpdateLayout = true
            }
            
            if let presence = result.presence {
                self.presenceManager?.reset(presence: presence)
            }
            if shouldUpdateLayout {
                self.setNeedsDisplay()
            }
        } else  if let view = postboxView as? ChatListTopPeersView {
            avatarControl.setState(account: chatInteraction.account, state: .GroupAvatar(view.peers))
            status = nil
            text = .initialize(string: L10n.chatTitleFeed, color: theme.colors.text, font: .medium(.title))
        }
    }
    
    
    override func updateLocalizationAndTheme() {
        super.updateLocalizationAndTheme()
        
        searchButton.set(image: theme.icons.chatSearch, for: .Normal)
        _ = searchButton.sizeToFit()
        
        callButton.set(image: theme.icons.chatCall, for: .Normal)
        _ = callButton.sizeToFit()
        
        closeButton.set(image: theme.icons.chatNavigationBack, for: .Normal)
        let inputActivities = self.inputActivities
        self.inputActivities = inputActivities
        
        if let peerView = postboxView as? PeerView, peerView.peers[peerView.peerId] is TelegramSecretChat {
            titleImage = theme.icons.chatSecretTitle
        } else {
            titleImage = nil
        }
        
    }
}
