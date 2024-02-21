//
//  PeerInfoLocationRowItem.swift
//  Telegram
//
//  Created by Mikhail Filimonov on 20.02.2024.
//  Copyright © 2024 Telegram. All rights reserved.
//

import Foundation
import TelegramCore
import Postbox
import SwiftSignalKit
import TGUIKit

final class PeerInfoLocationRowItem : GeneralRowItem {
    
   
    let context: AccountContext
    let peer: Peer
    let cachedData: CachedUserData
    let addressLayout: TextViewLayout
    let titleLayout: TextViewLayout
    let arguments: TransformImageArguments
    let media: TelegramMediaImage
    let resource: MapSnapshotMediaResource
    let open:()->Void
    init(_ initialSize: NSSize, stableId: AnyHashable, context: AccountContext, peer: Peer, cachedData: CachedUserData, viewType: GeneralViewType, open:@escaping()->Void) {
        self.context = context
        self.peer = peer
        self.open = open
        self.cachedData = cachedData
        //TODOLANG
        self.titleLayout = .init(.initialize(string: "location", color: theme.colors.text, font: .normal(.text)))
        self.addressLayout = .init(.initialize(string: "Unit R201, The Residences at Marina Gate 2, Dubai", color: theme.colors.text, font: .normal(.text)))
        let resource = MapSnapshotMediaResource(latitude: 25.08405406819793, longitude: 55.13948416803165, width: 320 * 2, height: 120 * 2, zoom: 15)

        self.resource = resource
        
        let imageSize = NSMakeSize(50, 50)
        
        let representation = TelegramMediaImageRepresentation(dimensions: PixelDimensions(imageSize), resource: resource, progressiveSizes: [], immediateThumbnailData: nil, hasVideo: false, isPersonal: false)
        
        self.media = TelegramMediaImage(imageId: MediaId(namespace: 0, id: MediaId.Id((resource.latitude * resource.longitude).hashValue)), representations: [representation], immediateThumbnailData: nil, reference: nil, partialReference: nil, flags: [])
        
        self.arguments = TransformImageArguments(corners: ImageCorners(radius: 8), imageSize: imageSize, boundingSize: imageSize, intrinsicInsets: NSEdgeInsets())

        
        
        super.init(initialSize, stableId: stableId, viewType: viewType)
    }
    
    
    
    override func makeSize(_ width: CGFloat, oldWidth: CGFloat = 0) -> Bool {
        _ = super.makeSize(width, oldWidth: oldWidth)
        
        var textWidth: CGFloat = blockWidth
        textWidth -= viewType.innerInset.left * 2
        textWidth -= 50
        textWidth -= 10
        titleLayout.measure(width: textWidth)
        addressLayout.measure(width: textWidth)
        
        return true
    }
    
    override var height: CGFloat {
        return max(viewType.innerInset.top * 2 + 50, viewType.innerInset.top * 2 + titleLayout.layoutSize.height + 6 + addressLayout.layoutSize.height)
    }
    
    override func viewClass() -> AnyClass {
        return PeerInfoLocationRowView.self
    }
}

private final class PeerInfoLocationRowView: GeneralContainableRowView {
    private let title = TextView()
    private let text = TextView()
    private let imageView = TransformImageView()
    required init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        addSubview(title)
        addSubview(text)
        addSubview(imageView)
        imageView.setFrameSize(NSMakeSize(50, 50))
        
        imageView.layer?.cornerRadius = 4
        
        title.userInteractionEnabled = false
        title.isSelectable = false
        
        
        containerView.set(handler: { [weak self] _ in
            if let item = self?.item as? PeerInfoLocationRowItem {
                item.open()
            }
        }, for: .Click)
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override func set(item: TableRowItem, animated: Bool = false) {
        super.set(item: item, animated: animated)
        
        guard let item = item as? PeerInfoLocationRowItem else {
            return
        }
        
        let arguments = item.arguments
        let media = item.media
        
        imageView.setSignal(signal: cachedMedia(media: item.media, arguments: item.arguments, scale: backingScaleFactor, positionFlags: nil), clearInstantly: false)
        
        imageView.setSignal( chatMapSnapshotImage(account: item.context.account, resource: item.resource), clearInstantly: false, animate: false, cacheImage: { result in
            cacheMedia(result, media: media, arguments: arguments, scale: System.backingScale, positionFlags: nil)
        })
        
        imageView.set(arguments: arguments)
        
        title.update(item.titleLayout)
        text.update(item.addressLayout)
    }
    
    override func updateLayout(size: NSSize, transition: ContainedViewLayoutTransition) {
        super.updateLayout(size: size, transition: transition)
        
        guard let item = item as? GeneralRowItem else {
            return
        }
        
        transition.updateFrame(view: title, frame: NSMakeRect(item.viewType.innerInset.left, item.viewType.innerInset.top, title.frame.width, title.frame.height))
        
        transition.updateFrame(view: text, frame: NSMakeRect(item.viewType.innerInset.left, title.frame.maxY + 6, text.frame.width, text.frame.height))
        
        transition.updateFrame(view: imageView, frame: imageView.centerFrameY(x: containerView.frame.width - imageView.frame.width - item.viewType.innerInset.right))

    }
}



final class PeerInfoHoursRowItem : GeneralRowItem {
    
    struct Day {
        let day: TextViewLayout
        let hours: [TextViewLayout]
        init(day: String, hours: [String]) {
            self.day = .init(.initialize(string: day, color: theme.colors.text, font: .normal(.text)), maximumNumberOfLines: 1)
            var list:[TextViewLayout] = []
            for hour in hours {
                list.append(.init(.initialize(string: hour, color: theme.colors.grayText, font: .normal(.text)), maximumNumberOfLines: 1))
            }
            self.hours = list
        }
        
        var height: CGFloat {
            return max(30, CGFloat(hours.count) * 20 + 10)
        }
    }
    
    let days:[Day]
    let context: AccountContext
    let peer: Peer
    let cachedData: CachedUserData
    let titleLayout: TextViewLayout
    let statusLayout: TextViewLayout
    let todayHoursLayout: TextViewLayout
    let revealed: Bool
    let open:()->Void
    init(_ initialSize: NSSize, stableId: AnyHashable, context: AccountContext, revealed: Bool, peer: Peer, cachedData: CachedUserData, viewType: GeneralViewType, open:@escaping()->Void) {
        self.context = context
        self.peer = peer
        self.open = open
        self.cachedData = cachedData
        self.revealed = revealed
        //TODOLANG
        self.titleLayout = .init(.initialize(string: "business hours", color: theme.colors.text, font: .normal(.text)), maximumNumberOfLines: 1)
        self.statusLayout = .init(.initialize(string: "Open", color: theme.colors.greenUI, font: .normal(.text)), maximumNumberOfLines: 1)
        
        self.todayHoursLayout = .init(.initialize(string: "09:00 - 13:00", color: theme.colors.grayText, font: .normal(.text)), maximumNumberOfLines: 1)
        
        var days: [Day] = []
        
        days.append(.init(day: "Monday", hours: ["09:00 - 15:00"]))
        days.append(.init(day: "Tuesday", hours: ["09:00 - 15:00"]))
        days.append(.init(day: "Wednesday", hours: ["09:00 - 15:00"]))
        days.append(.init(day: "Thrusday", hours: ["09:00 - 15:00", "16:00 - 19:00"]))
        days.append(.init(day: "Friday", hours: ["09:00 - 15:00", "16:00 - 19:00", "22:00 - 23:00"]))
        days.append(.init(day: "Saturday", hours: ["closed"]))
        days.append(.init(day: "Sunday", hours: ["closed"]))
        self.days = days

        super.init(initialSize, stableId: stableId, viewType: viewType)
    }
    
    
    
    override func makeSize(_ width: CGFloat, oldWidth: CGFloat = 0) -> Bool {
        _ = super.makeSize(width, oldWidth: oldWidth)
        
        var textWidth: CGFloat = blockWidth
        textWidth -= viewType.innerInset.left * 2
        titleLayout.measure(width: textWidth)
        statusLayout.measure(width: textWidth)
        todayHoursLayout.measure(width: textWidth - statusLayout.layoutSize.width - 5)
        
        for day in days {
            day.day.measure(width: textWidth)
            for hour in day.hours {
                hour.measure(width: textWidth - day.day.layoutSize.width - 5)
            }
        }
        return true
    }
    
    override var height: CGFloat {
        var height = basicHeight
        if revealed {
            height += days.reduce(0, { $0 + $1.height })
            height += viewType.innerInset.top
        }
        return height

    }
    
    var basicHeight: CGFloat {
        return viewType.innerInset.top * 2 + titleLayout.layoutSize.height + 6 + statusLayout.layoutSize.height
    }
    
    override func viewClass() -> AnyClass {
        return PeerInfoHoursRowView.self
    }
}

private final class PeerInfoHoursRowView: GeneralContainableRowView {
    
    private class Day: View {
        private let status = TextView()
        private let hours = View()
        required init(frame frameRect: NSRect) {
            super.init(frame: frameRect)
            addSubview(status)
            addSubview(hours)
            
            status.userInteractionEnabled = false
            status.isSelectable = false
            
            hours.layer?.masksToBounds = false
            
        }
        
        required init?(coder: NSCoder) {
            fatalError("init(coder:) has not been implemented")
        }
        
        func update(day: PeerInfoHoursRowItem.Day) {
            self.status.update(day.day)
            
            while hours.subviews.count > day.hours.count {
                hours.subviews.last?.removeFromSuperview()
            }
            while hours.subviews.count < day.hours.count {
                let view = TextView()
                hours.addSubview(view)
            }
            
            var y: CGFloat = 0
            var w: CGFloat = 0
            for (i, hour) in day.hours.enumerated() {
                let view = hours.subviews[i] as! TextView
                view.update(hour)
                view.frame = NSMakeRect(0, y, view.frame.width, view.frame.height)
                y += view.frame.height + 4
                w = max(w, view.frame.width)
            }
            hours.setFrameSize(NSMakeSize(w, y))
            needsLayout = true
        }
        
        override func layout() {
            super.layout()
            self.status.setFrameOrigin(NSMakePoint(0, 10))
            self.hours.setFrameOrigin(NSMakePoint(frame.width - hours.frame.width, 10))
        }
    }
    
    private let title = TextView()
    private let status = TextView()
    private let today = TextView()
    private let daysContainer: View = View()
    required init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        addSubview(title)
        addSubview(status)
        addSubview(today)
        addSubview(daysContainer)
        title.userInteractionEnabled = false
        title.isSelectable = false
        
        today.userInteractionEnabled = false
        today.isSelectable = false

        status.userInteractionEnabled = false
        status.isSelectable = false
        
        containerView.set(handler: { [weak self] _ in
            if let item = self?.item as? PeerInfoHoursRowItem {
                item.open()
            }
        }, for: .Click)
        
        daysContainer.layer?.masksToBounds = false

    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override func set(item: TableRowItem, animated: Bool = false) {
        super.set(item: item, animated: animated)
        
        guard let item = item as? PeerInfoHoursRowItem else {
            return
        }
                
        title.update(item.titleLayout)
        status.update(item.statusLayout)
        today.update(item.todayHoursLayout)
        
        if item.revealed {
            while daysContainer.subviews.count > item.days.count {
                daysContainer.subviews.last?.removeFromSuperview()
            }
            let subviews = daysContainer.subviews
            for subview in subviews {
                if subview.identifier == .init("removed") {
                    subview.removeFromSuperview()
                }
            }
            while daysContainer.subviews.count < item.days.count {
                let view = Day(frame: .zero)
                daysContainer.addSubview(view)
                if animated {
                    view.layer?.animateAlpha(from: 0, to: 1, duration: 0.2)
                }
            }
            
            var y: CGFloat = 0
            for (i, day) in item.days.enumerated() {
                let view = daysContainer.subviews[i] as! Day
                view.update(day: day)
                view.frame = NSMakeRect(0, y, daysContainer.frame.width, day.height)
                y += view.frame.height
            }
            
        } else {
            for subview in daysContainer.subviews {
                performSubviewRemoval(subview, animated: animated)
                subview.identifier = .init("removed")
            }
        }
    }
    
    override func updateLayout(size: NSSize, transition: ContainedViewLayoutTransition) {
        super.updateLayout(size: size, transition: transition)
        
        guard let item = item as? PeerInfoHoursRowItem else {
            return
        }
        
        
        transition.updateFrame(view: title, frame: NSMakeRect(item.viewType.innerInset.left, item.viewType.innerInset.top, title.frame.width, title.frame.height))
        
        transition.updateFrame(view: status, frame: NSMakeRect(item.viewType.innerInset.left, title.frame.maxY + 6, status.frame.width, status.frame.height))
        
        transition.updateFrame(view: today, frame: NSMakeRect(containerView.frame.width - today.frame.width - item.viewType.innerInset.right, status.frame.minY, today.frame.width, today.frame.height))

        transition.updateFrame(view: daysContainer, frame: NSMakeRect(item.viewType.innerInset.left, item.basicHeight, containerView.frame.width - item.viewType.innerInset.left * 2, 0))

        
    }
}
