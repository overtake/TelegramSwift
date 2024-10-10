//
//  InputSwapSuggestionsPanel.swift
//  Telegram
//
//  Created by Mike Renoir on 01.08.2022.
//  Copyright © 2022 Telegram. All rights reserved.
//

import Foundation
import TGUIKit
import TelegramCore
import Postbox
import SwiftSignalKit
import InAppSettings
import TGModernGrowingTextView
import QuartzCore

final class InputSwapSuggestionsPanel : View, TableViewDelegate {
    
    private let inputView: UITextView
    private let textContent: NSClipView
    private let __window: Window
    private let context: AccountContext
    private let tableView = HorizontalTableView(frame: .zero)
    private let containerView = View()
    private weak var relativeView: NSView?
    private let presentation: TelegramPresentationTheme
    private let backgroundLayer = SimpleShapeLayer()
    private let highlightRect:(NSRange, Bool)-> NSRect
    init(inputView: UITextView, textContent:NSClipView, relativeView: NSView, window: Window, context: AccountContext, presentation: TelegramPresentationTheme = theme, highlightRect:@escaping(NSRange, Bool)-> NSRect) {
        self.textContent = textContent
        self.highlightRect = highlightRect
        self.inputView = inputView
        self.context = context
        self.relativeView = relativeView
        self.__window = window
        self.presentation = presentation
        super.init(frame: .zero)
        addSubview(containerView)
        containerView.addSubview(tableView)
        
        self.layer?.addSublayer(backgroundLayer)
        let center = NotificationCenter.default
        center.addObserver(self, selector: #selector(updateAfterScroll), name: NSView.boundsDidChangeNotification, object: textContent)

        tableView.layer?.cornerRadius = 10
        
        containerView.layer?.cornerRadius = 10
        containerView.layer?.backgroundColor = .clear
        
        self.backgroundLayer.shadowColor = NSColor(white: 0.0, alpha: 1.0).cgColor
        self.backgroundLayer.shadowOffset = CGSize(width: 0.0, height: 2.0)
        self.backgroundLayer.shadowRadius = 3
        self.backgroundLayer.shadowOpacity = 0.15
        self.backgroundLayer.fillColor = presentation.colors.background.cgColor


        tableView.delegate = self
        
        tableView.getBackgroundColor = {
            .clear
        }

    }
    
    func selectionDidChange(row:Int, item:TableRowItem, byClick:Bool, isNew:Bool) {
        
    }
    func selectionWillChange(row:Int, item:TableRowItem, byClick:Bool) -> Bool {
        guard let item = item as? AnimatedClueRowItem else {
            return false
        }
        if byClick {
            let textInputState = inputView.interactions.presentation.textInputState()
            if let (stringRange, _, _) = textInputStateContextQueryRangeAndType(textInputState, includeContext: false) {
                let inputText = textInputState.inputText
                
                var range = NSRange(string: inputText, range: stringRange)
                
                let attach = NSMutableAttributedString()
                                
                let replacementText = inputText.nsstring.substring(with: range)
                
                let symbolLength = range.length
                var acceptedLast: Bool = false
                while range.location >= 0 {
                    let previous = NSMakeRange(max(0, range.location), symbolLength)
                    let isAnimated = textInputState.isAnimatedEmoji(at: previous)
                    if inputText.nsstring.substring(with: previous) == replacementText, !isAnimated {
                        attach.append(.makeAnimated(item.clue, text: replacementText))
                        range.location -= previous.length
                        range.length += previous.length
                        acceptedLast = true
                    } else {
                        break
                    }
                }
                if acceptedLast {
                    range.location += symbolLength
                    range.length -= symbolLength
                }
                inputView.insertText(attach, range: range.lowerBound ..< range.upperBound)
            }
        }
        return false
    }
    func isSelectable(row:Int, item:TableRowItem) -> Bool {
        return true
    }
    
    func findGroupStableId(for stableId: AnyHashable) -> AnyHashable? {
        return nil
    }
    
    func longSelect(row:Int, item:TableRowItem) -> Void {
        
    }
    
    deinit {
        NotificationCenter.default.removeObserver(self)
    }
    
    override func cursorUpdate(with event: NSEvent) {
        super.cursorUpdate(with: event)
        NSCursor.arrow.set()
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    required init(frame frameRect: NSRect) {
        fatalError("init(frame:) has not been implemented")
    }
    
    enum Entry : Comparable, Identifiable {
        case animated(TelegramMediaFile, Int)
        
        static func <(lhs: Entry, rhs: Entry) -> Bool {
            return lhs.index < rhs.index
        }
        
        var index: Int {
            switch self {
            case .animated(_, let index):
                return index
            }
        }
        var stableId: AnyHashable {
            switch self {
            case .animated(let file, _):
                return file.fileId.id
            }
        }
        
        func makeItem(_ size: NSSize, context: AccountContext, presentation: TelegramPresentationTheme) -> TableRowItem {
            switch self {
            case let .animated(file, _):
                return AnimatedClueRowItem(size, context: context, clue: file, presentation: presentation)
            }
        }
    }
    

    
    private var range: NSRange?
    private var items:[Entry] = []
    
    func apply(_ items: [TelegramMediaFile], range: NSRange, animated: Bool, isNew: Bool) {
        
        
        guard let relativeView = relativeView else {
            return
        }
        
        self.range = range
         
        
        relativeView.addSubview(self)
        let size = NSMakeSize(min(40 * 5 + 20, CGFloat(items.count) * 40) + 10, 55)
        let rect = self.highlightRect(range, false)

        let convert = inputView.convert(rect, to: relativeView)
        
        
        var index: Int = 0
        var entries:[Entry] = []
        
        for clue in items {
            entries.append(.animated(clue, index))
            index += 1
        }
        
        let context = self.context
        
        tableView.beginTableUpdates()
        
        
        let (deleteIndices, indicesAndItems, updateIndices) = mergeListsStableWithUpdates(leftList: self.items, rightList: entries)
        
        for rdx in deleteIndices.reversed() {
            tableView.remove(at: rdx, animation: animated ? .effectFade : .none)
            self.items.remove(at: rdx)
        }
        
        for (idx, item, _) in indicesAndItems {
            _ = tableView.insert(item: item.makeItem(bounds.size, context: context, presentation: self.presentation), at: idx, animation: animated ? .effectFade : .none)
            self.items.insert(item, at: idx)
        }
        for (idx, item, _) in updateIndices {
            let item =  item
            tableView.replace(item: item.makeItem(bounds.size, context: context, presentation: self.presentation), at: idx, animated: animated)
            self.items[idx] = item
        }

        tableView.endTableUpdates()
        
        var frame = CGRect(origin: NSMakePoint(convert.midX - size.width / 2, convert.minY - size.height), size: size)
        
        frame.origin.x = min(max(10, frame.origin.x), relativeView.frame.width - size.width - 10)

        
        let transition: ContainedViewLayoutTransition
        if animated && !isNew {
            transition = .animated(duration: 0.2, curve: .easeOut)
        } else {
            transition = .immediate
        }
        if isNew {
            self.frame = frame
            if animated {
                self.layer?.animateAlpha(from: 0, to: 1, duration: 0.2)
            }
        } else {
            transition.updateFrame(view: self, frame: frame)
        }
        self.updateLayout(size: size, transition: transition)
        self.updateRect(transition: transition)

    }
    
    @objc private func updateAfterScroll() {
        self.updateRect(transition: .immediate)
    }
    
    func updateRect(transition: ContainedViewLayoutTransition) {
        guard let relativeView = relativeView, let range = self.range else {
            return
        }
        
        let size = self.frame.size
        let rect = self.highlightRect(range, false)
        let convert = inputView.convert(rect, to: relativeView)
        
        let mid = convert.midX - size.width / 2
        
        var frame = CGRect(origin: NSMakePoint(mid, convert.minY - size.height), size: self.frame.size)
        frame.origin.x = min(max(10, frame.origin.x), relativeView.frame.width - size.width - 10)
        transition.updateFrame(view: self, frame: frame)
        updateLayout(size: size, transition: transition)
        
        let x = containerView.frame.width / 2 - (frame.minX - mid)
        
        self.isHidden = !NSPointInRect(NSMakePoint(rect.midX, rect.midY), textContent.documentVisibleRect)

        adjustBackground(relativePositionX: x, animated: transition.isAnimated)
        
        
    }
    
    func updateLayout(size: NSSize, transition: ContainedViewLayoutTransition) {
        
        containerView.setFrameSize(NSMakeSize(size.width - 10, size.height - 15))
        tableView.setFrameSize(containerView.frame.size)
        
        transition.updateFrame(view: containerView, frame: CGRect(origin: NSMakePoint(5, 5), size: containerView.frame.size))
        transition.updateFrame(view: tableView, frame: containerView.bounds)
    }
    
    func close(animated: Bool) {
        performSubviewRemoval(self, animated: animated)
    }
    
    public func adjustBackground(relativePositionX: CGFloat, animated: Bool) {
        let size = NSMakeSize(containerView.frame.width, frame.height - 10)
        if size.width.isZero {
            return
        }
        
        let radius: CGFloat = 10.0
        let notchSize = CGSize(width: 19.0, height: 7.5)
        
        let path = CGMutablePath()
        path.move(to: CGPoint(x: radius, y: 0.0))
        path.addArc(tangent1End: CGPoint(x: 0.0, y: 0.0), tangent2End: CGPoint(x: 0.0, y: radius), radius: radius)
        path.addLine(to: CGPoint(x: 0.0, y: size.height - notchSize.height - radius))
        path.addArc(tangent1End: CGPoint(x: 0.0, y: size.height - notchSize.height), tangent2End: CGPoint(x: radius, y: size.height - notchSize.height), radius: radius)
        
        let notchBase = CGPoint(x: min(size.width - radius - notchSize.width, max(radius, floor(relativePositionX - notchSize.width / 2.0))), y: size.height - notchSize.height)
        path.addLine(to: notchBase)
        path.addCurve(to: CGPoint(x: notchBase.x + 7.49968, y: notchBase.y + 5.32576), control1: CGPoint(x: notchBase.x + 2.10085, y: notchBase.y + 0.0), control2: CGPoint(x: notchBase.x + 5.41005, y: notchBase.y + 3.11103))
        path.addCurve(to: CGPoint(x: notchBase.x + 8.95665, y: notchBase.y + 6.61485), control1: CGPoint(x: notchBase.x + 8.2352, y: notchBase.y + 6.10531), control2: CGPoint(x: notchBase.x + 8.60297, y: notchBase.y + 6.49509))
        path.addCurve(to: CGPoint(x: notchBase.x + 9.91544, y: notchBase.y + 6.61599), control1: CGPoint(x: notchBase.x + 9.29432, y: notchBase.y + 6.72919), control2: CGPoint(x: notchBase.x + 9.5775, y: notchBase.y + 6.72953))
        path.addCurve(to: CGPoint(x: notchBase.x + 11.3772, y: notchBase.y + 5.32853), control1: CGPoint(x: notchBase.x + 10.2694, y: notchBase.y + 6.49707), control2: CGPoint(x: notchBase.x + 10.6387, y: notchBase.y + 6.10756))
        path.addCurve(to: CGPoint(x: notchBase.x + 19.0, y: notchBase.y + 0.0), control1: CGPoint(x: notchBase.x + 13.477, y: notchBase.y + 3.11363), control2: CGPoint(x: notchBase.x + 16.817, y: notchBase.y + 0.0))
        
        path.addLine(to: CGPoint(x: size.width - radius, y: size.height - notchSize.height))
        path.addArc(tangent1End: CGPoint(x: size.width, y: size.height - notchSize.height), tangent2End: CGPoint(x: size.width, y: size.height - notchSize.height - radius), radius: radius)
        path.addLine(to: CGPoint(x: size.width, y: radius))
        path.addArc(tangent1End: CGPoint(x: size.width, y: 0.0), tangent2End: CGPoint(x: size.width - radius, y: 0.0), radius: radius)
        path.addLine(to: CGPoint(x: radius, y: 0.0))
        
        
        CATransaction.begin()
        self.backgroundLayer.frame = CGRect(origin: CGPoint(x: 5, y: 5), size: size)
        self.backgroundLayer.path = path
        self.backgroundLayer.shadowPath = path
        
        if animated {
            self.backgroundLayer.animateFrameFast()
            self.backgroundLayer.animatePath()
            self.backgroundLayer.animateShadow()
        }
        CATransaction.commit()
    }

}

func InputSwapSuggestionsPanelItems(_ query: String, peerId: PeerId, context: AccountContext) -> Signal<[TelegramMediaFile], NoError> {
    
    let query = query.emojiUnmodified
    
    if (peerId != context.peerId && !context.isPremium ) || !FastSettings.suggestSwapEmoji {
        return .single([])
    }
    
    let boxKey = ValueBoxKey(query)
    let searchQuery: ItemCollectionSearchQuery = .exact(boxKey)
    
    let animated = context.account.postbox.transaction { transaction in
        return transaction.searchItemCollection(namespace: Namespaces.ItemCollection.CloudEmojiPacks, query: searchQuery)
    } |> map {
        $0.compactMap({ $0 as? StickerPackItem })
    }
        
    let featured: Signal<[StickerPackItem], NoError> = context.account.viewTracker.featuredEmojiPacks() |> map {
        $0.reduce([], { current, value in
            return current + value.topItems
        })
    }
    let recentlyUsed = recentUsedEmoji(postbox: context.account.postbox)
    
    return combineLatest(animated, featured, recentlyUsed) |> map { animated, featured, recentlyUsed in

        var foundItems: [StickerPackItem] = []
        
        foundItems.append(contentsOf: animated)
        foundItems.append(contentsOf: featured.filter { item in
            return item.file.customEmojiText?.fixed == query.fixed
        })
        foundItems = foundItems.reduce([], { current, value in
            if !current.contains(where: { $0.file.fileId == value.file.fileId}) {
                return current + [value]
            } else {
                return current
            }
        }).sorted(by: { lhs, rhs in
            let lhsIndex = recentlyUsed.animated.firstIndex(where: { $0 == lhs.file.fileId })
            let rhsIndex = recentlyUsed.animated.firstIndex(where: { $0 == rhs.file.fileId })

            if let lhsIndex = lhsIndex, let rhsIndex = rhsIndex {
                return lhsIndex < rhsIndex
            } else if lhsIndex != nil {
                return true
            } else {
                return false
            }
        })
        
        
        
        return foundItems.map { $0.file }
    }
    
}
