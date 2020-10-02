//
//  ChatCommentsBubbleControl.swift
//  Telegram
//
//  Created by Mikhail Filimonov on 02/09/2020.
//  Copyright © 2020 Telegram. All rights reserved.
//

import Cocoa
import TGUIKit
import SyncCore
import Postbox
import SwiftSignalKit

private let duration: TimeInterval = 0.4
private let timingFunction: CAMediaTimingFunctionName = .spring


private final class AvatarContentView: View {
    private let unclippedView: ImageView
    private let clippedView: ImageView
    
    private var disposable: Disposable?
    
    init(context: AccountContext, peer: Peer, message: Message?, synchronousLoad: Bool) {
        self.unclippedView = ImageView()
        self.clippedView = ImageView()
        
        super.init()
        
        self.addSubview(self.unclippedView)
        self.addSubview(self.clippedView)
        
        
        let signal = peerAvatarImage(account: context.account, photo: .peer(peer, peer.smallProfileImage, peer.displayLetters, message), displayDimensions: NSMakeSize(22, 22), scale: System.backingScale, font: .normal(10), genCap: true, synchronousLoad: synchronousLoad)
        
        let disposable = (signal
            |> deliverOnMainQueue).start(next: { [weak self] image in
                guard let strongSelf = self else {
                    return
                }
                if let image = image.0 {
                    strongSelf.updateImage(image: image)
                }
            })
        self.disposable = disposable
    }
    
    required init?(coder decoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    required init(frame frameRect: NSRect) {
        fatalError("init(frame:) has not been implemented")
    }
    
    private func updateImage(image: CGImage) {
        self.unclippedView.image = image
        self.clippedView.image = generateImage(CGSize(width: 22, height: 22), rotatedContext: { size, context in
            context.clear(CGRect(origin: CGPoint(), size: size))
            context.translateBy(x: size.width / 2.0, y: size.height / 2.0)
            context.scaleBy(x: 1.0, y: -1.0)
            context.translateBy(x: -size.width / 2.0, y: -size.height / 2.0)
            context.draw(image, in: CGRect(origin: CGPoint(), size: size))
            context.translateBy(x: size.width / 2.0, y: size.height / 2.0)
            context.scaleBy(x: 1.0, y: -1.0)
            context.translateBy(x: -size.width / 2.0, y: -size.height / 2.0)
            
            context.setBlendMode(.copy)
            context.setFillColor(NSColor.clear.cgColor)
            context.fillEllipse(in: CGRect(origin: CGPoint(), size: size).insetBy(dx: -1.5, dy: -1.5).offsetBy(dx: -19.0, dy: 0.0))
        })
    }
    
    deinit {
        self.disposable?.dispose()
    }
    
    func updateLayout(size: CGSize, isClipped: Bool, animated: Bool) {
        self.unclippedView.frame = CGRect(origin: CGPoint(), size: size)
        self.clippedView.frame = CGRect(origin: CGPoint(), size: size)
        self.unclippedView.change(opacity: isClipped ? 0.0 : 1.0, animated: animated)
        self.clippedView.change(opacity: isClipped ? 1.0 : 0.0, animated: animated)
    }
}




protocol ChannelCommentRenderer {
    func update(data: ChannelCommentsRenderData, size: NSSize, animated: Bool)
    var firstTextPosition: NSPoint { get }
    var lastTextPosition: NSPoint { get }
    var progressIndicatorPosition: NSPoint { get }
    var progressIndicatorSize: NSSize { get }
    var progressIndicatorColor: NSColor { get }
}


class CommentsBasicControl : Control, ChannelCommentRenderer {
    
    fileprivate var textViews: [ChannelCommentsRenderData.Text : (TextView, ChannelCommentsRenderData.Text)] = [:]
    fileprivate var renderData: ChannelCommentsRenderData?
    fileprivate var size: NSSize = .zero
    fileprivate var progressView: ProgressIndicator?
    func update(data: ChannelCommentsRenderData, size: NSSize, animated: Bool) {
        let previousLastTextPosition = lastTextPosition
        self.size = size
        self.renderData = data
        
        self.removeAllHandlers()
        
        self.set(handler: { [weak data] _ in
            data?.handler()
        }, for: .SingleClick)
        
        
        enum NumericAnimation {
            case forward
            case backward
        }
        
        var addition: [Int : NumericAnimation] = [:]
        var previousTextPos:[Int: NSPoint] = [:]
        for (key, textView) in textViews {
            let title = data._title.first(where: { $0.hashValue == key.hashValue })
            if textView.1 != title {
                let updated = title ?? key
                if let title = title {
                    addition[key.hashValue] = title < key ? .backward : .forward
                }
                
                textViews[key] = nil
                let field = textView.0
                previousTextPos[key.hashValue] = field.frame.origin
                if animated {
                    switch updated.animation {
                    case .crossFade:
                        field.layer?.animateAlpha(from: 1, to: 0, duration: duration, timingFunction: timingFunction, removeOnCompletion: false, completion: { [weak field] _ in
                            field?.removeFromSuperview()
                        })
                    case .numeric:
                        field.layer?.animateAlpha(from: 1, to: 0, duration: duration, timingFunction: timingFunction, removeOnCompletion: false, completion: { [weak field] _ in
                            field?.removeFromSuperview()
                        })
                        
                        let direction = addition[key.hashValue]
                        switch direction {
                        case .forward?:
                            field.layer?.animatePosition(from: field.frame.origin, to: NSMakePoint(field.frame.minX, field.frame.maxY), timingFunction: timingFunction, removeOnCompletion: false)
                        case .backward?:
                            field.layer?.animatePosition(from: field.frame.origin, to: NSMakePoint(field.frame.minX, field.frame.minY - field.frame.height), timingFunction: timingFunction, removeOnCompletion: false)
                        case .none:
                            break
                        }
                    }
                } else {
                    field.removeFromSuperview()
                }
            }
        }
        var pos = firstTextPosition
        for layout in data.titleLayout {
            if let view = textViews[layout.1] {
                if animated {
                    view.0.layer?.animatePosition(from: view.0.frame.origin - pos, to: .zero, timingFunction: timingFunction, removeOnCompletion: true, additive: true)
                }
                view.0.setFrameOrigin(pos)
            } else {
                let current = TextView()
                current.userInteractionEnabled = false
                current.isSelectable = false
                current.disableBackgroundDrawing = true
                self.textViews[layout.1] = (current, layout.1)
                current.update(layout.0, origin: pos)
                addSubview(current)
                if animated {
                    switch layout.1.animation {
                    case .crossFade:
                        current.layer?.animateAlpha(from: 0, to: 1, duration: duration)
                    case .numeric:
                        let prevPos = previousTextPos[layout.1.hashValue] ?? pos
                        let direction = addition[layout.1.hashValue]
                        switch direction {
                        case .forward?:
                            current.layer?.animatePosition(from: NSMakePoint(pos.x, pos.y - layout.0.layoutSize.height), to: pos, timingFunction: timingFunction)
                        case .backward?:
                            current.layer?.animatePosition(from: NSMakePoint(pos.x, pos.y + layout.0.layoutSize.height), to: pos, timingFunction: timingFunction)
                        case .none:
                            break
                        }
                        
                        current.layer?.animateAlpha(from: 0, to: 1, duration: duration)
                    }
                }
            }
            pos.x += max(layout.0.layoutSize.width, 4)
        }
        
        if data.isLoading {
            if progressView == nil {
                let indicator = ProgressIndicator(frame: NSMakeRect(0, 0, progressIndicatorSize.width, progressIndicatorSize.height))
                self.progressView = indicator
                self.progressView?.progressColor = progressIndicatorColor
                addSubview(indicator)
                if animated {
                    indicator.layer?.animateAlpha(from: 0, to: 1, duration: duration,  timingFunction: timingFunction)
                }
            }
            self.progressView?.progressColor = progressIndicatorColor
        } else {
            if animated {
                if let progressView = self.progressView {
                    self.progressView = nil
                    progressView.layer?.animateAlpha(from: 1, to: 0, duration: duration, timingFunction: timingFunction, removeOnCompletion: false, completion: { [weak progressView] _ in
                        progressView?.removeFromSuperview()
                    })
                }
            } else {
                self.progressView?.removeFromSuperview()
                self.progressView = nil
            }
        }
        self.progressView?.setFrameOrigin(progressIndicatorPosition)
    }
    
    var firstTextPosition: NSPoint {
        return .zero
    }
    
    var progressIndicatorSize: NSSize {
        return NSMakeSize(16, 16)
    }
    
    var progressIndicatorPosition: NSPoint {
        var rect = focus(progressIndicatorSize)
        rect.origin.x = 0
        return rect.origin
    }
    
    var progressIndicatorColor: NSColor {
        return theme.colors.accentIcon
    }
    
    override func layout() {
        super.layout()
        progressView?.setFrameOrigin(progressIndicatorPosition)
    }
    
    var lastTextPosition: NSPoint {
        guard let render = renderData, !render.titleLayout.isEmpty else {
            return .zero
        }
        
        return firstTextPosition + NSMakePoint(render.titleLayout.reduce(0, {
            $0 + max($1.0.layoutSize.width, 4)
        }), 0)
    }

}


final class ChannelCommentsRenderData {
    
    struct Text : Hashable, Comparable {
        enum Animation : Equatable {
            case crossFade
            case numeric
        }
        let text: NSAttributedString
        let animation: Animation
        let index: Int
        
        init(text: NSAttributedString, animation: Animation, index: Int) {
            self.text = text
            self.animation = animation
            self.index = index
        }
        
        static func <(lhs: Text, rhs: Text) -> Bool {
            let lhsInt: Int? = Int(lhs.text.string)
            let rhsInt: Int? = Int(rhs.text.string)
            
            if let lhsInt = lhsInt, let rhsInt = rhsInt {
                return lhsInt < rhsInt
            }
            return false
        }
        
        
        func hash(into hasher: inout Hasher) {
            hasher.combine(index)
        }
    }
    
    struct Avatar : Comparable, Identifiable {
        static func < (lhs: Avatar, rhs: Avatar) -> Bool {
            return lhs.index < rhs.index
        }
        
        var stableId: PeerId {
            return peer.id
        }
        
        static func == (lhs: ChannelCommentsRenderData.Avatar, rhs: ChannelCommentsRenderData.Avatar) -> Bool {
            if lhs.index != rhs.index {
                return false
            }
            if !lhs.peer.isEqual(rhs.peer) {
                return false
            }
            return true
        }
        
        let peer: Peer
        let index: Int
    }
    
    var titleSize: NSSize {
        return titleLayout.reduce(NSZeroSize, { current, value in
            var current = current
            current.width += max(value.0.layoutSize.width, 4)
            current.height = max(value.0.layoutSize.height, current.height)
            return current
        })
    }
    
    let _title: [Text]
    let peers:[Avatar]
    let drawBorder: Bool
    let context: AccountContext
    let message: Message?
    let hasUnread: Bool
    let isLoading: Bool
    fileprivate var titleLayout:[(TextViewLayout, Text)] = []
    fileprivate let handler: ()->Void
    
    init(context: AccountContext, message: Message?, hasUnread: Bool, title: [Text], peers: [Peer], drawBorder: Bool, isLoading: Bool, handler: @escaping()->Void = {}) {
        self.context = context
        self.message = message
        self._title = title
        self.isLoading = isLoading
        var index: Int = 0
        self.peers = peers.map { peer in
            let avatar = Avatar(peer: peer, index: index)
            index += 1
            return avatar
        }
        self.drawBorder = drawBorder
        self.hasUnread = hasUnread
        self.handler = handler
    }
    
    func makeSize() {
        self.titleLayout = _title.map {
            return (TextViewLayout($0.text, maximumNumberOfLines: 1, truncationType: .end), $0)
        }
        var mw: CGFloat = 200
        for layout in self.titleLayout {
            layout.0.measure(width: mw)
            mw -= max(layout.0.layoutSize.width, 4) - 2
        }
    }
    
    func size(_ bubbled: Bool, _ isOverlay: Bool = false) -> NSSize {
        var width: CGFloat = 0
        var height: CGFloat = 0
        if isOverlay {
            let iconSize = theme.chat_comments_overlay.backingSize
            if titleSize.width > 0 {
                width += titleSize.width
                width += 10
                width = max(width, 31)
                height = max(iconSize.height + titleSize.height + 16, width)
            } else {
                width = 31
                height = 31
            }
        } else if bubbled, titleSize.width > 0 {
            width += titleSize.width
            width += (6 * 4) + 13
            if peers.isEmpty {
                width += theme.icons.channel_comments_bubble.backingSize.width + 2
            } else {
                if peers.count == 1 {
                    width += 24
                } else {
                    width += 22 + (22 * CGFloat(peers.count - 1))
                }
            }
            width += theme.icons.channel_comments_bubble_next.backingSize.width
            height = ChatRowItem.channelCommentsBubbleHeight
            
            if hasUnread {
                width += 10
            }
        } else if titleSize.width > 0 {
            width += titleSize.width
            width += 3
            width += theme.icons.channel_comments_list.backingSize.width
            height = ChatRowItem.channelCommentsHeight
        }
        return NSMakeSize(width, height)
    }
}

class ChannelCommentsBubbleControl: CommentsBasicControl {
    private var peers:[ChannelCommentsRenderData.Avatar] = []
    private var avatars:[AvatarContentView] = []
    private let avatarsContainer = View(frame: NSMakeRect(0, 0, 22 * 3, 22))
    private let arrowView = ImageView()
    private var dotView: View? = nil
    required init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        addSubview(avatarsContainer)
        addSubview(arrowView)
        arrowView.isEventLess = true
        avatarsContainer.isEventLess = true
        
        arrowView.image = theme.icons.channel_comments_bubble_next
        arrowView.sizeToFit()
        
    }

    
    override var firstTextPosition: NSPoint {
        guard let render = renderData, !render.titleLayout.isEmpty else {
            return .zero
        }
        var rect: CGRect = .zero
        
        if render.peers.isEmpty {
            var f = focus(theme.icons.channel_comments_bubble.backingSize)
            f.origin.x = 15 + 6
            rect = f
        } else {
            if render.peers.count == 1 {
                rect = focus(NSMakeSize(24 * CGFloat(render.peers.count), 22))
            } else {
                rect = focus(NSMakeSize(22 + (22 * CGFloat(render.peers.count - 1)), 22))
            }
            rect.origin.x = 13 + 6
        }
        
        var f = focus(render.titleSize)
        f.origin.x = rect.maxX + 6
        f.origin.y -= 1
        rect = f
        
        return rect.origin
    }
    
    override var progressIndicatorPosition: NSPoint {
        var rect = focus(progressIndicatorSize)
        rect.origin.x = size.width - 6 - arrowView.frame.width
        return rect.origin
    }
    
    override var progressIndicatorColor: NSColor {
        return theme.colors.accentIcon
    }
    
    override func draw(_ layer: CALayer, in ctx: CGContext) {
        super.draw(layer, in: ctx)
        

        if let render = renderData {
            if render.drawBorder {
                ctx.setFillColor(theme.colors.accentIconBubble_incoming.withAlphaComponent(0.15).cgColor)
                ctx.fill(NSMakeRect(0, 0, frame.width, .borderSize))
            }
            if render.peers.isEmpty {
                var f = focus(theme.icons.channel_comments_bubble.backingSize)
                f.origin.x = 13 + 6
                ctx.draw(theme.icons.channel_comments_bubble, in: f)
            }
        }
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override func update(data: ChannelCommentsRenderData, size: NSSize, animated: Bool) {
        let previousLastTextPosition = lastTextPosition
        
        super.update(data: data, size: size, animated: animated)
        
        let (removed, inserted, updated) = mergeListsStableWithUpdates(leftList: self.peers, rightList: data.peers)
        
        for removed in removed.reversed() {
            let control = avatars.remove(at: removed)
            let peer = self.peers[removed]
            let haveNext = data.peers.contains(where: { $0.stableId == peer.stableId })
            control.updateLayout(size: NSMakeSize(22, 22), isClipped: false, animated: animated)
            if animated && !haveNext {
                control.layer?.animateAlpha(from: 1, to: 0, duration: duration, timingFunction: timingFunction, removeOnCompletion: false, completion: { [weak control] _ in
                    control?.removeFromSuperview()
                })
                control.layer?.animateScaleSpring(from: 1.0, to: 0.2, duration: duration)
            } else {
                control.removeFromSuperview()
            }
        }
        for inserted in inserted {
            let control = AvatarContentView(context: data.context, peer: inserted.1.peer, message: data.message, synchronousLoad: false)
            control.updateLayout(size: NSMakeSize(22, 22), isClipped: inserted.0 != 0, animated: animated)
            control.userInteractionEnabled = false
            control.setFrameSize(NSMakeSize(22, 22))
            control.setFrameOrigin(NSMakePoint(CGFloat(inserted.0) * 19, 0))
            avatars.insert(control, at: inserted.0)
            avatarsContainer.subviews.insert(control, at: inserted.0)
            if animated {
                if let index = inserted.2 {
                    control.layer?.animatePosition(from: NSMakePoint(CGFloat(index) * 19, 0), to: control.frame.origin, timingFunction: timingFunction)
                } else {
                    control.layer?.animateAlpha(from: 0, to: 1, duration: duration, timingFunction: timingFunction)
                    control.layer?.animateScaleSpring(from: 0.2, to: 1.0, duration: duration)
                }
            }
        }
        for updated in updated {
            let control = avatars[updated.0]
            control.updateLayout(size: NSMakeSize(22, 22), isClipped: updated.0 != 0, animated: animated)
            let updatedPoint = NSMakePoint(CGFloat(updated.0) * 19, 0)
            if animated {
                control.layer?.animatePosition(from: control.frame.origin - updatedPoint, to: .zero, duration: duration, timingFunction: timingFunction, additive: true)
            }
            control.setFrameOrigin(updatedPoint)
        }
        var index: CGFloat = 10
        for control in avatarsContainer.subviews.compactMap({ $0 as? AvatarContentView }) {
            control.layer?.zPosition = index
            index -= 1
        }
        
        self.peers = data.peers

        enum NumericAnimation {
            case forward
            case backward
        }
        
        arrowView.isHidden = data.isLoading
        
        if animated {
            var f = focus(arrowView.frame.size)
            f.origin.x = size.width - 6 - f.width
            arrowView.layer?.animatePosition(from: arrowView.frame.origin - f.origin, to: .zero, timingFunction: timingFunction, additive: true)
        }
        
        
        if data.hasUnread {
            let size = NSMakeSize(6, 6)
            var f = focus(size)
            f.origin.x = lastTextPosition.x + 6
            f.origin.y += 1
            if self.dotView == nil {
                let effectivePos = previousLastTextPosition != .zero ? previousLastTextPosition : f.origin
                self.dotView = View(frame: CGRect(origin: effectivePos, size: f.size))
                self.dotView?.layer?.cornerRadius = size.height / 2
                addSubview(self.dotView!)
                if animated {
                    self.dotView?.layer?.animateAlpha(from: 0, to: 1, duration: duration, timingFunction: timingFunction)
                    self.dotView?.layer?.animateScaleSpring(from: 0.2, to: 1.0, duration: duration, bounce: true)
                }
            }
            guard let dotView = self.dotView else {
                return
            }
            if animated {
                dotView.layer?.animatePosition(from: dotView.frame.origin - f.origin, to: .zero, timingFunction: timingFunction, additive: true)
            }
            dotView.backgroundColor = theme.colors.accentIcon
        } else {
            if let dotView = dotView {
                self.dotView = nil
                if animated {
                    dotView.layer?.animateAlpha(from: 1, to: 0, duration: duration, timingFunction: timingFunction, removeOnCompletion: false, completion: { [weak dotView] _ in
                        dotView?.removeFromSuperview()
                    })
                    dotView.layer?.animateScaleSpring(from: 1, to: 0.2, duration: duration)
                } else {
                    dotView.removeFromSuperview()
                }
            }
        }
        
        needsDisplay = true
        needsLayout = true
    }
    
    override func layout() {
        super.layout()
        self.avatarsContainer.centerY(x: 13 + 6)
        self.arrowView.centerY(x: frame.width - 6 - arrowView.frame.width)
        self.dotView?.centerY(x: lastTextPosition.x + 6, addition: 1)
    }
    
}




class ChannelCommentsControl: CommentsBasicControl {
    required init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
    }
    
    override var firstTextPosition: NSPoint {
        guard let render = renderData else {
            return .zero
        }
        var f = focus(render.titleSize)
        f.origin.x = 0
        return f.origin
    }
    
    
    override func draw(_ layer: CALayer, in ctx: CGContext) {
        super.draw(layer, in: ctx)
        
        if let render = renderData {
                        
            var rect: CGRect = .zero
            
            var f = focus(render.titleSize)
            f.origin.x = 0
            rect = f
            
            f = focus(theme.icons.channel_comments_list.backingSize)
            f.origin.x = rect.maxX + 3
            rect = f
            if !render.isLoading {
                ctx.draw(theme.icons.channel_comments_list, in: rect)
            }
        }
        
    }
    
    override var progressIndicatorPosition: NSPoint {
        if let render = renderData {
            var rect: CGRect = .zero
            
            var f = focus(render.titleSize)
            f.origin.x = 0
            rect = f
            
            f = focus(progressIndicatorSize)
            f.origin.x = rect.maxX + 3
            rect = f
            return rect.origin
        }
        return .zero
    }
    
    override var progressIndicatorColor: NSColor {
        return theme.colors.accent
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override func update(data: ChannelCommentsRenderData, size: NSSize, animated: Bool) {
        super.update(data: data, size: size, animated: animated)
        
       
        needsDisplay = true
        needsLayout = true
    }
    
    override func layout() {
        super.layout()
    }
    
}


final class ChannelCommentsSmallControl : CommentsBasicControl {

    private let imageView = ImageView()
    required init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        imageView.isEventLess = true
        addSubview(imageView)
    }

    override var firstTextPosition: NSPoint {
        guard let render = renderData, !render.titleLayout.isEmpty else {
            return .zero
        }
        let size = theme.chat_comments_overlay.backingSize
        var iconFrame = focus(size)
        iconFrame.origin.y = 5
        
        var titleFrame = focus(render.titleSize)
        titleFrame.origin.y = iconFrame.maxY + 2
        return titleFrame.origin
    }
    
    var imagePosition: NSPoint {
        if let renderData = renderData {
            let size = theme.chat_comments_overlay.backingSize
            if !renderData.titleLayout.isEmpty {
                var iconFrame = focus(size)
                iconFrame.origin.y = 5
                return iconFrame.origin
            } else {
                return focus(size).origin
            }
        }
        return .zero
    }
    
    override var progressIndicatorPosition: NSPoint {
        return imagePosition
    }
    
    override var progressIndicatorSize: NSSize {
        return theme.chat_comments_overlay.backingSize
    }
    
    override var progressIndicatorColor: NSColor {
        if theme.bubbled && theme.backgroundMode.hasWallpaper {
            return theme.chatServiceItemTextColor
        } else {
            return theme.colors.accent
        }
    }
    
    override func update(data: ChannelCommentsRenderData, size: NSSize, animated: Bool) {
        
        super.update(data: data, size: size, animated: animated)
        
        imageView.isHidden = data.isLoading
        
        
        if theme.bubbled && theme.backgroundMode.hasWallpaper {
            imageView.image = theme.chat_comments_overlay
        } else {
            imageView.image = theme.icons.channel_comments_overlay
        }
        _ = imageView.sizeToFit()
        
        layer?.cornerRadius = min(size.height, size.width) / 2
        
        let rect = CGRect(origin: .zero, size: size)
        let iconSize = theme.chat_comments_overlay.backingSize
        let iconPosition: NSPoint
        if !data.titleLayout.isEmpty {
            var iconFrame = rect.focus(iconSize)
            iconFrame.origin.y = 5
            iconPosition = iconFrame.origin
        } else {
            iconPosition = rect.focus(iconSize).origin
        }
        
        imageView.change(pos: iconPosition, animated: animated)
        change(size: size, animated: animated)
        needsDisplay = true
    }
    
    override func layout() {
        super.layout()
        imageView.setFrameOrigin(imagePosition)
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}
