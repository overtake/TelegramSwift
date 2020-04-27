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
import TelegramCore
import SyncCore
import Postbox
import SwiftSignalKit
import SyncCore

private enum PeerAvatarReference : Equatable {
    static func == (lhs: PeerAvatarReference, rhs: PeerAvatarReference) -> Bool {
        switch lhs {
        case let .image(lhsPeer, rep):
            if case .image(let rhsPeer, rep) = rhs {
                return lhsPeer.isEqual(rhsPeer)
            } else {
                return false
            }
        }
    }
    
    case image(Peer, TelegramMediaImageRepresentation?)
    
        var peerId: PeerId {
        switch self {
        case let .image(value, _):
            return value.id
        }
    }
}

private extension PeerAvatarReference {
    init(peer: Peer) {
        self = .image(peer, peer.smallProfileImage)
    }
}

func isPollEffectivelyClosed(message: Message, poll: TelegramMediaPoll) -> Bool {
    if poll.isClosed {
        return true
    } else if let deadlineTimeout = poll.deadlineTimeout, message.id.namespace == Namespaces.Message.Cloud {
        let startDate: Int32
        if let forwardInfo = message.forwardInfo {
            startDate = forwardInfo.date
        } else {
            startDate = message.timestamp
        }
        
        let timestamp = Int32(CFAbsoluteTimeGetCurrent() + NSTimeIntervalSince1970)
        if timestamp >= startDate + deadlineTimeout {
            return true
        } else {
            return false
        }
    } else {
        return false
    }
}



private let mergedImageSize: CGFloat = 16.0
private let mergedImageSpacing: CGFloat = 15.0

private let avatarFont = NSFont.avatar(8.0)

private final class MergedAvatarsView: Control {
    private var peers: [PeerAvatarReference] = []
    private var images: [PeerId: CGImage] = [:]
    private var disposables: [PeerId: Disposable] = [:]
    
    
    deinit {
        for (_, disposable) in self.disposables {
            disposable.dispose()
        }
    }
    
    func update(context: AccountContext, peers: [Peer], message: Message?, synchronousLoad: Bool) {
        var filteredPeers = Array(peers.map(PeerAvatarReference.init).prefix(3))

        if filteredPeers != self.peers {
            self.peers = filteredPeers
            
            var validImageIds: [PeerId] = []
            for peer in filteredPeers {
                if case .image = peer {
                    validImageIds.append(peer.peerId)
                }
            }
            
            var removedImageIds: [PeerId] = []
            for (id, _) in self.images {
                if !validImageIds.contains(id) {
                    removedImageIds.append(id)
                }
            }
            var removedDisposableIds: [PeerId] = []
            for (id, disposable) in self.disposables {
                if !validImageIds.contains(id) {
                    disposable.dispose()
                    removedDisposableIds.append(id)
                }
            }
            for id in removedImageIds {
                self.images.removeValue(forKey: id)
            }
            for id in removedDisposableIds {
                self.disposables.removeValue(forKey: id)
            }
            for peer in filteredPeers {
                switch peer {
                case let .image(peer, representation):
                    if self.disposables[peer.id] == nil {
                        let signal = peerAvatarImage(account: context.account, photo: PeerPhoto.peer(peer, representation, peer.displayLetters, message), displayDimensions: NSMakeSize(mergedImageSize, mergedImageSize), scale: backingScaleFactor, font: avatarFont, synchronousLoad: synchronousLoad)
                        let disposable = (signal
                            |> deliverOnMainQueue).start(next: { [weak self] image in
                                guard let strongSelf = self else {
                                    return
                                }
                                if let image = image.0 {
                                    strongSelf.images[peer.id] = image
                                    strongSelf.setNeedsDisplay()
                                }
                            })
                        self.disposables[peer.id] = disposable
                    }
                }
            }
            self.setNeedsDisplay()
        }
    }
    
    override func draw(_ layer: CALayer, in context: CGContext) {
        super.draw(layer, in: context)
        
        
        context.setBlendMode(.copy)
        context.setFillColor(NSColor.clear.cgColor)
        context.fill(bounds)

        
        context.setBlendMode(.copy)
        
        var currentX = mergedImageSize + mergedImageSpacing * CGFloat(self.peers.count - 1) - mergedImageSize
        for i in (0 ..< self.peers.count).reversed() {
            context.saveGState()
            
            context.translateBy(x: frame.width / 2.0, y: frame.height / 2.0)
            context.scaleBy(x: 1.0, y: -1.0)
            context.translateBy(x: -frame.width / 2.0, y: -frame.height / 2.0)
            
            let imageRect = CGRect(origin: CGPoint(x: currentX, y: 0.0), size: CGSize(width: mergedImageSize, height: mergedImageSize))
            context.setFillColor(NSColor.clear.cgColor)
            context.fillEllipse(in: imageRect.insetBy(dx: -1.0, dy: -1.0))
            
            if let image = self.images[self.peers[i].peerId] {
                context.draw(image, in: imageRect)
            } else {
                context.setFillColor(NSColor.gray.cgColor)
                context.fillEllipse(in: imageRect)
            }
            
            currentX -= mergedImageSpacing
            context.restoreGState()
        }
    }
}



extension TelegramMediaPoll {
    var title: String {
        if isClosed {
            return L10n.chatPollTypeClosed
        } else {
            switch self.kind {
            case .quiz:
                switch self.publicity {
                case .anonymous:
                    return L10n.chatPollTypeAnonymousQuiz
                case .public:
                    return L10n.chatPollTypeQuiz
                }
            default:
                switch self.publicity {
                case .anonymous:
                    return L10n.chatPollTypeAnonymous
                case .public:
                    return L10n.chatPollTypePublic
                }
            }
        }
    }
    
    var isMultiple: Bool {
        switch kind {
        case let .poll(multipleAnswers):
            return multipleAnswers
        default:
            return false
        }
    }
    var isQuiz: Bool {
        switch kind {
        case .poll:
            return false
        default:
            return true
        }
    }
}

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
        if items[i].remainder == 0 {
            break
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

func countNicePercent(votes:[Int], total: Int) -> [Int] {
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
    let isCorrect: Bool?
    let isQuiz: Bool
    let isMultipleSelected: Bool
    init(option:TelegramMediaPollOption, nameText: TextViewLayout, percent: Float?, realPercent: Float, voteCount: Int32, isSelected: Bool, isIncoming: Bool, isBubbled: Bool, voted: Bool, isLoading: Bool, presentation: TelegramPresentationTheme, isCorrect: Bool?, isQuiz: Bool, isMultipleSelected: Bool, vote: @escaping()->Void = {}, contentSize: NSSize = NSZeroSize) {
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
        self.isCorrect = isCorrect
        self.isQuiz = isQuiz
        self.isMultipleSelected = isMultipleSelected
    }
    
    func withUpdatedLoading(_ isLoading: Bool) -> PollOption {
        return PollOption(option: self.option, nameText: self.nameText, percent: self.percent, realPercent: self.realPercent, voteCount: self.voteCount, isSelected: self.isSelected, isIncoming: self.isIncoming, isBubbled: self.isBubbled, voted: self.voted, isLoading: isLoading, presentation: self.presentation, isCorrect: self.isCorrect, isQuiz: self.isQuiz, isMultipleSelected: self.isMultipleSelected, vote: self.vote, contentSize: self.contentSize)
    }
    func withUpdatedContentSize(_ contentSize: NSSize) -> PollOption {
        return PollOption(option: self.option, nameText: self.nameText, percent: self.percent, realPercent: self.realPercent, voteCount: self.voteCount, isSelected: self.isSelected, isIncoming: self.isIncoming, isBubbled: self.isBubbled, voted: self.voted, isLoading: self.isLoading, presentation: self.presentation, isCorrect: self.isCorrect, isQuiz: self.isQuiz, isMultipleSelected: self.isMultipleSelected, vote: self.vote, contentSize: contentSize)
    }
    func withUpdatedSelected(_ isSelected: Bool) -> PollOption {
        return PollOption(option: self.option, nameText: self.nameText, percent: self.percent, realPercent: self.realPercent, voteCount: self.voteCount, isSelected: isSelected, isIncoming: self.isIncoming, isBubbled: self.isBubbled, voted: self.voted, isLoading: self.isLoading, presentation: self.presentation, isCorrect: self.isCorrect, isQuiz: self.isQuiz, isMultipleSelected: self.isMultipleSelected, vote: self.vote, contentSize: self.contentSize)
    }
    
    
    static func ==(lhs: PollOption, rhs: PollOption) -> Bool {
        return lhs.option == rhs.option && lhs.percent == rhs.percent && lhs.isSelected == rhs.isSelected && lhs.isIncoming == rhs.isIncoming && lhs.isLoading == rhs.isLoading && lhs.contentSize == rhs.contentSize && lhs.voted == rhs.voted && lhs.realPercent == rhs.realPercent && lhs.voteCount == rhs.voteCount && lhs.isCorrect == rhs.isCorrect && lhs.isQuiz == rhs.isQuiz && lhs.isMultipleSelected == rhs.isMultipleSelected
    }
    
    
    var leftOptionInset: CGFloat {
        return 40 + PollOption.spaceBetweenTexts
    }
    var currentPercentImage: CGImage? {
       return presentation.chat.pollPercentAnimatedIcon(isIncoming, isBubbled, value: Int(realPercent))
    }
    
    static var spaceBetweenTexts: CGFloat {
        return 6
    }
    static var spaceBetweenOptions: CGFloat {
        return 5
    }
    
    
    
    func measure(width: CGFloat) -> NSSize {
        nameText.measure(width: width - leftOptionInset)
        let contentSize = NSMakeSize(nameText.layoutSize.width + leftOptionInset, 10 + nameText.layoutSize.height + PollOption.spaceBetweenOptions)
        return contentSize
    }
}

class ChatPollItem: ChatRowItem {
    private(set) fileprivate var titleText:TextViewLayout!
    private(set) fileprivate var titleTypeText:TextViewLayout!

    private(set) fileprivate var options:[PollOption] = []
    private(set) fileprivate var totalVotesText:TextViewLayout?

    fileprivate let poll: TelegramMediaPoll
    
    var actionButtonText: String? {
        if isBotQuiz {
            return nil
        }
        if self.isClosed {
            if poll.results.totalVoters == 0 || poll.results.totalVoters == nil {
                return nil
            }
            if poll.publicity != .anonymous {
                return L10n.chatPollViewResults
            } else {
                return nil
            }
        }
        let hasSelected = options.contains(where: { $0.isSelected })
        if poll.isMultiple {
            if !hasSelected {
                return L10n.chatPollSubmitVote
            } else {
                if poll.publicity != .anonymous {
                    if hasSelected {
                        return L10n.chatPollViewResults
                    }
                }
            }
        } else {
            if poll.publicity != .anonymous {
                if hasSelected {
                    return L10n.chatPollViewResults
                }
            }
        }
        return nil
    }
    
    var actionButtonIsEnabled: Bool {
        guard let message = message else {
            return false
        }
        if message.flags.contains(.Failed) || message.flags.contains(.Sending) || message.flags.contains(.Unsent) {
            return false
        }
        let hasSelected = options.contains(where: { $0.isMultipleSelected }) || options.contains(where: { $0.isSelected })
        if poll.isMultiple {
            return hasSelected
        } else {
            return true
        }
    }
    
    var isClosed: Bool {
       return isPollEffectivelyClosed(message: message!, poll: poll)
    }
    var isBotQuiz: Bool {
        if let message = message {
            if self.poll.isQuiz {
                return messageMainPeer(message)?.isBot == true
            }
        }
        return false
    }
    
    override init(_ initialSize: NSSize, _ chatInteraction: ChatInteraction, _ context: AccountContext, _ object: ChatHistoryEntry, _ downloadSettings: AutomaticMediaDownloadSettings, theme: TelegramPresentationTheme) {
        
        let poll = object.message!.media[0] as! TelegramMediaPoll
        self.poll = poll
        
        super.init(initialSize, chatInteraction, context, object, downloadSettings, theme: theme)
    
        
        
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
            let isCorrect: Bool?
            let voted = poll.results.voters?.first(where: {$0.selected}) != nil
            
            var votedCount: Int32 = 0
            if let vote = poll.results.voters?.first(where: {$0.opaqueIdentifier == option.opaqueIdentifier}), let totalVoters = poll.results.totalVoters, (voted || self.isClosed) {
                percent = maximum == 0 ? 0 : (Float(percents[i]) / Float(maximum))
                realPercent = totalVoters == 0 ? 0 : Float(percents[i])
                isSelected = vote.selected
                votedCount = vote.count
                if poll.kind == .quiz {
                    isCorrect = vote.isCorrect
                } else {
                   isCorrect = nil
                }
            } else {
                percent = poll.results.totalVoters == nil || poll.results.totalVoters == 0 ? (isClosed ? 0 : nil) : voted ? 0 : (isClosed ? 0 : nil)
                realPercent = 0
                isSelected = false
                isCorrect = nil
            }
            
            let nameFont: NSFont = .normal(.text)//voted && isSelected ? .bold(.text) : .normal(.text)
            let nameLayout = TextViewLayout(.initialize(string: option.text, color: self.presentation.chat.textColor(isIncoming, renderType == .bubble), font: nameFont), alwaysStaticItems: true)

            
            let wrapper = PollOption(option: option, nameText: nameLayout, percent: percent, realPercent: realPercent, voteCount: votedCount, isSelected: isSelected, isIncoming: isIncoming, isBubbled: renderType == .bubble, voted: voted, isLoading: object.additionalData.pollStateData.identifiers.contains(option.opaqueIdentifier) && object.additionalData.pollStateData.isLoading, presentation: self.presentation, isCorrect: isCorrect, isQuiz: poll.kind == .quiz, isMultipleSelected: object.additionalData.pollStateData.identifiers.contains(option.opaqueIdentifier), vote: { [weak self] in
                self?.voteOption(option)
            })
            
            options.append(wrapper)
        }
        self.options = options
        

        let totalCount = poll.results.totalVoters ?? 0
        
        var totalText = poll.isQuiz ? L10n.chatQuizTotalVotesCountable(Int(totalCount)) : L10n.chatPollTotalVotes1Countable(Int(totalCount))
        totalText = totalText.replacingOccurrences(of: "\(totalCount)", with: Int(totalCount).separatedNumber)
        
        if actionButtonText == nil && !isBotQuiz {
            let text: String
            if totalCount > 0 {
                text = totalText
            } else {
                if poll.isQuiz {
                    text = self.isClosed ? L10n.chatQuizTotalVotesResultEmpty : L10n.chatQuizTotalVotesEmpty
                } else {
                    text = self.isClosed ? L10n.chatPollTotalVotesResultEmpty : L10n.chatPollTotalVotesEmpty
                }
            }
            self.totalVotesText = TextViewLayout(.initialize(string: text, color: self.presentation.chat.grayText(isIncoming, renderType == .bubble), font: .normal(12)), maximumNumberOfLines: 1, alwaysStaticItems: true)
        } else {
            self.totalVotesText = nil
        }
        

        
        self.titleText = TextViewLayout(.initialize(string: poll.text, color: self.presentation.chat.textColor(isIncoming, renderType == .bubble), font: .medium(.text)), alwaysStaticItems: true)
        
        let typeText: String = self.isBotQuiz ? L10n.chatQuizTextType : poll.title
        
        self.titleTypeText = TextViewLayout(.initialize(string: typeText, color: self.presentation.chat.grayText(isIncoming, renderType == .bubble), font: .normal(12)), maximumNumberOfLines: 1, alwaysStaticItems: true)
    }
    
    override var additionalLineForDateInBubbleState: CGFloat? {
        var size: NSSize = .zero
        if let action = self.actionButtonText {
            size = TitleButton.size(with: action, font: .normal(.text))
        } else if let totalVotesText = self.totalVotesText {
            size = totalVotesText.layoutSize
        }
        
        if size.width > 0 {
            let dif = contentSize.width - (contentSize.width / 2 + size.width / 2)
            if dif < (rightSize.width + insetBetweenContentAndDate) {
                return 20
            }
            
        }
        
        if isBotQuiz {
            return 10
        }
        
        return super.additionalLineForDateInBubbleState
    }

    
    override var isFixedRightPosition: Bool {
        return true
    }
    
    override func menuItems(in location: NSPoint) -> Signal<[ContextMenuItem], NoError> {
        return super.menuItems(in: location) |> map { [weak self] items in
            guard let `self` = self, let message = self.message else { return items }
            var items = items
            if let poll = message.media.first as? TelegramMediaPoll {
                if !self.isClosed && !message.flags.contains(.Unsent) && !message.flags.contains(.Failed) {
                    var index: Int = 0
                    if let _ = poll.results.voters?.first(where: {$0.selected}), poll.kind != .quiz {
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
                            
                            items.insert(ContextMenuItem(poll.kind == .quiz ? L10n.chatQuizStop : L10n.chatPollStop, handler: { [weak self] in
                                confirm(for: mainWindow, header: poll.kind == .quiz ? L10n.chatQuizStopConfirmHeader : L10n.chatPollStopConfirmHeader, information: poll.kind == .quiz ? L10n.chatQuizStopConfirmText : L10n.chatPollStopConfirmText, okTitle: L10n.alertConfirmStop, successHandler: { [weak self] _ in
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
        
        if canInvokeVote {
            guard let message = message else { return }
            self.chatInteraction.vote(message.id, [], true)
        }
        
    }
    
    private func voteOption(_ option: TelegramMediaPollOption) {
        if canInvokeVote, !self.options.contains(where: { $0.isSelected }) {
            guard let message = message else { return }
            var identifiers = self.entry.additionalData.pollStateData.identifiers
            if let index = identifiers.firstIndex(of: option.opaqueIdentifier) {
                identifiers.remove(at: index)
            } else {
                identifiers.append(option.opaqueIdentifier)
            }
            chatInteraction.vote(message.id, identifiers, !self.poll.isMultiple)
        } else {
            if self.options.contains(where: { $0.isSelected }) || self.isClosed, self.poll.publicity == .public {
                guard let message = message else {
                    return
                }
                if message.flags.contains(.Failed) || message.flags.contains(.Unsent) || message.flags.contains(.Sending) || self.options.contains(where: { $0.isLoading }) {
                    return
                }
                self.invokeAction(fromOption: option.opaqueIdentifier)
            }
        }
    }
    
    private var canInvokeVote: Bool {
        guard let message = message else {
            return false
        }
        if message.flags.contains(.Failed) || message.flags.contains(.Unsent) || message.flags.contains(.Sending) {
            return false
        }
        if self.isClosed {
            return false
        }
        if self.options.contains(where: { $0.isLoading }) {
            return false
        }
        
        return true
    }
    
    fileprivate func invokeAction(fromOption: Data? = nil) {
        
        guard let message = message else { return }
        let hasSelected = self.options.contains(where: { $0.isSelected })
        if canInvokeVote, !hasSelected {
            let identifiers = self.entry.additionalData.pollStateData.identifiers
            chatInteraction.vote(message.id, identifiers, true)
        } else {
            if !isBotQuiz {
                showModal(with: PollResultController(context: context, message: message, scrollToOption: fromOption), for: context.window)
            }
        }
    }
    
    override func viewClass() -> AnyClass {
        return ChatPollItemView.self
    }
    
    override var instantlyResize: Bool {
        return true
    }

    override func makeContentSize(_ width: CGFloat) -> NSSize {
        
        let width = min(width, 320)
        
        
        var rightInset: CGFloat = 0
        
        if let _ = poll.results.solution, options.contains(where: { $0.isSelected }) || self.isClosed {
            rightInset += 10
        }
        let deadlineTimeout = poll.deadlineTimeout
        let displayDeadline = !options.contains(where: { $0.isSelected })

        
        
        titleText.measure(width: width - bubbleContentInset - rightInset)
        titleTypeText.measure(width: width - bubbleContentInset - rightInset)
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
        if let _ = self.actionButtonText {
            contentHeight += defaultContentInnerInset
            contentHeight += 15
        }
        
        return NSMakeSize(max(width, contentWidth), contentHeight)
    }
    
    override func copyAndUpdate(animated: Bool) {
        if let table = self.table {
            let item = ChatRowItem.item(table.frame.size, from: self.entry, interaction: self.chatInteraction, downloadSettings: self.downloadSettings, theme: self.presentation)
            _ = item.makeSize(table.frame.width, oldWidth: 0)
            let transaction = TableUpdateTransition(deleted: [], inserted: [], updated: [(self.index, item)], animated: animated)
            table.merge(with: transaction)
        }
    }
    
}


final class ChatPollItemView : ChatRowView {
    private var contentNode:PollView = PollView(frame: NSZeroRect)
    required init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        addSubview(contentNode)
    }
    
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
    
    
    func doAfterAnswer() {
        guard let item = item as? ChatPollItem else { return }

        let selected = item.options.first(where: { $0.isSelected })
        
        if let selected = selected {
            if item.poll.kind == .quiz {
                if let isCorrect = selected.isCorrect {
                    if isCorrect {
                        doWhenCorrectAnswer()
                    } else {
                       doWhenIncorrectAnswer()
                    }
                }
            }
        }
    }
    
    func doWhenCorrectAnswer() {
        guard let item = item as? ChatPollItem else { return }
        PlayConfetti(for: item.context.window)
        if FastSettings.inAppSounds {
            playSoundEffect(.confetti)
        }
    }
    func doWhenIncorrectAnswer() {
        shakeContentView()
        
        if FastSettings.inAppSounds {
            NSSound.beep()
        }
        self.contentNode.showSolution()
    }
    
    override func set(item: TableRowItem, animated: Bool) {
        
        guard let item = item as? ChatPollItem else { return }
        super.set(item: item, animated: animated)

        contentNode.change(size: NSMakeSize(contentFrameModifier.width, item.contentSize.height), animated: animated)
        contentNode.update(with: item, animated: animated)
        
    }
    
    override func mouseDown(with event: NSEvent) {
        super.mouseDown(with: event)
    }
    

    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override func canStartTextSelecting(_ event: NSEvent) -> Bool {
        
        let point = contentView.convert(event.locationInWindow, from: nil)
        return NSPointInRect(point, NSMakeRect(0, contentNode.titleView.frame.minY, contentNode.frame.width, contentNode.titleView.frame.height))
    }
    
    override var selectableTextViews: [TextView] {
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
    
    private var selectedImageView: ImageView?
    
    private var option: PollOption?
    required init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        nameView.userInteractionEnabled = false
        nameView.isSelectable = false
        progressView.hasMinumimVisibility = true
        addSubview(nameView)
        addSubview(progressView)
        addSubview(borderView)
        borderView.userInteractionEnabled = false
        progressView.userInteractionEnabled = false
        progressView.roundCorners = true
        
        progressView.isEventLess = true
        
        set(handler: { [weak self] _ in
            self?.option?.vote()
        }, for: .Click)
    }
    
    var defaultInset: CGFloat {
        return 13
    }
    
    func update(with option: PollOption, animated: Bool) {
        let animated = animated && self.option != option
        let previousOption = self.option

        let previousPercent = self.option?.realPercent

        self.option = option

        
        let duration: Double = 0.4
        let timingFunction: CAMediaTimingFunctionName = .spring
        
        nameView.update(option.nameText, origin: NSMakePoint(option.leftOptionInset, 0))
        progressView.setFrameOrigin(NSMakePoint(nameView.frame.minX, nameView.frame.maxY + 5))
        borderView.backgroundColor = option.presentation.chat.pollOptionBorder(option.isIncoming, option.isBubbled)
        borderView.frame = NSMakeRect(nameView.frame.minX, nameView.frame.maxY + 5 - .borderSize + progressView.progressHeight, frame.width - nameView.frame.minX, .borderSize)
        borderView.change(opacity: option.percent != nil ? 0 : 1, animated: animated, duration: duration)
        progressView.change(opacity: option.percent == nil ? 0 : 1, animated: animated, duration: duration)
        
        let votedColor: NSColor
        
        
        if option.isSelected {
            var justAdded = false
            if self.selectedImageView == nil {
                self.selectedImageView = ImageView()
                addSubview(self.selectedImageView!)
                justAdded = true
            }
            
            guard let selectedImageView = self.selectedImageView else {
                return
            }
            
            if option.isQuiz, let isCorrect = option.isCorrect {
                if isCorrect {
                    selectedImageView.image = option.presentation.chat.pollSelectedCorrect(option.isIncoming, option.isBubbled, icons: option.presentation.icons)
                } else {
                    selectedImageView.image = option.presentation.chat.pollSelectedIncorrect(option.isIncoming, option.isBubbled, icons: option.presentation.icons)
                }
            } else {
                selectedImageView.image = option.presentation.chat.pollSelected(option.isIncoming, option.isBubbled, icons: option.presentation.icons)
            }
            selectedImageView.setFrameSize(NSMakeSize(12, 12))
            
            selectedImageView.setFrameOrigin(NSMakePoint(progressView.frame.minX - selectedImageView.frame.width - 4, floorToScreenPixels(backingScaleFactor, progressView.frame.midY - selectedImageView.frame.height / 2)))
            
            if justAdded && animated {
                selectedImageView.layer?.animateScaleSpring(from: 0.2, to: 1.0, duration: duration)
                selectedImageView.layer?.animateAlpha(from: 0, to: 1, duration: duration, timingFunction: timingFunction)
            }
        } else {
            if option.isQuiz, let isCorrect = option.isCorrect, isCorrect {
                var justAdded = false
                if self.selectedImageView == nil {
                    self.selectedImageView = ImageView()
                    addSubview(self.selectedImageView!)
                    justAdded = true
                }
                
                guard let selectedImageView = self.selectedImageView else {
                    return
                }
                
                selectedImageView.image = option.presentation.chat.pollSelected(option.isIncoming, option.isBubbled, icons: option.presentation.icons)

                selectedImageView.setFrameSize(NSMakeSize(12, 12))
                
                selectedImageView.setFrameOrigin(NSMakePoint(progressView.frame.minX - selectedImageView.frame.width - 4, floorToScreenPixels(backingScaleFactor, progressView.frame.midY - selectedImageView.frame.height / 2)))
                
                if justAdded && animated {
                    selectedImageView.layer?.animateScaleSpring(from: 0.2, to: 1.0, duration: duration)
                    selectedImageView.layer?.animateAlpha(from: 0, to: 1, duration: duration, timingFunction: timingFunction)
                }
                
            } else {
                if let selectedImageView = self.selectedImageView {
                    self.selectedImageView = nil
                    if animated {
                        selectedImageView.layer?.animateScaleSpring(from: 1, to: 0.2, duration: duration, removeOnCompletion: false)
                        selectedImageView.layer?.animateAlpha(from: 1, to: 0, duration: duration, timingFunction: timingFunction, removeOnCompletion: false, completion: { [weak selectedImageView] _ in
                            selectedImageView?.removeFromSuperview()
                        })
                    } else {
                        selectedImageView.removeFromSuperview()
                    }
                }
            }
            
            
            
        }
        
        if option.isSelected, let isCorrect = option.isCorrect {
            votedColor = isCorrect ? option.presentation.chat.greenUI(option.isIncoming, option.isBubbled) : option.presentation.chat.redUI(option.isIncoming, option.isBubbled)
        } else {
            votedColor = option.presentation.chat.webPreviewActivity(option.isIncoming, option.isBubbled)
        }
        progressView.style = ControlStyle(foregroundColor: votedColor, backgroundColor: .clear)

        if let progress = option.percent {
            var totalOptionVotes = option.isQuiz ? L10n.chatQuizTooltipVotesCountable(Int(option.voteCount)) : L10n.chatPollTooltipVotesCountable(Int(option.voteCount))
            totalOptionVotes = totalOptionVotes.replacingOccurrences(of: "\(option.voteCount)", with: Int(option.voteCount).separatedNumber)
            
            toolTip = option.voteCount == 0 ? (option.isQuiz ? L10n.chatQuizTooltipNoVotes : L10n.chatPollTooltipNoVotes) : totalOptionVotes
            
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
            percentView?.setFrameOrigin(NSMakePoint(nameView.frame.minX - percentView!.frame.width - PollOption.spaceBetweenTexts, nameView.frame.minY + 1))
            
            if previousPercent != option.realPercent, animated {
                let images = option.presentation.chat.pollPercentAnimatedIcons(option.isIncoming, option.isBubbled, from: CGFloat(previousPercent ?? 0), to: CGFloat(option.realPercent), duration: duration / 2)
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
                        let images = option.presentation.chat.pollPercentAnimatedIcons(option.isIncoming, option.isBubbled, from: CGFloat(previousPercent ?? 0), to: CGFloat(0), duration: duration / 2)
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
//                progressIndicator?.lineWidth = 1.0
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
                selectingView?.animates = animated || (previousOption != nil && previousOption?.isMultipleSelected != option.isMultipleSelected)
                if option.isMultipleSelected {
                    selectingView?.image = option.presentation.chat.pollSelected(option.isIncoming, option.isBubbled, icons: option.presentation.icons)
                } else {
                    selectingView?.image = option.presentation.chat.pollOptionUnselectedImage(option.isIncoming, option.isBubbled)
                }
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
    private var actionButton: TitleButton?
    private var totalVotesTextView: TextView?
    
    private var mergedAvatarsView: MergedAvatarsView?
    
    private var solutionButton: ImageButton?
    private var timerView: PollBubbleTimerView?

    private var options:[PollOptionView] = []
    required init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
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
            
            
            self.options[i].frame = NSMakeRect(0, y - (i > 0 ? PollOption.spaceBetweenOptions : 0), frame.width, option.contentSize.height)
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
            guard let totalVotesTextView = self.totalVotesTextView else {
                return
            }
            totalVotesTextView.update(totalVotesText, origin: NSMakePoint(floorToScreenPixels(backingScaleFactor, (frame.width - totalVotesText.layoutSize.width) / 2), y))
        } else {
            totalVotesTextView?.removeFromSuperview()
            totalVotesTextView = nil
        }
        
        if let actionText = item.actionButtonText {
            y += item.defaultContentInnerInset - 4
            if self.actionButton == nil {
                self.actionButton = TitleButton()
                self.addSubview(self.actionButton!)
            }
            guard let actionButton = self.actionButton else {
                return
            }
            
            actionButton.isEnabled = item.actionButtonIsEnabled
            
            actionButton.removeAllHandlers()
            actionButton.set(handler: { [weak item] _ in
                item?.invokeAction()
            }, for: .SingleClick)
            
            actionButton.set(font: .normal(.text), for: .Normal)
            actionButton.set(color: item.presentation.chat.webPreviewActivity(item.isIncoming, item.isBubbled), for: .Normal)
            actionButton.set(text: actionText, for: .Normal)
            _ = actionButton.sizeToFit(NSMakeSize(10, 4), thatFit: false)
            actionButton.centerX(y: y)
        } else {
            self.actionButton?.removeFromSuperview()
            self.actionButton = nil
        }
        
        guard let message = item.message else {
            return
        }
        
        var avatarPeers: [Peer] = []
        if !item.isBotQuiz {
            for peerId in item.poll.results.recentVoters {
                if let peer = message.peers[peerId] {
                    avatarPeers.append(peer)
                }
            }
        }
        
        if !avatarPeers.isEmpty {
            if self.mergedAvatarsView == nil {
                self.mergedAvatarsView = MergedAvatarsView(frame: NSMakeRect(0, 0, mergedImageSpacing * CGFloat(avatarPeers.count) + 2, mergedImageSize))
                addSubview(self.mergedAvatarsView!)
            }
            self.mergedAvatarsView?.frame = CGRect(origin: NSMakePoint(typeView.frame.maxX + 6, typeView.frame.minY), size: NSMakeSize(mergedImageSpacing * CGFloat(avatarPeers.count) + 2, mergedImageSize))
            self.mergedAvatarsView?.update(context: item.context, peers: avatarPeers, message: message, synchronousLoad: false)
            self.mergedAvatarsView?.removeAllHandlers()
            
            self.mergedAvatarsView?.set(handler: { [weak item] _ in
                if item?.actionButtonText == L10n.chatPollViewResults, item?.actionButtonIsEnabled == true {
                    item?.invokeAction()
                }
            }, for: .Click)
        } else {
            self.mergedAvatarsView?.removeFromSuperview()
            self.mergedAvatarsView = nil
        }
        
        if let solution = item.poll.results.solution, item.options.contains(where: { $0.isSelected }) || item.isClosed {
            var mayApplyAnimation = false
            if solutionButton == nil {
                solutionButton = ImageButton()
                addSubview(solutionButton!)
                mayApplyAnimation = animated
            }
            if let solutionButton = self.solutionButton {
                solutionButton.set(image: item.presentation.chat.quizSolution(item), for: .Normal)
                solutionButton.style = ControlStyle(font: nil, foregroundColor: theme.colors.accent, highlightColor: theme.colors.accent.withAlphaComponent(0.7))
                _ = solutionButton.sizeToFit()
                solutionButton.setFrameOrigin(NSMakePoint(frame.width - solutionButton.frame.width - 6, 0))
                
                if mayApplyAnimation {
                    solutionButton.layer?.animateScaleSpring(from: 0.2, to: 1.0, duration: 0.3)
                }
            }
            solutionButton?.removeAllHandlers()
            
            
            solutionButton?.set(handler: { [weak item] control in
                
                guard let item = item else {
                    return
                }
                let text = ChatMessageItem.applyMessageEntities(with: [TextEntitiesMessageAttribute(entities: solution.entities)], for: solution.text, context: item.context, fontSize: .text, openInfo: item.chatInteraction.openInfo, textColor: .white, linkColor: nightAccentPalette.link, monospacedPre: .redUI, monospacedCode: .greenUI, mediaDuration: nil)
                
                tooltip(for: control, text: solution.text, attributedText: text, interactions: globalLinkExecutor, timeout: 10.0)
            }, for: .Click)
            
        } else {
            solutionButton?.removeFromSuperview()
            solutionButton = nil
        }
        
        let deadlineTimeout = item.poll.deadlineTimeout
        var displayDeadline = true
        if let voters = item.poll.results.voters {
            for voter in voters {
                if voter.selected {
                    displayDeadline = false
                    break
                }
            }
        }

        
        if let deadlineTimeout = deadlineTimeout, displayDeadline, !item.isClosed {
            let timerView: PollBubbleTimerView
            if let current = self.timerView {
                timerView = current
            } else {
                timerView = PollBubbleTimerView(frame: NSMakeRect(frame.width - 70 - 8, typeView.frame.minY, 70, 22))
                self.addSubview(timerView)
                self.timerView = timerView
                
                if animated {
                    timerView.layer?.animateScaleSpring(from: 0.2, to: 1.0, duration: 0.3)
                    timerView.layer?.animateAlpha(from: 0, to: 1, duration: 0.3)
                }
            }
            
            timerView.reachedTimeout = { [weak item] in
                item?.copyAndUpdate(animated: true)
            }
            var endDate: Int32?
            if message.id.namespace == Namespaces.Message.Cloud {
                let startDate: Int32
                if let forwardInfo = message.forwardInfo {
                    startDate = forwardInfo.date
                } else {
                    startDate = message.timestamp
                }
                endDate = startDate + deadlineTimeout
            }
            timerView.update(regularColor: item.presentation.chat.textColor(item.isIncoming, item.isBubbled), proximityColor: item.presentation.chat.redUI(item.isIncoming, item.isBubbled), timeout: deadlineTimeout, deadlineTimestamp: endDate)
            
        } else if let timerView = self.timerView {
            self.timerView = nil
            if animated {
                timerView.layer?.animateScaleSpring(from: 1, to: 0, duration: 0.3, removeOnCompletion: false, completion: { [weak timerView] _ in
                    timerView?.removeFromSuperview()
                })
                timerView.layer?.animateAlpha(from: 1, to: 0.2, duration: 0.3)
            } else {
                timerView.removeFromSuperview()
            }
        }
        
        
        
        
        
    }
    
    func showSolution() {
        self.solutionButton?.send(event: .Click)
    }
    
    override func layout() {
        super.layout()
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}
