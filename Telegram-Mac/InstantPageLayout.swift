//
//  InstantPageLayout.swift
//  Telegram
//
//  Created by keepcoder on 10/08/2017.
//  Copyright © 2017 Telegram. All rights reserved.
//

import Cocoa
import TelegramCoreMac
import PostboxMac
import TGUIKit

final class InstantPageLayout {
    let origin: CGPoint
    let contentSize: CGSize
    let items: [InstantPageItem]
    
    init(origin: CGPoint, contentSize: CGSize, items: [InstantPageItem]) {
        self.origin = origin
        self.contentSize = contentSize
        self.items = items
    }
    
    func items(in rect: NSRect) -> [InstantPageItem] {
        return items.filter{rect.intersects($0.frame)}
    }
    
    func flattenedItemsWithOrigin(_ origin: CGPoint) -> [InstantPageItem] {
        return self.items.map({ item in
            var _item = item
            _item.frame = item.frame.offsetBy(dx: origin.x, dy: origin.y)
            return _item
        })
    }
}

func layoutInstantPageBlock(_ block: InstantPageBlock, boundingWidth: CGFloat, horizontalInset: CGFloat, isCover: Bool, fillToWidthAndHeight: Bool, horizontalInsetBetweenMaxWidth: CGFloat, presentation: InstantViewAppearance, media: [MediaId: Media], mediaIndexCounter: inout Int, overlay: Bool, openChannel:@escaping(TelegramChannel)->Void, joinChannel:@escaping(TelegramChannel)->Void) -> InstantPageLayout {

    
    switch block {
    case let .cover(block):
        return layoutInstantPageBlock(block, boundingWidth: boundingWidth, horizontalInset: horizontalInset, isCover: true, fillToWidthAndHeight: fillToWidthAndHeight, horizontalInsetBetweenMaxWidth: horizontalInsetBetweenMaxWidth, presentation: presentation, media: media, mediaIndexCounter: &mediaIndexCounter, overlay: overlay, openChannel: openChannel, joinChannel: joinChannel)
    case let .title(text):
        let styleStack = InstantPageTextStyleStack()
        styleStack.push(.fontSize(28.0))
        styleStack.push(.fontSerif(true))
        styleStack.push(.lineSpacingFactor(0.685))
        let item = layoutTextItemWithString(attributedStringForRichText(text, styleStack: styleStack), boundingWidth: boundingWidth - horizontalInset * 2.0)
        item.frame = item.frame.offsetBy(dx: horizontalInset, dy: 0.0)
        return InstantPageLayout(origin: CGPoint(), contentSize: item.frame.size, items: [item])
    case let .subtitle(text):
        let styleStack = InstantPageTextStyleStack()
        styleStack.push(.fontSize(17.0))
        let item = layoutTextItemWithString(attributedStringForRichText(text, styleStack: styleStack), boundingWidth: boundingWidth - horizontalInset * 2.0)
        item.frame = item.frame.offsetBy(dx: horizontalInset, dy: 0.0)
        return InstantPageLayout(origin: CGPoint(), contentSize: item.frame.size, items: [item])
    case let .header(text):
        let styleStack = InstantPageTextStyleStack()
        styleStack.push(.fontSize(24.0))
        styleStack.push(.fontSerif(true))
        styleStack.push(.lineSpacingFactor(0.685))
        let item = layoutTextItemWithString(attributedStringForRichText(text, styleStack: styleStack), boundingWidth: boundingWidth - horizontalInset * 2.0)
        item.frame = item.frame.offsetBy(dx: horizontalInset, dy: 0.0)
        return InstantPageLayout(origin: CGPoint(), contentSize: item.frame.size, items: [item])
    case let .subheader(text):
        let styleStack = InstantPageTextStyleStack()
        styleStack.push(.fontSize(19.0))
        styleStack.push(.fontSerif(true))
        styleStack.push(.lineSpacingFactor(0.685))
        let item = layoutTextItemWithString(attributedStringForRichText(text, styleStack: styleStack), boundingWidth: boundingWidth - horizontalInset * 2.0)
        item.frame = item.frame.offsetBy(dx: horizontalInset, dy: 0.0)
        return InstantPageLayout(origin: CGPoint(), contentSize: item.frame.size, items: [item])
    case let .paragraph(text):
        let styleStack = InstantPageTextStyleStack()
        styleStack.push(.fontSize(17.0))
        if presentation.fontSerif {
            styleStack.push(.fontSerif(true))
        }
        let item = layoutTextItemWithString(attributedStringForRichText(text, styleStack: styleStack), boundingWidth: boundingWidth - horizontalInset * 2.0)
        item.frame = item.frame.offsetBy(dx: horizontalInset, dy: 0.0)
        return InstantPageLayout(origin: CGPoint(), contentSize: item.frame.size, items: [item])
    case let .preformatted(text):
        let styleStack = InstantPageTextStyleStack()
        styleStack.push(.fontSize(16.0))
        styleStack.push(.fontFixed(true))
        
        styleStack.push(.lineSpacingFactor(0.685))
        let backgroundInset: CGFloat = 14.0
        let item = layoutTextItemWithString(attributedStringForRichText(text, styleStack: styleStack), boundingWidth: boundingWidth - horizontalInset * 2.0 - backgroundInset * 2.0)
        item.frame = item.frame.offsetBy(dx: horizontalInset, dy: backgroundInset)
        let backgroundItem = InstantPageShapeItem(frame: CGRect(origin: CGPoint(), size: CGSize(width: boundingWidth, height: item.frame.height + backgroundInset * 2.0)), shapeFrame: CGRect(origin: CGPoint(), size: CGSize(width: boundingWidth, height: item.frame.height + backgroundInset * 2.0)), shape: .rect, color: theme.colors.grayBackground)
        return InstantPageLayout(origin: CGPoint(), contentSize: backgroundItem.frame.size, items: [backgroundItem, item])
    case let .authorDate(author: author, date: date):
        let styleStack = InstantPageTextStyleStack()
        styleStack.push(.fontSize(15.0))
        if presentation.fontSerif {
            styleStack.push(.fontSerif(true))
        }
        styleStack.push(.textColor(theme.colors.grayText))
        
        var text: RichText?
        if case .empty = author {
            if date != 0 {
                let dateStringPlain = DateFormatter.localizedString(from: Date(timeIntervalSince1970: Double(date)), dateStyle: .long, timeStyle: .none)
                text = RichText.plain(dateStringPlain)
            }
        } else {
            let dateStringPlain = DateFormatter.localizedString(from: Date(timeIntervalSince1970: Double(date)), dateStyle: .long, timeStyle: .none)
            let dateText = RichText.plain(dateStringPlain)
            
            if date != 0 {
                let formatString = _NSLocalizedString("InstantPage.AuthorAndDateTitle")
                let authorRange = formatString.range(of: "%1$@")!
                let dateRange = formatString.range(of: "%2$@")!
                
                if authorRange.lowerBound < dateRange.lowerBound {
                    let byPart = formatString.substring(to: authorRange.lowerBound)
                    let middlePart = formatString.substring(with: authorRange.upperBound ..< dateRange.lowerBound)
                    let endPart = formatString.substring(from: dateRange.upperBound)
                    
                    text = .concat([.plain(byPart), author, .plain(middlePart), dateText, .plain(endPart)])
                } else {
                    let beforePart = formatString.substring(to: dateRange.lowerBound)
                    let middlePart = formatString.substring(with: dateRange.upperBound ..< authorRange.lowerBound)
                    let endPart = formatString.substring(from: authorRange.upperBound)
                    
                    text = .concat([.plain(beforePart), dateText, .plain(middlePart), author, .plain(endPart)])
                }
            } else {
                text = author
            }
        }
        if let text = text {
            let item = layoutTextItemWithString(attributedStringForRichText(text, styleStack: styleStack), boundingWidth: boundingWidth - horizontalInset * 2.0)
            item.frame = item.frame.offsetBy(dx: horizontalInset, dy: 0.0)
            return InstantPageLayout(origin: CGPoint(), contentSize: item.frame.size, items: [item])
        } else {
            return InstantPageLayout(origin: CGPoint(), contentSize: CGSize(), items: [])
        }
    case let .image(id, caption):
        if let image = media[id] as? TelegramMediaImage, let largest = largestImageRepresentation(image.representations) {
            let imageSize = largest.dimensions
            var filledSize = imageSize.fit(CGSize(width: boundingWidth, height: 600.0))
            
            if fillToWidthAndHeight {
                filledSize = CGSize(width: boundingWidth - horizontalInsetBetweenMaxWidth * 2, height: boundingWidth - horizontalInsetBetweenMaxWidth * 2);
            } else if isCover {
                filledSize = imageSize.aspectFilled(CGSize(width: boundingWidth - horizontalInsetBetweenMaxWidth * 2, height: 1.0))
                
                if filledSize.height > .ulpOfOne {
                    let maxSize = CGSize(width: boundingWidth - horizontalInsetBetweenMaxWidth * 2, height: floor((boundingWidth - horizontalInsetBetweenMaxWidth * 2) * 3.0 / 5.0))
                        filledSize = CGSize(width: min(filledSize.width, maxSize.width), height: min(filledSize.height, maxSize.height))
                }
            }
            
            let mediaIndex = mediaIndexCounter
            mediaIndexCounter += 1
            
            var items:[InstantPageItem] = []
            
            var contentSize: NSSize = NSMakeSize(boundingWidth, 0.0)
            
            contentSize.height += filledSize.height
            
            let mediaItem = InstantPageMediaItem(frame: CGRect(origin: CGPoint(x: floor((boundingWidth - filledSize.width) / 2.0), y: 0.0), size: filledSize), media: InstantPageMedia(index: mediaIndex, media: image, caption: richPlainText(caption)), arguments: InstantPageMediaArguments.image(interactive: true, roundCorners: false, fit: false))
            
            items.append(mediaItem)
            
            var hasCaption: Bool = true
            if case .empty = caption {
                hasCaption = false
            }
            
            if hasCaption {
                contentSize.height += 10
                
                let styleStack = InstantPageTextStyleStack()
                styleStack.push(.fontSize(15.0))
                styleStack.push(.textColor(theme.colors.grayText))
                if presentation.fontSerif {
                    styleStack.push(.fontSerif(true))
                }
                let captionItem = layoutTextItemWithString(attributedStringForRichText(caption, styleStack: styleStack), boundingWidth: boundingWidth - horizontalInset * 2.0)
                captionItem.alignment = .center
                if filledSize.width > boundingWidth - .ulpOfOne {
                    captionItem.frame = captionItem.frame.offsetBy(dx: horizontalInset, dy: contentSize.height)
                } else {
                    captionItem.frame = captionItem.frame.offsetBy(dx: floorToScreenPixels(scaleFactor: System.backingScale, (boundingWidth - captionItem.frame.size.width) / 2.0), dy: contentSize.height)
                }
                contentSize.height += captionItem.frame.size.height;
                items.append(captionItem)
            }
            
            
            return InstantPageLayout(origin: CGPoint(), contentSize: contentSize, items: items)
        } else {
            return InstantPageLayout(origin: CGPoint(), contentSize: CGSize(), items: [])
        }
    case let .video(id, caption, autoplay, loop):
        
        if let video = media[id] as? TelegramMediaFile {
            let imageSize = video.dimensions ?? CGSize()
            if imageSize.width > .ulpOfOne && imageSize.height > .ulpOfOne {
                var filledSize = imageSize.fit(CGSize(width: boundingWidth, height: 600.0))
                if fillToWidthAndHeight {
                    filledSize = CGSize(width: boundingWidth - horizontalInsetBetweenMaxWidth * 2, height: boundingWidth - horizontalInsetBetweenMaxWidth * 2)
                } else if isCover {
                    filledSize = imageSize.aspectFilled(CGSize(width: boundingWidth - horizontalInsetBetweenMaxWidth * 2, height: 1))
                    if filledSize.height > .ulpOfOne {
                        let maxSize = CGSize(width: boundingWidth - horizontalInsetBetweenMaxWidth * 2, height: floor((boundingWidth - horizontalInsetBetweenMaxWidth * 2) * 3.0 / 5.0))
                        filledSize = CGSize(width: min(filledSize.width, maxSize.width), height: min(filledSize.height, maxSize.height))
                    }
                }
                
                var items:[InstantPageItem] = []
                
                let mediaIndex = mediaIndexCounter
                mediaIndexCounter += 1
                
                var contentSize = CGSize(width: boundingWidth, height: 0)
                
                contentSize.height += filledSize.height
                
                let mediaItem = InstantPageMediaItem(frame: CGRect(origin: CGPoint(x: floor((boundingWidth - filledSize.width) / 2.0), y: 0.0), size: filledSize), media: InstantPageMedia(index: mediaIndex, media: video, caption: richPlainText(caption)), arguments: InstantPageMediaArguments.video(interactive: true, autoplay: autoplay))
                
                items.append(mediaItem)
                
                var hasCaption: Bool = true
                if case .empty = caption {
                    hasCaption = false
                }
                
                if hasCaption {
                    contentSize.height += 10
                    
                    let styleStack = InstantPageTextStyleStack()
                    styleStack.push(.fontSize(15.0))
                    if presentation.fontSerif {
                        styleStack.push(.fontSerif(true))
                    }
                    styleStack.push(.textColor(theme.colors.grayText))
                    
                    let captionItem = layoutTextItemWithString(attributedStringForRichText(caption, styleStack: styleStack), boundingWidth: boundingWidth - horizontalInset * 2.0)
                    captionItem.alignment = .center
                    if filledSize.width > boundingWidth - .ulpOfOne {
                        captionItem.frame = captionItem.frame.offsetBy(dx: horizontalInset, dy: contentSize.height)
                    } else {
                        captionItem.frame = captionItem.frame.offsetBy(dx: floorToScreenPixels(scaleFactor: System.backingScale, (boundingWidth - captionItem.frame.size.width) / 2.0), dy: contentSize.height)
                    }
                    contentSize.height += captionItem.frame.size.height;
                    items.append(captionItem)
                }
                
                
                return InstantPageLayout(origin: CGPoint(), contentSize: contentSize, items: items)
                
            }
        }
        
    case let .webEmbed(url, html, dimensions, caption, stretchToWidth, allowScrolling, coverId):
        var embedBoundingWidth = boundingWidth - horizontalInset * 2.0
        if stretchToWidth {
            embedBoundingWidth = boundingWidth
        }
        let size: CGSize
        if dimensions.width.isLessThanOrEqualTo(0.0) {
            size = CGSize(width: embedBoundingWidth, height: dimensions.height)
        } else {
            size = dimensions.aspectFitted(CGSize(width: embedBoundingWidth, height: embedBoundingWidth))
        }
        let item = InstantPageWebEmbedItem(frame: CGRect(origin: CGPoint(x: floor((boundingWidth - size.width) / 2.0), y: 0.0), size: size), url: url, html: html, enableScrolling: allowScrolling)
        return InstantPageLayout(origin: CGPoint(), contentSize: item.frame.size, items: [item])
    case let .postEmbed(_, _, avatarId, author, date, blocks, caption):
        
        var contentSize = NSMakeSize(boundingWidth, 0.0)
        let lineInset: CGFloat = 20.0
        let verticalInset:CGFloat = 4.0
        let itemSpacing:CGFloat = 10.0
        var avatarInset:CGFloat = 0.0
        var avatarVerticalInset:CGFloat = 0.0
        
        contentSize.height += verticalInset
        
        var items:[InstantPageItem] = []

        if author.length > 0 {
            let avatar: TelegramMediaImage?
            if let avatarId = avatarId {
                avatar = media[avatarId] as? TelegramMediaImage
            } else {
                avatar = nil
            }
            if let avatar = avatar {
                let avatarItem = InstantPageMediaItem(frame: NSMakeRect(horizontalInset + lineInset + 1.0, contentSize.height - 2.0, 50.0, 50.0), media: InstantPageMedia.init(index: -1, media: avatar, caption: richPlainText(caption)), arguments: .image(interactive: false, roundCorners: true, fit: false))
                
                items.append(avatarItem)
                avatarInset += 62.0
                avatarVerticalInset += 6.0
                if date == 0 {
                    avatarVerticalInset += 11.0
                }
            }
            
            let styleStack = InstantPageTextStyleStack()
            styleStack.push(.fontSize(17))
            if presentation.fontSerif {
                styleStack.push(.fontSerif(true))
            }
            styleStack.push(.bold)
            styleStack.push(.textColor(theme.colors.text))
            
            let textItem = layoutTextItemWithString(attributedStringForRichText(.plain(author), styleStack: styleStack), boundingWidth: boundingWidth - horizontalInset * 2.0)
            textItem.frame = textItem.frame.offsetBy(dx: horizontalInset + lineInset + avatarInset, dy: contentSize.height + avatarVerticalInset)
            
            contentSize.height += textItem.frame.size.height + avatarVerticalInset
            items.append(textItem)
        }
        
        if date != 0 {
            if !items.isEmpty {
                contentSize.height += itemSpacing
            }
            let dateString = DateFormatter.localizedString(from: Date(timeIntervalSince1970: TimeInterval(date)), dateStyle: .long, timeStyle: .none)

            let styleStack = InstantPageTextStyleStack()
            styleStack.push(.textColor(theme.colors.grayText))
            styleStack.push(.fontSize(15))
            if presentation.fontSerif {
                styleStack.push(.fontSerif(true))
            }
            
            let textItem = layoutTextItemWithString(attributedStringForRichText(.plain(dateString), styleStack: styleStack), boundingWidth: boundingWidth - horizontalInset * 2.0)
            textItem.frame = textItem.frame.offsetBy(dx: horizontalInset + lineInset + avatarInset, dy: contentSize.height)
            items.append(textItem)
        }
        
        if !items.isEmpty {
            contentSize.height += itemSpacing;
        }
        
        var previous: InstantPageBlock? = nil
        for sub in blocks {
            let subLayout = layoutInstantPageBlock(sub, boundingWidth: boundingWidth - horizontalInset * 2 - lineInset, horizontalInset: 0, isCover: false, fillToWidthAndHeight: false, horizontalInsetBetweenMaxWidth: horizontalInsetBetweenMaxWidth, presentation: presentation, media: media, mediaIndexCounter: &mediaIndexCounter, overlay: overlay, openChannel: openChannel, joinChannel: joinChannel)
            let spacing = spacingBetweenBlocks(upper: previous, lower: sub)
            let subItems = subLayout.flattenedItemsWithOrigin(NSMakePoint(horizontalInset + lineInset, contentSize.height + spacing))
            items.append(contentsOf: subItems)
            contentSize.height += subLayout.contentSize.height + spacing
            previous = sub
        }
        
        contentSize.height += verticalInset;
        
        items.append(InstantPageShapeItem(frame: NSMakeRect(horizontalInset, 0.0, 3.0, contentSize.height), shapeFrame: NSMakeRect(0.0, 0.0, 3.0, contentSize.height), shape: .roundLine, color: theme.colors.text))
        
        var hasCaption: Bool = true
        if case .empty = caption {
            hasCaption = false
        }
        
        if hasCaption {
            contentSize.height += 14.0
            
            let styleStack = InstantPageTextStyleStack()
            styleStack.push(.textColor(theme.colors.grayText))
            styleStack.push(.fontSize(15.0))
            if presentation.fontSerif {
                styleStack.push(.fontSerif(true))
            }
            let captionItem = layoutTextItemWithString(attributedStringForRichText(caption, styleStack: styleStack), boundingWidth: boundingWidth - horizontalInset * 2.0)
            captionItem.frame = captionItem.frame.offsetBy(dx: horizontalInset, dy: contentSize.height)
            contentSize.height += captionItem.frame.size.height
            items.append(captionItem)
        }
        return InstantPageLayout(origin: CGPoint(), contentSize: contentSize, items: items)
    case let .collage(blocks, _):
        
        let spacing: CGFloat = 2
        let itemsPerRow: CGFloat = min(round(boundingWidth / 150), CGFloat(blocks.count))
        let itemSize: CGFloat = floorToScreenPixels(scaleFactor: System.backingScale, (boundingWidth - spacing * max(0, itemsPerRow - 1)) / itemsPerRow)
        
        var items:[InstantPageItem] = []
        var nextItemOrigin: CGPoint = CGPoint()
        for subBlock in blocks {
            if nextItemOrigin.x + itemSize > boundingWidth {
                nextItemOrigin.x = 0.0
                nextItemOrigin.y += itemSize + spacing
            }
            let subLayout = layoutInstantPageBlock(subBlock, boundingWidth: itemSize, horizontalInset: 0, isCover: false, fillToWidthAndHeight: true, horizontalInsetBetweenMaxWidth: horizontalInsetBetweenMaxWidth, presentation: presentation, media: media, mediaIndexCounter: &mediaIndexCounter, overlay: overlay, openChannel: openChannel, joinChannel: joinChannel)
            items.append(contentsOf: subLayout.flattenedItemsWithOrigin(nextItemOrigin))
            nextItemOrigin.x += itemSize + spacing;
        }
        
        
        return InstantPageLayout(origin: CGPoint(), contentSize: CGSize(width: boundingWidth, height: nextItemOrigin.y + itemSize), items: items)
    case .anchor(let anchor):
        return InstantPageLayout(origin: CGPoint(), contentSize: CGSize(), items: [InstantPageAnchorItem(frame: CGRect(), anchor: anchor)])
    case .channelBanner(let channel):
        if let channel = channel {
            let width = boundingWidth - horizontalInsetBetweenMaxWidth * 2
            let item = InstantPageChannelItem(frame: CGRect(x: floorToScreenPixels(scaleFactor: System.backingScale, (boundingWidth - width)/2), y: 0, width: width , height: InstantPageChannelView.height), channel: channel, overlay: overlay, openChannel: openChannel, joinChannel: joinChannel)
            return InstantPageLayout(origin: CGPoint(), contentSize: CGSize(width: boundingWidth, height: item.frame.height), items: [item])
        }
    case .footer(let text):
        let styleStack = InstantPageTextStyleStack()
        styleStack.push(.textColor(theme.colors.grayText))
        styleStack.push(.fontSize(15.0))
        if presentation.fontSerif {
            styleStack.push(.fontSerif(true))
        }
        let item = layoutTextItemWithString(attributedStringForRichText(text, styleStack: styleStack), boundingWidth: boundingWidth - horizontalInset * 2.0)
        item.frame = item.frame.offsetBy(dx: horizontalInset, dy: 0.0)
        return InstantPageLayout(origin: CGPoint(), contentSize: item.frame.size, items: [item])
    case .divider:
        let lineWidth = floorToScreenPixels(scaleFactor: System.backingScale, boundingWidth / 2)
        let shapeItem = InstantPageShapeItem(frame: CGRect(x: floorToScreenPixels(scaleFactor: System.backingScale, (boundingWidth - lineWidth) / 2.0), y: 0.0, width: lineWidth, height: 1.0), shapeFrame: CGRect(x: 0, y: 0, width: lineWidth, height: 1.0), shape: .rect, color: theme.colors.grayText)
        return InstantPageLayout(origin: CGPoint(), contentSize: shapeItem.frame.size, items: [shapeItem])
    case let .list(items, ordered):
        
        var contentSize = CGSize(width: boundingWidth, height: 0)
        var maxIndexWidth:CGFloat = 0.0
        var listItems:[InstantPageItem] = []
        var indexItems:[InstantPageItem] = []
        for i in 0 ..< items.count {
            if ordered {
                let styleStack = InstantPageTextStyleStack()
                styleStack.push(.fontSize(17))
                if presentation.fontSerif {
                    styleStack.push(.fontSerif(true))
                }
                styleStack.push(.textColor(theme.colors.text))
                let textItem = layoutTextItemWithString(attributedStringForRichText(.plain("\(i + 1)."), styleStack: styleStack), boundingWidth: boundingWidth - horizontalInset * 2)
                textItem.frame.size.width = textItem.lines.first!.frame.width
                maxIndexWidth = max(textItem.frame.width, maxIndexWidth);
                indexItems.append(textItem)
            } else {
                let shapeItem = InstantPageShapeItem(frame: CGRect(x: 0.0, y: 0.0, width: 6.0, height: 12.0), shapeFrame: CGRect(x: 0.0, y: 3.0, width: 6.0, height: 6.0), shape: .ellipse, color: theme.colors.text)
                indexItems.append(shapeItem)
            }
        }
        var index: Int = -1
        let indexSpacing: CGFloat = ordered ? 7.0 : 20.0
        for text in items {
            index += 1
            if index != 0 {
                contentSize.height += 20.0
            }
            let styleStack = InstantPageTextStyleStack()
            styleStack.push(.fontSize(17))
            if presentation.fontSerif {
                styleStack.push(.fontSerif(true))
            }
            styleStack.push(.textColor(theme.colors.text))
            
            let textItem = layoutTextItemWithString(attributedStringForRichText(text, styleStack: styleStack), boundingWidth: boundingWidth - horizontalInset * 2 - indexSpacing - maxIndexWidth)
            textItem.frame = textItem.frame.offsetBy(dx: horizontalInset + indexSpacing + maxIndexWidth, dy: contentSize.height)
            contentSize.height += textItem.frame.size.height
            
            var indexItem = indexItems[index]
            var _item = indexItem
            _item.frame = indexItem.frame.offsetBy(dx: horizontalInset, dy: textItem.frame.minY)
            
            listItems.append(_item)
            listItems.append(textItem)
            
        }
        return InstantPageLayout(origin: CGPoint(), contentSize: contentSize, items: listItems)
    case let .blockQuote(text, caption):
        let lineInset: CGFloat = 20.0
        let verticalInset: CGFloat = 4
        var contentSize = CGSize(width: boundingWidth, height: verticalInset)
        var items:[InstantPageItem] = []
        
        let styleStack = InstantPageTextStyleStack()
        styleStack.push(.fontSize(17))
        styleStack.push(.fontSerif(true))
        styleStack.push(.italic)
        styleStack.push(.textColor(theme.colors.text))
        
        let textItem = layoutTextItemWithString(attributedStringForRichText(text, styleStack: styleStack), boundingWidth: boundingWidth - horizontalInset * 2 - lineInset)
        textItem.frame = textItem.frame.offsetBy(dx: horizontalInset + lineInset, dy: contentSize.height)
        
        contentSize.height += textItem.frame.size.height
        items.append(textItem)
        
        
        var hasCaption: Bool = true
        if case .empty = caption {
            hasCaption = false
        }
        
        if hasCaption {
            contentSize.height += 14.0
            
            let styleStack = InstantPageTextStyleStack()
            styleStack.push(.textColor(theme.colors.grayText))
            styleStack.push(.fontSize(15.0))
            if presentation.fontSerif {
                styleStack.push(.fontSerif(true))
            }
            let captionItem = layoutTextItemWithString(attributedStringForRichText(caption, styleStack: styleStack), boundingWidth: boundingWidth - horizontalInset * 2.0)
            captionItem.frame = captionItem.frame.offsetBy(dx: horizontalInset + lineInset, dy: contentSize.height)
            contentSize.height += captionItem.frame.size.height
            items.append(captionItem)
        }
        
        contentSize.height += verticalInset
        items.append(InstantPageShapeItem(frame: CGRect(x: horizontalInset, y: 0, width: 3.0, height: contentSize.height), shapeFrame: CGRect(x: 0.0, y: 0.0, width: 3.0, height: contentSize.height), shape: .roundLine, color: theme.colors.text))
        
        
        return InstantPageLayout(origin: CGPoint(), contentSize: contentSize, items: items)
    case let .pullQuote(text, caption):
        
        let verticalInset: CGFloat = 4.0
        var contentSize = CGSize(width: boundingWidth, height: verticalInset)
        var items:[InstantPageItem] = []
        
        let styleStack = InstantPageTextStyleStack()
        styleStack.push(.fontSize(17))
        styleStack.push(.fontSerif(true))
        styleStack.push(.italic)
        styleStack.push(.textColor(theme.colors.text))
        
        let textItem = layoutTextItemWithString(attributedStringForRichText(text, styleStack: styleStack), boundingWidth: boundingWidth - horizontalInset * 2)
        textItem.frame = textItem.frame.offsetBy(dx: floorToScreenPixels(scaleFactor: System.backingScale, (boundingWidth - textItem.frame.size.width) / 2.0), dy: contentSize.height)
        textItem.alignment = .center
        
        contentSize.height += textItem.frame.size.height
        items.append(textItem)
        
        if true {
            contentSize.height += 14.0
            
            let styleStack = InstantPageTextStyleStack()
            styleStack.push(.textColor(theme.colors.grayText))
            styleStack.push(.fontSize(15.0))
            if presentation.fontSerif {
                styleStack.push(.fontSerif(true))
            }
            let captionItem = layoutTextItemWithString(attributedStringForRichText(caption, styleStack: styleStack), boundingWidth: boundingWidth - horizontalInset * 2.0)
            captionItem.frame = captionItem.frame.offsetBy(dx: floorToScreenPixels(scaleFactor: System.backingScale, (boundingWidth - captionItem.frame.size.width) / 2.0), dy: contentSize.height)
            captionItem.alignment = .center
            contentSize.height += captionItem.frame.size.height
            items.append(captionItem)
        }
        
        contentSize.height += verticalInset
        return InstantPageLayout(origin: CGPoint(), contentSize: contentSize, items: items)
    case let .audio(id, caption):
        var contentSize = CGSize(width: boundingWidth, height: 0.0)
        var items: [InstantPageItem] = []
        
        if let file = media[id] as? TelegramMediaFile {
            let mediaIndex = mediaIndexCounter
            mediaIndexCounter += 1
            let item = InstantPageAudioItem(frame: CGRect(origin: CGPoint(x: horizontalInset, y: 0.0), size: CGSize(width: boundingWidth, height: 48.0)), media: InstantPageMedia(index: mediaIndex, media: file, caption: ""))
            
            contentSize.height += item.frame.size.height
            items.append(item)
            
            if case .empty = caption {
            } else {
                contentSize.height += 10.0
                
                let styleStack = InstantPageTextStyleStack()
                styleStack.push(.textColor(theme.colors.grayText))
                styleStack.push(.fontSize(15.0))
                if presentation.fontSerif {
                    styleStack.push(.fontSerif(true))
                }
                let captionItem = layoutTextItemWithString(attributedStringForRichText(caption, styleStack: styleStack), boundingWidth: boundingWidth - horizontalInset * 2.0)
                captionItem.frame = captionItem.frame.offsetBy(dx: floorToScreenPixels(scaleFactor: System.backingScale, (boundingWidth - captionItem.frame.size.width) / 2.0), dy: contentSize.height)
                captionItem.alignment = .center
                contentSize.height += captionItem.frame.size.height
                items.append(captionItem)
            }
        }
        
        return InstantPageLayout(origin: CGPoint(), contentSize: contentSize, items: items)
    case let .slideshow(blocks, caption):
        
        var medias:[InstantPageMedia] = []
        var contentSize = CGSize(width: boundingWidth, height: 0.0)
        var items:[InstantPageItem] = []
        
        for subBlock in blocks {
            switch subBlock {
            case let .image(id, caption):
                if let photo = media[id] as? TelegramMediaImage, let imageSize = largestImageRepresentation(photo.representations)?.dimensions {
                    let mediaIndex = mediaIndexCounter
                    mediaIndexCounter += 1
                    let filledSize = imageSize.fit(CGSize(width: boundingWidth, height: 600))
                    contentSize.height = min(max(contentSize.height, filledSize.height), boundingWidth)
                    medias.append(InstantPageMedia(index: mediaIndex, media: photo, caption: richPlainText(caption)))
                }
            case let .video(id, caption, _, _):
                if let file = media[id] as? TelegramMediaFile, file.videoSize != NSZeroSize {
                    let mediaIndex = mediaIndexCounter
                    mediaIndexCounter += 1
                    let filledSize = file.videoSize.fit(CGSize(width: boundingWidth, height: 600))
                    contentSize.height = min(max(contentSize.height, filledSize.height), boundingWidth)
                    medias.append(InstantPageMedia(index: mediaIndex, media: file, caption: richPlainText(caption)))
                }
            default:
                break
            }
        }
        
        items.append(InstantPageSlideshowItem(frame: CGRect(x: 0, y: 0, width: boundingWidth, height: contentSize.height), medias: medias))
        
        var hasCaption: Bool = true
        if case .empty = caption {
            hasCaption = false
        }
        
        if hasCaption {
            contentSize.height += 14.0
            
            let styleStack = InstantPageTextStyleStack()
            styleStack.push(.textColor(theme.colors.grayText))
            styleStack.push(.fontSize(15.0))
            if presentation.fontSerif {
                styleStack.push(.fontSerif(true))
            }
            let captionItem = layoutTextItemWithString(attributedStringForRichText(caption, styleStack: styleStack), boundingWidth: boundingWidth - horizontalInset * 2.0)
            captionItem.frame = captionItem.frame.offsetBy(dx: floorToScreenPixels(scaleFactor: System.backingScale, (boundingWidth - captionItem.frame.size.width) / 2.0), dy: contentSize.height)
            captionItem.alignment = .center
            contentSize.height += captionItem.frame.size.height
            items.append(captionItem)
            
        }
        return InstantPageLayout(origin: CGPoint(), contentSize: contentSize, items: items)
    case .unsupported:
        break
    }
    return InstantPageLayout(origin: CGPoint(), contentSize: CGSize(), items: [])
}


func instantPageMedias(for webpage: TelegramMediaWebpage) -> [InstantPageMedia] {
    var medias:[InstantPageMedia] = []
    let layout = instantPageLayoutForWebPage(webpage, boundingWidth: 800, presentation: InstantViewAppearance.defaultSettings, openChannel: {_ in}, joinChannel: {_ in})
    for item in layout.items {
        medias.append(contentsOf: item.medias)
    }
    return medias
}

func instantPageLayoutForWebPage(_ webPage: TelegramMediaWebpage, boundingWidth: CGFloat, presentation: InstantViewAppearance, openChannel:@escaping(TelegramChannel)->Void, joinChannel:@escaping(TelegramChannel)->Void) -> InstantPageLayout {
    var maybeLoadedContent: TelegramMediaWebpageLoadedContent?
    if case let .Loaded(content) = webPage.content {
        maybeLoadedContent = content
    }
    
    guard let loadedContent = maybeLoadedContent, let instantPage = loadedContent.instantPage else {
        return InstantPageLayout(origin: CGPoint(), contentSize: CGSize(), items: [])
    }
    
    let pageBlocks = instantPage.blocks
    var contentSize = CGSize(width: boundingWidth, height: 0.0)
    var items: [InstantPageItem] = []
    
    var media = instantPage.media
    if let image = loadedContent.image, let id = image.id {
        media[id] = image
    }
    
    var mediaIndexCounter: Int = 0
    
    var previousBlock: InstantPageBlock?
    var previousLayout:InstantPageLayout?
    for block in pageBlocks {
        var spacingBetween = spacingBetweenBlocks(upper: previousBlock, lower: block)
        
        if (spacingBetween < -.ulpOfOne) {
            spacingBetween -= (previousLayout?.contentSize.height ?? 0) - (previousLayout?.items.first?.frame.height ?? 0);
        }
        
        let horizontalInsetBetweenMaxWidth = max(0, (boundingWidth - 720)/2)
        
        let blockLayout = layoutInstantPageBlock(block, boundingWidth: boundingWidth, horizontalInset: 40 + horizontalInsetBetweenMaxWidth, isCover: false, fillToWidthAndHeight: false, horizontalInsetBetweenMaxWidth: horizontalInsetBetweenMaxWidth, presentation: presentation, media: media, mediaIndexCounter: &mediaIndexCounter, overlay: spacingBetween < -.ulpOfOne, openChannel: openChannel, joinChannel: joinChannel)
        
       let spacing = blockLayout.contentSize.height > .ulpOfOne ? spacingBetween : 0.0

        let blockItems = blockLayout.flattenedItemsWithOrigin(CGPoint(x: 0.0, y: contentSize.height + spacing))
        items.append(contentsOf: blockItems)
        if CGFloat(0.0).isLess(than: blockLayout.contentSize.height) {
            contentSize.height += spacing > -.ulpOfOne ? blockLayout.contentSize.height + spacing : 0.0
            previousBlock = block
            previousLayout = blockLayout
        }
    }
    
    let closingSpacing = spacingBetweenBlocks(upper: previousBlock, lower: nil)
    contentSize.height += closingSpacing
    
    return InstantPageLayout(origin: CGPoint(), contentSize: contentSize, items: items)
}
