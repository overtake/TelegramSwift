//
//  SelectColorController.swift
//  Telegram
//
//  Created by Mike Renoir on 17.10.2023.
//  Copyright © 2023 Telegram. All rights reserved.
//

import Cocoa
import TGUIKit
import SwiftSignalKit
import TelegramCore
import Postbox
import InAppSettings
import ColorPalette


private class GroupInfoRowItem : GeneralRowItem {
    fileprivate let text: TextViewLayout
    init(_ initialSize: NSSize, stableId: AnyHashable, viewType: GeneralViewType, action:@escaping()->Void) {
        self.text = .init(.initialize(string: strings().selectColorGroupBlockInfo, color: theme.colors.text, font: .normal(.text)).detectBold(with: .medium(.text)))
        super.init(initialSize, stableId: stableId, viewType: viewType, action: action)
    }
    
    override func makeSize(_ width: CGFloat, oldWidth: CGFloat = 0) -> Bool {
        _ = super.makeSize(width, oldWidth: oldWidth)
        text.measure(width: blockWidth - viewType.innerInset.left - viewType.innerInset.right - viewType.innerInset.left - 30)
        return true
    }
    
    override var height: CGFloat {
        return text.layoutSize.height + viewType.innerInset.top + viewType.innerInset.bottom
    }
    
    override func viewClass() -> AnyClass {
        return GroupInfoRowView.self
    }
}

private final class GroupInfoRowView: GeneralContainableRowView {
    private let textView = TextView()
    private let imageView = ImageView()
    required init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        addSubview(imageView)
        addSubview(textView)
        textView.userInteractionEnabled = false
        textView.isSelectable = false
        
        containerView.scaleOnClick = true
        containerView.set(handler: { [weak self] _ in
            if let item = self?.item as? GeneralRowItem {
                item.action()
            }
        }, for: .Click)
    }
    
    override func layout() {
        super.layout()
        guard let item = item as? GroupInfoRowItem else {
            return
        }
        self.imageView.centerY(x: item.viewType.innerInset.left)
        self.textView.centerY(x: self.imageView.frame.maxX + item.viewType.innerInset.left)
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override func set(item: TableRowItem, animated: Bool = false) {
        super.set(item: item, animated: animated)
        
        guard let item = item as? GroupInfoRowItem else {
            return
        }
        self.imageView.image = NSImage(named: "Icon_GroupBlock_Boost")?.precomposed(theme.colors.accent)
        self.imageView.sizeToFit()
        textView.update(item.text)
    }
}

private class ProfilePreviewRowItem : GeneralRowItem {
    fileprivate let theme: TelegramPresentationTheme
    fileprivate let peer: Peer
    fileprivate let nameColor: PeerNameColor?
    fileprivate let backgroundEmojiId: Int64?
    fileprivate let context: AccountContext
    fileprivate let nameLayout: TextViewLayout
    fileprivate let statusLayout: TextViewLayout
    fileprivate let getColor:(PeerNameColor)->PeerNameColors.Colors
    init(_ initialSize: NSSize, stableId: AnyHashable, peer: Peer, subscribers: Int?, isGroup: Bool, nameColor: PeerNameColor?, backgroundEmojiId: Int64?, context: AccountContext, theme: TelegramPresentationTheme, viewType: GeneralViewType, getColor:@escaping(PeerNameColor)->PeerNameColors.Colors) {
        self.theme = theme
        self.peer = peer
        self.getColor = getColor
        self.nameColor = nameColor
        self.backgroundEmojiId = backgroundEmojiId
        self.context = context
        let textColor: NSColor
        let grayText: NSColor
        if let nameColor = nameColor {
            textColor = getColor(nameColor).main.lightness > 0.8 ? NSColor(0x000000) : NSColor(0xffffff)
            grayText = textColor.withAlphaComponent(0.4)
        } else {
            textColor = theme.colors.text
            grayText = theme.colors.listGrayText
        }

        
        let status: String
        if let subscribers = subscribers {
            if isGroup {
                status = strings().peerStatusMemberCountable(subscribers)
            } else {
                status = strings().peerStatusSubscribersCountable(subscribers)
            }
        } else {
            status = strings().peerStatusRecently
        }
        
        self.nameLayout = .init(.initialize(string: peer.displayTitle, color: textColor, font: .medium(18)), maximumNumberOfLines: 1)
        self.statusLayout = .init(.initialize(string: status, color: grayText, font: .normal(15)))
        super.init(initialSize, stableId: stableId, viewType: viewType)
    }
    
    var accentColor: NSColor {
        if let nameColor = nameColor {
            let textColor = context.peerNameColors.getProfile(nameColor).main.lightness > 0.8 ? NSColor(0x000000) : NSColor(0xffffff)
            return textColor
        } else {
            return theme.colors.accent
        }
    }
    
    override func makeSize(_ width: CGFloat, oldWidth: CGFloat = 0) -> Bool {
        _ = super.makeSize(width, oldWidth: oldWidth)
        
        
        nameLayout.measure(width: blockWidth - 60)
        statusLayout.measure(width: blockWidth - 60)

        return true
    }
    
    override func viewClass() -> AnyClass {
        return ProfilePreviewRowView.self
    }
    
    
    override var hasBorder: Bool {
        return false
    }
    override var height: CGFloat {
        return 240
    }
}

private final class ProfilePreviewRowView : GeneralContainableRowView {
    private let avatar = AvatarControl(font: .avatar(18))
    private let nameView = TextView()
    private let statusView = TextView()
    private var statusControl: PremiumStatusControl?
    private var emojiSpawn: PeerInfoSpawnEmojiView?
    private let backgroundView = PeerInfoBackgroundView(frame: .zero)
    required init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        addSubview(backgroundView)
        addSubview(avatar)
        addSubview(nameView)
        addSubview(statusView)
        
        
        nameView.userInteractionEnabled = false
        nameView.isSelectable = false
        
        statusView.userInteractionEnabled = false
        statusView.isSelectable = false
        
        avatar.setFrameSize(NSMakeSize(120, 120))
        avatar.layer?.cornerRadius = avatar.frame.height / 2
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    
    override var backdorColor: NSColor {
        return .clear
    }
    
    override func set(item: TableRowItem, animated: Bool = false) {
        super.set(item: item, animated: animated)
        guard let item = item as? ProfilePreviewRowItem else {
            return
        }
        avatar.setPeer(account: item.context.account, peer: item.peer)
        
        
        
        nameView.update(item.nameLayout)
        statusView.update(item.statusLayout)
        
        let control = PremiumStatusControl.control(item.peer, account: item.context.account, inlinePacksContext: item.context.inlinePacksContext, left: false, isSelected: false, isBig: true, playTwice: true, color: item.accentColor, cached: self.statusControl, animated: animated)
        if let control = control {
            self.statusControl = control
            self.addSubview(control)
        } else if let view = self.statusControl {
            performSubviewRemoval(view, animated: animated)
            self.statusControl = nil
        }
        
        if let nameColor = item.nameColor {
            backgroundView.gradient = [item.getColor(nameColor).main, item.getColor(nameColor).secondary ?? item.getColor(nameColor).main]
        } else {
            backgroundView.gradient = [NSColor(0xffffff, 0)]
        }
        
        if animated {
            backgroundView.layer?.animateBackground()
        }
        
        
        if let emoji = item.backgroundEmojiId {
            let current: PeerInfoSpawnEmojiView
            if let view = self.emojiSpawn {
                current = view
            } else {
                var rect = focus(NSMakeSize(180, 180))
                rect.origin.y = 0
                current = PeerInfoSpawnEmojiView(frame: rect)
                self.emojiSpawn = current
                addSubview(current, positioned: .above, relativeTo: backgroundView)
            }
            let color: NSColor
            if let nameColor = item.nameColor {
                color = item.getColor(nameColor).main.withAlphaComponent(0.3)
            } else {
                color = theme.colors.text.withAlphaComponent(0.3)
            }
            
            current.set(fileId: emoji, color: color, context: item.context, animated: animated)
        } else if let view = self.emojiSpawn {
            performSubviewRemoval(view, animated: animated)
            self.emojiSpawn = nil
        }
        
        needsLayout = true
    }
    
    override func layout() {
        super.layout()
        
        backgroundView.frame = containerView.bounds
        avatar.centerX(y: 30)
        nameView.centerX(y: avatar.frame.maxY + 20)
        statusView.centerX(y: nameView.frame.maxY + 4)
        emojiSpawn?.centerX(y: 30)
        
        statusControl?.setFrameOrigin(NSMakePoint(nameView.frame.maxX, nameView.frame.minY))
    }
}

private class PreviewRowItem: GeneralRowItem {

    fileprivate let theme: TelegramPresentationTheme
    fileprivate let items:[TableRowItem]
    fileprivate let getColor:(PeerNameColor)->PeerNameColors.Colors
    init(_ initialSize: NSSize, stableId: AnyHashable, peer: Peer, nameColor: PeerNameColor?, backgroundEmojiId: Int64?, emojiStatus: PeerEmojiStatus?, context: AccountContext, theme: TelegramPresentationTheme, viewType: GeneralViewType, getColor:@escaping(PeerNameColor)->PeerNameColors.Colors) {
        self.theme = theme.withUpdatedBackgroundSize(WallpaperDimensions.aspectFilled(NSMakeSize(200, 200)))
        self.getColor = getColor
        let peerId = PeerId(namespace: Namespaces.Peer.CloudGroup, id: ._internalFromInt64Value(0))
        
        let chatInteraction = ChatInteraction(chatLocation: .peer(peerId), context: context, isLogInteraction: true, disableSelectAbility: true, isGlobalSearchMessage: true)
        
        let previewPeer: Peer?
        if let peer = peer as? TelegramUser {
            previewPeer = TelegramUser(id: peerId, accessHash: peer.accessHash, firstName: peer.firstName, lastName: peer.lastName, username: peer.username, phone: peer.phone, photo: peer.photo, botInfo: nil, restrictionInfo: nil, flags: [], emojiStatus: emojiStatus, usernames: [], storiesHidden: nil, nameColor: nameColor, backgroundEmojiId: backgroundEmojiId, profileColor: nameColor, profileBackgroundEmojiId: backgroundEmojiId, subscriberCount: nil, verificationIconFileId: nil)
        } else if let peer = peer as? TelegramChannel {
            previewPeer = TelegramChannel(id: peerId, accessHash: peer.accessHash, title: peer.title, username: peer.username, photo: peer.profileImageRepresentations, creationDate: peer.creationDate, version: peer.version, participationStatus: peer.participationStatus, info: peer.info, flags: peer.flags, restrictionInfo: peer.restrictionInfo, adminRights: peer.adminRights, bannedRights: peer.bannedRights, defaultBannedRights: peer.defaultBannedRights, usernames: peer.usernames, storiesHidden: peer.storiesHidden, nameColor: nameColor, backgroundEmojiId: backgroundEmojiId, profileColor: nameColor, profileBackgroundEmojiId: backgroundEmojiId, emojiStatus: emojiStatus, approximateBoostLevel: nil, subscriptionUntilDate: nil, verificationIconFileId: nil, sendPaidMessageStars: nil, linkedMonoforumId: nil)
        } else {
            previewPeer = nil
        }
      
           

        
                
        
        if let previewPeer = previewPeer {
            
            let firstMessage = Message(stableId: 0, stableVersion: 0, id: MessageId(peerId: previewPeer.id, namespace: 0, id: 0), globallyUniqueId: 0, groupingKey: 0, groupInfo: nil, threadId: nil, timestamp: 60 * 18 + 60*60*18, flags: [], tags: [], globalTags: [], localTags: [], customTags: [], forwardInfo: nil, author: previewPeer, text: strings().selectColorMessage1, attributes: [], media: [], peers:SimpleDictionary([previewPeer.id : previewPeer]) , associatedMessages: SimpleDictionary(), associatedMessageIds: [], associatedMedia: [:], associatedThreadInfo: nil, associatedStories: [:])

            
            let timestamp1: Int32 = 60 * 20 + 60 * 60 * 18
            
            let media = TelegramMediaWebpage(webpageId: MediaId(namespace: 0, id: 0), content: TelegramMediaWebpageContent.Loaded(TelegramMediaWebpageLoadedContent(url: "", displayUrl: "", hash: 0, type: "photo", websiteName: appName, title: strings().selectColorMessage2PreviewTitle, text: strings().selectColorMessage2PreviewText, embedUrl: nil, embedType: nil, embedSize: nil, duration: nil, author: nil, isMediaLargeByDefault: nil, imageIsVideoCover: false, image: nil, file: nil, story: nil, attributes: [], instantPage: nil)))

            let secondMessage = Message(stableId: 1, stableVersion: 0, id: MessageId(peerId: previewPeer.id, namespace: 0, id: 1), globallyUniqueId: 0, groupingKey: 0, groupInfo: nil, threadId: nil, timestamp: timestamp1, flags: [.Incoming], tags: [], globalTags: [], localTags: [], customTags: [], forwardInfo: nil, author: previewPeer, text: strings().selectColorMessage2, attributes: [ReplyMessageAttribute(messageId: firstMessage.id, threadMessageId: nil, quote: nil, isQuote: false, todoItemId: nil)], media: [media], peers:SimpleDictionary([previewPeer.id : previewPeer]) , associatedMessages: SimpleDictionary([firstMessage.id : firstMessage]), associatedMessageIds: [], associatedMedia: [:], associatedThreadInfo: nil, associatedStories: [:])
            
            let secondEntry: ChatHistoryEntry = .MessageEntry(secondMessage, MessageIndex(secondMessage), true, theme.bubbled ? .bubble : .list, .Full(rank: nil, header: .normal), nil, ChatHistoryEntryData(nil, MessageEntryAdditionalData(), AutoplayMediaPreferences.defaultSettings))
            
            let item2 = ChatRowItem.item(initialSize, from: secondEntry, interaction: chatInteraction, theme: theme)
            self.items = [item2]
        } else {
            self.items = []
        }
        
        super.init(initialSize, stableId: stableId, viewType: viewType)
        
        chatInteraction.getGradientOffsetRect = { [weak self] in
            guard let `self` = self else {
                return .zero
            }
            return CGRect(origin: NSMakePoint(0, self.height), size: NSMakeSize(self.width, self.height))
        }
        
        _ = makeSize(initialSize.width, oldWidth: 0)
    }
    
    override func makeSize(_ width: CGFloat, oldWidth: CGFloat = 0) -> Bool {
        _ = super.makeSize(width, oldWidth: oldWidth)
        
        let itemWidth = self.blockWidth - self.viewType.innerInset.left - self.viewType.innerInset.right
        for item in items {
            _ = item.makeSize(itemWidth, oldWidth: 0)
        }
        return true
    }
    
    override var instantlyResize: Bool {
        return true
    }
    
    override var height: CGFloat {
        var height: CGFloat = self.viewType.innerInset.top + self.viewType.innerInset.bottom
        
        for item in self.items {
            height += item.height
        }
        return height
    }
    
    override func viewClass() -> AnyClass {
        return PreviewRowView.self
    }
    
}

private final class PreviewRowView : GeneralContainableRowView {
    private let backgroundView: BackgroundView
    private let itemsView = View()
    required init(frame frameRect: NSRect) {
        backgroundView = BackgroundView(frame: NSMakeRect(0, 0, frameRect.width, frameRect.height))
        backgroundView.useSharedAnimationPhase = false
        super.init(frame: frameRect)
        addSubview(self.backgroundView)
        self.backgroundView.addSubview(itemsView)
    }
    
    override func set(item: TableRowItem, animated: Bool = false) {
        super.set(item: item, animated: animated)
        
        guard let item = item as? PreviewRowItem else {
            return
        }
        
        self.layout()
        
        
    
        var y: CGFloat = item.viewType.innerInset.top
        for (i, item) in item.items.enumerated() {
            let vz = item.viewClass() as! TableRowView.Type
            let view: TableRowView
            if self.itemsView.subviews.count > i {
                view = self.itemsView.subviews[i] as! TableRowView
            } else {
                view = vz.init(frame:NSMakeRect(0, y, self.backgroundView.frame.width, item.height))
            }
            view.set(item: item, animated: false)
            if view.superview == nil {
                self.itemsView.addSubview(view)
            }
            
            if let view = view as? ChatRowView {
                view.updateBackground(animated: false, item: view.item, rotated: true)
            }
            
            y += item.height
        }
        
        
    }
    
    override func updateColors() {
        guard let item = item as? PreviewRowItem else {
            return
        }
        self.containerView.backgroundColor = background
        self.backgroundView.backgroundMode = item.theme.bubbled ? item.theme.backgroundMode : .color(color: item.theme.colors.chatBackground)
        self.borderView.backgroundColor = theme.colors.border
        self.backgroundColor = item.viewType.rowBackground
    }
    
    override var backdorColor: NSColor {
        return theme.colors.background
    }
    
    override func layout() {
        super.layout()
        self.backgroundView.frame = self.containerView.bounds
        self.borderView.frame = NSMakeRect(0, self.containerView.frame.height - .borderSize, self.containerView.frame.width, .borderSize)
        itemsView.frame = backgroundView.bounds
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}



func generateRingImage(nameColor: PeerNameColors.Colors) -> CGImage {
    return generateImage(CGSize(width: 35, height: 35), rotatedContext: { size, context in
        let bounds = CGRect(origin: CGPoint(), size: size)
        context.clear(bounds)
        
        context.setStrokeColor(nameColor.main.cgColor)
        context.setLineWidth(2.0)
        context.strokeEllipse(in: bounds.insetBy(dx: 1.0, dy: 1.0))
    })!
}

func generateFillImage(nameColor: PeerNameColors.Colors) -> CGImage {
    return generateImage(CGSize(width: 35, height: 35), rotatedContext: { size, context in
        let bounds = CGRect(origin: CGPoint(), size: size)
        context.clear(bounds)
        
        let circleBounds = bounds
        context.addEllipse(in: circleBounds)
        context.clip()
        
        if let secondColor = nameColor.secondary {
            context.setFillColor(secondColor.cgColor)
            context.fill(circleBounds)
            
            context.move(to: .zero)
            context.addLine(to: CGPoint(x: size.width, y: 0.0))
            context.addLine(to: CGPoint(x: 0.0, y: size.height))
            context.closePath()
            context.setFillColor(nameColor.main.cgColor)
            context.fillPath()
            
            if let thirdColor = nameColor.tertiary {
                context.setFillColor(thirdColor.cgColor)
                context.translateBy(x: size.width / 2.0, y: size.height / 2.0)
                context.rotate(by: .pi / 4.0)
                
                let path = CGMutablePath()
                path.addRoundedRect(in: CGRect(origin: CGPoint(x: -8, y: -8), size: CGSize(width: 16, height: 16)), cornerWidth: 4, cornerHeight: 4)
                context.addPath(path)
                context.fillPath()
            }
        } else {
            context.setFillColor(nameColor.main.cgColor)
            context.fill(circleBounds)
        }
    })!
}




private enum PeerNameColorEntryId: Hashable {
    case color(Int32)
}

private enum PeerNameColorEntry: Comparable, Identifiable {
    case color(Int, PeerNameColor, Bool)
    
    var stableId: PeerNameColorEntryId {
        switch self {
            case let .color(_, color, _):
                return .color(color.rawValue)
        }
    }
    
    static func ==(lhs: PeerNameColorEntry, rhs: PeerNameColorEntry) -> Bool {
        switch lhs {
            case let .color(lhsIndex, lhsAccentColor, lhsSelected):
                if case let .color(rhsIndex, rhsAccentColor, rhsSelected) = rhs, lhsIndex == rhsIndex, lhsAccentColor == rhsAccentColor, lhsSelected == rhsSelected {
                    return true
                } else {
                    return false
                }
        }
    }
    
    static func <(lhs: PeerNameColorEntry, rhs: PeerNameColorEntry) -> Bool {
        switch lhs {
            case let .color(lhsIndex, _, _):
                switch rhs {
                    case let .color(rhsIndex, _, _):
                        return lhsIndex < rhsIndex
            }
        }
    }
    
    func item(initialSize: NSSize, context: AccountContext, getColor:@escaping(PeerNameColor)->PeerNameColors.Colors, action: @escaping (PeerNameColor) -> Void) -> PeerNameColorIconItem {
        switch self {
            case let .color(_, color, selected):
            return PeerNameColorIconItem(initialSize: initialSize, stableId: self.stableId, context: context, color: color, selected: selected, action: action, getColor: getColor)
        }
    }
}



private class PeerNameColorIconItem: TableRowItem {
    let color: PeerNameColor
    let selected: Bool
    let action: (PeerNameColor) -> Void
    let context: AccountContext
    let getColor:(PeerNameColor)->PeerNameColors.Colors
    public init(initialSize: NSSize, stableId: AnyHashable, context: AccountContext, color: PeerNameColor, selected: Bool, action: @escaping (PeerNameColor) -> Void, getColor:@escaping(PeerNameColor)->PeerNameColors.Colors) {
        self.color = color
        self.selected = selected
        self.action = action
        self.context = context
        self.getColor = getColor
        super.init(initialSize, stableId: stableId)
    }
    
    override var height: CGFloat {
        return 55
    }
    override var width: CGFloat {
        return 55
    }
    
    override func viewClass() -> AnyClass {
        return PeerNameColorIconView.self
    }
}

private final class PeerNameColorIconView : View {
    
    private let fillView: SimpleLayer = SimpleLayer()
    private let ringView: SimpleLayer = SimpleLayer()
    private let control = Control()
    required init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        self.layer?.addSublayer(ringView)
        self.layer?.addSublayer(fillView)
        addSubview(control)
        let bounds = focus(CGSize(width: 35, height: 35))
        
        fillView.frame = bounds
        ringView.frame = bounds

        
        control.frame = bounds
        
        
        control.set(handler: { [weak self] _ in
            guard let item = self?.item as? PeerNameColorIconItem else {
                return
            }
            item.action(item.color)
        }, for: .Click)
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    private var wasSelected: Bool = false
    
    private var item: TableRowItem?
    
    func set(item: TableRowItem, animated: Bool) {
        
        self.item = item
        
        guard let item = item as? PeerNameColorIconItem else {
            return
        }
                
        let colors = item.getColor(item.color)


        
        self.fillView.contents = generateFillImage(nameColor: colors)
        self.ringView.contents = generateRingImage(nameColor: colors)

        if wasSelected != item.selected {
            if item.selected {
                self.fillView.transform = CATransform3DScale(CATransform3DIdentity, 0.8, 0.8, 1.0)
                if animated {
                    self.fillView.animateScale(from: 1, to: 0.8, duration: animated ? 0.2 : 0, removeOnCompletion: true)
                }
            } else {
                self.fillView.transform = CATransform3DScale(CATransform3DIdentity, 1.0, 1.0, 1.0)
                if animated {
                    self.fillView.animateScale(from: 0.8, to: 1, duration: animated ? 0.2 : 0, removeOnCompletion: true)
                }
            }
        }
        
        self.wasSelected = item.selected

    }
}

private final class PeerNamesRowItem : GeneralRowItem {
    fileprivate let colors: [PeerNameColor]
    fileprivate let selected: PeerNameColor?
    fileprivate let selectAction:(PeerNameColor)->Void
    fileprivate let context: AccountContext
    fileprivate let getColor:(PeerNameColor)->PeerNameColors.Colors

    let itemSize: NSSize = NSMakeSize(45, 45)
    init(_ initialSize: NSSize, stableId: AnyHashable, context: AccountContext, colors: [PeerNameColor], selected: PeerNameColor?, viewType: GeneralViewType, action: @escaping(PeerNameColor)->Void, getColor:@escaping(PeerNameColor)->PeerNameColors.Colors) {
        self.colors = colors
        self.context = context
        self.selected = selected
        self.selectAction = action
        self.getColor = getColor
        super.init(initialSize, stableId: stableId, viewType: viewType)
    }
    
    var frames:[CGRect] = []
    
    override func makeSize(_ width: CGFloat, oldWidth: CGFloat = 0) -> Bool {
        _ = super.makeSize(width, oldWidth: oldWidth)

        frames.removeAll()
        
        let perRow = Int(floor((blockWidth - 10) / itemSize.width))

        var point: CGPoint = NSMakePoint(5, 5)
        for i in 1 ... colors.count {
            frames.append(CGRect(origin: point, size: itemSize))
            if i % perRow == 0 {
                point.x = 5
                point.y += itemSize.height
            } else {
                point.x += itemSize.width
            }
        }
        
        return true
    }
    
    override var instantlyResize: Bool {
        return true
    }
    
    override var height: CGFloat {
        let perRow = floor((blockWidth - 10) / itemSize.width)
        
        return frames[frames.count - 1].maxY + 5
    }
    
    override func viewClass() -> AnyClass {
        return PeerNamesRowView.self
    }
}

private final class PeerNamesRowView : GeneralContainableRowView {
    let tableView: View
    required init(frame frameRect: NSRect) {
        tableView = View(frame: frameRect)
        super.init(frame: frameRect)
        addSubview(tableView)
    }
    
    override func layout() {
        super.layout()
        tableView.frame = containerView.bounds
        guard let item = item as? PeerNamesRowItem else {
            return
        }
        
        for (i, subview) in tableView.subviews.enumerated() {
            subview.frame = item.frames[i]
        }
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    private var previous: [PeerNameColorEntry] = []
    
    override func set(item: TableRowItem, animated: Bool = false) {
        super.set(item: item, animated: animated)
        
        guard let item = item as? PeerNamesRowItem else {
            return
        }
        
        var entries: [PeerNameColorEntry] = []
        
        var index: Int = 0
        for color in item.colors {
            entries.append(.color(index, color, color == item.selected))
            index += 1
        }

        let (deleteIndices, indicesAndItems, updateIndices) = mergeListsStableWithUpdates(leftList: previous, rightList: entries)
        
        //let animation: NSTableView.AnimationOptions = animated ? .effectFade : .none
        
        for rdx in deleteIndices.reversed() {
            tableView.subviews[rdx].removeFromSuperview()
        }
        
        
        for (idx, entry, _) in indicesAndItems {
            let view = PeerNameColorIconView(frame: item.itemSize.bounds)
            let item = entry.item(initialSize: bounds.size, context: item.context, getColor: item.getColor, action: item.selectAction)
            view.set(item: item, animated: animated)
            tableView.subviews.insert(view, at: idx)
        }
        for (idx, entry, _) in updateIndices {
            let item = item
            let updatedItem = entry.item(initialSize: bounds.size, context: item.context, getColor: item.getColor, action: item.selectAction)
            (tableView.subviews[idx] as? PeerNameColorIconView)?.set(item: updatedItem, animated: animated)
        }

        self.previous = entries
        
        needsLayout = true
        
    }
    
}


private final class Arguments {
    let context: AccountContext
    let premiumConfiguration: PremiumConfiguration
    let source: SelectColorSource
    let toggleColor:(PeerNameColor, SelectColorType) -> Void
    let showEmojiPanel:(SelectColorType)->Void
    let showEmojiPack:()->Void
    let removeIcon:(SelectColorType)->Void
    let resetColor:(SelectColorType)->Void
    let getColor:(PeerNameColor, SelectColorType)->PeerNameColors.Colors
    let showEmojiStatus:()->Void
    let showChannelWallpaper:()->Void
    let boost:()->Void
    let wearCollectible:(StarGift)->Void
    init(context: AccountContext, source: SelectColorSource, toggleColor:@escaping(PeerNameColor, SelectColorType) -> Void, showEmojiPanel:@escaping(SelectColorType)->Void, showEmojiPack:@escaping()->Void, removeIcon:@escaping(SelectColorType)->Void, resetColor:@escaping(SelectColorType)->Void, getColor:@escaping(PeerNameColor, SelectColorType)->PeerNameColors.Colors, showEmojiStatus:@escaping()->Void, showChannelWallpaper:@escaping()->Void, boost:@escaping()->Void, wearCollectible:@escaping(StarGift)->Void) {
        self.context = context
        self.source = source
        self.premiumConfiguration = PremiumConfiguration.with(appConfiguration: context.appConfiguration)
        self.toggleColor = toggleColor
        self.showEmojiPanel = showEmojiPanel
        self.showEmojiPack = showEmojiPack
        self.removeIcon = removeIcon
        self.resetColor = resetColor
        self.getColor = getColor
        self.showEmojiStatus = showEmojiStatus
        self.showChannelWallpaper = showChannelWallpaper
        self.boost = boost
        self.wearCollectible = wearCollectible
    }
}

private struct State : Equatable {
    
    var boostLevel: Int32 {
        if let status = status {
            return Int32(status.level)
        } else if let channel = peer._asPeer() as? TelegramChannel {
            return channel.approximateBoostLevel ?? 0
        } else {
            return 0
        }
    }
    
    var wearable: [RecentStarGiftItem] = []

    var peer: EnginePeer
    
    var status: ChannelBoostStatus?
    var myStatus: MyBoostStatus?

    var selected: PeerNameColor?
    var selected_profile: PeerNameColor?

    var backgroundEmojiId: Int64? = nil
    var backgroundEmojiId_profile: Int64? = nil
    
    var emojiStatus:PeerEmojiStatus?

    var saving: Bool = false
    var subscribers: Int?
    var icon: CGImage?
    var icon_profile: CGImage?
    var icon_emojiStatus: CGImage?
    
    var theme: TelegramPresentationTheme
    
    var wallpaper: TelegramWallpaper?
    var actualWallpaper: TelegramWallpaper?
    
    var emojiPack: StickerPackCollectionInfo?
    var actualEmojiPack: StickerPackCollectionInfo?
    
    
    var icon_emojiPack: CGImage?

    func isSame(to peer: Peer) -> Bool {
        if peer.profileColor != selected_profile {
            return false
        }
        if peer.nameColor != selected {
            return false
        }
        if peer.backgroundEmojiId != backgroundEmojiId {
            return false
        }
        if peer.profileBackgroundEmojiId != backgroundEmojiId_profile {
            return false
        }
        if peer.emojiStatus?.fileId != emojiStatus?.fileId {
            return false
        }
        if wallpaper != actualWallpaper {
            return false
        }
        if emojiPack != actualEmojiPack {
            return false
        }
        return true
    }
}

private let _id_colors = InputDataIdentifier("_id_colors")
private let _id_preview = InputDataIdentifier("_id_preview")
private let _id_emojies = InputDataIdentifier("_id_emojies")
private let _id_icon = InputDataIdentifier("_id_icon")
private let _id_icon_remove = InputDataIdentifier("_id_icon_remove")
private let _id_reset_color = InputDataIdentifier("_id_reset_color")


private let _id_colors_profile = InputDataIdentifier("_id_colors_profile")
private let _id_preview_profile = InputDataIdentifier("_id_preview_profile")
private let _id_emojies_profile = InputDataIdentifier("_id_emojies_profile")
private let _id_icon_profile = InputDataIdentifier("_id_icon_profile")
private let _id_icon_remove_profile = InputDataIdentifier("_id_icon_remove_profile")
private let _id_reset_color_profile = InputDataIdentifier("_id_reset_color_profile")
private let _id_reset_color_name = InputDataIdentifier("_id_reset_color_name")

private let _id_emoji_status = InputDataIdentifier("_id_emoji_status")
private let _id_emoji_pack = InputDataIdentifier("_id_emoji_pack")

private let _id_group_block = InputDataIdentifier("_id_group_block")

private let _id_wallpaper = InputDataIdentifier("_id_wallpaper")

private func _id_stars_gifts(_ index: Int) -> InputDataIdentifier {
    return InputDataIdentifier("_id_stars_gifts_\(index)")
}


private func entries(_ state: State, arguments: Arguments) -> [InputDataEntry] {
    var entries:[InputDataEntry] = []
    
    var sectionId:Int32 = 0
    var index: Int32 = 0
    
    
    var afterNameImage_emojiStatus: CGImage? = nil
    var afterNameImage_NameIcon: CGImage? = nil
    var afterNameImage_ProfileIcon: CGImage? = nil
    var afterNameImage_WallpaperIcon: CGImage? = nil
    var afterNameImage_EmojiPack: CGImage? = nil

    switch arguments.source {
    case .channel:
        if state.boostLevel < arguments.premiumConfiguration.minChannelEmojiStatusLevel {
            afterNameImage_emojiStatus = generateDisclosureActionBoostLevelBadgeImage(text: strings().boostBadgeLevel(Int(arguments.premiumConfiguration.minChannelEmojiStatusLevel)))
        }
        if state.boostLevel < arguments.premiumConfiguration.minChannelNameIconLevel {
            afterNameImage_NameIcon = generateDisclosureActionBoostLevelBadgeImage(text: strings().boostBadgeLevel(Int(arguments.premiumConfiguration.minChannelNameIconLevel)))
        }
        if state.boostLevel < arguments.premiumConfiguration.minChannelProfileIconLevel {
            afterNameImage_ProfileIcon = generateDisclosureActionBoostLevelBadgeImage(text: strings().boostBadgeLevel(Int(arguments.premiumConfiguration.minChannelProfileIconLevel)))
        }
        if state.boostLevel < arguments.premiumConfiguration.minChannelWallpaperLevel {
            afterNameImage_WallpaperIcon = generateDisclosureActionBoostLevelBadgeImage(text: strings().boostBadgeLevel(Int(arguments.premiumConfiguration.minChannelWallpaperLevel)))
        }
    case .group:
        if state.boostLevel < arguments.premiumConfiguration.minGroupEmojiStatusLevel {
            afterNameImage_emojiStatus = generateDisclosureActionBoostLevelBadgeImage(text: strings().boostBadgeLevel(Int(arguments.premiumConfiguration.minGroupEmojiStatusLevel)))
        }
        if state.boostLevel < arguments.premiumConfiguration.minGroupProfileIconLevel {
            afterNameImage_ProfileIcon = generateDisclosureActionBoostLevelBadgeImage(text: strings().boostBadgeLevel(Int(arguments.premiumConfiguration.minGroupProfileIconLevel)))
        }
        if state.boostLevel < arguments.premiumConfiguration.minGroupWallpaperLevel {
            afterNameImage_WallpaperIcon = generateDisclosureActionBoostLevelBadgeImage(text: strings().boostBadgeLevel(Int(arguments.premiumConfiguration.minGroupWallpaperLevel)))
        }
        if state.boostLevel < arguments.premiumConfiguration.minGroupEmojiPackLevel {
            afterNameImage_EmojiPack = generateDisclosureActionBoostLevelBadgeImage(text: strings().boostBadgeLevel(Int(arguments.premiumConfiguration.minGroupEmojiPackLevel)))
        }
    default:
        break
    }
    
    switch arguments.source {
    case .channel, .account:
        
        entries.append(.sectionId(sectionId, type: .normal))
        sectionId += 1
        
        
        entries.append(.custom(sectionId: sectionId, index: index, value: .none, identifier: _id_preview, equatable: .init(state), comparable: nil, item: { initialSize, stableId in
            return PreviewRowItem(initialSize, stableId: stableId, peer: arguments.source.peer, nameColor: state.selected, backgroundEmojiId: state.backgroundEmojiId, emojiStatus: state.emojiStatus, context: arguments.context, theme: state.theme, viewType: .firstItem, getColor: { name in
                arguments.getColor(name, .name)
            })
        }))
        
        var colors: [PeerNameColor] = []
        for index in arguments.context.peerNameColors.displayOrder {
            colors.append(PeerNameColor(rawValue: index))
        }
        
        let colorsViewType: GeneralViewType
        colorsViewType = .innerItem
      
        entries.append(.custom(sectionId: sectionId, index: index, value: .none, identifier: _id_colors, equatable: .init(state), comparable: nil, item: { initialSize, stableId in
            return PeerNamesRowItem(initialSize, stableId: stableId, context: arguments.context, colors: colors, selected: state.selected, viewType: colorsViewType, action: { color in
                arguments.toggleColor(color, .name)
            }, getColor: {
                arguments.getColor($0, .name)
            })
        }))
        
        
        let type: GeneralInteractedType
        if let icon = state.icon {
            type = .imageContext(icon, "")
        } else {
            type = .context(strings().selectColorIconSelectOff)
        }
        
        entries.append(.general(sectionId: sectionId, index: index, value: .none, error: nil, identifier: _id_icon, data: .init(name: strings().selectColorIconSelectReplies, color: theme.colors.text, icon: nil, type: type, viewType: .lastItem, enabled: true, action: {
            arguments.showEmojiPanel(.name)
        }, afterNameImage: afterNameImage_NameIcon)))
        
        let iconInfo: String
        switch arguments.source {
        case .account:
            iconInfo = strings().selectColorIconInfoUser
        case .channel, .group:
            iconInfo = strings().selectColorIconInfoChannel
        }
        entries.append(.desc(sectionId: sectionId, index: index, text: .plain(iconInfo), data: .init(color: theme.colors.listGrayText, viewType: .textBottomItem)))
        index += 1
        
        if state.selected != state.peer.nameColor {
            entries.append(.sectionId(sectionId, type: .normal))
            sectionId += 1
            
            entries.append(.general(sectionId: sectionId, index: index, value: .none, error: nil, identifier: _id_reset_color_name, data: .init(name: strings().selectColorResetColorName, color: theme.colors.accent, viewType: .singleItem, action: {
                arguments.resetColor(.name)
            })))
        }
    default:
        break
    }
    
    switch arguments.source {
    case .channel:
        entries.append(.sectionId(sectionId, type: .normal))
        sectionId += 1
        
        let title: String
        let info: String
        switch arguments.source {
        case .channel:
            title = strings().selectColorChannelWallpaper
            info = strings().selectColorChannelWallpaperInfo
        case .group:
            title = strings().selectColorGroupWallpaper
            info = strings().selectColorGroupWallpaperInfo
        default:
            fatalError()
        }
        
        entries.append(.general(sectionId: sectionId, index: index, value: .none, error: nil, identifier: _id_wallpaper, data: .init(name: title, color: theme.colors.text, icon: nil, type: .next, viewType: .singleItem, enabled: true, action: {
            arguments.showChannelWallpaper()
        }, afterNameImage: afterNameImage_WallpaperIcon)))
        
        entries.append(.desc(sectionId: sectionId, index: index, text: .plain(info), data: .init(color: theme.colors.listGrayText, viewType: .textBottomItem)))
        index += 1
    default:
        break
    }
    
    
    //!!!!!!PROFILE!!!!!!!
    
    if true {
        
        entries.append(.sectionId(sectionId, type: .normal))
        sectionId += 1
        
        
        entries.append(.desc(sectionId: sectionId, index: index, text: .plain(strings().selectColorProfilePageTitle), data: .init(color: theme.colors.listGrayText, viewType: .textTopItem)))
        index += 1
        
        let previewViewType: GeneralViewType
        let isGroup: Bool
        switch arguments.source {
        case .group:
            previewViewType = .singleItem
            isGroup = true
        default:
            previewViewType = .firstItem
            isGroup = false
        }
        

        
        entries.append(.custom(sectionId: sectionId, index: index, value: .none, identifier: _id_preview_profile, equatable: .init(state), comparable: nil, item: { initialSize, stableId in
            return ProfilePreviewRowItem(initialSize, stableId: stableId, peer: arguments.source.peer, subscribers: state.subscribers, isGroup: isGroup, nameColor: state.selected_profile, backgroundEmojiId: state.backgroundEmojiId_profile, context: arguments.context, theme: theme, viewType: previewViewType, getColor: {
                arguments.getColor($0, .profile)
            })
        }))
        
        switch arguments.source {
        case .group:
            entries.append(.sectionId(sectionId, type: .normal))
            sectionId += 1
            
            entries.append(.custom(sectionId: sectionId, index: index, value: .none, identifier: _id_group_block, equatable: .init(state), comparable: nil, item: { initialSize, stableId in
                return GroupInfoRowItem(initialSize, stableId: stableId, viewType: .singleItem, action: {
                    arguments.boost()
                })
            }))
            
            entries.append(.sectionId(sectionId, type: .normal))
            sectionId += 1
        default:
            break
        }
        
        
        var colors: [PeerNameColor] = []
        for index in arguments.context.peerNameColors.profileDisplayOrder {
            colors.append(PeerNameColor(rawValue: index))
        }
        
       
        let colorsViewType: GeneralViewType
        switch arguments.source {
        case .group:
            colorsViewType = .firstItem
        default:
            colorsViewType = .innerItem
        }

      
        entries.append(.custom(sectionId: sectionId, index: index, value: .none, identifier: _id_colors_profile, equatable: .init(state), comparable: nil, item: { initialSize, stableId in
            return PeerNamesRowItem(initialSize, stableId: stableId, context: arguments.context, colors: colors, selected: state.selected_profile, viewType: colorsViewType, action: { color in
                arguments.toggleColor(color, .profile)
            }, getColor: {
                arguments.getColor($0, .profile)
            })
        }))
        
        let type: GeneralInteractedType
        if let icon = state.icon_profile {
            type = .imageContext(icon, "")
        } else {
            type = .context(strings().selectColorIconSelectOff)
        }
        
        entries.append(.general(sectionId: sectionId, index: index, value: .none, error: nil, identifier: _id_icon_profile, data: .init(name: strings().selectColorIconSelectProfile, color: theme.colors.text, icon: nil, type: type, viewType: .lastItem, enabled: true, action: {
            arguments.showEmojiPanel(.profile)
        }, afterNameImage: afterNameImage_ProfileIcon)))
        
        let iconInfo: String
        switch arguments.source {
        case .account:
            iconInfo = strings().selectColorIconInfoUserProfile
        case .channel:
            iconInfo = strings().selectColorIconInfoChannelProfile
        case .group:
            iconInfo = strings().selectColorIconInfoGroupProfile
        }
        entries.append(.desc(sectionId: sectionId, index: index, text: .plain(iconInfo), data: .init(color: theme.colors.listGrayText, viewType: .textBottomItem)))
        index += 1
        
        if state.selected_profile != nil {
            entries.append(.sectionId(sectionId, type: .normal))
            sectionId += 1
            
            entries.append(.general(sectionId: sectionId, index: index, value: .none, error: nil, identifier: _id_reset_color_profile, data: .init(name: strings().selectColorResetColorProfile, color: theme.colors.accent, viewType: .singleItem, action: {
                arguments.resetColor(.profile)
            })))
        }
        
    }
    
    entries.append(.sectionId(sectionId, type: .normal))
    sectionId += 1
    
    let title: String 
    let emojiStatusInfo: String
    switch arguments.source {
    case .account:
        title = strings().selectColorEmojiStatusUser
        emojiStatusInfo = strings().selectColorEmojiStatusInfoUser
    case .channel:
        title = strings().selectColorEmojiStatusChannel
        emojiStatusInfo = strings().selectColorEmojiStatusInfoChannel
    case .group:
        title = strings().selectColorEmojiStatusGroup
        emojiStatusInfo = strings().selectColorEmojiStatusInfoGroup
    }
    
    let statusType: GeneralInteractedType
    if let icon = state.icon_emojiStatus {
        statusType = .imageContext(icon, "")
    } else {
        statusType = .nextContext("")
    }
    
    entries.append(.general(sectionId: sectionId, index: index, value: .none, error: nil, identifier: _id_emoji_status, data: .init(name: title, color: theme.colors.text, icon: nil, type: statusType, viewType: .singleItem, enabled: true, action: {
        arguments.showEmojiStatus()
    }, afterNameImage: afterNameImage_emojiStatus)))
    entries.append(.desc(sectionId: sectionId, index: index, text: .plain(emojiStatusInfo), data: .init(color: theme.colors.listGrayText, viewType: .textBottomItem)))
    index += 1
    

    switch arguments.source {
    case .group:
        entries.append(.sectionId(sectionId, type: .normal))
        sectionId += 1
        
        let title: String = strings().selectColorEmojiPackGroup
        let emojiPackInfo: String = strings().selectColorEmojiPackInfoGroup
        
        let statusType: GeneralInteractedType
        if let icon = state.icon_emojiPack {
            statusType = .imageContext(icon, "")
        } else {
            statusType = .nextContext("")
        }
        
        entries.append(.general(sectionId: sectionId, index: index, value: .none, error: nil, identifier: _id_emoji_pack, data: .init(name: title, color: theme.colors.text, icon: nil, type: statusType, viewType: .singleItem, enabled: true, action: {
            arguments.showEmojiPack()
        }, afterNameImage: afterNameImage_EmojiPack)))
        entries.append(.desc(sectionId: sectionId, index: index, text: .plain(emojiPackInfo), data: .init(color: theme.colors.listGrayText, viewType: .textBottomItem)))
        index += 1
    default:
        break
    }
    
    entries.append(.sectionId(sectionId, type: .normal))
    sectionId += 1
    
    switch arguments.source {
    case .group:
        
        let title: String
        let info: String
        switch arguments.source {
        case .channel:
            title = strings().selectColorChannelWallpaper
            info = strings().selectColorChannelWallpaperInfo
        case .group:
            title = strings().selectColorGroupWallpaper
            info = strings().selectColorGroupWallpaperInfo
        default:
            fatalError()
        }
        
        entries.append(.general(sectionId: sectionId, index: index, value: .none, error: nil, identifier: _id_wallpaper, data: .init(name: title, color: theme.colors.text, icon: nil, type: .next, viewType: .singleItem, enabled: true, action: {
            arguments.showChannelWallpaper()
        }, afterNameImage: afterNameImage_WallpaperIcon)))
        
        entries.append(.desc(sectionId: sectionId, index: index, text: .plain(info), data: .init(color: theme.colors.listGrayText, viewType: .textBottomItem)))
        index += 1
        
        entries.append(.sectionId(sectionId, type: .normal))
        sectionId += 1
    default:
        break
    }
    
    switch arguments.source {
    case .account:
        if !state.wearable.isEmpty {
           
            entries.append(.desc(sectionId: sectionId, index: index, text: .plain(strings().selectColorUseGiftTitle), data: .init(color: theme.colors.listGrayText, viewType: .textTopItem)))
            index += 1
            
            let selected = state.wearable.first(where: { $0.starGift.file?.fileId.id == state.peer._asPeer().emojiStatus?.fileId })?.starGift
            
            let chunks = state.wearable.chunks(3)
            
            struct Tuple : Equatable {
                let chunk: [RecentStarGiftItem]
                let viewType: GeneralViewType
                let selected: StarGift.UniqueGift?
            }
            
            var tupls: [Tuple] = []
            
            for (i, chunk) in chunks.enumerated() {
                tupls.append(.init(chunk: chunk, viewType: .innerItem, selected: selected))
            }
            
            entries.append(.custom(sectionId: sectionId, index: index, value: .none, identifier: .init("_s_\(-1)"), equatable: nil, comparable: nil, item: { initialSize, stableId in
                return GeneralRowItem(initialSize, height: 20, stableId: stableId, viewType: .firstItem, drawCustomSeparator: false, backgroundColor: theme.colors.background, containable: true)
            }))
            
            for (i, tuple) in tupls.enumerated() {
                entries.append(.custom(sectionId: sectionId, index: index, value: .none, identifier: _id_stars_gifts(i), equatable: .init(tuple), comparable: nil, item: { initialSize, stableId in
                    return GiftOptionsRowItem(initialSize, stableId: stableId, context: arguments.context, options: tuple.chunk.map { .initialize($0.starGift) }, perRowCount: 3, fitToSize: true, viewType: tuple.viewType, callback: { option in
                        if let gift = option.gift {
                            arguments.wearCollectible(gift)
                        }
                    }, selected: selected.flatMap { .unique($0) })
                }))
                if i != tupls.count - 1 {
                    entries.append(.custom(sectionId: sectionId, index: index, value: .none, identifier: .init("_s_\(i)"), equatable: nil, comparable: nil, item: { initialSize, stableId in
                        return GeneralRowItem(initialSize, height: 20, stableId: stableId, viewType: .innerItem, drawCustomSeparator: false, backgroundColor: theme.colors.background, containable: true)
                    }))
                }
            }
            
            entries.append(.custom(sectionId: sectionId, index: index, value: .none, identifier: .init("_s_\(1000)"), equatable: nil, comparable: nil, item: { initialSize, stableId in
                return GeneralRowItem(initialSize, height: 20, stableId: stableId, viewType: .lastItem, drawCustomSeparator: false, backgroundColor: theme.colors.background, containable: true)
            }))
            
            entries.append(.desc(sectionId: sectionId, index: index, text: .plain(strings().selectColorUseGiftInfo), data: .init(color: theme.colors.listGrayText, viewType: .textBottomItem)))
            index += 1


            entries.append(.sectionId(sectionId, type: .customModern(10)))
            sectionId += 1
            
        }
    default:
        break
    }
    
    return entries
}

enum SelectColorType {
    case name
    case profile
}

enum SelectColorSource {
    case account(Peer)
    case channel(Peer)
    case group(Peer)
    
    var isGroup: Bool {
        switch self {
        case .group:
            return true
        default:
            return false
        }
    }

    var peerId: PeerId {
        switch self {
        case .account(let peer):
            return peer.id
        case .channel(let peer):
            return peer.id
        case .group(let peer):
            return peer.id
        }
    }
    var peer: Peer {
        switch self {
        case .account(let peer):
            return peer
        case .channel(let peer):
            return peer
        case .group(let peer):
            return peer
        }
    }
    
    func nameColor(_ type: SelectColorType) -> PeerNameColor? {
        switch type {
        case .name:
            return peer.nameColor
        case .profile:
            return peer.profileColor

        }
    }
    func backgroundIcon(_ type: SelectColorType) -> Int64? {
        switch type {
        case .name:
            return peer.backgroundEmojiId
        case .profile:
            return peer.profileBackgroundEmojiId
        }
    }
}

final class SelectColorCallback {
    var getState:(()->(PeerNameColor?, Int64?))? = nil
    var validate:(()->Void)? = nil
    init() {
        
    }
}

func SelectColorController(context: AccountContext, peer: Peer, callback: SelectColorCallback? = nil) -> InputDataController {

    let source: SelectColorSource
    if peer.isGroup || peer.isSupergroup {
        source = .group(peer)
    } else if peer.isChannel {
        source = .channel(peer)
    } else {
        source = .account(peer)
    }
    
    let actionsDisposable = DisposableSet()

    let initialState = State(peer: .init(source.peer), selected: source.nameColor(.name), selected_profile: source.nameColor(.profile), backgroundEmojiId: source.backgroundIcon(.name), backgroundEmojiId_profile: source.backgroundIcon(.profile), emojiStatus: source.peer.emojiStatus, theme: theme.withUpdatedEmoticonThemes(context.emoticonThemes))
    
    
    
    
    let statePromise = ValuePromise(initialState, ignoreRepeated: true)
    let stateValue = Atomic(value: initialState)
    let updateState: ((State) -> State) -> Void = { f in
        statePromise.set(stateValue.modify (f))
    }
    
    actionsDisposable.add(context.engine.data.subscribe(TelegramEngine.EngineData.Item.Peer.Peer(id: peer.id)).start(next: { peer in
        updateState { current in
            var current = current
            if let peer {
                current.peer = peer
                current.emojiStatus = peer.emojiStatus
                current.selected_profile = peer.profileColor
                current.selected = peer.nameColor
                current.backgroundEmojiId_profile = peer.profileBackgroundEmojiId
                current.backgroundEmojiId = peer.backgroundEmojiId
            }
            return current
        }
    }))
    
    let isGroup: Bool
    switch source {
    case .group:
        isGroup = true
    default:
        isGroup = false
    }
    
    callback?.getState = {
        return stateValue.with { ($0.selected, $0.backgroundEmojiId) }
    }
    

    let peerId: PeerId = source.peerId
    
    let getColor:(PeerNameColor, SelectColorType)->PeerNameColors.Colors = { color ,type in
        switch type {
        case .name:
            return  context.peerNameColors.get(color)
        case .profile:
            return  context.peerNameColors.getProfile(color)
        }
    }
    func backgroundIcon(_ type: SelectColorType) -> Int64? {
        switch type {
        case .name:
            return stateValue.with { $0.backgroundEmojiId }
        case .profile:
            return stateValue.with { $0.backgroundEmojiId_profile }
        }
    }
    
    let cachedData = getCachedDataView(peerId: peerId, postbox: context.account.postbox)
    |> map { $0 as? CachedChannelData }
    |> map { $0 }
    |> take(1)
    
    
    actionsDisposable.add(cachedData.start(next: { cachedData in
        let wallpaper = cachedData?.wallpaper
        let emojiPack = cachedData?.emojiPack

        updateState { current in
            var current = current
            if let wallpaper = wallpaper {
                current.theme = current.theme.withUpdatedWallpaper(.init(wallpaper: .init(wallpaper), associated: nil))
            } else {
                current.theme = current.theme.withUpdatedWallpaper(theme.wallpaper)
            }
            current.wallpaper = wallpaper
            current.actualWallpaper = wallpaper
            current.emojiPack = emojiPack
            current.actualEmojiPack = emojiPack
            return current
        }
    }))
    
    
    switch source {
    case let .account(peer):
        let signal = context.account.postbox.itemCollectionsView(orderedItemListCollectionIds: [Namespaces.OrderedItemList.CloudUniqueStarGifts], namespaces: [Namespaces.ItemCollection.CloudEmojiPacks], aroundIndex: nil, count: 100)
        actionsDisposable.add(signal.start(next: { view in
            for listView in view.orderedItemListsViews {
                if listView.collectionId == Namespaces.OrderedItemList.CloudUniqueStarGifts {
                    var items: [RecentStarGiftItem] = []
                    for item in listView.items {
                        guard let item = item.contents.get(RecentStarGiftItem.self) else {
                            continue
                        }
                        items.append(item)
                    }
                    
                    updateState { current in
                        var current = current
                        current.wearable = items
                        return current
                    }
                }
            }
        }))
    default:
        break
    }
    
    var backgroundEmojiId: Int64? = nil
    var color: PeerNameColor?
    var layer: InlineStickerItemLayer?
    actionsDisposable.add(statePromise.get().start(next: { state in
        if state.backgroundEmojiId != backgroundEmojiId || state.selected != color {
            DispatchQueue.main.async {
                if let emojiId = state.backgroundEmojiId {
                    
                    let color: NSColor
                    if let selected = state.selected {
                        color = getColor(selected, .name).main
                    } else {
                        color = theme.colors.text
                    }
                    layer = InlineStickerItemLayer(account: context.account, inlinePacksContext: context.inlinePacksContext, emoji: .init(fileId: emojiId, file: nil, emoji: clown), size: NSMakeSize(25, 25), playPolicy: .framesCount(1), textColor: color)
                    layer?.isPlayable = true
                    
                    layer?.contentDidUpdate = { image in
                        updateState { current in
                            var current = current
                            current.icon = image
                            return current
                        }
                    }

                } else {
                    layer = nil
                    updateState { current in
                        var current = current
                        current.icon = nil
                        return current
                    }
                }
            }
        }
        backgroundEmojiId = state.backgroundEmojiId
        color = state.selected
    }))
    
    var backgroundEmojiId_profile: Int64? = nil
    var color_profile: PeerNameColor?
    var layer_profile: InlineStickerItemLayer?
    actionsDisposable.add(statePromise.get().start(next: { state in
        if state.backgroundEmojiId_profile != backgroundEmojiId_profile || state.selected_profile != color_profile {
            DispatchQueue.main.async {
                if let emojiId = state.backgroundEmojiId_profile {
                    
                    let color: NSColor
                    if let selected = state.selected_profile {
                        color = getColor(selected, .profile).main
                    } else {
                        color = theme.colors.text
                    }
                    layer_profile = InlineStickerItemLayer(account: context.account, inlinePacksContext: context.inlinePacksContext, emoji: .init(fileId: emojiId, file: nil, emoji: clown), size: NSMakeSize(25, 25), playPolicy: .framesCount(1), textColor: color)
                    layer_profile?.isPlayable = true
                    
                    layer_profile?.contentDidUpdate = { image in
                        updateState { current in
                            var current = current
                            current.icon_profile = image
                            return current
                        }
                    }

                } else {
                    layer_profile = nil
                    updateState { current in
                        var current = current
                        current.icon_profile = nil
                        return current
                    }
                }
            }
        }
        backgroundEmojiId_profile = state.backgroundEmojiId_profile
        color_profile = state.selected_profile
    }))
    
    var emojiStatus: PeerEmojiStatus?
    var emoji_statusLayer: InlineStickerItemLayer?
    actionsDisposable.add(statePromise.get().start(next: { state in
        if state.emojiStatus != emojiStatus  {
            DispatchQueue.main.async {
                if let emojiId = state.emojiStatus?.fileId {
                    
                    emoji_statusLayer = InlineStickerItemLayer(account: context.account, inlinePacksContext: context.inlinePacksContext, emoji: .init(fileId: emojiId, file: nil, emoji: clown), size: NSMakeSize(25, 25), playPolicy: .framesCount(1), textColor: theme.colors.accent)
                    emoji_statusLayer?.isPlayable = true
                    
                    emoji_statusLayer?.contentDidUpdate = { image in
                        updateState { current in
                            var current = current
                            current.icon_emojiStatus = image
                            return current
                        }
                    }

                } else {
                    emoji_statusLayer = nil
                    updateState { current in
                        var current = current
                        current.icon_emojiStatus = nil
                        return current
                    }
                }
            }
        }
        emojiStatus = state.emojiStatus
    }))
    
    
    var emojiPack_Layer: InlineStickerItemLayer?
    
    let emojiPack: Signal<(StickerPackCollectionInfo, StickerPackItem)?, NoError> = statePromise.get() |> map { $0.emojiPack } |> distinctUntilChanged |> mapToSignal { info in
        if let info = info {
            return context.engine.stickers.loadedStickerPack(reference: StickerPackReference.id(id: info.id.id, accessHash: info.accessHash), forceActualized: false) |> mapToSignal { result in
                switch result {
                case let .result(info, items, _):
                    if let item = items.first {
                        return .single((info._parse(), item))
                    } else {
                        return .single(nil)
                    }
                default:
                    return .complete()
                }
            }
        } else {
            return .single(nil)
        }
    }
    
    actionsDisposable.add(emojiPack.start(next: { info in
        DispatchQueue.main.async {
            if let item = info?.1 {
                emojiPack_Layer = InlineStickerItemLayer(account: context.account, file: item.file._parse(), size: NSMakeSize(25, 25), playPolicy: .framesCount(1), textColor: theme.colors.accent)
                emojiPack_Layer?.isPlayable = true
                
                emojiPack_Layer?.contentDidUpdate = { image in
                    updateState { current in
                        var current = current
                        current.icon_emojiPack = image
                        return current
                    }
                }
            } else {
                emojiPack_Layer = nil
                updateState { current in
                    var current = current
                    current.icon_emojiPack = nil
                    return current
                }
            }
        }
    }))
    
    let subscribers = context.engine.data.get(TelegramEngine.EngineData.Item.Peer.ParticipantCount(id: source.peerId))
    
    actionsDisposable.add(subscribers.start(next: { value in
        updateState { current in
            var current = current
            current.subscribers = value
            return current
        }
    }))

    let boostStatus = combineLatest(context.engine.peers.getChannelBoostStatus(peerId: peerId), context.engine.peers.getMyBoostStatus())
    
    actionsDisposable.add(boostStatus.startStandalone(next: { stats, myStatus in
        updateState { current in
            var current = current
            current.status = stats
            current.myStatus = myStatus
            return current
        }
    }))
    

    var getControl:((SelectColorType?)->Control?)? = nil
    
    
    var close:(()->Void)? = nil

    let arguments = Arguments(context: context, source: source, toggleColor: { value, type in
        updateState { current in
            var current = current
            switch type {
            case .name:
                current.selected = value
            case .profile:
                current.selected_profile = value
            }
            return current
        }
    }, showEmojiPanel: { type in
        
        let selectedBg: EmojiesSectionRowItem.SelectedItem? = backgroundIcon(type).flatMap {
            .init(source: .custom($0), type: .normal)
        }
        let nameColor: PeerNameColor? = stateValue.with { state in
            return type == .name ? state.selected : state.selected_profile
        }
        let colors: PeerNameColors.Colors? = nameColor != nil ? getColor(nameColor!, type) : nil
        let emojis = EmojiesController(context, mode: .backgroundIcon, selectedItems: selectedBg != nil ? [selectedBg!] : [], color: colors?.main ?? theme.colors.text)
        emojis._frameRect = NSMakeRect(0, 0, 350, 300)
        
        let interactions = EntertainmentInteractions(.emoji, peerId: peerId)

        interactions.sendAnimatedEmoji = { [weak emojis] sticker, _, _, _, fromRect in
            
            if sticker.file._parse().mimeType.hasPrefix("bundle") {
                updateState { current in
                    var current = current
                    switch type {
                    case .name:
                        current.backgroundEmojiId = nil
                    case .profile:
                        current.backgroundEmojiId_profile = nil
                    }
                    return current
                }
            } else {
                updateState { current in
                    var current = current
                    switch type {
                    case .name:
                        current.backgroundEmojiId = sticker.file.fileId.id
                    case .profile:
                        current.backgroundEmojiId_profile = sticker.file.fileId.id
                    }
                    return current
                }
            }
            emojis?.closePopover()
        }
        
        emojis.update(with: interactions, chatInteraction: .init(chatLocation: .peer(peerId), context: context))

        if let emojiControl = getControl?(type) {
            showPopover(for: emojiControl, with: emojis)
        }
    }, showEmojiPack: {
        context.bindings.rootNavigation().push(GroupEmojiPackController(context: context, peerId: peerId, selected: stateValue.with { $0.emojiPack }, updated: { info in
            updateState { current in
                var current = current
                current.emojiPack = info
                return current
            }
        }))
    }, removeIcon: { type in
        updateState { current in
            var current = current
            switch type {
            case .name:
                current.backgroundEmojiId = nil
            case .profile:
                current.backgroundEmojiId_profile = nil
            }
            return current
        }
    }, resetColor: { type in
        updateState { current in
            var current = current
            switch type {
            case .name:
                current.selected = current.peer.nameColor
                current.backgroundEmojiId = nil
            case .profile:
                current.selected_profile = nil
                current.backgroundEmojiId_profile = nil
            }
            return current
        }
    }, getColor: getColor, showEmojiStatus: {
        let setStatus:(Control, TelegramUser)->Void = { control, peer in
            let callback:(TelegramMediaFile, StarGift.UniqueGift?, Int32?, CGRect?)->Void = { file, _, timeout, fromRect in
                updateState { current in
                    var current = current
                    current.emojiStatus = .init(content: .emoji(fileId: file.fileId.id), expirationDate: timeout)
                    return current
                }
            }
            if control.popover == nil {
                showPopover(for: control, with: PremiumStatusController(context, callback: callback, peer: peer), edge: .maxY, inset: NSMakePoint(-80, -35), static: true, animationMode: .reveal)
            }
        }
        if let control = getControl?(nil) {
            switch source {
            case let .account(peer):
                setStatus(control, peer as! TelegramUser)
            case let .channel(peer), let .group(peer):
                let selectedBg: EmojiesSectionRowItem.SelectedItem? = stateValue.with { $0.emojiStatus?.fileId }.flatMap {
                    .init(source: .custom($0), type: .normal)
                }
                let emojis = EmojiesController(context, mode: .channelStatus, selectedItems: selectedBg != nil ? [selectedBg!] : [], color: nil)
                emojis._frameRect = NSMakeRect(0, 0, 350, 300)
                
                let interactions = EntertainmentInteractions(.emoji, peerId: peerId)

                interactions.sendAnimatedEmoji = { [weak emojis] sticker, _, _, expirationDate, fromRect in
                    updateState { current in
                        var current = current
                        if sticker.file._parse().mimeType.hasPrefix("bundle") {
                            current.emojiStatus = nil
                        } else {
                            current.emojiStatus = .init(content: .emoji(fileId: sticker.file.fileId.id), expirationDate: expirationDate)
                        }
                        return current
                    }
                    emojis?.closePopover()
                }
                
                emojis.update(with: interactions, chatInteraction: .init(chatLocation: .peer(peerId), context: context))
                showPopover(for: control, with: emojis)
            }
        }
    }, showChannelWallpaper: {
        let actual = stateValue.with { $0.actualWallpaper }
        let current = stateValue.with { $0.wallpaper }
        showModal(with: ChannelWallpapersController(context: context, peerId: peerId, isGroup: source.isGroup, boostLevel: stateValue.with { $0.boostLevel }, selected: (actual != current, current), callback: { value in
            
            updateState { current in
                var current = current
                if let value = value {
                    current.theme = current.theme.withUpdatedWallpaper(.init(wallpaper: .init(value), associated: nil))
                } else {
                    current.theme = current.theme.withUpdatedWallpaper(theme.wallpaper)
                }
                current.wallpaper = value
                return current
            }
            
        }), for: context.window)
    }, boost: {
        let status = stateValue.with { $0.status }
        let myBoost = stateValue.with { $0.myStatus }
        if let status = status {
            showModal(with: BoostChannelModalController(context: context, peer: source.peer, boosts: status, myStatus: myBoost, infoOnly: true), for: context.window)
        }
    }, wearCollectible: { gift in
        if let unique = gift.unique {
            _ = context.engine.accountData.setStarGiftStatus(starGift: unique, expirationDate: nil).start()
        }
    })
    
    let signal = statePromise.get() |> deliverOnPrepareQueue |> map { state in
        return InputDataSignalValue(entries: entries(state, arguments: arguments))
    }
    

    let controller = InputDataController(dataSignal: signal, title: strings().telegramAppearanceViewController, removeAfterDisappear: false, hasDone: true, doneString: {
        return strings().selectColorApply
    })
    
    controller.onDeinit = {
        actionsDisposable.dispose()
    }
    
    
    
    
    let invoke:()->Void = {
        let state = stateValue.with { $0 }
        
        
        
        let nameColor = state.selected ?? state.peer.nameColor ?? .blue
        let backgroundEmojiId = state.backgroundEmojiId
        let profileColor = state.selected_profile
        let profileBackgroundEmojiId = state.backgroundEmojiId_profile
        let emojiStatus = state.emojiStatus
        
        let wallpaper = state.wallpaper
        let actualWallpaper = state.actualWallpaper
        
        let emojiPack = state.emojiPack
        let actualEmojiPack = state.actualEmojiPack

        
        let request:(@escaping()->Void)->Void = { f in
            
            updateState { current in
                var current = current
                current.saving = true
                return current
            }
            
            var signals:[Signal<Never, NoError>] = []
            
            switch source {
            case .account:
                signals.append(context.engine.accountData.updateNameColorAndEmoji(nameColor: nameColor, backgroundEmojiId: backgroundEmojiId, profileColor: profileColor, profileBackgroundEmojiId: profileBackgroundEmojiId) |> ignoreValues |> `catch` { _ in return Signal<Never, NoError>.complete() })
                
            case .channel, .group:
                signals.append(context.engine.peers.updatePeerNameColorAndEmoji(peerId: peerId, nameColor: nameColor, backgroundEmojiId: backgroundEmojiId, profileColor: profileColor, profileBackgroundEmojiId: profileBackgroundEmojiId) |> ignoreValues |> `catch` { _ in return Signal<Never, NoError>.complete() })
                
                if emojiPack != actualEmojiPack {
                    signals.append(context.engine.peers.updateGroupSpecificEmojiset(peerId: peerId, info: emojiPack) |> ignoreValues |> `catch` { _ in return Signal<Never, NoError>.complete() })
                }
            }
            
            if emojiStatus?.fileId != state.peer.emojiStatus?.fileId {
                signals.append(context.engine.peers.updatePeerEmojiStatus(peerId: peerId, fileId: emojiStatus?.fileId, expirationDate: emojiStatus?.expirationDate) |> ignoreValues |> `catch` { _ in return Signal<Never, NoError>.complete() })
            }
            if wallpaper != actualWallpaper {
                if let wallpaper = wallpaper {
                    switch wallpaper {
                    case let .file(file):
                        let rep: TelegramMediaImageRepresentation = .init(dimensions: file.file.dimensions ?? .init(CGSize(width: 1024, height: 1024)), resource: file.file.resource, progressiveSizes: [], immediateThumbnailData: nil, hasVideo: false, isPersonal: false)
                        
                        context.account.pendingPeerMediaUploadManager.add(peerId: peerId, content: .wallpaper(wallpaper: .image([rep], file.settings), forBoth: false))
                    default:
                        signals.append(context.engine.themes.setChatWallpaper(peerId: peerId, wallpaper: wallpaper, forBoth: false) |> `catch` { _ in return Signal<Never, NoError>.complete() })
                    }
                } else {
                    signals.append(context.engine.themes.setChatWallpaper(peerId: peerId, wallpaper: nil, forBoth: false) |> `catch` { _ in return Signal<Never, NoError>.complete() })
                }
            }
            actionsDisposable.add((combineLatest(signals) |> deliverOnMainQueue).startStandalone(completed: {
                close?()
                f()
            }))
        }
        
        let peer = source.peer
        switch source {
        case .channel, .group:
            let peerId = peer.id
            
            let stats = stateValue.with { $0.status }
            let myStatus = stateValue.with { $0.myStatus }
            
            let nameColorLevel: Int32
            let nameIconLevel: Int32

            let profileColorLevel: Int32
            let profileIconLevel: Int32

            let emojiStatusLevel: Int32
            let emojiPackLevel: Int32

            let wallpaperLevel: Int32
            let customWallpaperLevel: Int32

            
            switch source {
            case .channel:
                
                emojiPackLevel = 0

                
                nameColorLevel = arguments.context.peerNameColors.nameColorsChannelMinRequiredBoostLevel[stateValue.with { $0.selected?.rawValue ?? 0 }] ?? 0
                nameIconLevel = arguments.premiumConfiguration.minChannelNameIconLevel

                profileColorLevel = arguments.context.peerNameColors.nameColorsChannelMinRequiredBoostLevel[stateValue.with { $0.selected_profile?.rawValue ?? 0 }] ?? 0
                profileIconLevel = arguments.premiumConfiguration.minChannelProfileIconLevel

                emojiStatusLevel = arguments.premiumConfiguration.minChannelEmojiStatusLevel
                wallpaperLevel = arguments.premiumConfiguration.minChannelWallpaperLevel
                customWallpaperLevel = arguments.premiumConfiguration.minChannelCustomWallpaperLevel
            case .group:
                nameColorLevel = 0
                nameIconLevel = 0

                profileColorLevel = arguments.context.peerNameColors.nameColorsGroupMinRequiredBoostLevel[stateValue.with { $0.selected_profile?.rawValue ?? 0 }] ?? 0
                profileIconLevel = arguments.premiumConfiguration.minGroupProfileIconLevel

                emojiStatusLevel = arguments.premiumConfiguration.minGroupEmojiStatusLevel
                emojiPackLevel = arguments.premiumConfiguration.minGroupEmojiPackLevel

                wallpaperLevel = arguments.premiumConfiguration.minGroupWallpaperLevel
                customWallpaperLevel = arguments.premiumConfiguration.minGroupCustomWallpaperLevel
            default:
                fatalError()
            }

            if let stats = stats {
                if wallpaper != actualWallpaper {
                    if let wallpaper = wallpaper {
                        switch wallpaper {
                        case .emoticon:
                            if stats.level < wallpaperLevel {
                                showModal(with: BoostChannelModalController(context: context, peer: peer, boosts: stats, myStatus: myStatus, infoOnly: true, source: .wallpaper(wallpaperLevel)), for: context.window)
                                return
                            }
                        default:
                            if stats.level < customWallpaperLevel {
                                showModal(with: BoostChannelModalController(context: context, peer: peer, boosts: stats, myStatus: myStatus, infoOnly: true, source: .wallpaper(customWallpaperLevel)), for: context.window)
                                return
                            }
                        }
                    }
                }
                
                if stats.level < nameColorLevel, nameColor != peer.nameColor {
                    showModal(with: BoostChannelModalController(context: context, peer: peer, boosts: stats, myStatus: myStatus, infoOnly: true, source: .nameColor(nameColorLevel)), for: context.window)
                } else if stats.level < nameIconLevel, backgroundEmojiId != peer.backgroundEmojiId {
                    showModal(with: BoostChannelModalController(context: context, peer: peer, boosts: stats, myStatus: myStatus, infoOnly: true, source: .nameIcon(nameIconLevel)), for: context.window)
                } else if stats.level < profileColorLevel, profileColor != peer.profileColor {
                    showModal(with: BoostChannelModalController(context: context, peer: peer, boosts: stats, myStatus: myStatus, infoOnly: true, source: .profileColor(profileColorLevel)), for: context.window)
                } else if stats.level < profileIconLevel, profileBackgroundEmojiId != peer.profileBackgroundEmojiId {
                    showModal(with: BoostChannelModalController(context: context, peer: peer, boosts: stats, myStatus: myStatus, infoOnly: true, source: .profileIcon(profileIconLevel)), for: context.window)
                } else if stats.level < emojiStatusLevel, emojiStatus?.fileId != peer.emojiStatus?.fileId {
                    showModal(with: BoostChannelModalController(context: context, peer: peer, boosts: stats, myStatus: myStatus, infoOnly: true, source: .emojiStatus(emojiStatusLevel)), for: context.window)
                } else if stats.level < emojiPackLevel, emojiPack != actualEmojiPack {
                    showModal(with: BoostChannelModalController(context: context, peer: peer, boosts: stats, myStatus: myStatus, infoOnly: true, source: .emojiPack(emojiStatusLevel)), for: context.window)
                } else {
                    request({
                        let text: String
                        if isGroup {
                            text = strings().selectColorSuccessAppearanceGroup
                        } else {
                            text = strings().selectColorSuccessAppearanceChannel
                        }
                        showModalText(for: context.window, text: text)
                    })
                }
            }
        case .account:
            if context.isPremium {
                request({
                    showModalText(for: context.window, text: strings().selectColorSuccessAppearanceUser)

                })
            } else {
                showModalText(for: context.window, text: strings().selectColorPremium, callback: { _ in
                    prem(with: PremiumBoardingController(context: context), for: context.window)
                })
            }
        }
    }
    
    controller.validateData = { _ in
        invoke()
        return .none
    }
    
    controller.updateDoneValue = { data in
        return { f in
            if stateValue.with({ $0.saving }) {
                f(.loading)
            } else {
                if !stateValue.with ({ $0.isSame(to: source.peer) }) {
                    f(.enabled(strings().selectColorApply))
                } else {
                    f(.disabled(strings().selectColorApply))
                }
            }
        }
    }
    controller.didLoad = { controller, _ in
        getControl = { [weak controller] type in
            let id: InputDataIdentifier
            if let type = type {
                switch type {
                case .name:
                    id = _id_icon
                case .profile:
                    id = _id_icon_profile
                }
            } else {
                id = _id_emoji_status
            }
            
            let view = controller?.tableView.item(stableId: InputDataEntryId.general(id))?.view as? GeneralInteractedRowView
            return view?.textView
        }
    }
   
    close = {
        updateState { current in
            var current = current
            current.saving = false
            return current
        }
        context.bindings.rootNavigation().back()
    }
    
    return controller
    
}

