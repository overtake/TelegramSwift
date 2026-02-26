//
//  EmojiTabsItem.swift
//  Telegram
//
//  Created by Mike Renoir on 11.07.2022.
//  Copyright © 2022 Telegram. All rights reserved.
//

import Foundation
import TGUIKit


final class EmojiTabsItem: TableRowItem {
    let segments: [EmojiSegment]
    let selected: EmojiSegment?
    let select:(EmojiSegment)->Void
    private let _stableId: AnyHashable
    let presentation: TelegramPresentationTheme?
    init(_ initialSize: NSSize, stableId: AnyHashable, segments:[EmojiSegment], selected: EmojiSegment?, select:@escaping(EmojiSegment)->Void, presentation: TelegramPresentationTheme?) {
        self._stableId = stableId
        self.segments = segments
        self.selected = selected
        self.select = select
        self.presentation = presentation
        super.init(initialSize)
    }
    
    override var stableId: AnyHashable {
        return _stableId
    }
    
    override var width: CGFloat {
        return 36
    }
    
    override var height: CGFloat {
        return isSelected ? min(CGFloat(segments.count) * 36, 4 * 36 + 15) : 36
    }
    
    override func viewClass() -> AnyClass {
        return EmojiTabsView.self
    }
}


private final class EmojiTabsView: HorizontalRowView {
    
    private final class SegmentsView : View {
        private let container = View()
        
        private let leftGradient = ShadowView()
        private let rightGradient = ShadowView()

        private var scrollPoint: NSPoint?
        
        override func scrollWheel(with event: NSEvent) {
            
            if frame.width == frame.height {
                super.scrollWheel(with: event)
                return
            }
            
            var scrollPoint = container.frame.origin
            let isInverted: Bool = System.isScrollInverted
            if event.scrollingDeltaY != 0 {
                if isInverted {
                    scrollPoint.x -= -event.scrollingDeltaY
                } else {
                    scrollPoint.x += event.scrollingDeltaY
                }
            }
            if event.scrollingDeltaX != 0 {
                if !isInverted {
                    scrollPoint.x -= -event.scrollingDeltaX
                } else {
                    scrollPoint.x += event.scrollingDeltaX
                }
            }
            scrollPoint.x = min(0, max(scrollPoint.x, frame.width - container.frame.width))
            
            self.scrollPoint = scrollPoint
            
            self.updateLayout(size: frame.size, transition: .immediate)
        }
        
        required init(frame frameRect: NSRect) {
            super.init(frame: frameRect)
            addSubview(container)
            container.layer?.cornerRadius = 18
            self.layer?.cornerRadius = 18
            
            self.addSubview(leftGradient)
            self.addSubview(rightGradient)
            
        }
        
        func update(item: EmojiTabsItem, animated: Bool) {
            
            
            let theme = item.presentation ?? theme
            
            leftGradient.shadowBackground = theme.colors.background.withAlphaComponent(1)
            leftGradient.direction = .horizontal(false)
            rightGradient.shadowBackground = theme.colors.background.withAlphaComponent(1)
            rightGradient.direction = .horizontal(true)

            container.backgroundColor = .clear

            
            while container.subviews.count < item.segments.count {
                container.addSubview(ImageButton())
            }
            
            while container.subviews.count > item.segments.count {
                container.subviews.last?.removeFromSuperview()
            }
            
            var tabIcons:[CGImage] = []
            tabIcons.append(theme.icons.emojiRecentTab)
            tabIcons.append(theme.icons.emojiSmileTab)
            tabIcons.append(theme.icons.emojiNatureTab)
            tabIcons.append(theme.icons.emojiFoodTab)
            tabIcons.append(theme.icons.emojiSportTab)
            tabIcons.append(theme.icons.emojiCarTab)
            tabIcons.append(theme.icons.emojiObjectsTab)
            tabIcons.append(theme.icons.emojiSymbolsTab)
            tabIcons.append(theme.icons.emojiFlagsTab)
            
            var tabIconsSelected:[CGImage] = []
            tabIconsSelected.append(theme.icons.emojiRecentTabActive)
            tabIconsSelected.append(theme.icons.emojiSmileTabActive)
            tabIconsSelected.append(theme.icons.emojiNatureTabActive)
            tabIconsSelected.append(theme.icons.emojiFoodTabActive)
            tabIconsSelected.append(theme.icons.emojiSportTabActive)
            tabIconsSelected.append(theme.icons.emojiCarTabActive)
            tabIconsSelected.append(theme.icons.emojiObjectsTabActive)
            tabIconsSelected.append(theme.icons.emojiSymbolsTabActive)
            tabIconsSelected.append(theme.icons.emojiFlagsTabActive)
            
            let views = container.subviews.compactMap { $0 as? ImageButton }
            for (i, segment) in item.segments.enumerated() {
                views[i].set(image: tabIcons[segment.hashValue], for: .Normal)
                views[i].set(image: tabIconsSelected[segment.hashValue], for: .Highlight)
                let frame = CGRect(origin: NSMakePoint(CGFloat(i) * container.frame.height, 0), size: NSMakeSize(item.width, item.width))
                views[i].frame = frame
                views[i].isSelected = (item.selected == segment || (item.selected == nil && i == 0)) && item.isSelected
                views[i].userInteractionEnabled = item.isSelected
                views[i].removeAllHandlers()
                views[i].set(handler: { [weak item] _ in
                    item?.select(segment)
                }, for: .Click)
            }
            self.scrollPoint = nil
        }
        
        override func layout() {
            super.layout()
            updateLayout(size: self.frame.size, transition: .immediate)
        }
        
        func updateLayout(size: NSSize, transition: ContainedViewLayoutTransition) {
            var rect = NSMakeRect(0, 0, container.subviewsWidthSize.width, size.height)
            let subviews = container.subviews.compactMap { $0 as? Control}
            let selected = subviews.first(where: { $0.isSelected }) ?? subviews.first
            if let scrollPoint = scrollPoint {
                rect.origin.x = scrollPoint.x
            } else if let selected = selected {
                rect.origin.x = floor( min(0, max(-selected.frame.minX + size.width / 2 - selected.frame.width / 2, size.width - rect.width)) )
            }

            transition.updateFrame(view: container, frame: rect)
            transition.updateFrame(view: leftGradient, frame: NSMakeRect(0, 0, 5, size.height))
            transition.updateFrame(view: rightGradient, frame: NSMakeRect(size.width - 5, 0, 5, size.height))
            
            
            transition.updateAlpha(view: leftGradient, alpha: size.width > size.height && rect.minX < 0 ? 1 : 0)
            transition.updateAlpha(view: rightGradient, alpha: size.width > size.height && rect.minX > size.width - rect.width ? 1 : 0)
        }
        
        required init?(coder: NSCoder) {
            fatalError("init(coder:) has not been implemented")
        }
    }
    
    private var segments:SegmentsView = SegmentsView(frame: .zero)
    
    required init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        
        addSubview(segments)
    }
    
    
    override func layout() {
        super.layout()
        guard let item = item as? EmojiTabsItem else {
            return
        }
        segments.frame = NSMakeRect(0, 0, item.height, item.width)
    }
    
    override var backdorColor: NSColor {
        return .clear
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override func set(item: TableRowItem, animated: Bool) {
        super.set(item: item, animated: animated)
        
        guard let item = item as? EmojiTabsItem else {
            return
        }
        let transiton: ContainedViewLayoutTransition
        if animated {
            transiton = .animated(duration: 0.2, curve: .easeOut)
        } else {
            transiton = .immediate
        }
        let rect = NSMakeRect(0, 0, item.height, item.width)
        
        self.segments.update(item: item, animated: animated)
        
        self.segments.updateLayout(size: rect.size, transition: transiton)
        transiton.updateFrame(view: self.segments, frame: rect)
        
    }
}
