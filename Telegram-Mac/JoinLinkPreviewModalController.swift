//
//  JoinLinkPreviewModalController.swift
//  Telegram
//
//  Created by keepcoder on 04/02/2017.
//  Copyright © 2017 Telegram. All rights reserved.
//

import Cocoa
import TGUIKit
import TelegramCore

import Postbox
import SwiftSignalKit

private class JoinLinkPreviewView : View {
    private let imageView:AvatarControl = AvatarControl(font: .avatar(30))
    private let titleView:TextView = TextView()
    private let basicContainer:View = View()
    private let usersContainer: View = View()
    required init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        self.backgroundColor = .clear
        imageView.setFrameSize(70,70)
        addSubview(basicContainer)
        basicContainer.backgroundColor = .clear
        titleView.backgroundColor = .clear
        basicContainer.addSubview(imageView)
        basicContainer.addSubview(titleView)
        addSubview(usersContainer)
        
        titleView.userInteractionEnabled = false
        titleView.isSelectable = false
    }
    
    func update(with peer:TelegramGroup, account:Account, participants:[Peer]? = nil, groupUserCount: Int32 = 0) -> Void {
        
        imageView.setPeer(account: account, peer: peer)
        let attr = NSMutableAttributedString()
        _ = attr.append(string: peer.displayTitle, color: theme.colors.text, font: .normal(.title))
        _ = attr.append(string: "\n")
        
        _ = attr.append(string: strings().peerStatusMemberCountable(peer.participantCount).replacingOccurrences(of: "\(peer.participantCount)", with: peer.participantCount.formattedWithSeparator), color: theme.colors.grayText, font: .normal(.text))
        let titleLayout = TextViewLayout(attr, alignment: .center)
        titleLayout.measure(width: frame.width - 40)
        titleView.update(titleLayout)
        
        basicContainer.setFrameSize(frame.width, imageView.frame.height + titleView.frame.height + 10)
        
        usersContainer.removeAllSubviews()
        
        if let participants = participants {
            for participant in participants {
                if usersContainer.subviews.count < 3 {
                    let avatar = AvatarControl(font: .avatar(20))
                    avatar.setFrameSize(50, 50)
                    avatar.setPeer(account: account, peer: participant)
                    usersContainer.addSubview(avatar)
                } else {
                    let additionCount = Int(groupUserCount) - usersContainer.subviews.count
                    if additionCount > 0 {
                        let avatar = AvatarControl(font: .avatar(20))
                        avatar.setFrameSize(50, 50)
                        avatar.setState(account: account, state: .Empty)
                        let icon = generateImage(NSMakeSize(46, 46), contextGenerator: { size, ctx in
                            ctx.clear(NSMakeRect(0, 0, size.width, size.height))
                            var fontSize: CGFloat = 13
                            
                            if additionCount.prettyNumber.length == 1 {
                                fontSize = 18
                            } else if additionCount.prettyNumber.length == 2 {
                                fontSize = 15
                            }
                            let layout = TextViewLayout(.initialize(string: "+\(additionCount.prettyNumber)", color: .white, font: .medium(fontSize)), maximumNumberOfLines: 1, truncationType: .middle)
                            layout.measure(width: size.width - 4)
                            if !layout.lines.isEmpty {
                                let line = layout.lines[0]
                               // ctx.textMatrix = CGAffineTransform(scaleX: 1.0, y: -1.0)
                                ctx.textPosition = NSMakePoint(floorToScreenPixels(System.backingScale, (size.width - line.frame.width)/2.0) - 1, floorToScreenPixels(System.backingScale, (size.height - line.frame.height)/2.0) + 4)
                                
                                CTLineDraw(line.line, ctx)
                            }
                        })!
                        avatar.setSignal(generateEmptyPhoto(avatar.frame.size, type: .icon(colors: theme.colors.peerColors(5), icon: icon, iconSize: icon.backingSize, cornerRadius: nil), bubble: false) |> map {($0, false)})
                        usersContainer.addSubview(avatar)
                    }
                    break
                }
               
            }
        }
        
        needsLayout = true
        
        
    }
    
    override func setFrameOrigin(_ newOrigin: NSPoint) {
        super.setFrameOrigin(newOrigin)
    }
    
    override func layout() {
        super.layout()
        imageView.centerX(y: 0)
        titleView.centerX(y: imageView.frame.maxY + 10)
        
        if !usersContainer.subviews.isEmpty {
            basicContainer.centerX(y: 0)
            var x:CGFloat = 0
            for avatar in usersContainer.subviews {
                avatar.setFrameOrigin(NSMakePoint(x, 0))
                x += avatar.frame.width + 10
            }
            usersContainer.setFrameSize(x - 10, usersContainer.subviews[0].frame.height)
        } else {
            basicContainer.centerX(y: 0)
        }
        
        usersContainer.centerX(y: basicContainer.frame.maxY + 20)
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}

class JoinLinkPreviewModalController: ModalViewController {

    private let context:AccountContext
    private let join:ExternalJoiningChatState
    private let joinhash:String
    private let interaction:(Peer)->Void
    override func viewDidLoad() {
        super.viewDidLoad()
        switch join {
        case let .invite(state):
            let peer = TelegramGroup(id: PeerId(namespace: Namespaces.Peer.CloudGroup, id: PeerId.Id._internalFromInt64Value(0)), title: state.title, photo: state.photoRepresentation.flatMap { [$0] } ?? [], participantCount: Int(state.participantsCount), role: .member, membership: .Left, flags: [], defaultBannedRights: nil, migrationReference: nil, creationDate: 0, version: 0)
            genericView.update(with: peer, account: context.account, participants: state.participants?.map { $0._asPeer() }, groupUserCount: state.participantsCount)
        default:
            break
        }
        readyOnce()
    }
    
    private var genericView:JoinLinkPreviewView {
        return self.view as! JoinLinkPreviewView
    }
    
    override func viewClass() -> AnyClass {
        return JoinLinkPreviewView.self
    }
    
    init(_ context: AccountContext, hash:String, join:ExternalJoiningChatState, interaction:@escaping(Peer)->Void) {
        self.context = context
        self.join = join
        self.joinhash = hash
        self.interaction = interaction
        
        var rect = NSMakeRect(0, 50, 300, 190)
        switch join {
        case let .invite(state):
            if let participants = state.participants, participants.count > 0 {
                rect.size.height = 260
            }
        default:
            break
        }
        super.init(frame: rect)
    }
    
    override var dynamicSize: Bool {
        return true
    }
    
    override var modalInteractions: ModalInteractions? {
        let context = self.context
        return ModalInteractions(acceptTitle: strings().joinLinkJoin, accept: { [weak self] in
            if let strongSelf = self, let window = strongSelf.window {
                _ = showModalProgress(signal: context.engine.peers.joinChatInteractively(with: strongSelf.joinhash), for: window).start(next: { [weak strongSelf] peer in
                    if let peer = peer?._asPeer() {
                        strongSelf?.interaction(peer)
                    }
                    strongSelf?.close()
                }, error: { error in
                    let text: String
                    switch error {
                    case .generic:
                        text = strings().unknownError
                    case .tooMuchJoined:
                        showInactiveChannels(context: context, source: .join)
                        return
                    case .tooMuchUsers:
                        text = strings().groupUsersTooMuchError
                    case .requestSent:
                        text = strings().unknownError
                    case .flood:
                        text = strings().joinLinkFloodError
                    }
                    alert(for: context.window, info: text)
                })
            }
        }, singleButton: true)
        
    }
    
    override var modalHeader: (left: ModalHeaderData?, center: ModalHeaderData?, right: ModalHeaderData?)? {
        return (left: ModalHeaderData(image: theme.icons.modalClose, handler: { [weak self] in
            self?.close()
        }), center: nil, right: nil)
    }
    
    override var containerBackground: NSColor {
        return theme.colors.listBackground
    }
    
    override var modalTheme: ModalViewController.Theme {
        return .init(text: presentation.colors.text, grayText: presentation.colors.grayText, background: .clear, border: .clear, accent: presentation.colors.accent, grayForeground: presentation.colors.grayBackground, activeBackground: presentation.colors.background, activeBorder: presentation.colors.border)
    }
    
}
