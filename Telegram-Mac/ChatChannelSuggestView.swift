//
//  ChatChannelSuggestView.swift
//  Telegram
//
//  Created by Mike Renoir on 10.11.2023.
//  Copyright © 2023 Telegram. All rights reserved.
//

import Foundation
import TGUIKit
import TelegramCore
import Postbox
import SwiftSignalKit
import Accelerate

private let avatarSize = NSMakeSize(60, 60)

final class ChannelSuggestData {
    
    struct Channel {
        let peer: Peer
        let name: TextViewLayout
        let subscribers: TextViewLayout
        let locked: Bool
        var size: NSSize {
            return NSMakeSize(avatarSize.width + 20, avatarSize.height + name.layoutSize.height + 4 + 10)
        }
    }
    
    private(set) var channels:[Channel] = []
    private(set) var size: NSSize = .zero
    
    init(channels: RecommendedChannels, context: AccountContext, presentation: TelegramPresentationTheme) {
        var list: [Channel] = []
        for channel in channels.channels {
            let attr = NSMutableAttributedString()
            let isPremium: Bool = context.isPremium
            let nameText: String
            let color: NSColor
            let subscribersText: String
            let limit = context.appConfiguration.getGeneralValue("recommended_channels_limit_premium", orElse: 0)
            if !isPremium, channel == channels.channels.last {
                nameText = strings().peerMediaSimilarChannelsMoreChannels
                color = presentation.colors.grayText
                subscribersText = "+\(Int(limit) - channels.channels.count)"
            } else {
                nameText = channel.peer._asPeer().displayTitle
                color = presentation.colors.text
                subscribersText = Int(channel.subscribers).prettyNumber
            }
            
            attr.append(string: nameText, color: color, font: .normal(.short))
            let name = TextViewLayout(attr, maximumNumberOfLines: 2, alignment: .center)
            name.measure(width: avatarSize.width + 20)
            
            let subscribers: TextViewLayout = .init(.initialize(string: subscribersText, color: .white, font: .medium(10)), maximumNumberOfLines: 1, alignment: .center)
            subscribers.measure(width: avatarSize.width + 20)
            
            
            let value = Channel(peer: channel.peer._asPeer(), name: name, subscribers: subscribers, locked: !isPremium && channel == channels.channels.last)
            list.append(value)
        }
        self.channels = list
    }
    
    func makeSize(width: CGFloat) {
        let effective_w: CGFloat = channels.reduce(0, {
            $0 + $1.size.width
        })
        let effective_h: CGFloat = channels.map { $0.size.height }.max()!
        self.size = NSMakeSize(min(effective_w, width), effective_h + 40)
    }
}



private final class ChannelView : Control {
    
    
    private final class SubscribersView : ImageView {
        private let textView = TextView()
        private let disposable = MetaDisposable()
        private let imageView = ImageView()
        required override init(frame frameRect: NSRect) {
            super.init(frame: frameRect)
            addSubview(textView)
            addSubview(imageView)
            textView.userInteractionEnabled = false
            textView.isSelectable = false
        }
        
        required init?(coder: NSCoder) {
            fatalError("init(coder:) has not been implemented")
        }
        
        deinit {
            disposable.dispose()
        }
        
        func set(subscribers: TextViewLayout, locked: Bool, presentation: TelegramPresentationTheme) {
            imageView.image = locked ? NSImage(named: "Icon_EmojiLock")?.precomposed(.white) : NSImage(named: "Icon_Reply_User")?.precomposed(.white)
            imageView.contentGravity = .resizeAspectFill
            imageView.setFrameSize(NSMakeSize(12, 12))
            textView.update(subscribers)
           // backgroundColor = .random
            setFrameSize(NSMakeSize(max(26, subscribers.layoutSize.width + 25), subscribers.layoutSize.height + 8))
            self.layer?.cornerRadius = frame.height / 2
            layer?.borderColor = presentation.colors.background.cgColor
            layer?.borderWidth = 2
        }
        
        override func layout() {
            super.layout()
            imageView.centerY(x: 4)
            textView.centerY(x: imageView.frame.maxX + 2)
        }
        
        private var img: CGImage?
        
        func applyBlur(color: NSColor?, image: CGImage) {
            
            guard img != image else {
                return
            }
            
            self.img = image
            
            let signal: Signal<CGImage?, NoError> = Signal { subscriber in
                let blurredWidth = 12
                let blurredHeight = 12
                let context = DrawingContext(size: CGSize(width: CGFloat(blurredWidth), height: CGFloat(blurredHeight)), scale: 1.0)
                let size = CGSize(width: CGFloat(blurredWidth), height: CGFloat(blurredHeight))


                context.withContext { c in
                    c.setFillColor((color ?? NSColor(rgb: 0xffffff)).cgColor)
                    c.fill(CGRect(origin: CGPoint(), size: size))
                    
                    let rect = CGRect(origin: CGPoint(x: -size.width / 2.0, y: -size.height / 2.0), size: CGSize(width: size.width * 1.8, height: size.height * 1.8))
                    c.draw(image, in: rect)
                }
                            
                var destinationBuffer = vImage_Buffer()
                destinationBuffer.width = UInt(blurredWidth)
                destinationBuffer.height = UInt(blurredHeight)
                destinationBuffer.data = context.bytes
                destinationBuffer.rowBytes = context.bytesPerRow
                
                vImageBoxConvolve_ARGB8888(&destinationBuffer,
                                           &destinationBuffer,
                                           nil,
                                           0, 0,
                                           UInt32(15),
                                           UInt32(15),
                                           nil,
                                           vImage_Flags(kvImageTruncateKernel))
                
                let divisor: Int32 = 0x1000

                let rwgt: CGFloat = 0.3086
                let gwgt: CGFloat = 0.6094
                let bwgt: CGFloat = 0.0820

                let adjustSaturation: CGFloat = 1.7

                let a = (1.0 - adjustSaturation) * rwgt + adjustSaturation
                let b = (1.0 - adjustSaturation) * rwgt
                let c = (1.0 - adjustSaturation) * rwgt
                let d = (1.0 - adjustSaturation) * gwgt
                let e = (1.0 - adjustSaturation) * gwgt + adjustSaturation
                let f = (1.0 - adjustSaturation) * gwgt
                let g = (1.0 - adjustSaturation) * bwgt
                let h = (1.0 - adjustSaturation) * bwgt
                let i = (1.0 - adjustSaturation) * bwgt + adjustSaturation

                let satMatrix: [CGFloat] = [
                    a, b, c, 0,
                    d, e, f, 0,
                    g, h, i, 0,
                    0, 0, 0, 1
                ]

                var matrix: [Int16] = satMatrix.map { value in
                    return Int16(value * CGFloat(divisor))
                }

                vImageMatrixMultiply_ARGB8888(&destinationBuffer, &destinationBuffer, &matrix, divisor, nil, nil, vImage_Flags(kvImageDoNotTile))
                
                context.withFlippedContext { c in
                    c.setFillColor((color ?? NSColor(0xffffff)).withMultipliedAlpha(0.6).cgColor)
                    c.fill(CGRect(origin: CGPoint(), size: size))
                }
                
                subscriber.putNext(context.generateImage())
                return ActionDisposable {
                    
                }
            }
            |> runOn(.concurrentBackgroundQueue())
            |> deliverOnMainQueue
            
            disposable.set(signal.start(next: { [weak self] image in
                self?.layer?.contents = image
            }))

        }
    }
    
    private let avatar = AvatarControl(font: .avatar(17))
    private let textView = TextView()
    private let subscribers = SubscribersView(frame: .zero)
    required init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        avatar.setFrameSize(avatarSize)
        addSubview(avatar)
        addSubview(textView)
        addSubview(subscribers)
        
        avatar.userInteractionEnabled = false
        textView.userInteractionEnabled = false
        textView.isSelectable = false
        
        scaleOnClick = true
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    func set(channel: ChannelSuggestData.Channel, presentation: TelegramPresentationTheme, context: AccountContext, animated: Bool) {
        
        avatar.contentUpdated = { [weak self] value in
            if let value = value {
                let image = value as! CGImage
                self?.subscribers.applyBlur(color: presentation.colors.background.darker(), image: image)
            }
        }
        self.subscribers.set(subscribers: channel.subscribers, locked: channel.locked, presentation: presentation)
        avatar.setPeer(account: context.account, peer: channel.peer)
        textView.update(channel.name)
        
//        avatar.callContentUpdater()
        
    }
    
    
    
    override func layout() {
        super.layout()
        avatar.centerX(y: 0)
        textView.centerX(y: avatar.frame.maxY + 4)
        subscribers.centerX(y: avatar.frame.maxY - subscribers.frame.height + 5)
    }
}

final class ChatChannelSuggestView : Control {
    private let titleView = TextView()
    private let dismiss = ImageButton()
    private let container = View(frame: .zero)
    private let scrollView = HorizontalScrollView(frame: .zero)
    private let bgLayer = SimpleShapeLayer()
    required init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        addSubview(titleView)
        addSubview(dismiss)
        addSubview(scrollView)
        dismiss.autohighlight = false
        dismiss.scaleOnClick = true
        
        titleView.userInteractionEnabled = false
        titleView.isSelectable = false
        
        scrollView.documentView = container
        
//        self.layer = bgLayer
//        
//        bgLayer.backgroundColor = NSColor.red.cgColor
//        
//        bgLayer.frame = frameRect.size.bounds
        
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    func set(item: ChatServiceItem, data: ChannelSuggestData, animated: Bool) {
        
        let layout = TextViewLayout(.initialize(string: strings().peerMediaSimilarChannels, color: item.presentation.colors.text, font: .medium(.text)))
        layout.measure(width: .greatestFiniteMagnitude)
        
        titleView.update(layout)
        
        dismiss.set(image: item.presentation.icons.wallpaper_color_close, for: .Normal)
        dismiss.sizeToFit()
        backgroundColor = item.presentation.colors.background
        layer?.cornerRadius = 10
        
        while container.subviews.count > data.channels.count {
            container.subviews.last?.removeFromSuperview()
        }
        
        while container.subviews.count < data.channels.count {
            let view = ChannelView(frame: .zero)
            container.addSubview(view)
        }
                
        
        var x: CGFloat = 10
        for (i, channel) in data.channels.enumerated() {
            let view = container.subviews[i] as! ChannelView
            view.frame = CGRect(origin: NSMakePoint(x, 0), size: channel.size)
            x += view.frame.width
            view.set(channel: channel, presentation: item.presentation, context: item.context, animated: animated)
            
            view.set(handler: { [weak item] _ in
                if !channel.locked {
                    item?.openChannel(channel.peer.id)
                } else {
                    item?.openPremiumBoarding()
                }
            }, for: .Click)
        }
        container.setFrameSize(NSMakeSize(container.subviewsWidthSize.width + 20, container.subviewsWidthSize.height))
        
        dismiss.removeAllHandlers()
        dismiss.set(handler: { [weak item] _ in
            item?.dismissRecommendedChannels()
        }, for: .Click)
        
        container.backgroundColor = item.presentation.colors.background
        backgroundColor = item.presentation.colors.background
    }
    
    override func layout() {
        super.layout()
        self.updateLayout(size: self.frame.size, transition: .immediate)
    }
    
    func updateLayout(size: NSSize, transition: ContainedViewLayoutTransition) {
        let titleFrame = NSRect(x: 10, y: 10, width: titleView.frame.width, height: titleView.frame.height)
        transition.updateFrame(view: titleView, frame: titleFrame)

        let dismissFrame = NSRect(
            x: size.width - dismiss.frame.width - 8,
            y: 5,
            width: dismiss.frame.width,
            height: dismiss.frame.height
        )
        transition.updateFrame(view: dismiss, frame: dismissFrame)

        // ScrollView just below, spanning full width and container's height
        let scrollFrame = NSRect(x: 0, y: 40, width: size.width, height: container.frame.height)
        transition.updateFrame(view: scrollView, frame: scrollFrame)
    }

}
