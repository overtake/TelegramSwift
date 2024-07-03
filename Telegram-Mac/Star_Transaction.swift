//
//  Star_Transaction.swift
//  Telegram
//
//  Created by Mikhail Filimonov on 21.05.2024.
//  Copyright © 2024 Telegram. All rights reserved.
//

import Foundation
import TelegramCore
import Postbox
import Cocoa
import TGUIKit
import SwiftSignalKit


private final class GallerySupplyment : InteractionContentViewProtocol {
    private weak var tableView: TableView?
    init(tableView: TableView) {
        self.tableView = tableView
    }
    
    func contentInteractionView(for stableId: AnyHashable, animateIn: Bool) -> NSView? {
        if let tableView = tableView {
            let item = tableView.item(stableId: InputDataEntryId.custom(_id_header))
            return item?.view?.interactionContentView(for: stableId, animateIn: animateIn)
        }
        return nil
    }
    func interactionControllerDidFinishAnimation(interactive: Bool, for stableId: AnyHashable) {
        
    }
    func addAccesoryOnCopiedView(for stableId: AnyHashable, view: NSView) {
        
    }
    func videoTimebase(for stableId: AnyHashable) -> CMTimebase? {
        return nil
    }
    func applyTimebase(for stableId: AnyHashable, timebase: CMTimebase?) {
        
    }
}

private final class HeaderItem : GeneralRowItem {
    fileprivate let context: AccountContext
    fileprivate let transaction: StarsContext.State.Transaction
    fileprivate let peer: EnginePeer?
    fileprivate let headerLayout: TextViewLayout
    fileprivate let infoLayout: TextViewLayout
    fileprivate let descLayout: TextViewLayout?
    fileprivate let incoming: Bool
    
    fileprivate var refund: TextViewLayout?
    fileprivate let arguments: Arguments
    
    init(_ initialSize: NSSize, stableId: AnyHashable, context: AccountContext, transaction: StarsContext.State.Transaction, peer: EnginePeer?, arguments: Arguments) {
        self.context = context
        self.transaction = transaction
        self.peer = peer
        self.arguments = arguments
        
        let header: String
        let incoming: Bool = transaction.count > 0
        self.incoming = incoming
        switch transaction.peer {
        case .appStore:
            header = strings().starListTransactionAppStore
        case .fragment:
            header = strings().starListTransactionFragment
        case .playMarket:
            header = strings().starListTransactionPlayMarket
        case .premiumBot:
            header = strings().starListTransactionPremiumBot
        case .ads:
            header = strings().starListTransactionAds
        case .unsupported:
            header = strings().starListTransactionUnknown
        case .peer:
            if !transaction.media.isEmpty {
                header = strings().starsTransactionMediaPurchase
            } else {
                header = transaction.title ?? peer?._asPeer().displayTitle ?? ""
            }
        }
        
        self.headerLayout = .init(.initialize(string: header, color: theme.colors.text, font: .medium(18)), alignment: .center)
        
        let attr = NSMutableAttributedString()
        attr.append(string: "\(incoming ? "+" : "")\(transaction.count) \(clown)", color: incoming ? theme.colors.greenUI : theme.colors.redUI, font: .medium(15))
        attr.insertEmbedded(.embeddedAnimated(LocalAnimatedSticker.star_currency.file), for: clown)
        
        self.infoLayout = .init(attr)
        
        
        if !transaction.media.isEmpty {
            
            var description: String = ""
            
            let videoCount = transaction.media.filter {
                $0 is TelegramMediaFile
            }.count
            let photoCount = Int(transaction.media.count - videoCount)
            
            if photoCount > 0 && videoCount > 0 {
                description = strings().starsTransferMediaAnd(strings().starsTransferPhotosCountable(photoCount), strings().starsTransferVideosCountable(videoCount))
            } else if photoCount > 0 {
                if photoCount > 1 {
                    description += strings().starsTransferPhotosCountable(photoCount)
                } else {
                    description += strings().starsTransferSinglePhoto
                }
            } else if videoCount > 0 {
                if videoCount > 1 {
                    description += strings().starsTransferVideosCountable(videoCount)
                } else {
                    description += strings().starsTransferSingleVideo
                }
            }
            self.descLayout = .init(.initialize(string: description, color: theme.colors.text, font: .normal(.text)), alignment: .center)
        } else if let desc = transaction.description {
            self.descLayout = .init(.initialize(string: desc, color: theme.colors.text, font: .normal(.text)), alignment: .center)
        } else {
            self.descLayout = nil
        }
        
        if transaction.flags.contains(.isRefund) {
            self.refund = .init(.initialize(string: strings().starListRefund, color: theme.colors.greenUI, font: .medium(.text)), alignment: .center)
            self.refund?.measure(width: .greatestFiniteMagnitude)
        } else {
            self.refund = nil
        }
        
        super.init(initialSize, stableId: stableId, viewType: .legacy, inset: .init())
    }
    
    override func makeSize(_ width: CGFloat, oldWidth: CGFloat = 0) -> Bool {
        _ = super.makeSize(width, oldWidth: oldWidth)
        
        self.headerLayout.measure(width: width - 40)
        self.infoLayout.measure(width: width - 40)
        self.descLayout?.measure(width: width - 40)
        return true
    }
    
    override func viewClass() -> AnyClass {
        return HeaderView.self
    }
    override var height: CGFloat {
        var height = 10 + 80 + 10 + headerLayout.layoutSize.height + 5 + infoLayout.layoutSize.height
        if let descLayout {
            height += descLayout.layoutSize.height + 5 + 2
        }
        return height
    }
    
}

private final class HeaderView : GeneralContainableRowView {
    private var photo: TransformImageView?
    private var avatar: AvatarControl?
    private let control = Control(frame: NSMakeRect(0, 0, 80, 80))
    private let sceneView: GoldenStarSceneView
    private let dismiss = ImageButton()
    private let headerView = TextView()
    private let infoView = InteractiveTextView()
    private var refundView: TextView?
    private let infoContainer: View = View()
    private var outgoingView: ImageView?
    private var descView: TextView?
    required init(frame frameRect: NSRect) {
        self.sceneView = GoldenStarSceneView(frame: NSMakeRect(0, 0, frameRect.width, 150))
        super.init(frame: frameRect)
        addSubview(dismiss)
        addSubview(sceneView)
        addSubview(headerView)
        addSubview(control)
        infoContainer.addSubview(infoView)
        
        self.sceneView.sceneBackground = theme.colors.listBackground
        
        addSubview(infoContainer)
        
        sceneView.hideStar()
        
        control.scaleOnClick = true
        
        control.set(handler: { [weak self] _ in
            if let item = self?.item as? HeaderItem {
                item.arguments.previewMedia()
            }
        }, for: .Click)

    }
    
    override func interactionContentView(for innerId: AnyHashable, animateIn: Bool) -> NSView {
        return photo ?? self.control
    }
    
    override var backdorColor: NSColor {
        return theme.colors.listBackground
    }
    
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override func set(item: TableRowItem, animated: Bool = false) {
        super.set(item: item, animated: animated)
        
        guard let item = item as? HeaderItem else {
            return
        }
        
        if let media = item.transaction.media.first, let messageId = item.transaction.paidMessageId {
            if let view = self.avatar {
                performSubviewRemoval(view, animated: animated)
                self.avatar = nil
            }
            let current: TransformImageView
            
            if let view = self.photo {
                current = view
            } else {
                current = TransformImageView(frame: NSMakeRect(0, 0, 80, 80))
                current.preventsCapture = true
                if #available(macOS 10.15, *) {
                    current.layer?.cornerCurve = .continuous
                }
                control.addSubview(current)
                self.photo = current
            }
            current.layer?.cornerRadius = 10
            
            let reference = StarsTransactionReference(peerId: messageId.peerId, id: item.transaction.id, isRefund: item.transaction.flags.contains(.isRefund))
            
            var updateImageSignal: Signal<ImageDataTransformation, NoError>?
            
            if let image = media as? TelegramMediaImage {
                updateImageSignal = chatMessagePhoto(account: item.context.account, imageReference: ImageMediaReference.starsTransaction(transaction: reference, media: image), scale: backingScaleFactor, synchronousLoad: false, autoFetchFullSize: true)
            } else if let file = media as? TelegramMediaFile {
                updateImageSignal = chatMessageVideo(postbox: item.context.account.postbox, fileReference: .starsTransaction(transaction: reference, media: file), scale: backingScaleFactor)
            }

            if let updateImageSignal {
                current.setSignal(updateImageSignal, isProtected: true)
            }
            
            var dimensions: NSSize = current.frame.size
            
            if let image = media as? TelegramMediaImage {
                dimensions = image.representationForDisplayAtSize(PixelDimensions(current.frame.size))?.dimensions.size ?? current.frame.size
            } else if let file = media as? TelegramMediaFile {
                dimensions = file.dimensions?.size ?? current.frame.size
            }
        
            current.set(arguments: TransformImageArguments(corners: .init(radius: 10), imageSize: dimensions, boundingSize: current.frame.size, intrinsicInsets: .init()))
            
        } else if let photo = item.transaction.photo {
            if let view = self.avatar {
                performSubviewRemoval(view, animated: animated)
                self.avatar = nil
            }
            let current: TransformImageView
            if let view = self.photo {
                current = view
            } else {
                current = TransformImageView(frame: NSMakeRect(0, 0, 80, 80))
                if #available(macOS 10.15, *) {
                    current.layer?.cornerCurve = .continuous
                }
                control.addSubview(current)
                self.photo = current
            }
            current.layer?.cornerRadius = floor(current.frame.height / 2)

            current.setSignal(chatMessageWebFilePhoto(account: item.context.account, photo: photo, scale: backingScaleFactor))
    
            _ = fetchedMediaResource(mediaBox: item.context.account.postbox.mediaBox, userLocation: .other, userContentType: .other, reference: MediaResourceReference.standalone(resource: photo.resource)).start()
    
            current.set(arguments: TransformImageArguments(corners: .init(radius: 10), imageSize: photo.dimensions?.size ?? NSMakeSize(80, 80), boundingSize: current.frame.size, intrinsicInsets: .init()))

            
        } else {
            if let view = self.photo {
                performSubviewRemoval(view, animated: animated)
                self.photo = nil
            }
            
            let current: AvatarControl
            if let view = self.avatar {
                current = view
            } else {
                current = AvatarControl(font: .avatar(20))
                current.setFrameSize(NSMakeSize(80, 80))
                self.avatar = current
                control.addSubview(current)
            }
            current.setPeer(account: item.context.account, peer: item.peer?._asPeer())
        }
        
        self.headerView.update(item.headerLayout)
        self.infoView.set(text: item.infoLayout, context: item.context)
        
        self.dismiss.set(image: theme.icons.modalClose, for: .Normal)
        self.dismiss.sizeToFit()
        self.dismiss.scaleOnClick = true
        self.dismiss.autohighlight = false
        
        
        if item.peer == nil {
            let current: ImageView
            if let view = self.outgoingView {
                current = view
            } else {
                current = ImageView()
                control.addSubview(current)
                self.outgoingView = current
            }
            switch item.transaction.peer {
            case .appStore:
                current.image = NSImage(resource: .iconStarTransactionPreviewAppStore).precomposed()
            case .fragment:
                current.image = NSImage(resource: .iconStarTransactionPreviewFragment).precomposed()
            case .playMarket:
                current.image = NSImage(resource: .iconStarTransactionPreviewAndroid).precomposed()
            case .peer:
                break
            case .premiumBot:
                current.image = NSImage(resource: .iconStarTransactionPreviewPremiumBot).precomposed()
            case .unsupported:
                current.image = NSImage(resource: .iconStarTransactionPreviewUnknown).precomposed()
            case .ads:
                current.image = NSImage(resource: .iconStarTransactionPreviewFragment).precomposed()
            }
            current.setFrameSize(NSMakeSize(80, 80))
        } else if let view = self.outgoingView {
            performSubviewRemoval(view, animated: animated)
            self.outgoingView = nil
        }
        
        if let descLayout = item.descLayout {
            let current: TextView
            if let view = self.descView {
                current = view
            } else {
                current = TextView()
                self.addSubview(current)
                self.descView = current
            }
            current.update(descLayout)
        } else if let view = self.descView {
            performSubviewRemoval(view, animated: animated)
            self.descView = nil
        }
        
        if let refundLayout = item.refund {
            let current: TextView
            if let view = self.refundView {
                current = view
            } else {
                current = TextView()
                infoContainer.addSubview(current)
                self.refundView = current
            }
            current.update(refundLayout)
            current.setFrameSize(NSMakeSize(current.frame.width + 6, current.frame.height + 4))
            current.layer?.cornerRadius = .cornerRadius
            current.background = theme.colors.greenUI.withAlphaComponent(0.2)
        } else if let view = self.refundView {
            performSubviewRemoval(view, animated: animated)
            self.refundView = nil
        }
        
        infoContainer.setFrameSize(NSMakeSize(infoContainer.subviewsWidthSize.width + 4, infoContainer.subviewsWidthSize.height + 2))
        
        needsLayout = true
    }
    
    override func layout() {
        super.layout()
        sceneView.centerX(y: -10)
        
        control.centerX(y: 10)
        
        avatar?.center()
        photo?.center()
        outgoingView?.center()
        
        dismiss.setFrameOrigin(NSMakePoint(10, floorToScreenPixels((50 - dismiss.frame.height) / 2) - 10))
        
        
        headerView.centerX(y: 90 + 10)
        
        infoContainer.centerX(y: headerView.frame.maxY + 5)
        infoView.centerY(x: 0)
        refundView?.centerY(x: infoView.frame.maxX + 4, addition: -1)

        if let descView {
            descView.centerX(y: infoContainer.frame.maxY + 5)
        }
    }
    
    
}

private final class Arguments {
    let context: AccountContext
    let openPeer:(PeerId)->Void
    let copyTransaction:(String)->Void
    let openLink:(String)->Void
    let previewMedia:()->Void
    init(context: AccountContext, openPeer:@escaping(PeerId)->Void, copyTransaction:@escaping(String)->Void, openLink:@escaping(String)->Void, previewMedia:@escaping()->Void) {
        self.context = context
        self.openPeer = openPeer
        self.copyTransaction = copyTransaction
        self.openLink = openLink
        self.previewMedia = previewMedia
    }
}

private struct State : Equatable {
    var transaction: StarsContext.State.Transaction
    var peer: EnginePeer?
    var paidPeer: EnginePeer?
}

private let _id_header = InputDataIdentifier("_id_header")
private let _id_rows = InputDataIdentifier("_id_rows")

private func entries(_ state: State, arguments: Arguments) -> [InputDataEntry] {
    var entries:[InputDataEntry] = []
    
    var sectionId:Int32 = 0
    var index: Int32 = 0
    
    entries.append(.sectionId(sectionId, type: .customModern(10)))
    sectionId += 1
    
    entries.append(.custom(sectionId: sectionId, index: index, value: .none, identifier: _id_header, equatable: .init(state), comparable: nil, item: { initialSize, stableId in
        return HeaderItem(initialSize, stableId: stableId, context: arguments.context, transaction: state.transaction, peer: state.peer, arguments: arguments)
    }))
    
    entries.append(.sectionId(sectionId, type: .customModern(10)))
    sectionId += 1
  
    
    
    var rows: [InputDataTableBasedItem.Row] = []
    
    if let peer = state.peer {
        let from: TextViewLayout = .init(parseMarkdownIntoAttributedString("[\(peer._asPeer().displayTitle)](\(peer.id.toInt64()))", attributes: MarkdownAttributes(body: MarkdownAttributeSet(font: .medium(.text), textColor: theme.colors.text), bold: MarkdownAttributeSet(font: .bold(.text), textColor: theme.colors.text), link: MarkdownAttributeSet(font: .medium(.text), textColor: theme.colors.accentIcon), linkAttribute: { contents in
            return (NSAttributedString.Key.link.rawValue, contents)
        })), maximumNumberOfLines: 1, alwaysStaticItems: true)
        
        from.interactions.processURL = { _ in
            arguments.openPeer(peer.id)
        }
        
        let fromText: String
        if peer._asPeer().isUser && state.transaction.count > 0 {
            fromText = strings().starTransactionFrom
        } else {
            fromText = strings().starTransactionTo
        }
        
        rows.append(.init(left: .init(.initialize(string: fromText, color: theme.colors.text, font: .normal(.text))), right: .init(name: from, leftView: { previous in
            let control: AvatarControl
            if let previous = previous as? AvatarControl {
                control = previous
            } else {
                control = AvatarControl(font: .avatar(6))
            }
            control.setFrameSize(NSMakeSize(20, 20))
            control.setPeer(account: arguments.context.account, peer: peer._asPeer())
            return control
        })))
        
        if let messageId = state.transaction.paidMessageId, let peer = state.paidPeer {
            
            let link: String
            if let address = peer.addressName {
                link = "t.me/\(address)/\(messageId.id)"
            } else {
                link = "t.me/c/\(peer.id.id._internalGetInt64Value())/\(messageId.id)"
            }
            
            let messageIdText: TextViewLayout = .init(parseMarkdownIntoAttributedString("[\(link)](\(link))", attributes: MarkdownAttributes(body: MarkdownAttributeSet(font: .code(.text), textColor: theme.colors.text), bold: MarkdownAttributeSet(font: .code(.text), textColor: theme.colors.text), link: MarkdownAttributeSet(font: .normal(.text), textColor: theme.colors.accent), linkAttribute: { contents in
                return (NSAttributedString.Key.link.rawValue, contents)
            })), alwaysStaticItems: true)

            messageIdText.interactions.processURL = { inapplink in
                if let inapplink = inapplink as? String {
                    arguments.openLink(inapplink)
                }
            }
            
            rows.append(.init(left: .init(.initialize(string: strings().starTransactionMessageId, color: theme.colors.text, font: .normal(.text))), right: .init(name: messageIdText)))

        }
    }
    
    let transactionId: TextViewLayout = .init(parseMarkdownIntoAttributedString("[\(state.transaction.id)](\(state.transaction.id))", attributes: MarkdownAttributes(body: MarkdownAttributeSet(font: .code(.text), textColor: theme.colors.text), bold: MarkdownAttributeSet(font: .code(.text), textColor: theme.colors.text), link: MarkdownAttributeSet(font: .code(.text), textColor: theme.colors.text), linkAttribute: { contents in
        return (NSAttributedString.Key.link.rawValue, contents)
    })), alwaysStaticItems: true)
    
    transactionId.interactions.processURL = { inapplink in
        if let inapplink = inapplink as? String {
            arguments.copyTransaction(inapplink)
        }
    }

    
    rows.append(.init(left: .init(.initialize(string: strings().starTransactionId, color: theme.colors.text, font: .normal(.text))), right: .init(name: transactionId)))
    
    rows.append(.init(left: .init(.initialize(string: strings().starTransactionDate, color: theme.colors.text, font: .normal(.text))), right: .init(name: .init(.initialize(string: stringForFullDate(timestamp: state.transaction.date), color: theme.colors.text, font: .normal(.text))))))


    
    entries.append(.custom(sectionId: sectionId, index: index, value: .none, identifier: _id_rows, equatable: .init(state), comparable: nil, item: { initialSize, stableId in
        return InputDataTableBasedItem(initialSize, stableId: stableId, viewType: .singleItem, rows: rows)
    }))
    index += 1
    
  
    
    entries.append(.desc(sectionId: sectionId, index: index, text: .markdown(strings().starTransactionTos, linkHandler: arguments.openLink), data: .init(color: theme.colors.listGrayText, viewType: .singleItem, centerViewAlignment: true, alignment: .center)))
    
    entries.append(.sectionId(sectionId, type: .customModern(10)))
    sectionId += 1

    
    return entries
}

func Star_TransactionScreen(context: AccountContext, peer: EnginePeer?, transaction: StarsContext.State.Transaction) -> InputDataModalController {

    let actionsDisposable = DisposableSet()
    var close:(()->Void)? = nil
    
    var gallery: GallerySupplyment? = nil
    var getTableView:(()->TableView?)? = nil

    
    let initialState = State(transaction: transaction, peer: peer)
    
    let statePromise = ValuePromise(initialState, ignoreRepeated: true)
    let stateValue = Atomic(value: initialState)
    let updateState: ((State) -> State) -> Void = { f in
        statePromise.set(stateValue.modify (f))
    }
    
    if let paidMessageId = transaction.paidMessageId {
        actionsDisposable.add(context.engine.data.get(TelegramEngine.EngineData.Item.Peer.Peer(id: paidMessageId.peerId)).start(next: { peer in
            updateState { current in
                var current = current
                current.paidPeer = peer
                return current
            }
        }))
    }
    
    var getController:(()->ViewController?)? = nil
    
    var window:Window {
        get {
            return bestWindow(context, getController?())
        }
    }

    let arguments = Arguments(context: context, openPeer: { peerId in
        context.bindings.rootNavigation().push(ChatController(context: context, chatLocation: .peer(peerId)))
        close?()
    }, copyTransaction: { string in
        copyToClipboard(string)
        showModalText(for: window, text: strings().starTransactionCopied)
    }, openLink: { link in
        execute(inapp: inApp(for: link.nsstring, context: context, openInfo: { peerId, _, messageId, _ in
            if let messageId = messageId {
                let signal = context.engine.messages.getMessagesLoadIfNecessary([messageId], strategy: .cloud(skipLocal: false)) |> filter {
                    switch $0 {
                    case .progress:
                        return false
                    default:
                        return true
                    }
                } |> take(1)
                _ = showModalProgress(signal: signal, for: window).startStandalone(next: { result in
                    switch result {
                    case let .result(messages):
                        if let _ = messages.first {
                            context.bindings.rootNavigation().push(ChatAdditionController(context: context, chatLocation: .peer(messageId.peerId), focusTarget: .init(messageId: messageId)))
                             closeAllModals()
                        } else {
                            showModalText(for: window, text: strings().chatOpenMessageNotExist)
                        }
                    default:
                        break
                    }
                })
            }
        }))
    }, previewMedia: {
        let medias = stateValue.with { $0.transaction.media }
        let amount = stateValue.with { $0.transaction.count }
        let peer = stateValue.with { $0.peer?._asPeer() }
        if !medias.isEmpty, let peer {
            let message = Message(TelegramMediaPaidContent(amount: amount, extendedMedia: medias.map { .full(media: $0) }), stableId: 0, messageId: .init(peerId: peer.id, namespace: 0, id: 0))
            showPaidMedia(context: context, medias: medias, parent: message, firstIndex: 0, firstStableId: ChatHistoryEntryId.mediaId(0, message), getTableView?(), nil)
        }
    })
    
    let signal = statePromise.get() |> deliverOnPrepareQueue |> map { state in
        return InputDataSignalValue(entries: entries(state, arguments: arguments))
    }
    
    let controller = InputDataController(dataSignal: signal, title: "")
    
    getController = { [weak controller] in
        return controller
    }
    
    controller.didLoad = { controller, _ in
        gallery = .init(tableView: controller.tableView)
        controller.tableView.supplyment = gallery
        getTableView = { [weak controller] in
            return controller?.tableView
        }
    }
    
    controller.onDeinit = {
        actionsDisposable.dispose()
    }

    let modalInteractions = ModalInteractions(acceptTitle: strings().modalDone, accept: {
        close?()
    }, singleButton: true)
    
    let modalController = InputDataModalController(controller, modalInteractions: modalInteractions)
    
    controller.leftModalHeader = ModalHeaderData(image: theme.icons.modalClose, handler: { [weak modalController] in
        modalController?.close()
    })
    
    close = { [weak modalController] in
        modalController?.modal?.close()
    }
    
    return modalController
}


