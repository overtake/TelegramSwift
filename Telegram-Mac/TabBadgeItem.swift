//
//  TabBadgeItem.swift
//  TelegramMac
//
//  Created by keepcoder on 05/01/2017.
//  Copyright © 2017 Telegram. All rights reserved.
//

import Cocoa
import TGUIKit
import Postbox
import SwiftSignalKit
import TelegramCore
import SyncCore

private final class AvatarTabContainer : View {
    private let avatar = AvatarControl(font: .avatar(12))
    private var selected: Bool = false
    private let circle: View = View()
    required init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        avatar.setFrameSize(frameRect.size)
        avatar.userInteractionEnabled = false
        circle.setFrameSize(frameRect.size)
        circle.layer?.cornerRadius = frameRect.height / 2
        circle.layer?.borderWidth = 1.33
        circle.layer?.borderColor = theme.colors.accentIcon.cgColor
        addSubview(circle)
        addSubview(avatar)
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    func setPeer(account: Account, peer: Peer?) {
        avatar.setPeer(account: account, peer: peer)
    }
    
    override func updateLocalizationAndTheme(theme: PresentationTheme) {
        super.updateLocalizationAndTheme(theme: theme)
        circle.layer?.borderColor = theme.colors.accentIcon.cgColor
    }
    
    
    override func layout() {
        super.layout()
        avatar.center()
    }
    
    func setSelected(_ selected: Bool, animated: Bool) {
        self.selected = selected
        
        circle.change(opacity: selected ? 1 : 0, animated: animated, duration: 0.4, timingFunction: .spring)
        
        avatar.setFrameSize(frame.size)

        if animated {
            let from: CGFloat = selected ? 1 : 24 / frame.height
            let to: CGFloat = selected ? 24 / frame.height : 1
            avatar.layer?.animateScaleSpring(from: from, to: to, duration: 0.3, removeOnCompletion: false, bounce: false, completion: { completed in
                
            })
            if selected {
                circle.layer?.animateScaleSpring(from: 0.5, to: 1.0, duration: 0.3, bounce: false)
            } else {
                circle.layer?.animateScaleSpring(from: 1.0, to: 0.5, duration: 0.3, removeOnCompletion: false, bounce: false)
            }
        } else {
            if selected {
                avatar.setFrameSize(NSMakeSize(24, 24))
            } else {
                avatar.setFrameSize(frame.size)
            }
        }

        needsLayout = true
    }

}


class TabBadgeItem: TabItem {
    private let context:AccountContext
    init(_ context: AccountContext, controller:ViewController, image: CGImage, selectedImage: CGImage, longHoverHandler:((Control)->Void)? = nil) {
        self.context = context
        super.init(image: image, selectedImage: selectedImage, controller: controller, subNode:GlobalBadgeNode(context.account, sharedContext: context.sharedContext, dockTile: true, view: View(), removeWhenSidebar: true), longHoverHandler: longHoverHandler)
    }
    override func withUpdatedImages(_ image: CGImage, _ selectedImage: CGImage) -> TabItem {
        return TabBadgeItem(context, controller: self.controller, image: image, selectedImage: selectedImage, longHoverHandler: self.longHoverHandler)
    }
}
class TabAllBadgeItem: TabItem {
    private let context:AccountContext
    private let disposable = MetaDisposable()
    private var peer: Peer?
    init(_ context: AccountContext, image: CGImage, selectedImage: CGImage, controller:ViewController, subNode:Node? = nil, longHoverHandler:((Control)->Void)? = nil) {
        self.context = context
        super.init(image: image, selectedImage: selectedImage, controller: controller, subNode:GlobalBadgeNode(context.account, sharedContext: context.sharedContext, collectAllAccounts: true, view: View(), applyFilter: false), longHoverHandler: longHoverHandler)
    }
    deinit {
        disposable.dispose()
    }
    
    override func withUpdatedImages(_ image: CGImage, _ selectedImage: CGImage) -> TabItem {
        return TabAllBadgeItem(context, image: image, selectedImage: selectedImage, controller: self.controller, subNode: self.subNode, longHoverHandler: self.longHoverHandler)
    }
    
    override func makeView() -> NSView {
        let context = self.context
        
        let semaphore = DispatchSemaphore(value: 0)
        var isMultiple = true
        _ = (context.sharedContext.activeAccounts |> take(1)).start(next: { accounts in
            isMultiple = accounts.accounts.count > 1
            semaphore.signal()
        })

        semaphore.wait()
        
        if !isMultiple {
            return super.makeView()
        }
        
        let view = AvatarTabContainer(frame: NSMakeRect(0, 0, 30, 30))
        /*
         |> distinctUntilChanged(isEqual: { lhs, rhs -> Bool in
         return lhs?.smallProfileImage != rhs?.smallProfileImage
         })
 */
        disposable.set((context.account.postbox.peerView(id: context.account.peerId) |> map { $0.peers[$0.peerId] } |> deliverOnMainQueue).start(next: { [weak view] peer in
            view?.setPeer(account: context.account, peer: peer)
        }))
        
        return view
    }
    
    override func setSelected(_ selected: Bool, for view: NSView, animated: Bool) {
        (view as? AvatarTabContainer)?.setSelected(selected, animated: animated)
        super.setSelected(selected, for: view, animated: animated)
    }
    
}
