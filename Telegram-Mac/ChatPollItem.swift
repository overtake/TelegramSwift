//
//  ChatPollItem.swift
//  Telegram
//
//  Created by Mikhail Filimonov on 18/12/2018.
//  Copyright © 2018 Telegram. All rights reserved.
//

import Cocoa
import Cocoa
import TGUIKit
import TelegramCoreMac
import PostboxMac
import SwiftSignalKitMac


private struct PercentCounterItem : Comparable  {
    var index: Int = 0
    var percent: Int = 0
    var remainder: Int = 0
    
    static func <(lhs: PercentCounterItem, rhs: PercentCounterItem) -> Bool {
        if lhs.remainder > rhs.remainder {
            return true
        } else if lhs.remainder < rhs.remainder {
            return false
        }
        return lhs.percent < rhs.percent
    }
    
}

private func adjustPercentCount(_ items: [PercentCounterItem], left: Int) -> [PercentCounterItem] {
    var left = left
    var items = items.sorted(by: <)
    var i:Int = 0
    while i != items.count {
        let item = items[i]
        var j = i + 1
        loop: while j != items.count {
            if items[j].percent != item.percent || items[j].remainder != item.remainder {
                break loop
            }
            j += 1
        }
        let equal = j - i
        if equal <= left {
            left -= equal
            while i != j {
                items[i].percent += 1
                i += 1
            }
        } else {
            i = j
        }
    }
    return items
}

private func countNicePercent(votes:[Int], total: Int) -> [Int] {
    var result:[Int] = Array(repeating: 0, count: votes.count)
    var items:[PercentCounterItem] = Array(repeating: PercentCounterItem(), count: votes.count)
    
    guard total > 0 else {
        return result
    }
    
    let count = votes.count
    
    var left:Int = 100
    for i in 0 ..< votes.count {
        let votes = votes[i]
        items[i].index = i
        items[i].percent = Int((Float(votes) * 100) / Float(total))
        items[i].remainder = (votes * 100) - (items[i].percent * total)
        left -= items[i].percent
    }
    
    if left > 0 && left <= count {
        items = adjustPercentCount(items, left: left)
    }
    for item in items {
        result[item.index] = item.percent
    }
    
    return result
}

//
//void CountNicePercent(
//    gsl::span<const int> votes,
//    int total,
//gsl::span<int> result) {
//    Expects(result.size() >= votes.size());
//    Expects(votes.size() <= PollData::kMaxOptions);
//
//    const auto count = size_type(votes.size());
//    PercentCounterItem ItemsStorage[PollData::kMaxOptions];
//    const auto items = gsl::make_span(ItemsStorage).subspan(0, count);
//    auto left = 100;
//    auto &&zipped = ranges::view::zip(
//    votes,
//    items,
//    ranges::view::ints(0));
//    for (auto &&[votes, item, index] : zipped) {
//        item.index = index;
//        item.percent = (votes * 100) / total;
//        item.remainder = (votes * 100) - (item.percent * total);
//        left -= item.percent;
//    }
//    if (left > 0 && left <= count) {
//        AdjustPercentCount(items, left);
//    }
//    for (const auto &item : items) {
//        result[item.index] = item.percent;
//    }
//}
//
//}




private final class PollOption : Equatable {
    let option: TelegramMediaPollOption
    let nameText: TextViewLayout
    let percent: Float?
    let voteCount: Int32
    let realPercent: Float
    let isSelected: Bool
    let voted: Bool
    let isIncoming: Bool
    let isBubbled: Bool
    let isLoading: Bool
    let presentation: TelegramPresentationTheme
    let contentSize: NSSize
    let vote:()-> Void
    
    init(option:TelegramMediaPollOption, nameText: TextViewLayout, percent: Float?, realPercent: Float, voteCount: Int32, isSelected: Bool, isIncoming: Bool, isBubbled: Bool, voted: Bool, isLoading: Bool, presentation: TelegramPresentationTheme, vote: @escaping()->Void = {}, contentSize: NSSize = NSZeroSize) {
        self.option = option
        self.nameText = nameText
        self.percent = percent
        self.realPercent = realPercent
        self.isSelected = isSelected
        self.voted = voted
        self.presentation = presentation
        self.isIncoming = isIncoming
        self.isBubbled = isBubbled
        self.isLoading = isLoading
        self.vote = vote
        self.voteCount = voteCount
        self.contentSize = contentSize
    }
    
    func withUpdatedLoading(_ isLoading: Bool) -> PollOption {
        return PollOption(option: self.option, nameText: self.nameText, percent: self.percent, realPercent: self.realPercent, voteCount: self.voteCount, isSelected: self.isSelected, isIncoming: self.isIncoming, isBubbled: self.isBubbled, voted: self.voted, isLoading: isLoading, presentation: self.presentation, vote: self.vote, contentSize: self.contentSize)
    }
    func withUpdatedContentSize(_ contentSize: NSSize) -> PollOption {
        return PollOption(option: self.option, nameText: self.nameText, percent: self.percent, realPercent: self.realPercent, voteCount: self.voteCount, isSelected: self.isSelected, isIncoming: self.isIncoming, isBubbled: self.isBubbled, voted: self.voted, isLoading: self.isLoading, presentation: self.presentation, vote: self.vote, contentSize: contentSize)
    }
    func withUpdatedSelected(_ isSelected: Bool) -> PollOption {
        return PollOption(option: self.option, nameText: self.nameText, percent: self.percent, realPercent: self.realPercent, voteCount: self.voteCount, isSelected: isSelected, isIncoming: self.isIncoming, isBubbled: self.isBubbled, voted: self.voted, isLoading: self.isLoading, presentation: self.presentation, vote: self.vote, contentSize: self.contentSize)
    }
    
    
    static func ==(lhs: PollOption, rhs: PollOption) -> Bool {
        return lhs.option == rhs.option && lhs.percent == rhs.percent && lhs.isSelected == rhs.isSelected && lhs.isIncoming == rhs.isIncoming && lhs.isLoading == rhs.isLoading && lhs.contentSize == rhs.contentSize && lhs.voted == rhs.voted && lhs.realPercent == rhs.realPercent && lhs.voteCount == rhs.voteCount
    }
    
    
    var leftOptionInset: CGFloat {
        return 40 + PollOption.spaceBetweenTexts
    }
    var currentPercentImage: CGImage? {
       return presentation.chat.pollPercentAnimatedIcon(isIncoming, isBubbled, selected: isSelected, value: Int(realPercent))
    }
    
    static var spaceBetweenTexts: CGFloat {
        return 6
    }
    static var spaceBetweenOptions: CGFloat {
        return 5
    }
    
    
    
    func measure(width: CGFloat) -> NSSize {
        nameText.measure(width: width - leftOptionInset)
        let contentSize = NSMakeSize(nameText.layoutSize.width + leftOptionInset, 10 + nameText.layoutSize.height)
        return contentSize
    }
}

class ChatPollItem: ChatRowItem {
    private(set) fileprivate var titleText:TextViewLayout!
    private(set) fileprivate var titleTypeText:TextViewLayout!

    private(set) fileprivate var options:[PollOption] = []
    private(set) fileprivate var totalVotesText:TextViewLayout?

    fileprivate let poll: TelegramMediaPoll
    
    var isClosed: Bool {
        return poll.isClosed
    }
    
    
    
    override init(_ initialSize: NSSize, _ chatInteraction: ChatInteraction, _ context: AccountContext, _ object: ChatHistoryEntry, _ downloadSettings: AutomaticMediaDownloadSettings) {
        
        let poll = object.message!.media[0] as! TelegramMediaPoll
        self.poll = poll
        
        super.init(initialSize, chatInteraction, context, object, downloadSettings)
    
        
        
        var options: [PollOption] = []
        
        
        var votes:[Int] = []
        
        for option in poll.options {
            let count = Int(poll.results.voters?.first(where: {$0.opaqueIdentifier == option.opaqueIdentifier})?.count ?? 0)
            votes.append(count)
        }
        

        
        let percents = countNicePercent(votes: votes, total: Int(poll.results.totalVoters ?? 0))
        let maximum: Int = percents.max() ?? 0
        
        for (i, option) in poll.options.enumerated() {
            
            let percent: Float?
            let realPercent: Float
            let isSelected: Bool
            
            let voted = poll.results.voters?.first(where: {$0.selected}) != nil
            
            var votedCount: Int32 = 0
            if let vote = poll.results.voters?.first(where: {$0.opaqueIdentifier == option.opaqueIdentifier}), let totalVoters = poll.results.totalVoters, (voted || poll.isClosed) {
                percent = maximum == 0 ? 0 : (Float(percents[i]) / Float(maximum))
                realPercent = totalVoters == 0 ? 0 : Float(percents[i])
                isSelected = vote.selected
                votedCount = vote.count
            } else {
                percent = poll.results.totalVoters == nil || poll.results.totalVoters == 0 ? nil : voted ? 0 : nil
                realPercent = 0
                isSelected = false
            }
            
            let nameFont: NSFont = .normal(.text)//voted && isSelected ? .bold(.text) : .normal(.text)
            let nameLayout = TextViewLayout(.initialize(string: option.text, color: self.presentation.chat.textColor(isIncoming, renderType == .bubble), font: nameFont), alwaysStaticItems: true)

            
            let wrapper = PollOption(option: option, nameText: nameLayout, percent: percent, realPercent: realPercent, voteCount: votedCount, isSelected: isSelected, isIncoming: isIncoming, isBubbled: renderType == .bubble, voted: voted, isLoading: object.additionalData?.opaqueIdentifier == option.opaqueIdentifier , presentation: self.presentation, vote: { [weak self] in
                self?.voteOption(option)
            })
            
            options.append(wrapper)
        }
        self.options = options
        
        let totalCount = poll.results.totalVoters ?? 0
        self.totalVotesText = TextViewLayout(.initialize(string: totalCount > 0 ? L10n.chatPollTotalVotesCountable(Int(totalCount)) : poll.isClosed ? L10n.chatPollTotalVotesResultEmpty : L10n.chatPollTotalVotesEmpty, color: self.presentation.chat.grayText(isIncoming, renderType == .bubble), font: .normal(12)), maximumNumberOfLines: 1, alwaysStaticItems: true)

        
        self.titleText = TextViewLayout(.initialize(string: poll.text, color: self.presentation.chat.textColor(isIncoming, renderType == .bubble), font: .medium(.text)), alwaysStaticItems: true)
        self.titleTypeText = TextViewLayout(.initialize(string: poll.isClosed ? L10n.chatPollTypeClosed : L10n.chatPollTypeAnonymous, color: self.presentation.chat.grayText(isIncoming, renderType == .bubble), font: .normal(12)), maximumNumberOfLines: 1, alwaysStaticItems: true)
    }
    
    override var isFixedRightPosition: Bool {
        return true
    }
    
    override func menuItems(in location: NSPoint) -> Signal<[ContextMenuItem], NoError> {
        return super.menuItems(in: location) |> map { [weak self] items in
            guard let `self` = self, let message = self.message else { return items }
            var items = items
            if let poll = message.media.first as? TelegramMediaPoll {
                if !poll.isClosed && !message.flags.contains(.Unsent) && !message.flags.contains(.Failed) {
                    var index: Int = 0
                    if let _ = poll.results.voters?.first(where: {$0.selected}) {
                        items.insert(ContextMenuItem(L10n.chatPollUnvote, handler: { [weak self] in
                            self?.unvote()
                        }), at: index)
                        index += 1
                    }
                    if message.forwardInfo == nil {
                        var canClose: Bool = message.author?.id == self.context.peerId
                        if let peer = self.peer as? TelegramChannel {
                            canClose = peer.hasPermission(.sendMessages) || peer.hasPermission(.editAllMessages)
                        }
                        if canClose {
                            items.insert(ContextMenuItem(L10n.chatPollStop, handler: { [weak self] in
                                confirm(for: mainWindow, header: L10n.chatPollStopConfirmHeader, information: L10n.chatPollStopConfirmText, okTitle: L10n.alertConfirmStop, successHandler: { [weak self] _ in
                                    self?.stop()
                                })
                            }), at: index)
                            index += 1
                        }
                    }
                    if index != 0 {
                        items.insert(ContextSeparatorItem(), at: index)
                    }
                }
                
            }
            return items
        }
    }
    
    private func stop() {
        if let message = message {
            chatInteraction.closePoll(message.id)
        }
    }
    
    private func unvote() {
        guard let message = message else { return }
        
        
        self.chatInteraction.vote(message.id, nil)
    }
    
    private func voteOption(_ option: TelegramMediaPollOption) {
        
        guard self.options.firstIndex(where: {$0.isSelected}) == nil, let message = message, !message.flags.contains(.Failed) && !message.flags.contains(.Unsent), !self.poll.isClosed else {
            return
        }
    
       chatInteraction.vote(message.id, option.opaqueIdentifier)
    }
    
    override func viewClass() -> AnyClass {
        return ChatPollItemView.self
    }
    
    override var instantlyResize: Bool {
        return true
    }

    override func makeContentSize(_ width: CGFloat) -> NSSize {
        
        let width = min(width, 320)
        
        titleText.measure(width: width - bubbleContentInset)
        titleTypeText.measure(width: width - bubbleContentInset)
        totalVotesText?.measure(width: width - bubbleContentInset)
        
        
        
        var maxOptionNameWidth: CGFloat = 0
        for (i, option) in options.enumerated() {
            let size = option.measure(width: width)
            self.options[i] = option.withUpdatedContentSize(size)
            if maxOptionNameWidth < size.width {
                maxOptionNameWidth = size.width
            }
        }
    
        
        let contentWidth:CGFloat = max(max(maxOptionNameWidth, titleText.layoutSize.width), titleTypeText.layoutSize.width)
        
        var contentHeight: CGFloat = 0
        
        contentHeight += titleText.layoutSize.height + defaultContentInnerInset
        contentHeight += titleTypeText.layoutSize.height + defaultContentInnerInset
        contentHeight += options.reduce(0, { $0 + $1.contentSize.height }) + (CGFloat(options.count - 1) * PollOption.spaceBetweenOptions)
        
        if let totalVotesText = totalVotesText {
            contentHeight += defaultContentInnerInset
            contentHeight += totalVotesText.layoutSize.height
        }
        
        
        return NSMakeSize(max(width, contentWidth), contentHeight)
    }
    
    deinit {
    }
}


private final class ChatPollItemView : ChatRowView {
    fileprivate(set) var contentNode:PollView = PollView(frame: NSZeroRect)
    
    required init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        addSubview(contentNode)
    }
    
    /*
     var contentFrame:NSRect {
     guard let item = item as? ChatRowItem else {return NSZeroRect}
     var rect = NSMakeRect(item.contentOffset.x, item.contentOffset.y, item.contentSize.width, item.contentSize.height)
     if item.isBubbled {
     if !item.isIncoming {
     rect.origin.x = bubbleFrame.minX + item.bubbleContentInset
     } else {
     rect.origin.x = bubbleFrame.minX + item.bubbleContentInset + item.additionBubbleInset
     }
     
     }
     return rect
     }
 */
    
    override var contentFrameModifier: NSRect {
        guard let item = item as? ChatRowItem else {return NSZeroRect}
        
        if item.isBubbled {
            var frame = bubbleFrame
            frame.size.width -= item.additionBubbleInset
            frame.origin.y = super.contentFrameModifier.minY
            if item.isIncoming {
                frame.origin.x += item.additionBubbleInset
            }
            return frame
        } else {
            var frame = super.contentFrameModifier
            frame.origin.x -= item.bubbleContentInset
            return frame
        }
    }
    
    
    override func set(item: TableRowItem, animated: Bool) {
        
        guard let item = item as? ChatPollItem else { return }
        super.set(item: item, animated: animated)

        contentNode.change(size: NSMakeSize(contentFrameModifier.width, item.contentSize.height), animated: animated)
        contentNode.update(with: item, animated: animated)
        
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override func canStartTextSelecting(_ event: NSEvent) -> Bool {
        
        let point = contentView.convert(event.locationInWindow, from: nil)
        return NSPointInRect(point, NSMakeRect(0, contentNode.titleView.frame.minY, contentNode.frame.width, contentNode.titleView.frame.height))
    }
    
    override var selectableTextViews: [TextView] {
      //  let views:[TextView] = [text]
        //        if let webpage = webpageContent {
        //            views += webpage.selectableTextViews
        //        }
       // return views
        return [contentNode.titleView]
    }
    
    override func canMultiselectTextIn(_ location: NSPoint) -> Bool {
        let point = contentView.convert(location, from: nil)
        return NSPointInRect(point, NSMakeRect(0, contentNode.titleView.frame.minY, contentNode.frame.width, contentNode.titleView.frame.height))
    }
    
    override var needsDisplay: Bool {
        get {
            return super.needsDisplay
        }
        set {
            super.needsDisplay = true
            contentNode.needsDisplay = true
        }
    }
    
    override var backgroundColor: NSColor {
        didSet {
            
            contentNode.backgroundColor = .clear//contentColor
        }
    }
    
    override func shakeView() {
        contentNode.shake()
    }
    
    
    override func draw(_ dirtyRect: NSRect) {
        
    }

    override func updateColors() {
        super.updateColors()
         contentNode.backgroundColor = .clear//contentColor
    }
    

}


private final class PollOptionView : Control {
    private var percentView: ImageView?
    private let nameView: TextView = TextView()
    private var selectingView:ImageView?

    private var progressView: LinearProgressControl = LinearProgressControl(progressHeight: 5)
    private var progressIndicator: ProgressIndicator?
    private let borderView: View = View(frame: NSZeroRect)
    
    private var option: PollOption?
    required init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
      //  background = .random
        nameView.userInteractionEnabled = false
        nameView.isSelectable = false
        progressView.hasMinumimVisibility = true
        addSubview(nameView)
        addSubview(progressView)
        addSubview(borderView)
        borderView.userInteractionEnabled = false
        progressView.userInteractionEnabled = false
        progressView.roundCorners = true
        
        set(handler: { [weak self] _ in
            self?.option?.vote()
        }, for: .Click)
    }
    
    var defaultInset: CGFloat {
        return 13
    }
    
    func update(with option: PollOption, animated: Bool) {
        let animated = animated && self.option != option
        
        let previousPercent = self.option?.realPercent

        self.option = option

        
        let duration: Double = 0.4
        
        nameView.update(option.nameText, origin: NSMakePoint(option.leftOptionInset, 0))
        progressView.setFrameOrigin(NSMakePoint(nameView.frame.minX, nameView.frame.maxY + 5))
        borderView.backgroundColor = option.presentation.chat.pollOptionBorder(option.isIncoming, option.isBubbled)
        borderView.frame = NSMakeRect(nameView.frame.minX, nameView.frame.maxY + 5 - .borderSize + progressView.progressHeight, frame.width - nameView.frame.minX, .borderSize)
        borderView.change(opacity: option.percent != nil ? 0 : 1, animated: animated, duration: duration)
        progressView.change(opacity: option.percent == nil ? 0 : 1, animated: animated, duration: duration)
        progressView.style = ControlStyle(foregroundColor: option.presentation.chat.webPreviewActivity(option.isIncoming, option.isBubbled), backgroundColor: .clear)

        if let progress = option.percent {
            
            toolTip = option.voteCount == 0 ? L10n.chatPollTooltipNoVotes : L10n.chatPollTooltipVotesCountable(Int(option.voteCount))

            
            progressView.frame = NSMakeRect(nameView.frame.minX, nameView.frame.maxY + 5, frame.width - nameView.frame.minX - defaultInset, progressView.frame.height)
            progressView.set(progress: CGFloat(progress), animated: animated, duration: duration / 2)
            if percentView == nil {
                percentView = ImageView()
                addSubview(percentView!)
                if animated {
                    percentView!.layer?.animateAlpha(from: 0, to: 1, duration: duration / 2)
                }
            }
            
            percentView?.animates = animated
            percentView?.image = option.currentPercentImage
            percentView?.setFrameSize(36, 16)
            percentView?.setFrameOrigin(NSMakePoint(nameView.frame.minX - percentView!.frame.width - PollOption.spaceBetweenTexts, nameView.frame.minY + 2))
            
            if previousPercent != option.realPercent, animated {
                let images = option.presentation.chat.pollPercentAnimatedIcons(option.isIncoming, option.isBubbled, selected: option.isSelected || !option.voted, from: CGFloat(previousPercent ?? 0), to: CGFloat(option.realPercent), duration: duration / 2)
                if !images.isEmpty {
                    let animation = CAKeyframeAnimation(keyPath: "contents")
                    animation.values = images
                    animation.duration = duration / 2
                    animation.calculationMode = .discrete
                    percentView?.layer?.add(animation, forKey: "image")
                }

            }
            
            if let selectingView = selectingView {
                self.selectingView = nil
                if animated {
                    selectingView.layer?.animateAlpha(from: 1, to: 0, duration: duration / 2, removeOnCompletion: false, completion: { [weak selectingView] completed in
                        if completed {
                            selectingView?.removeFromSuperview()
                        }
                    })
                } else {
                    selectingView.removeFromSuperview()
                }
            }
            if let progressIndicator = progressIndicator {
                self.progressIndicator = nil
                if animated {
                    progressIndicator.layer?.animateAlpha(from: 1, to: 0, duration: duration / 2, removeOnCompletion: false, completion: { [weak progressIndicator] completed in
                        if completed {
                            progressIndicator?.removeFromSuperview()
                        }
                    })
                } else {
                    progressIndicator.removeFromSuperview()
                }
            }
        } else {
            toolTip = nil
            if let percentView = self.percentView {
                self.percentView = nil
                if animated {
                    
                    if previousPercent != 0 {
                        let images = option.presentation.chat.pollPercentAnimatedIcons(option.isIncoming, option.isBubbled, selected: option.isSelected, from: CGFloat(previousPercent ?? 0), to: CGFloat(0), duration: duration / 2)
                        if !images.isEmpty {
                            let animation = CAKeyframeAnimation(keyPath: "contents")
                            animation.values = images
                            animation.duration = duration / 2
                            animation.calculationMode = .discrete
                            percentView.layer?.add(animation, forKey: "image")
                        }
                    }
                    
                    percentView.layer?.animateAlpha(from: 1, to: 0, duration: duration / 2, removeOnCompletion: false, completion: { [weak percentView] completed in
                        if completed {
                            percentView?.removeFromSuperview()
                        }
                    })
                } else {
                    percentView.removeFromSuperview()
                }
            }
            
            progressView.set(progress: 0, animated: animated)
            
            if option.isLoading {
                if let selectingView = selectingView {
                    self.selectingView = nil
                    if animated {
                        selectingView.layer?.animateAlpha(from: 1, to: 0, duration: duration / 2, removeOnCompletion: false, completion: { [weak selectingView] completed in
                            if completed {
                                selectingView?.removeFromSuperview()
                            }
                        })
                    } else {
                        selectingView.removeFromSuperview()
                    }
                }
                if progressIndicator == nil {
                    progressIndicator = ProgressIndicator(frame: NSMakeRect(0, 0, 18, 18))
                    addSubview(progressIndicator!)
                    if animated {
                        progressIndicator?.layer?.animateAlpha(from: 0, to: 1, duration: duration / 2)
                    }
                }
                progressIndicator?.lineWidth = 1.0
                progressIndicator?.progressColor = option.presentation.chat.webPreviewActivity(option.isIncoming, option.isBubbled)
                progressIndicator?.setFrameOrigin(NSMakePoint(defaultInset, 0))

            } else {
                if let progressIndicator = progressIndicator {
                    self.progressIndicator = nil
                    if animated {
                        progressIndicator.layer?.animateAlpha(from: 1, to: 0, duration: duration / 2, removeOnCompletion: false, completion: { [weak progressIndicator] completed in
                            if completed {
                                progressIndicator?.removeFromSuperview()
                            }
                        })
                    } else {
                        progressIndicator.removeFromSuperview()
                    }
                }
                
                if selectingView == nil {
                    selectingView = ImageView(frame: NSMakeRect(0, 0, 22, 22))
                    addSubview(selectingView!)
                    if animated {
                        selectingView?.layer?.animateAlpha(from: 0, to: 1, duration: duration / 2)
                    }
                }
                selectingView?.image = option.presentation.chat.pollOptionUnselectedImage(option.isIncoming, option.isBubbled)
                selectingView?.sizeToFit()
                selectingView?.setFrameOrigin(NSMakePoint(defaultInset, 0))
            }
            
        }
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}

private final class PollView : Control {
    fileprivate let titleView: TextView = TextView()
    private let typeView: TextView = TextView()
    private var totalVotesTextView: TextView?
    private var options:[PollOptionView] = []
    required init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
       // titleView.isSelectable = false
       // titleView.userInteractionEnabled = false
        typeView.isSelectable = false
        typeView.userInteractionEnabled = false
        addSubview(titleView)
        addSubview(typeView)
    }
    
    func update(with item: ChatPollItem, animated: Bool) {
        
        titleView.update(item.titleText)
        typeView.update(item.titleTypeText)
        
        var y: CGFloat = 0
        
        titleView.setFrameOrigin(NSMakePoint(item.bubbleContentInset, y))
        y += titleView.frame.height + item.defaultContentInnerInset
        typeView.setFrameOrigin(NSMakePoint(item.bubbleContentInset, y))
        y += typeView.frame.height + item.defaultContentInnerInset
        
        while options.count < item.options.count {
            let option = PollOptionView(frame: NSZeroRect)
            options.append(option)
            addSubview(option)
        }
        while options.count > item.options.count {
            let option = options.removeLast()
            option.removeFromSuperview()
        }
        for (i, option) in item.options.enumerated() {
            self.options[i].frame = NSMakeRect(0, y, frame.width, option.contentSize.height)
            self.options[i].update(with: option, animated: animated)
            y += option.contentSize.height
            if i != item.options.count - 1 {
                y += PollOption.spaceBetweenOptions
            }
        }
        
        if let totalVotesText = item.totalVotesText {
            y += item.defaultContentInnerInset
            if totalVotesTextView == nil {
                totalVotesTextView = TextView()
                totalVotesTextView!.userInteractionEnabled = false
                totalVotesTextView!.isSelectable = false
                addSubview(totalVotesTextView!)
            }
            totalVotesTextView?.update(totalVotesText, origin: NSMakePoint(item.bubbleContentInset, y))
        } else {
            totalVotesTextView?.removeFromSuperview()
            totalVotesTextView = nil
        }
    }
    
    override func layout() {
        super.layout()
        


    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}
