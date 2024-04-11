//
//  StoryMyInputView.swift
//  Telegram
//
//  Created by Mike Renoir on 05.05.2023.
//  Copyright © 2023 Telegram. All rights reserved.
//

import Foundation
import TGUIKit
import TGModernGrowingTextView
import Postbox
import TelegramCore
import SwiftSignalKit



final class Story_AvatarContentView: View {
    private var disposable: Disposable?
    private var images:[CGImage] = []
    init(context: AccountContext, peers:[Peer]?, size: NSSize) {
        
        
        let count: CGFloat = peers != nil ? CGFloat(peers!.count) : 3
        var sz = size.width + CGFloat(count) * (size.width / 2)
        if count == 1 {
            sz-=size.width/2
        }
        let viewSize = NSMakeSize(sz - (count - 1) * 1, size.height)
        
        super.init(frame: CGRect(origin: .zero, size: viewSize))
        
        layer?.masksToBounds = false
        
        if let peers = peers {
            let signal:Signal<[(CGImage?, Bool)], NoError> = combineLatest(peers.map { peer in
                return peerAvatarImage(account: context.account, photo: .peer(peer, peer.smallProfileImage, peer.nameColor, peer.displayLetters, nil), displayDimensions: NSMakeSize(size.width * System.backingScale, size.height * System.backingScale), font: .avatar(14), genCap: true, synchronousLoad: false)
            })
            
            
            let disposable = (signal
                |> deliverOnMainQueue).start(next: { [weak self] values in
                    guard let strongSelf = self else {
                        return
                    }
                    let images = values.compactMap { $0.0 }
                    strongSelf.updateImages(images)
                })
            self.disposable = disposable
        } else {
            let image = generateImage(NSMakeSize(size.width, size.height), scale: System.backingScale, rotatedContext: { size, ctx in
                ctx.clear(size.bounds)
                ctx.setFillColor(darkAppearance.colors.grayText.withAlphaComponent(0.5).cgColor)
                ctx.fillEllipse(in: size.bounds)
            })!
            self.images = [image, image, image]
        }
       
    }
    
    override func draw(_ layer: CALayer, in context: CGContext) {
        super.draw(layer, in: context)
        
        
        let mergedImageSize: CGFloat = frame.height
        let mergedImageSpacing: CGFloat = frame.height - 10
        
        context.setBlendMode(.copy)
        context.setFillColor(NSColor.clear.cgColor)
        context.fill(bounds)
        
        
        
        var currentX = mergedImageSize + mergedImageSpacing * CGFloat(images.count - 1) - mergedImageSize
        for i in 0 ..< self.images.count {
            
            let image = self.images[i]
                            
            context.saveGState()
            
            context.translateBy(x: frame.width / 2.0, y: frame.height / 2.0)
            context.scaleBy(x: 1.0, y: -1.0)
            context.translateBy(x: -frame.width / 2.0, y: -frame.height / 2.0)
            
            let imageRect = CGRect(origin: CGPoint(x: currentX, y: 0.0), size: CGSize(width: mergedImageSize, height: mergedImageSize))
            
            context.setBlendMode(.clear)
            context.setFillColor(NSColor.red.cgColor)
            context.fillEllipse(in: imageRect.insetBy(dx: -1.0, dy: -1.0))
            context.setBlendMode(.normal)
            context.draw(image, in: imageRect)
            
            currentX -= mergedImageSpacing
            context.restoreGState()
        }
    }
    
    private func updateImages(_ images: [CGImage]) {
        self.images = images
        needsDisplay = true
    }
    
    deinit {
        disposable?.dispose()
    }
    
    required init?(coder decoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    required init(frame frameRect: NSRect) {
        fatalError("init(frame:) has not been implemented")
    }
}

final class Story_LikesCountView : View {
    private let textView: TextView = TextView()
    private let imageView = ImageView()
    required init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        addSubview(imageView)
        addSubview(textView)
        imageView.image = like_image
        imageView.sizeToFit()
        textView.userInteractionEnabled = false
        textView.isSelectable = false
    }
    
    func update(_ count: Int) {
        let string = strings().storyMyInputLikesCountable(count)
        
        let text: NSAttributedString = .initialize(string: string, color: darkAppearance.colors.text, font: .normal(.short))
        let layout = TextViewLayout(text)
        layout.measure(width: .greatestFiniteMagnitude)
        textView.update(layout)
        setFrameSize(NSMakeSize(layout.layoutSize.width + imageView.frame.width + 5, frame.height))
        
    }
    
    override func layout() {
        super.layout()
        imageView.centerY(x: 0)
        textView.centerY(x: imageView.frame.maxX + 5)
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}

private let more_image = NSImage(named: "Icon_StoryMore")!.precomposed(NSColor.white)
private let delete_image = NSImage(named: "Icon_StoryDelete")!.precomposed(NSColor.white)
private let like_image = NSImage(named: "Icon_StoryLike_Count")!.precomposed()


private func makeItem(_ peer: Peer, context: AccountContext, callback:@escaping(PeerId)->Void) -> ContextMenuItem {
    let title = peer.displayTitle.prefixWithDots(20)
    let item = ReactionPeerMenu(title: title, handler: {
        callback(peer.id)
    }, peer: peer, context: context, reaction: nil, destination: .common)
    
    
    return item
}

final class StoryMyInputView : Control, StoryInput {
    
    func like(_ like: StoryReactionAction, resetIfNeeded: Bool) {
        
    }
    
    

    private var photos:[PeerId]? = nil

    private var avatars: Story_AvatarContentView?
    
    private let delete = ImageButton()
    private let more = ImageButton()
    private let views = Control()
    private let viewsText = TextView()
    
    private var like: Story_LikesCountView?
    
    private var arguments: StoryArguments?
    private var story: StoryContentItem?
    
    required init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        self.layer?.cornerRadius = 10
        addSubview(delete)
        addSubview(more)
        addSubview(views)
        views.addSubview(viewsText)
        
        viewsText.userInteractionEnabled = false
        viewsText.isSelectable = false
        
//        views.scaleOnClick = true
        
        more.scaleOnClick = true
        more.autohighlight = false
        
        delete.scaleOnClick = true
        delete.autohighlight = false
        
        more.set(image: more_image, for: .Normal)
        more.sizeToFit(.zero, NSMakeSize(24, 24), thatFit: true)
        
        delete.set(image: delete_image, for: .Normal)
        delete.sizeToFit(.zero, NSMakeSize(24, 24), thatFit: true)
        
        more.contextMenu = { [weak self] in
            let menu = ContextMenu(presentation: AppMenu.Presentation.current(darkAppearance.colors))
            if let story = self?.story, let menu = self?.arguments?.storyContextMenu(story) {
                return menu
            }
            return nil
        }
        
        delete.set(handler: { [weak self] _ in
            self?.deleteAction()
        }, for: .Click)
      
        
        self.views.scaleOnClick = true
    }
    
    private func deleteAction() {
        guard let arguments = self.arguments, let story = self.story else {
            return
        }
        arguments.deleteStory(story)
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    func setArguments(_ arguments: StoryArguments?, groupId: PeerId?) {
        self.arguments = arguments
        
    }
    
    func update(_ story: StoryContentItem, animated: Bool) {
        guard let arguments = self.arguments else {
            return
        }
        self.story = story
        let storyViews = story.storyItem.views
        
        let string = strings().storyMyInputViewsCountable(storyViews?.seenCount ?? 0)
        
        let text: NSAttributedString = .initialize(string: string, color: darkAppearance.colors.text, font: .normal(.short))
        let layout = TextViewLayout(text)
        layout.measure(width: .greatestFiniteMagnitude)
        self.viewsText.update(layout)
        
        
        let avatars: Story_AvatarContentView?
        
        let photos = storyViews?.seenPeers.reversed().map { $0.id } ?? []
        let peers = storyViews?.seenPeers.reversed().map { $0._asPeer() } ?? []
        if photos != self.photos {
            self.photos = photos
            if !photos.isEmpty {
                avatars = .init(context: arguments.context, peers: peers, size: NSMakeSize(24, 24))
            } else {
                avatars = nil
            }
            if let avatars = self.avatars {
                performSubviewRemoval(avatars, animated: animated)
            }
            self.avatars = avatars
            if let avatars = avatars {
                views.addSubview(avatars)
                avatars.centerY(x: 0)
            }
        } else {
            if photos.isEmpty {
                if let avatars = self.avatars {
                    performSubviewRemoval(avatars, animated: animated)
                }
                self.avatars = nil
            }
        }
        
        if let views = story.storyItem.views, views.seenCount > 3 || views.seenCount == 0 {
            self.views.removeAllHandlers()
            self.views.set(handler: { [weak arguments] _ in
                arguments?.showViewers(story)
            }, for: .SingleClick)
        } else {
            self.views.removeAllHandlers()
        }
        
        if let views = story.storyItem.views, views.reactedCount != 0 {
            let current: Story_LikesCountView
            if let view = self.like {
                current = view
            } else {
                current = Story_LikesCountView(frame: NSMakeRect(0, 0, 30, 30))
                self.views.addSubview(current)
                self.like = current
            }
            current.update(views.reactedCount)
        } else if let view = self.like {
            performSubviewRemoval(view, animated: animated)
            self.like = nil
        }
        
        self.views.contextMenu = { [weak self] in
            let menu = ContextMenu(presentation: AppMenu.Presentation.current(darkAppearance.colors))
            if let story = self?.story, let arguments = self?.arguments {
                if let views = story.storyItem.views {
                    for peer in views.seenPeers {
                        menu.addItem(makeItem(peer._asPeer(), context: arguments.context, callback: { peerId in
                            arguments.openPeerInfo(peerId, nil)
                        }))
                    }
                }
            }
            return menu
        }
       
        
        
        let transition: ContainedViewLayoutTransition
        if animated {
            transition = .animated(duration: 0.2, curve: .easeOut)
        } else {
            transition = .immediate
        }
        self.updateLayout(size: self.frame.size, transition: transition)
    }
    
    func updateState(_ state: StoryInteraction.State, animated: Bool) {
        
    }
    
    func updateInputText(_ state: ChatTextInputState, prevState: ChatTextInputState, animated: Bool) {
        
    }
    
    func updateInputState(animated: Bool) {
        guard let superview = self.superview else {
            return
        }
        updateInputSize(size: NSMakeSize(superview.frame.width, 30), animated: animated)
    }
    
    func installInputStateUpdate(_ f: ((StoryInputState) -> Void)?) {
        
    }
    
    func updateInputContext(with result:ChatPresentationInputQueryResult?, context: InputContextHelper, animated:Bool) {
        
    }
    
    
    func resetInputView() {
        
    }
    
    var isFirstResponder: Bool {
        return false
    }
    
    var text: UITextView? {
        return nil
    }
    
    var input: NSTextView? {
        return nil
    }
    
    
    private func updateInputSize(size: NSSize, animated: Bool) {
        let transition: ContainedViewLayoutTransition
        if animated {
            transition = .animated(duration: 0.2, curve: .easeOut)
        } else {
            transition = .immediate
        }
        guard let superview = superview, let window = self.window else {
            return
        }
        
        let wSize = NSMakeSize(window.frame.width - 100, superview.frame.height - 110)
        let aspect = StoryLayoutView.size.aspectFitted(wSize)

        transition.updateFrame(view: self, frame: CGRect(origin: CGPoint(x: floorToScreenPixels(backingScaleFactor,  (superview.frame.width - size.width) / 2), y: aspect.height + 10 - size.height + 30), size: size))
        self.updateLayout(size: size, transition: transition)

    }

    func updateLayout(size: NSSize, transition: ContainedViewLayoutTransition) {
        transition.updateFrame(view: delete, frame: delete.centerFrameY(x: size.width - delete.frame.width - 16))
        transition.updateFrame(view: more, frame: more.centerFrameY(x: delete.frame.minX - more.frame.width - 10))
        var viewsRect = NSMakeRect(16, 0, viewsText.frame.width, size.height)
        if let view = self.like {
            viewsRect.size.width += (view.frame.width + 5)
        }
        if let avatars = self.avatars {
            viewsRect.size.width += avatars.frame.width + 5
            transition.updateFrame(view: views, frame: viewsRect)
            transition.updateFrame(view: avatars, frame: avatars.centerFrameY(x: 0))
            
            transition.updateFrame(view: viewsText, frame: viewsText.centerFrameY(x: avatars.frame.maxX + 5))
            
            if let view = self.like {
                transition.updateFrame(view: view, frame: view.centerFrameY(x: viewsText.frame.maxX + 5))
            }
        } else {
            transition.updateFrame(view: views, frame: viewsRect)
            transition.updateFrame(view: viewsText, frame: viewsText.centerFrameY(x: 0))
            
            if let view = self.like {
                transition.updateFrame(view: view, frame: view.centerFrameY(x: viewsText.frame.maxX + 5))
            }
        }
    }
    
    override func layout() {
        super.layout()
        self.updateLayout(size: self.frame.size, transition: .immediate)
    }
    
}
