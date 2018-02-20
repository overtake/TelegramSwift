//
//  JoinLinkPreviewModalController.swift
//  Telegram
//
//  Created by keepcoder on 04/02/2017.
//  Copyright © 2017 Telegram. All rights reserved.
//

import Cocoa
import TGUIKit
import TelegramCoreMac
import PostboxMac
import SwiftSignalKitMac

private class JoinLinkPreviewView : View {
    private let imageView:AvatarControl = AvatarControl(font: .avatar(.huge))
    private let titleView:TextView = TextView()
    private let basicContainer:View = View()
    private let usersContainer: View = View()
    required init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        self.backgroundColor = theme.colors.background
        imageView.setFrameSize(70,70)
        addSubview(basicContainer)
        basicContainer.backgroundColor = theme.colors.background
        titleView.backgroundColor = theme.colors.background
        basicContainer.addSubview(imageView)
        basicContainer.addSubview(titleView)
        addSubview(usersContainer)
    }
    
    func update(with peer:TelegramGroup, account:Account, participants:[Peer]? = nil, groupUserCount: Int32 = 0) -> Void {
        imageView.setPeer(account: account, peer: peer)
        let attr = NSMutableAttributedString()
        _ = attr.append(string: peer.displayTitle, color: theme.colors.text, font: .normal(.title))
        _ = attr.append(string: "\n")
        
        _ = attr.append(string: tr(L10n.peerStatusMemberCountable(peer.participantCount)), color: theme.colors.grayText, font: .normal(.text))
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
                                ctx.textPosition = NSMakePoint(floorToScreenPixels(scaleFactor: System.backingScale, (size.width - line.frame.width)/2.0) - 1, floorToScreenPixels(scaleFactor: System.backingScale, (size.height - line.frame.height)/2.0) + 4)
                                
                                CTLineDraw(line.line, ctx)
                            }
                        })!
                        avatar.setSignal(generateEmptyPhoto(avatar.frame.size, type: .icon(colors: theme.colors.peerColors(5), icon: icon, iconSize: icon.backingSize)) |> map {($0, false)})
                        usersContainer.addSubview(avatar)
                    }
                    break
                }
               
            }
        }
        
        needsLayout = true
        
        
    }
    
    override func layout() {
        super.layout()
        imageView.centerX(y: 0)
        titleView.centerX(y: 80)
        
        if !usersContainer.subviews.isEmpty {
            basicContainer.centerX(y: 20)
            var x:CGFloat = 0
            for avatar in usersContainer.subviews {
                avatar.setFrameOrigin(NSMakePoint(x, 0))
                x += avatar.frame.width + 10
            }
            usersContainer.setFrameSize(x - 10, usersContainer.subviews[0].frame.height)
        } else {
            basicContainer.center()
        }
        
        usersContainer.centerX(y: basicContainer.frame.maxY + 20)
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}

class JoinLinkPreviewModalController: ModalViewController {

    private let account:Account
    private let join:ExternalJoiningChatState
    private let joinhash:String
    private let interaction:(PeerId?)->Void
    override func viewDidLoad() {
        super.viewDidLoad()
        switch join {
        case let .invite(data):
            let peer = TelegramGroup(id: PeerId(namespace: 0, id: 0), title: data.title, photo: data.photoRepresentation != nil ? [data.photoRepresentation!] : [], participantCount: Int(data.participantsCount), role: .member, membership: .Left, flags: [], migrationReference: nil, creationDate: 0, version: 0)
            genericView.update(with: peer, account: account, participants: data.participants, groupUserCount: data.participantsCount)
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
    
    init(_ account:Account, hash:String, join:ExternalJoiningChatState, interaction:@escaping(PeerId?)->Void) {
        self.account = account
        self.join = join
        self.joinhash = hash
        self.interaction = interaction
        
        var rect = NSMakeRect(0, 0, 270, 180)
        switch join {
        case let .invite(_, _, _, participants):
            if let participants = participants, participants.count > 0 {
                rect.size.height = 230
            }
        default:
            break
        }
        super.init(frame: rect)
        bar = .init(height: 0)
    }
    
    override var modalInteractions: ModalInteractions? {
        return ModalInteractions(acceptTitle: tr(L10n.joinLinkJoin), accept: { [weak self] in
            if let strongSelf = self, let window = strongSelf.window {
                _ = showModalProgress(signal: joinChatInteractively(with: strongSelf.joinhash, account: strongSelf.account), for: window).start(next: { [weak strongSelf] (peerId) in
                    strongSelf?.interaction(peerId)
                    self?.close()
                })
            }
        }, cancelTitle: tr(L10n.modalCancel))
        
    }
    
}
