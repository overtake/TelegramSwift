//
//  StickersPackPreviewModalController.swift
//  Telegram
//
//  Created by keepcoder on 27/02/2017.
//  Copyright © 2017 Telegram. All rights reserved.
//

import Cocoa
import TGUIKit
import PostboxMac
import TelegramCoreMac
import SwiftSignalKitMac
import MtProtoKitMac



final class StickerPackArguments {
    let account: Account
    let send:(TelegramMediaFile)->Void
    let addpack:(StickerPackCollectionInfo, [ItemCollectionItem], Bool)->Void
    let share:(String)->Void
    let close:()->Void
    init(account:Account, send:@escaping(Media)->Void, addpack:@escaping(StickerPackCollectionInfo, [ItemCollectionItem], Bool)->Void, share:@escaping(String)->Void, close:@escaping()->Void) {
        self.account = account
        self.send = send
        self.addpack = addpack
        self.share = share
        self.close = close
    }
}



private class StickersModalView : View {
    private let grid:GridNode = GridNode(frame: NSZeroRect)
    private let add:TitleButton = TitleButton()
    private let shareView:ImageButton = ImageButton()
    private let close: ImageButton = ImageButton()
    private let headerTitle:TextView = TextView()
    private let headerSeparatorView:View = View()
    private let dismiss:ImageButton = ImageButton()
    private let indicatorView:ProgressIndicator = ProgressIndicator(frame: NSMakeRect(0, 0, 25, 25))
    private let shadowView: ShadowView = ShadowView()
    required init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        backgroundColor = theme.colors.background
        addSubview(grid)
        //addSubview(interactionView)
        addSubview(headerTitle)
        addSubview(shareView)
        addSubview(close)
        addSubview(headerSeparatorView)
        addSubview(dismiss)
        
        shadowView.shadowBackground = theme.colors.background
        shadowView.setFrameSize(frame.width, 70)
        
        addSubview(shadowView)
        
        dismiss.set(image: theme.icons.stickerPackDelete, for: .Normal)
        _ = dismiss.sizeToFit()
        add.disableActions()
        add.setFrameSize(170, 40)
        add.layer?.cornerRadius = 20
        
        add.set(color: .white, for: .Normal)
        add.set(font: .medium(.title), for: .Normal)
        add.set(background: theme.colors.blueFill, for: .Normal)
        add.set(background: theme.colors.blueFill, for: .Hover)
        add.set(background: theme.colors.blueFill, for: .Highlight)
        add.set(text: tr(L10n.stickerPackAdd1Countable(0)), for: .Normal)

        addSubview(add)
        headerTitle.backgroundColor = theme.colors.background
        headerSeparatorView.backgroundColor = theme.colors.border
        
        shareView.set(image: theme.icons.stickersShare, for: .Normal)
        close.set(image: theme.icons.stickerPackClose, for: .Normal)
        _ = shareView.sizeToFit()
        _ = close.sizeToFit()
        
        
    }
    
    
    func layout(with result: LoadedStickerPack, arguments: StickerPackArguments) -> Void {
        

        switch result {
        case .none:
            break
        case .fetching:
            dismiss.isHidden = true
            shareView.isHidden = true
            addSubview(indicatorView)
            indicatorView.isHidden = false
            indicatorView.center()
            add.isHidden = true
            shadowView.isHidden = true
            indicatorView.animates = true
        case let .result(info: info, items: collectionItems, installed: installed):
            indicatorView.isHidden = true
            indicatorView.removeFromSuperview()
            dismiss.isHidden = !installed
            shareView.isHidden = false
            add.set(text: tr(L10n.stickerPackAdd1Countable(collectionItems .count)).uppercased(), for: .Normal)
            _ = add.sizeToFit(NSMakeSize(20, 0), NSMakeSize(frame.width - 40, 40), thatFit: false)
            add.isHidden = installed
            shadowView.isHidden = installed
            let attr = NSMutableAttributedString()
            
            _ = attr.append(string: info.title, color: theme.colors.text, font: .medium(16.0))
            attr.detectLinks(type: [.Mentions], account: arguments.account, color: .blueUI, openInfo: { (peerId, _, _, _) in
                _ = (arguments.account.postbox.loadedPeerWithId(peerId) |> deliverOnMainQueue).start(next: { peer in
                    arguments.close()
                    if peer.isUser || peer.isBot {
                        arguments.account.context.mainNavigation?.push(PeerInfoController(account: arguments.account, peer: peer))
                    } else {
                        arguments.account.context.mainNavigation?.push(ChatAdditionController(account: arguments.account, chatLocation: .peer(peer.id)))
                    }
                })
            })
            let layout = TextViewLayout(attr, maximumNumberOfLines: 2, alignment: .center)
            layout.interactions = globalLinkExecutor
            
            
            layout.measure(width: frame.width - 160)
            headerTitle.update(layout)
            
            let items = collectionItems.filter({ item -> Bool in
                return item is StickerPackItem
            }).map ({ item -> StickerPackGridItem in
                return StickerPackGridItem(account: arguments.account, file: (item as! StickerPackItem).file, send: arguments.send, selected: {})
            })
            
            var insert:[GridNodeInsertItem] = []
            
            for index in 0 ..< items.count {
                insert.append(GridNodeInsertItem(index: index, item: items[index], previousIndex: nil))
            }
            
            grid.removeAllItems()
            
            grid.transaction(GridNodeTransaction(deleteItems: [], insertItems: insert, updateItems: [], scrollToItem: nil, updateLayout: GridNodeUpdateLayout(layout: GridNodeLayout(size: CGSize(width: frame.width, height: frame.height), insets: NSEdgeInsets(left: 0, right: 0, top: 10, bottom: installed ? 0 : 60), preloadSize: self.bounds.width, type: .fixed(itemSize: CGSize(width: 80, height: 80), lineSpacing: 10)), transition: .immediate), itemTransition: .immediate, stationaryItems: .all, updateFirstIndexInSectionOffset: nil), completion: { _ in })
            
            grid.layer?.animateAlpha(from: 0, to: 1, duration: 0.2)
            self.needsLayout = true
            
            
            
            shareView.set(handler: { _ in
                arguments.share("https://t.me/addstickers/\(info.shortName)")
            }, for: .SingleClick)
            
            add.removeAllHandlers()
            dismiss.removeAllHandlers()
            close.removeAllHandlers()
            
            func action(_ control:Control) {
                arguments.addpack(info, collectionItems, installed)
            }
            
            
            add.set(handler: action, for: .SingleClick)
            dismiss.set(handler: action, for: .SingleClick)

            close.set(handler: { _ in
                arguments.close()
            }, for: .Click)
            
        }
        
       
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override func layout() {
        super.layout()
        
        let headerHeight:CGFloat = 50
        
        grid.frame = NSMakeRect(0, headerHeight, frame.width, frame.height - headerHeight)
        
        headerTitle.centerX(y : floorToScreenPixels(scaleFactor: backingScaleFactor, (headerHeight - headerTitle.frame.height)/2) + 1)
        headerSeparatorView.frame = NSMakeRect(0, headerHeight - .borderSize, frame.width, .borderSize)
        shareView.setFrameOrigin(frame.width - close.frame.width - 12, floorToScreenPixels(scaleFactor: backingScaleFactor, (headerHeight - shareView.frame.height)/2))
        close.setFrameOrigin(12, floorToScreenPixels(scaleFactor: backingScaleFactor, (headerHeight - shareView.frame.height)/2))
        add.centerX(y: frame.height - add.frame.height - 15)
        dismiss.setFrameOrigin(NSMakePoint(shareView.frame.minX - dismiss.frame.width - 15, floorToScreenPixels(scaleFactor: backingScaleFactor, (headerHeight - shareView.frame.height)/2)))
        
        shadowView.setFrameOrigin(0, frame.height - shadowView.frame.height)
    }
}



class StickersPackPreviewModalController: ModalViewController {
    private let account:Account
    private let peerId:PeerId?
    private let reference:StickerPackReference
    private let disposable: MetaDisposable = MetaDisposable()
    private var arguments:StickerPackArguments!
   
    init(_ account:Account, peerId:PeerId?, reference:StickerPackReference) {
        self.account = account
        self.peerId = peerId
        self.reference = reference
        super.init(frame: NSMakeRect(0, 0, 360, 400))
        bar = .init(height: 0)
        arguments = StickerPackArguments(account: account, send: { [weak self] media in
            self?.close()
            if let peerId = peerId, let strongSelf = self {
                
                var attributes:[MessageAttribute] = []
                if FastSettings.isChannelMessagesMuted(peerId) {
                    attributes.append(NotificationInfoMessageAttribute(flags: [.muted]))
                }
                
                _ = (strongSelf.account.postbox.loadedPeerWithId(peerId) |> filter {$0.canSendMessage && !$0.stickersRestricted} |> mapToSignal { _ in
                    return enqueueMessages(account: account, peerId: peerId, messages: [EnqueueMessage.message(text: "", attributes: attributes, media: media, replyToMessageId: nil, localGroupingKey: nil)])
                }) .start()
                
            }
        }, addpack: { [weak self] info, items, installed in
            self?.close()
            self?.disposable.dispose()
            //installStickerSetInteractively(account: account, info: info, items: items)
            _ = (!installed ? addStickerPackInteractively(postbox: account.postbox, info: info, items: items) : removeStickerPackInteractively(postbox: account.postbox, id: info.id)).start()
        }, share: { [weak self] link in
            self?.close()
            showModal(with: ShareModalController(ShareLinkObject(account, link: link)), for: mainWindow)
        }, close: { [weak self] in
            self?.close()
        })
    }
    
    fileprivate var genericView:StickersModalView {
        return self.view as! StickersModalView
    }
    
    override func viewClass() -> AnyClass {
        return StickersModalView.self
    }
    
    
    override var dynamicSize: Bool {
        return true
    }
    
    
    override func measure(size: NSSize) {
       // self.modal?.resize(with:NSMakeSize(genericView.frame.width, min(size.height - 70, genericView.listHeight)), animated: false)
    }
    
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        
        disposable.set((loadedStickerPack(postbox: account.postbox, network: account.network, reference: reference) |> deliverOnMainQueue).start(next: { [weak self] result in
            guard let `self` = self else {return}
            switch result {
            case .none:
                alert(for: mainWindow, info: L10n.stickerSetDontExist)
                self.close()
            default:
                self.genericView.layout(with: result, arguments: self.arguments)
                self.readyOnce()
            }

        }))

    }
    
    deinit {
        disposable.dispose()
    }
    
}
