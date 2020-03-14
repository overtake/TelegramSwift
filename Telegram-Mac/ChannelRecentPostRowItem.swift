//
//  ChannelRecentPostRowItem.swift
//  Telegram
//
//  Created by Mikhail Filimonov on 12.03.2020.
//  Copyright © 2020 Telegram. All rights reserved.
//

import Cocoa
import TGUIKit
import Postbox
import SwiftSignalKit
import TelegramCore
import SyncCore

class ChannelRecentPostRowItem: GeneralRowItem {
    fileprivate let viewsCountLayout: TextViewLayout
    fileprivate let sharesCountLayout: TextViewLayout
    fileprivate let titleLayout: TextViewLayout
    fileprivate let dateLayout: TextViewLayout
    fileprivate let message: Message
    fileprivate let contentImageMedia: TelegramMediaImage?
    fileprivate let context: AccountContext
    init(_ initialSize: NSSize, stableId: AnyHashable, context: AccountContext, message: Message, interactions: ChannelStatsMessageInteractions?, viewType: GeneralViewType, action: @escaping()->Void) {
        self.context = context
        self.message = message
        var contentImageMedia: TelegramMediaImage?
        for media in message.media {
            if let image = media as? TelegramMediaImage {
                contentImageMedia = image
                break
            } else if let file = media as? TelegramMediaFile {
                if file.isVideo && !file.isInstantVideo {
                    let iconImageRepresentation:TelegramMediaImageRepresentation? = smallestImageRepresentation(file.previewRepresentations)
                    if let iconImageRepresentation = iconImageRepresentation {
                        contentImageMedia = TelegramMediaImage(imageId: MediaId(namespace: 0, id: 0), representations: [iconImageRepresentation], immediateThumbnailData: nil, reference: nil, partialReference: nil, flags: [])
                    }
                    break
                }
            } else if let webpage = media as? TelegramMediaWebpage, case let .Loaded(content) = webpage.content {
                if let image = content.image {
                    contentImageMedia = image
                    break
                } else if let file = content.file {
                    if file.isVideo && !file.isInstantVideo {
                        let iconImageRepresentation:TelegramMediaImageRepresentation? = smallestImageRepresentation(file.previewRepresentations)
                        if let iconImageRepresentation = iconImageRepresentation {
                            contentImageMedia = TelegramMediaImage(imageId: MediaId(namespace: 0, id: 0), representations: [iconImageRepresentation], immediateThumbnailData: nil, reference: nil, partialReference: nil, flags: [])
                        }
                        break
                    }
                }
            }
        }
        self.contentImageMedia = contentImageMedia
        
        self.titleLayout = TextViewLayout(NSAttributedString.initialize(string: pullText(from: message) as String, color: theme.colors.text, font: .medium(.text)), maximumNumberOfLines: 1)
        self.dateLayout = TextViewLayout(NSAttributedString.initialize(string: stringForFullDate(timestamp: message.timestamp), color: theme.colors.grayText, font: .normal(.text)), maximumNumberOfLines: 1)
        
        
        let views = Int(max(message.channelViewsCount ?? 0, interactions?.views ?? 0))
        let shares = Int(interactions?.forwards ?? 0)
        
        let viewsString = L10n.channelStatsViewsCountCountable(views).replacingOccurrences(of: "\(views)", with: views.formattedWithSeparator)
        let sharesString = L10n.channelStatsSharesCountCountable(shares).replacingOccurrences(of: "\(shares)", with: shares.formattedWithSeparator)

        viewsCountLayout = TextViewLayout(NSAttributedString.initialize(string: viewsString, color: theme.colors.text, font: .normal(.short)),maximumNumberOfLines: 1)
        sharesCountLayout = TextViewLayout(NSAttributedString.initialize(string: sharesString, color: theme.colors.grayText, font: .normal(.short)),maximumNumberOfLines: 1)

        super.init(initialSize, height: 46, stableId: stableId, viewType: viewType, action: action)
    }
    
    override func makeSize(_ width: CGFloat, oldWidth: CGFloat = 0) -> Bool {
        _ = super.makeSize(width, oldWidth: oldWidth)
        
        viewsCountLayout.measure(width: .greatestFiniteMagnitude)
        sharesCountLayout.measure(width: .greatestFiniteMagnitude)
        
        let titleAndDateWidth: CGFloat = blockWidth - viewType.innerInset.left - (contentImageMedia != nil ? 34 + 10 : 0) - max(viewsCountLayout.layoutSize.width, sharesCountLayout.layoutSize.width) - 10 - viewType.innerInset.right

        titleLayout.measure(width: titleAndDateWidth)
        dateLayout.measure(width: titleAndDateWidth)

        return true
    }
    
    override func viewClass() -> AnyClass {
        return ChannelRecentPostRowView.self
    }
}


private final class ChannelRecentPostRowView : GeneralContainableRowView {
    private let viewCountView = TextView()
    private let sharesCountView = TextView()
    private let titleView = TextView()
    private let dateView = TextView()
    private let fetchDisposable = MetaDisposable()
    private var imageView: TransformImageView?
    
    required init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        addSubview(viewCountView)
        addSubview(sharesCountView)
        addSubview(titleView)
        addSubview(dateView)
        
        sharesCountView.userInteractionEnabled = false
        sharesCountView.isSelectable = false
        sharesCountView.isEventLess = true
        
        titleView.userInteractionEnabled = false
        titleView.isSelectable = false
        titleView.isEventLess = true
        
        viewCountView.userInteractionEnabled = false
        viewCountView.isSelectable = false
        viewCountView.isEventLess = true
        
        dateView.userInteractionEnabled = false
        dateView.isSelectable = false
        dateView.isEventLess = true
        
        containerView.set(handler: { [weak self] _ in
            self?.updateColors()
        }, for: .Highlight)
        containerView.set(handler: { [weak self] _ in
            self?.updateColors()
        }, for: .Normal)
        containerView.set(handler: { [weak self] _ in
            self?.updateColors()
        }, for: .Hover)
        
        containerView.set(handler: { [weak self] _ in
            guard let item = self?.item as? ChannelRecentPostRowItem else {
                return
            }
            item.action()
        }, for: .Click)
    }
    
    override func layout() {
        super.layout()
        
        guard let item = item as? ChannelRecentPostRowItem else {
            return
        }
        
        viewCountView.setFrameOrigin(NSMakePoint(item.blockWidth - viewCountView.frame.width - item.viewType.innerInset.right, 5))
        sharesCountView.setFrameOrigin(NSMakePoint(item.blockWidth - sharesCountView.frame.width - item.viewType.innerInset.right, containerView.frame.height - sharesCountView.frame.height - 5))

        let leftOffset: CGFloat = (imageView != nil ? 34 + 10 : 0) + item.viewType.innerInset.left
        
        titleView.setFrameOrigin(NSMakePoint(leftOffset, 5))
        dateView.setFrameOrigin(NSMakePoint(leftOffset, containerView.frame.height - dateView.frame.height - 5))
        
        imageView?.centerY(x: item.viewType.innerInset.left)
    }
    
    override var backdorColor: NSColor {
        return isSelect ? theme.colors.accentSelect : theme.colors.background
    }
    
    override func updateColors() {
        super.updateColors()
        if let item = item as? GeneralRowItem {
            self.background = item.viewType.rowBackground
            let highlighted = isSelect ? self.backdorColor : theme.colors.grayHighlight
            titleView.backgroundColor = containerView.controlState == .Highlight && !isSelect ? .clear : self.backdorColor
            dateView.backgroundColor = containerView.controlState == .Highlight && !isSelect ? .clear : self.backdorColor
            viewCountView.backgroundColor = containerView.controlState == .Highlight && !isSelect ? .clear : self.backdorColor
            sharesCountView.backgroundColor = containerView.controlState == .Highlight && !isSelect ? .clear : self.backdorColor
            containerView.set(background: self.backdorColor, for: .Normal)
            containerView.set(background: highlighted, for: .Highlight)
        }
    }
    
    override func set(item: TableRowItem, animated: Bool = false) {
        super.set(item: item, animated: animated)
        
        guard let item = item as? ChannelRecentPostRowItem else {
            return
        }
        
        viewCountView.update(item.viewsCountLayout)
        sharesCountView.update(item.sharesCountLayout)
        dateView.update(item.dateLayout)
        titleView.update(item.titleLayout)

        
        if let media = item.contentImageMedia {
            if imageView == nil {
                self.imageView = TransformImageView(frame: NSMakeRect(0, 0, 34, 34))
                imageView?.set(arguments: TransformImageArguments(corners: .init(radius: 4), imageSize: NSMakeSize(34, 34), boundingSize: NSMakeSize(34, 34), intrinsicInsets: NSEdgeInsets()))
                addSubview(self.imageView!)
            }
            let updateIconImageSignal = chatWebpageSnippetPhoto(account: item.context.account, imageReference: ImageMediaReference.message(message: MessageReference(item.message), media: media), scale: backingScaleFactor, small:true)
            imageView?.setSignal(updateIconImageSignal)
            
            fetchDisposable.set(chatMessagePhotoInteractiveFetched(account: item.context.account, imageReference: ImageMediaReference.message(message: MessageReference(item.message), media: media)).start())
            
        } else {
            imageView?.removeFromSuperview()
            imageView = nil
            fetchDisposable.set(nil)
        }
    }

    deinit {
        fetchDisposable.dispose()
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}
