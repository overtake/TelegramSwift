//
//  BoostChannelModalController.swift
//  Telegram
//
//  Created by Mike Renoir on 03.09.2023.
//  Copyright © 2023 Telegram. All rights reserved.
//

import Foundation

import Cocoa
import TGUIKit
import SwiftSignalKit
import TelegramCore
import Postbox
import TelegramMedia

func requiredBoostSubjectLevel(subject: BoostSubject, context: AccountContext, configuration: PremiumConfiguration) -> Int32 {
    switch subject {
    case .stories:
        return 1
    case let .channelReactions(reactionCount):
        return reactionCount
    case let .nameColors(colors):
        if let value = context.peerNameColors.nameColorsChannelMinRequiredBoostLevel[colors.rawValue] {
            return value
        } else {
            return 1
        }
    case .nameIcon:
        return configuration.minChannelNameIconLevel
    case .profileColors:
        return configuration.minChannelProfileColorLevel
    case .profileIcon:
        return configuration.minChannelProfileIconLevel
    case .emojiStatus:
        return configuration.minChannelEmojiStatusLevel
    case .wallpaper:
        return configuration.minChannelWallpaperLevel
    case .customWallpaper:
        return configuration.minChannelCustomWallpaperLevel
    }
}



enum BoostSubject: Equatable {
    case stories
    case channelReactions(reactionCount: Int32)
    case nameColors(colors: PeerNameColor)
    case nameIcon
    case profileColors
    case profileIcon
    case emojiStatus
    case wallpaper
    case customWallpaper
    
    func requiredLevel(context: AccountContext, configuration: PremiumConfiguration) -> Int32 {
        return requiredBoostSubjectLevel(subject: self, context: context, configuration: configuration)
    }
}



private func generateBadgePath(rectSize: CGSize, tailPosition: CGFloat = 0.5) -> CGPath {
    let cornerRadius: CGFloat = rectSize.height / 2.0
    let tailWidth: CGFloat = 20.0
    let tailHeight: CGFloat = 9.0
    let tailRadius: CGFloat = 4.0

    let rect = CGRect(origin: CGPoint(x: 0.0, y: tailHeight), size: rectSize)

    let path = CGMutablePath()

    path.move(to: CGPoint(x: rect.minX, y: rect.minY + cornerRadius))

    var leftArcEndAngle: CGFloat = .pi / 2.0
    var leftConnectionArcRadius = tailRadius
    var tailLeftHalfWidth: CGFloat = tailWidth / 2.0
    var tailLeftArcStartAngle: CGFloat = -.pi / 4.0
    var tailLeftHalfRadius = tailRadius
    
    var rightArcStartAngle: CGFloat = -.pi / 2.0
    var rightConnectionArcRadius = tailRadius
    var tailRightHalfWidth: CGFloat = tailWidth / 2.0
    var tailRightArcStartAngle: CGFloat = .pi / 4.0
    var tailRightHalfRadius = tailRadius
    
    if tailPosition < 0.5 {
        let fraction = max(0.0, tailPosition - 0.15) / 0.35
        leftArcEndAngle *= fraction
        
        let connectionFraction = max(0.0, tailPosition - 0.35) / 0.15
        leftConnectionArcRadius *= connectionFraction
        
        if tailPosition < 0.27 {
            let fraction = tailPosition / 0.27
            tailLeftHalfWidth *= fraction
            tailLeftArcStartAngle *= fraction
            tailLeftHalfRadius *= fraction
        }
    } else if tailPosition > 0.5 {
        let tailPosition = 1.0 - tailPosition
        let fraction = max(0.0, tailPosition - 0.15) / 0.35
        rightArcStartAngle *= fraction
        
        let connectionFraction = max(0.0, tailPosition - 0.35) / 0.15
        rightConnectionArcRadius *= connectionFraction
        
        if tailPosition < 0.27 {
            let fraction = tailPosition / 0.27
            tailRightHalfWidth *= fraction
            tailRightArcStartAngle *= fraction
            tailRightHalfRadius *= fraction
        }
    }
        
    path.addArc(
        center: CGPoint(x: rect.minX + cornerRadius, y: rect.minY + cornerRadius),
        radius: cornerRadius,
        startAngle: .pi,
        endAngle: .pi + leftArcEndAngle,
        clockwise: true
    )

    let leftArrowStart = max(rect.minX, rect.minX + rectSize.width * tailPosition - tailLeftHalfWidth - leftConnectionArcRadius)
    path.addArc(
        center: CGPoint(x: leftArrowStart, y: rect.minY - leftConnectionArcRadius),
        radius: leftConnectionArcRadius,
        startAngle: .pi / 2.0,
        endAngle: .pi / 4.0,
        clockwise: false
    )

    path.addLine(to: CGPoint(x: max(rect.minX, rect.minX + rectSize.width * tailPosition - tailLeftHalfRadius), y: rect.minY - tailHeight))

    path.addArc(
        center: CGPoint(x: rect.minX + rectSize.width * tailPosition, y: rect.minY - tailHeight + tailRadius / 2.0),
        radius: tailRadius,
        startAngle: -.pi / 2.0 + tailLeftArcStartAngle,
        endAngle: -.pi / 2.0 + tailRightArcStartAngle,
        clockwise: true
    )
    
    path.addLine(to: CGPoint(x: min(rect.maxX, rect.minX + rectSize.width * tailPosition + tailRightHalfRadius), y: rect.minY - tailHeight))

    let rightArrowStart = min(rect.maxX, rect.minX + rectSize.width * tailPosition + tailRightHalfWidth + rightConnectionArcRadius)
    path.addArc(
        center: CGPoint(x: rightArrowStart, y: rect.minY - rightConnectionArcRadius),
        radius: rightConnectionArcRadius,
        startAngle: .pi - .pi / 4.0,
        endAngle: .pi / 2.0,
        clockwise: false
    )

    path.addArc(
        center: CGPoint(x: rect.minX + rectSize.width - cornerRadius, y: rect.minY + cornerRadius),
        radius: cornerRadius,
        startAngle: rightArcStartAngle,
        endAngle: 0.0,
        clockwise: true
    )

    path.addLine(to: CGPoint(x: rect.minX + rectSize.width, y: rect.minY + rectSize.height - cornerRadius))

    path.addArc(
        center: CGPoint(x: rect.minX + rectSize.width - cornerRadius, y: rect.minY + rectSize.height - cornerRadius),
        radius: cornerRadius,
        startAngle: 0.0,
        endAngle: .pi / 2.0,
        clockwise: true
    )

    path.addLine(to: CGPoint(x: rect.minX + cornerRadius, y: rect.minY + rectSize.height))

    path.addArc(
        center: CGPoint(x: rect.minX + cornerRadius, y: rect.minY + rectSize.height - cornerRadius),
        radius: cornerRadius,
        startAngle: .pi / 2.0,
        endAngle: .pi,
        clockwise: true
    )
    
    return path
}


private final class Arguments {
    let context: AccountContext
    let presentation: TelegramPresentationTheme
    let boost:()->Void
    let openChannel:()->Void
    let shareLink:(String)->Void
    let copyLink:(String)->Void
    let openGiveaway:()->Void
    init(context: AccountContext, presentation: TelegramPresentationTheme, boost:@escaping()->Void, openChannel:@escaping()->Void, shareLink: @escaping(String)->Void, copyLink: @escaping(String)->Void, openGiveaway:@escaping()->Void) {
        self.context = context
        self.presentation = presentation
        self.boost = boost
        self.copyLink = copyLink
        self.shareLink = shareLink
        self.openChannel = openChannel
        self.openGiveaway = openGiveaway
    }
}

extension ChannelBoostStatus {
    func increment() -> ChannelBoostStatus {
        return .init(level: self.level, boosts: self.boosts + 1, giftBoosts: self.giftBoosts, currentLevelBoosts: self.currentLevelBoosts, nextLevelBoosts: self.nextLevelBoosts, premiumAudience: self.premiumAudience, url: self.url, prepaidGiveaways: self.prepaidGiveaways, boostedByMe: self.boostedByMe)
    }
}


private struct State : Equatable {
    var peer: PeerEquatable
    var status: ChannelBoostStatus
    var myStatus: MyBoostStatus?
    var canApplyStatus: Bool {
        return true
    }
    
    var samePeer: Bool
    var infoOnly: Bool
    var source: BoostChannelSource
    var percentToNext: CGFloat {
        if let nextLevelBoosts = status.nextLevelBoosts {
            return CGFloat(status.boosts - status.currentLevelBoosts) / CGFloat(nextLevelBoosts - status.currentLevelBoosts)
        } else {
            return 1.0
        }
    }
    var isAdmin: Bool {
        return infoOnly && peer.peer.groupAccess.isCreator //&& self.boosted
    }
    var boosted: Bool {
        return status.boostedByMe
    }
    var link: String {
        if let address = peer.peer.addressName {
            return "https://t.me/\(address)?boost"
        } else {
            return "https://t.me/c/\(peer.peer.id.id._internalGetInt64Value())?boost"

        }
    }
    
    var currentLevelBoosts: Int {
        return status.boosts - status.currentLevelBoosts
    }
    
    var title: String {
        var title: String = ""
        var remaining: Int?
        if let nextLevelBoosts = self.status.nextLevelBoosts {
            remaining = nextLevelBoosts - self.status.boosts
        }
        
        let level = self.status.level
        
        if isAdmin {
            if let _ = remaining {
                switch source {
                case .nameColor:
                    title = strings().channelBoostEnableColors
                case .nameIcon:
                    title = strings().channelBoostNameIcon
                case .profileColor:
                    title = strings().channelBoostProfileColor
                case .profileIcon:
                    title = strings().channelBoostProfileIcon
                case .emojiStatus:
                    title = strings().channelBoostEmojiStatus
                case .reactions:
                    title = strings().channelBoostEnableReactions
                case .wallpaper:
                    title = strings().channelBoostEnableWallpapers
                default:
                    if level == 0 {
                        title = strings().channelBoostEnableStories
                    } else {
                        title = strings().channelBoostIncreaseLimit
                    }
                }
            } else {
                title = strings().channelBoostMaxLevelReached
            }
        } else {
            if let _ = remaining {
                if level == 0 {
                    title = samePeer ? strings().channelBoostEnableStoriesForChannel : strings().channelBoostEnableStoriesForOtherChannel
                } else {
                    title = strings().channelBoostHelpUpgradeChannel
                }
            } else {
                title = strings().channelBoostMaxLevelReached
            }
        }
       
        if self.boosted {
            if let _ = remaining {
                title = samePeer ? strings().channelBoostYouBoostedChannel(peer.peer.compactDisplayTitle) : strings().channelBoostYouBoostedOtherChannel
            } else {
                title = strings().channelBoostMaxLevelReached
            }
        }
                       

        return title
    }
}



private final class BoostRowItem : TableRowItem {
    fileprivate let context: AccountContext
    fileprivate let state: State
    fileprivate let text: TextViewLayout
    fileprivate let presentation: TelegramPresentationTheme
    fileprivate let boost:()->Void
    fileprivate let openChannel:()->Void
    init(_ initialSize: NSSize, presentation: TelegramPresentationTheme, state: State, context: AccountContext, boost:@escaping()->Void, openChannel:@escaping()->Void) {
        self.context = context
        self.state = state
        self.boost = boost
        self.presentation = presentation
        self.openChannel = openChannel
        
        var remaining: Int?
        if let nextLevelBoosts = state.status.nextLevelBoosts {
            remaining = nextLevelBoosts - state.status.boosts
        }

        let level = state.status.level
        var string: String
        
        if state.status.nextLevelBoosts != nil {
            if state.isAdmin {
                if let remaining = remaining {
                    let valueString: String = strings().channelBoostMoreBoostsCountable(remaining)
                    switch state.source {
                    case let .nameColor(level):
                        string = strings().channelBoostEnableColorsText("\(level)")
                    case let .nameIcon(level):
                        string = strings().channelBoostEnableNameIconLevelText("\(level)")
                    case let .profileIcon(level):
                        string = strings().channelBoostEnableProfileIconLevelText("\(level)")
                    case let .profileColor(level):
                        string = strings().channelBoostEnableProfileColorLevelText("\(level)")
                    case let .emojiStatus(level):
                        string = strings().channelBoostEnableEmojiStatusLevelText("\(level)")
                    case let .wallpaper(level):
                        string = strings().channelBoostEnableWallpapersText("\(level)")
                    case .reactions:
                        string = strings().channelBoostEnableReactionsText("\(level + 1)", "\(level)")
                    default:
                        if level == 0 {
                            string = strings().channelBoostEnableStoriesText(valueString)
                        } else {
                            string = strings().channelBoostIncreaseLimitText(valueString, "\(level + 1)")
                        }
                    }
                } else {
                    string = ""
                }
            } else {
                let storiesString = strings().channelBoostStoriesPerDayCountable(level + 1)
                if let remaining = remaining {
                    let valueString: String = strings().channelBoostMoreBoostsCountable(remaining)
                    if remaining == 0 {
                        string = strings().channelBoostBoostedChannelReachedLevel("\(level + 1)", storiesString)
                    } else {
                        string = strings().channelBoostBoostedChannelMoreRequired(valueString, storiesString)
                    }

                } else {
                    string = ""
                }
            }
            
            if state.boosted {
                let storiesString = strings().channelBoostStoriesPerDayCountable(level + 1)
                if let remaining = remaining {
                    let valueString: String = strings().channelBoostMoreBoostsCountable(remaining)
                    if level == 0 {
                        if remaining == 0 {
                            string = strings().channelBoostEnabledStoriesForChannelText
                        } else {
                            string = strings().channelBoostEnableStoriesMoreRequired(valueString)
                        }
                    } else {
                        if remaining == 0 {
                            string = strings().channelBoostBoostedChannelReachedLevel("\(level + 1)", storiesString)
                        } else {
                            string = strings().channelBoostBoostedChannelMoreRequired(valueString, storiesString)
                        }
                    }
                } else {
                    string = strings().channelBoostBoostedChannelReachedLevel("\(level + 1)", storiesString)
                }
            }
        } else {
            let storiesString = strings().channelBoostStoriesPerDayCountable(level)
            string = strings().channelBoostMaxLevelReachedText("\(level)", storiesString)
        }
       

        
        let textString = NSMutableAttributedString()
        textString.append(string: string, color: presentation.colors.text, font: .normal(.text))
        textString.detectBoldColorInString(with: .medium(.text))
        
        self.text = .init(textString, alignment: .center)

        super.init(initialSize)
        _ = makeSize(initialSize.width)
    }
    
    override var stableId: AnyHashable {
        return 0
    }
    
    override func makeSize(_ width: CGFloat, oldWidth: CGFloat = 0) -> Bool {
        _ = super.makeSize(width, oldWidth: oldWidth)
        
        text.measure(width: width - 40)

        return true
    }
    
    override var height: CGFloat {
        var height: CGFloat = 0
                        
        height += 100
        
        if !state.samePeer {
            height += 60
        } else {
            height += 10
        }
        
        height += text.layoutSize.height
        
        return height
    }
    
    override func viewClass() -> AnyClass {
        return BoostRowItemView.self
    }
}

private final class BoostRowItemView : TableRowView {
   

    private class ChannelView : Control {
        private let avatar = AvatarControl(font: .avatar(12))
        private let textView = TextView()
        required init(frame frameRect: NSRect) {
            super.init(frame: frameRect)
            addSubview(avatar)
            addSubview(textView)
            textView.userInteractionEnabled = false
            textView.isSelectable = false
            avatar.setFrameSize(NSMakeSize(30, 30))
            scaleOnClick = true
        }
        
        required init?(coder: NSCoder) {
            fatalError("init(coder:) has not been implemented")
        }
        
        func update(_ peer: Peer, context: AccountContext, presentation: TelegramPresentationTheme, maxWidth: CGFloat) {
            self.avatar.setPeer(account: context.account, peer: peer)
            
            let layout = TextViewLayout(.initialize(string: peer.displayTitle, color: presentation.colors.text, font: .medium(.text)))
            layout.measure(width: maxWidth - 40)
            textView.update(layout)
            self.backgroundColor = presentation.colors.background
            
            self.setFrameSize(NSMakeSize(layout.layoutSize.width + 10 + avatar.frame.width + 10, 30))
            
            self.layer?.cornerRadius = frame.height / 2
        }
        
        override func layout() {
            super.layout()
            textView.centerY(x: avatar.frame.maxX + 10)
        }
    }
    
    private class LineView: View {
        
        private let currentLevel = TextView()
        private let nextLevel = TextView()

        private let nextLevel_background = View()
        private let currentLevel_background = PremiumGradientView(frame: .zero)
        
        private var state: State?
        
        required init(frame frameRect: NSRect) {
            super.init(frame: frameRect)
            addSubview(nextLevel_background)
            addSubview(currentLevel_background)
            addSubview(nextLevel)
            addSubview(currentLevel)
            nextLevel.userInteractionEnabled = false
            currentLevel.userInteractionEnabled = false
            
            nextLevel.isSelectable = false
            currentLevel.isSelectable = false
        }
        
        func update(_ state: State, context: AccountContext, presentation: TelegramPresentationTheme, transition: ContainedViewLayoutTransition) {
            
            self.state = state
            
            let width = frame.width * state.percentToNext

            
            var normalCountLayout = TextViewLayout(.initialize(string: strings().channelBoostLevel("\(state.status.level)"), color: presentation.colors.text, font: .medium(13)))
            normalCountLayout.measure(width: .greatestFiniteMagnitude)
            
            if width >= 10 + normalCountLayout.layoutSize.width {
                normalCountLayout = TextViewLayout(.initialize(string: normalCountLayout.attributedString.string, color: .white, font: .medium(13)))
                normalCountLayout.measure(width: .greatestFiniteMagnitude)
            }

            currentLevel.update(normalCountLayout)

            
            
            var premiumCountLayout = TextViewLayout(.initialize(string: strings().channelBoostLevel("\(state.status.level + 1)"), color: presentation.colors.text, font: .medium(13)))
            premiumCountLayout.measure(width: .greatestFiniteMagnitude)
            
            if width >= frame.width - 10 {
                premiumCountLayout = TextViewLayout(.initialize(string: premiumCountLayout.attributedString.string, color: .white, font: .medium(13)))
                premiumCountLayout.measure(width: .greatestFiniteMagnitude)
            }

            nextLevel.update(premiumCountLayout)
            nextLevel.isHidden = state.status.nextLevelBoosts == nil
            
            nextLevel_background.backgroundColor = presentation.colors.background
            
            self.updateLayout(size: self.frame.size, transition: transition)
        }
        
        func updateLayout(size: NSSize, transition: ContainedViewLayoutTransition) {
            guard let state = self.state else {
                return
            }
            
            let width = frame.width * state.percentToNext

            transition.updateFrame(view: currentLevel, frame: currentLevel.centerFrameY(x: 10))
            transition.updateFrame(view: nextLevel, frame: nextLevel.centerFrameY(x: bounds.width - 10 - nextLevel.frame.width))

            transition.updateFrame(view: nextLevel_background, frame: NSMakeRect(width, 0, size.width - width, frame.height))
            transition.updateFrame(view: currentLevel_background, frame: NSMakeRect(0, 0, width, frame.height))
            
        }
        
        override func layout() {
            super.layout()
            self.updateLayout(size: self.frame.size, transition: .immediate)
        }
        
        required init?(coder: NSCoder) {
            fatalError("init(coder:) has not been implemented")
        }
    }
    
    
    private class TypeView : View {
        private let backgrounView = ImageView()
        
        private let textView = DynamicCounterTextView(frame: .zero)
        private let imageView = ImageView()
        private let container = View()
        
        
        required init(frame frameRect: NSRect) {
            super.init(frame: frameRect)
            addSubview(backgrounView)
            container.addSubview(textView)
            container.addSubview(imageView)
            addSubview(container)
            
            textView.userInteractionEnabled = false
        }
        
        override func layout() {
            super.layout()
            backgrounView.frame = bounds
            container.centerX()
            imageView.centerY(x: -3)
            textView.centerY(x: imageView.frame.maxX)
        }
        
        required init?(coder: NSCoder) {
            fatalError("init(coder:) has not been implemented")
        }
        
        
        func update(state: State, context: AccountContext, transition: ContainedViewLayoutTransition) -> NSSize {
            
            let dynamicValue = DynamicCounterTextView.make(for: "\(state.status.boosts)", count: "\(state.status.boosts)", font: .avatar(20), textColor: .white, width: .greatestFiniteMagnitude)
            
            textView.update(dynamicValue, animated: transition.isAnimated)
            transition.updateFrame(view: textView, frame: CGRect(origin: textView.frame.origin, size: dynamicValue.size))
            
            imageView.image = NSImage(named: "Icon_Boost_Lighting")?.precomposed()
            imageView.sizeToFit()
            
            container.setFrameSize(NSMakeSize(dynamicValue.size.width + imageView.frame.width, 40))
                        
            let size = NSMakeSize(container.frame.width + 20, 50)
            
            let image = generateImage(NSMakeSize(size.width, size.height - 10), contextGenerator: { size, ctx in
                ctx.clear(size.bounds)
               
                let path = CGMutablePath()
                path.addRoundedRect(in: NSMakeRect(0, 0, size.width, size.height), cornerWidth: size.height / 2, cornerHeight: size.height / 2)
                
                ctx.addPath(path)
                ctx.setFillColor(NSColor.black.cgColor)
                ctx.fillPath()
                
            })!
            
            let corner = generateImage(NSMakeSize(30, 10), contextGenerator: { size, context in
                context.clear(CGRect(origin: CGPoint(), size: size))
                context.setFillColor(NSColor.black.cgColor)
                context.scaleBy(x: 0.333, y: 0.333)
                let _ = try? drawSvgPath(context, path: "M85.882251,0 C79.5170552,0 73.4125613,2.52817247 68.9116882,7.02834833 L51.4264069,24.5109211 C46.7401154,29.1964866 39.1421356,29.1964866 34.4558441,24.5109211 L16.9705627,7.02834833 C12.4696897,2.52817247 6.36519576,0 0,0 L85.882251,0 ")
                context.fillPath()
            })!

            let clipImage = generateImage(size, rotatedContext: { size, ctx in
                ctx.clear(size.bounds)
                ctx.draw(image, in: NSMakeRect(0, 0, image.backingSize.width, image.backingSize.height))
                
                ctx.draw(corner, in: NSMakeRect(size.bounds.focus(corner.backingSize).minX, image.backingSize.height, corner.backingSize.width, corner.backingSize.height))
            })!
            
            let fullImage = generateImage(size, contextGenerator: { size, ctx in
                ctx.clear(size.bounds)

                ctx.clip(to: size.bounds, mask: clipImage)
                
                let colors = premiumGradient.compactMap { $0.cgColor } as NSArray
                
                let delta: CGFloat = 1.0 / (CGFloat(colors.count) - 1.0)
                
                var locations: [CGFloat] = []
                for i in 0 ..< colors.count {
                    locations.append(delta * CGFloat(i))
                }
                let colorSpace = deviceColorSpace
                let gradient = CGGradient(colorsSpace: colorSpace, colors: colors, locations: &locations)!
                
                ctx.drawLinearGradient(gradient, start: CGPoint(x: 0, y: size.height), end: CGPoint(x: size.width, y: size.height), options: CGGradientDrawingOptions())
            })!
            
            self.backgrounView.image = fullImage
            
            
            needsLayout = true
            
            return size
        }

    }
    

    private let headerBg = View()
    private let lineView = LineView(frame: .zero)
    private let top = TypeView(frame: .zero)
    private let channel = ChannelView(frame: .zero)
    
    
    private var text: TextView?

    required init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        addSubview(channel)
        addSubview(headerBg)
        headerBg.addSubview(top)
        headerBg.addSubview(lineView)
        
        channel.set(handler: { [weak self] _ in
            if let item = self?.item as? BoostRowItem {
                item.openChannel()
            }
        }, for: .Click)
        
       
    }
    
    override var backdorColor: NSColor {
        return .clear
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override func set(item: TableRowItem, animated: Bool = false) {
        super.set(item: item, animated: animated)
        
        guard let item = item as? BoostRowItem else {
            return
        }
        
        if self.text?.textLayout?.attributedString.string != item.text.attributedString.string {
            if let view = self.text {
                performSubviewRemoval(view, animated: animated, scale: true)
                self.text = nil
            }
            let text: TextView = TextView()
            text.userInteractionEnabled = false
            text.isSelectable = false
            self.text = text
            addSubview(text)
            text.frame = text.centerFrameX(y: frame.height - 20 - 30 - text.frame.height - 20)
            text.update(item.text)
            if animated {
                text.layer?.animateAlpha(from: 0, to: 1, duration: 0.2)
                text.layer?.animateScaleSpring(from: 0.1, to: 1, duration: 0.2)
            }
        }
       
        
        let transition: ContainedViewLayoutTransition
        if animated {
            transition = .animated(duration: 0.2, curve: .easeOut)
        } else {
            transition = .immediate
        }
        
        channel.update(item.state.peer.peer, context: item.context, presentation: item.presentation, maxWidth: frame.width - 40)
        channel.isHidden = item.state.samePeer
        
        
        lineView.setFrameSize(NSMakeSize(frame.width - 40, 30))
        lineView.update(item.state, context: item.context, presentation: item.presentation, transition: transition)
        lineView.layer?.cornerRadius = 10
        
        let size = top.update(state: item.state, context: item.context, transition: transition)
        top.setFrameSize(size)

        headerBg.setFrameSize(NSMakeSize(lineView.frame.width, top.frame.height + lineView.frame.height + 10))
        
      
        updateLayout(size: self.frame.size, transition: transition)
    }
    
    
    override func updateLayout(size: NSSize, transition: ContainedViewLayoutTransition) {
        super.updateLayout(size: size, transition: transition)
        
        guard let item = self.item as? BoostRowItem else {
            return
        }
        
        transition.updateFrame(view: channel, frame: channel.centerFrameX(y: 10))
        
        if channel.isHidden {
            transition.updateFrame(view: headerBg, frame: headerBg.centerFrameX(y: 10))
        } else {
            transition.updateFrame(view: headerBg, frame: headerBg.centerFrameX(y: channel.frame.maxY + 20))
        }
        transition.updateFrame(view: lineView, frame: lineView.centerFrameX(y: headerBg.frame.height - lineView.frame.height))

        transition.updateFrame(view: top, frame: CGRect.init(origin: NSMakePoint(max(min(headerBg.frame.width * item.state.percentToNext - top.frame.width / 2, headerBg.frame.width - top.frame.width), 0), lineView.frame.minY - top.frame.height - 10), size: top.frame.size))

        if let text = text {
            transition.updateFrame(view: text, frame: text.centerFrameX(y: size.height - text.frame.height))
        }
        
    }
}

private final class AcceptRowItem : TableRowItem {
    
    fileprivate let boost:()->Void
    fileprivate let state: State
    fileprivate let context: AccountContext
    fileprivate let presentation: TelegramPresentationTheme
    init(_ initialSize: NSSize, state: State, context: AccountContext, presentation: TelegramPresentationTheme, boost:@escaping()->Void) {
        self.boost = boost
        self.presentation = presentation
        self.state = state
        self.context = context
        super.init(initialSize)
    }
    override var height: CGFloat {
        return 80
    }
    
    override var stableId: AnyHashable {
        return _id_accept
    }
    override func viewClass() -> AnyClass {
        return AcceptRowView.self
    }
}

private final class AcceptRowView : TableRowView {
    private final class AcceptView : Control {
        private let gradient: PremiumGradientView = PremiumGradientView(frame: .zero)
        private let textView = TextView()
        private let imageView = LottiePlayerView(frame: NSMakeRect(0, 0, 24, 24))
        private let container = View()
        required init(frame frameRect: NSRect) {
            super.init(frame: frameRect)
            addSubview(gradient)
            container.addSubview(textView)
            container.addSubview(imageView)
            addSubview(container)
            scaleOnClick = true
            
            
            textView.userInteractionEnabled = false
            textView.isSelectable = false
        }
        
        override func layout() {
            super.layout()
            gradient.frame = bounds
            container.center()
            if imageView.isHidden {
                textView.center()
            } else {
                imageView.centerY(x: 0)
                textView.centerY(x: imageView.frame.maxX)
            }
        }
        
        required init?(coder: NSCoder) {
            fatalError("init(coder:) has not been implemented")
        }
        
        func update(state: State, presentation: TelegramPresentationTheme, lottie: LocalAnimatedSticker) {
            
            let title: String
            var gradient: Bool = false
            if state.status.nextLevelBoosts == nil {
                title = strings().modalOK
            } else {
                if state.isAdmin {
                    title = strings().modalCopyLink
                } else {
                    title = strings().channelBoostBoostChannel
                    gradient = true
                }
            }
            set(background: presentation.colors.accent, for: .Normal)
            
            //self.gradient.isHidden = !gradient
            
            let layout = TextViewLayout(.initialize(string: title, color: NSColor.white, font: .medium(.text)))
            layout.measure(width: .greatestFiniteMagnitude)
            textView.update(layout)
            
            if let data = lottie.data, gradient {
                let colors:[LottieColor] = [.init(keyPath: "", color: NSColor(0xffffff))]
                imageView.set(LottieAnimation(compressed: data, key: .init(key: .bundle("bundle_\(lottie.rawValue)"), size: NSMakeSize(24, 24), colors: colors), cachePurpose: .temporaryLZ4(.thumb), playPolicy: .onceEnd, maximumFps: 60, colors: colors, runOnQueue: .mainQueue()))
            }
            imageView.isHidden = !gradient
                  
            if imageView.isHidden {
                container.setFrameSize(NSMakeSize(layout.layoutSize.width, max(layout.layoutSize.height, imageView.frame.height)))
            } else {
                container.setFrameSize(NSMakeSize(layout.layoutSize.width + imageView.frame.width, max(layout.layoutSize.height, imageView.frame.height)))
            }
                        
            needsLayout = true
            
        }
    }

    private let button: AcceptView = AcceptView(frame: .zero)
    required init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        addSubview(button)
        
        
        button.set(handler: { [weak self] _ in
            if let item = self?.item as? AcceptRowItem {
                item.boost()
            }
        }, for: .Click)
        button.scaleOnClick = true
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override func set(item: TableRowItem, animated: Bool = false) {
        super.set(item: item, animated: animated)
        guard let item = item as? AcceptRowItem else {
            return
        }
        
        button.update(state: item.state, presentation: item.presentation, lottie: .menu_lighting)
        
        button.setFrameSize(NSMakeSize(frame.width - 40, 40))
        button.layer?.cornerRadius = 10

    }
    
    override var backdorColor: NSColor {
        return .clear
    }
    
    override func updateLayout(size: NSSize, transition: ContainedViewLayoutTransition) {
        super.updateLayout(size: size, transition: transition)
        
        transition.updateFrame(view: button, frame: button.centerFrameX(y: 20))
    }
}

private let _id_accept = InputDataIdentifier("accept")

private func _id_perk(_ perk: BoostChannelPerk, _ level: Int32) -> InputDataIdentifier {
    return .init("perk_\(perk.title().hashValue)_\(level)")
}
private func _id_perk_level(_ level: Int32) -> InputDataIdentifier {
    return .init("perk_level_\(level)")
}


private func entries(_ state: State, arguments: Arguments) -> [InputDataEntry] {
    var entries:[InputDataEntry] = []
    
    var index: Int32 = 0
    var sectionId: Int32 = 0
    
    entries.append(.custom(sectionId: sectionId, index: index, value: .none, identifier: .init("whole"), equatable: .init(state), comparable: nil, item: { initialSize, stableId in
        return BoostRowItem(initialSize, presentation: arguments.presentation, state: state, context: arguments.context, boost: arguments.boost, openChannel: arguments.openChannel)
    }))
    index += 1
    
    var noLastSection = false
    
    if state.isAdmin, state.status.nextLevelBoosts != nil {
        
        entries.append(.sectionId(sectionId, type: .customModern(20)))
        sectionId += 1
                
        entries.append(.custom(sectionId: sectionId, index: index, value: .none, identifier: InputDataIdentifier("link"), equatable: InputDataEquatable(state.link), comparable: nil, item: { initialSize, stableId in
            return GeneralBlockTextRowItem(initialSize, stableId: stableId, viewType: .singleItem, text: state.link, font: .normal(.text), insets: NSEdgeInsets(left: 20, right: 20), rightAction: .init(image: arguments.presentation.icons.fast_copy_link, action: {
                arguments.copyLink(state.link)
            }), customTheme: .initialize(arguments.presentation))
        }))
        index += 1
        
        entries.append(.sectionId(sectionId, type: .customModern(10)))
        sectionId += 1
        
        entries.append(.desc(sectionId: sectionId, index: index, text: .markdown(strings().boostGetBoosts, linkHandler: { _ in
            arguments.openGiveaway()
        }), data: .init(color: arguments.presentation.colors.text, viewType: .textBottomItem, fontSize: 13, centerViewAlignment: true, alignment: .center, linkColor: arguments.presentation.colors.link)))
        
        
    } else {
        entries.append(.custom(sectionId: sectionId, index: index, value: .none, identifier: _id_accept, equatable: .init(state), comparable: nil, item: { initialSize, stableId in
            return AcceptRowItem(initialSize, state: state, context: arguments.context, presentation: arguments.presentation, boost: arguments.boost)
        }))
        index += 1
        noLastSection = true
    }
    
    var nextLevels: ClosedRange<Int32>?
    if state.status.level < 10 {
        nextLevels = Int32(state.status.level) + 1 ... 10
    }

    let premiumConfiguration = PremiumConfiguration.with(appConfiguration: arguments.context.appConfiguration)
    
    var nameColorsAtLevel: [(Int32, Int32)] = []
    var nameColorsCountMap: [Int32: Int32] = [:]
    for color in arguments.context.peerNameColors.displayOrder {
        if let level = arguments.context.peerNameColors.nameColorsChannelMinRequiredBoostLevel[color] {
            if let current = nameColorsCountMap[level] {
                nameColorsCountMap[level] = current + 1
            } else {
                nameColorsCountMap[level] = 1
            }
        }
    }
    for (key, value) in nameColorsCountMap {
        nameColorsAtLevel.append((key, value))
    }

    
    if let nextLevels = nextLevels {
        for level in nextLevels {
            var perks: [BoostChannelPerk] = []
            perks.append(.story(level))
            perks.append(.reaction(level))
                         
            var nameColorsCount: Int32 = 0
            for (colorLevel, count) in nameColorsAtLevel {
                if level >= colorLevel && colorLevel == 1 {
                    nameColorsCount = count
                }
            }
            if nameColorsCount > 0 {
                perks.append(.nameColor(nameColorsCount))
            }
            
            if level >= premiumConfiguration.minChannelProfileColorLevel {
                let delta = min(level - premiumConfiguration.minChannelProfileColorLevel + 1, 2)
                perks.append(.profileColor(8 * delta))
            }
            if level >= premiumConfiguration.minChannelProfileIconLevel {
                perks.append(.profileIcon)
            }
            
            var linkColorsCount: Int32 = 0
            for (colorLevel, count) in nameColorsAtLevel {
                if level >= colorLevel {
                    linkColorsCount += count
                }
            }
            if linkColorsCount > 0 {
                perks.append(.linkColor(linkColorsCount))
            }
                                
            if level >= premiumConfiguration.minChannelNameIconLevel {
                perks.append(.linkIcon)
            }
            if level >= premiumConfiguration.minChannelEmojiStatusLevel {
                perks.append(.emojiStatus)
            }
            if level >= premiumConfiguration.minChannelWallpaperLevel {
                perks.append(.wallpaper(8))
            }
            if level >= premiumConfiguration.minChannelCustomWallpaperLevel {
                perks.append(.customWallpaper)
            }
            
            // header
            entries.append(.custom(sectionId: sectionId, index: index, value: .none, identifier: _id_perk_level(level), equatable: .init(level), comparable: nil, item: { initialSize, stableId in
                return BoostPerkLevelHeaderItem(initialSize, stableId: stableId, level: level)
            }))
            
            for perk in perks {
                entries.append(.custom(sectionId: sectionId, index: index, value: .none, identifier: _id_perk(perk, level), equatable: .init(perk), comparable: nil, item: { initialSize, stableId in
                    return BoostFeatureRowItem(initialSize, stableId: stableId, perk: perk)
                }))
            }
        }
    }
    if !noLastSection {
        entries.append(.sectionId(sectionId, type: .customModern(20)))
        sectionId += 1
    }
    
    
    return entries
}

enum BoostChannelSource : Equatable {
    case basic
    case story
    case reactions
    case nameColor(Int32)
    case nameIcon(Int32)
    case profileColor(Int32)
    case profileIcon(Int32)
    case emojiStatus(Int32)
    case wallpaper(Int32)
}

func BoostChannelModalController(context: AccountContext, peer: Peer, boosts: ChannelBoostStatus, myStatus: MyBoostStatus?, infoOnly: Bool = false, source: BoostChannelSource = .basic, presentation: TelegramPresentationTheme = theme) -> InputDataModalController {

    let actionsDisposable = DisposableSet()
    
    let updateDisposable = MetaDisposable()
    
    actionsDisposable.add(updateDisposable)

    let initialState = State(peer: .init(peer), status: boosts, myStatus: myStatus, samePeer: context.globalLocationId == .peer(peer.id), infoOnly: infoOnly, source: source)
    
    let statePromise = ValuePromise(initialState, ignoreRepeated: true)
    let stateValue = Atomic(value: initialState)
    let updateState: ((State) -> State) -> Void = { f in
        statePromise.set(stateValue.modify (f))
    }
    
    let peerId = peer.id

    var close:(()->Void)? = nil
    
    let arguments = Arguments(context: context, presentation: presentation, boost: {
        
        let myStatus = stateValue.with { $0.myStatus }
        let nextLevelBoosts = stateValue.with { $0.status.nextLevelBoosts }
        
        var myBoostCount: Int32 = 0
        var availableBoosts: [MyBoostStatus.Boost] = []
        var occupiedBoosts: [MyBoostStatus.Boost] = []
        if let myStatus = myStatus {
            for boost in myStatus.boosts {
                if let boostPeer = boost.peer {
                    if boostPeer.id == peer.id {
                        myBoostCount += 1
                    } else {
                        occupiedBoosts.append(boost)
                    }
                } else {
                    availableBoosts.append(boost)
                }
            }
        }

        
        if let _ = nextLevelBoosts {
            if let availableBoost = availableBoosts.first {
                availableBoosts.removeFirst()
                
                let _ = context.engine.peers.applyChannelBoost(peerId: peerId, slots: [availableBoost.slot]).startStandalone(completed: {
                    updateDisposable.set(nil)
                    updateDisposable.set(combineLatest(context.engine.peers.getChannelBoostStatus(peerId: peerId), context.engine.peers.getMyBoostStatus()).startStandalone(next: { status, myStatus in
                        updateState { current in
                            var current = current
                            if let status = status {
                                current.status = status
                            }
                            current.myStatus = myStatus
                            return current
                        }
                    }))
                })

                PlayConfetti(for: context.window)
            } else if !occupiedBoosts.isEmpty, let _ = myStatus {
                showModal(with: BoostReassignController(context: context, peer: peer, boosts: occupiedBoosts), for: context.window)
                close?()
            } else {
                if context.isPremium {
                    alert(for: context.window, header: strings().boostGiftToGetMoreTitle, info: strings().boostGiftToGetMoreInfo(peer.displayTitle))
                } else {
                    showModal(with: PremiumBoardingController(context: context, source: .channel_boost(peerId)), for: context.window)
                }
            }
        } else {
            close?()
        }


    }, openChannel: {
        close?()
        context.bindings.rootNavigation().push(ChatAdditionController(context: context, chatLocation: .peer(peer.id)))
    }, shareLink: { link in
        showModal(with: ShareModalController(ShareLinkObject(context, link: link)), for: context.window)
    }, copyLink: { link in
        showModalText(for: context.window, text: strings().shareLinkCopied)
        copyToClipboard(link)
    }, openGiveaway: {
        showModal(with: GiveawayModalController(context: context, peerId: peer.id, prepaid: nil), for: context.window)
    })
    
    let signal = statePromise.get() |> deliverOnPrepareQueue |> map { state in
        return InputDataSignalValue(entries: entries(state, arguments: arguments))
    }
    
        
    let controller = InputDataController(dataSignal: signal, title: initialState.title)
    
    controller.onDeinit = {
        actionsDisposable.dispose()
    }
    
    controller.afterTransaction = { controller in
        controller.setCenterTitle(stateValue.with { $0.title })
    }
    
    let modalController = InputDataModalController(controller, modalInteractions: nil, size: NSMakeSize(380, 300), presentation: presentation)
    
    
    controller.leftModalHeader = ModalHeaderData(image: presentation.icons.modalClose, handler: {
        close?()
    })
    
    close = { [weak modalController] in
        modalController?.close()
    }
    
    controller.getBackgroundColor = {
        return presentation.colors.listBackground
    }
    
    return modalController
}


