//
//  EntertainmentViewController.swift
//  Telegram-Mac
//
//  Created by keepcoder on 08/10/2016.
//  Copyright © 2016 Telegram. All rights reserved.
//

import Cocoa
import TGUIKit
import SwiftSignalKitMac
import TelegramCoreMac
import PostboxMac

public final class EntertainmentInteractions {
    
    var current:EntertainmentState = .emoji
    
    var sendEmoji:(String) ->Void = {_ in}
    var sendSticker:(TelegramMediaFile) ->Void = {_ in}
    var sendGIF:(TelegramMediaFile) ->Void = {_ in}
    
    var showEntertainment:(EntertainmentState,Bool)->Void = { _,_  in}
    var close:()->Void = {}

    let peerId:PeerId
    
    init(_ defaultState: EntertainmentState, peerId:PeerId) {
        current = defaultState
        self.peerId = peerId
    }
    
}



class EntertainmentViewController: NavigationViewController {
    private let languageDisposable:MetaDisposable = MetaDisposable()

    private var account:Account
    private var chatInteraction:ChatInteraction?
    private(set) var interactions:EntertainmentInteractions?
    private let cap:SidebarCapViewController
    
    private let section: SectionViewController

    private var disposable:MetaDisposable = MetaDisposable()
    private var locked:Bool = false


    private let emoji:EmojiViewController
    private let stickers:StickersViewController
    private let gifs:GIFViewController
    
    func update(with chatInteraction:ChatInteraction) -> Void {
        self.chatInteraction = chatInteraction
        
        let interactions = EntertainmentInteractions(FastSettings.entertainmentState, peerId: chatInteraction.peerId)

        interactions.close = { [weak self] in
            self?.closePopover()
        }
        interactions.sendSticker = { [weak self] file in
            self?.chatInteraction?.sendAppFile(file)
            self?.closePopover()
        }
        interactions.sendGIF = { [weak self] file in
            self?.chatInteraction?.sendAppFile(file)
            self?.closePopover()
        }
        interactions.sendEmoji = { [weak self] emoji in
            _ = self?.chatInteraction?.appendText(emoji)
        }
        
        self.interactions = interactions
        
        emoji.update(with: interactions)
        stickers.update(with: interactions, chatInteraction: chatInteraction)
        gifs.update(with: interactions, chatInteraction: chatInteraction)
    }
    

    func closedBySide() {
        self.viewWillDisappear(false)
    }
    
    init(size:NSSize, account:Account) {
        
        self.account = account
        self.cap = SidebarCapViewController(account: account)
        self.emoji = EmojiViewController(account)
        self.stickers = StickersViewController(account:account)
        self.gifs = GIFViewController(account: account)
        
        var items:[SectionControllerItem] = []
        items.append(SectionControllerItem(title:{L10n.entertainmentEmoji.uppercased()}, controller: emoji))
        items.append(SectionControllerItem(title: {L10n.entertainmentStickers.uppercased()}, controller: stickers))
        items.append(SectionControllerItem(title: {L10n.entertainmentGIF.uppercased()}, controller: gifs))
        self.section = SectionViewController(sections: items, selected: Int(FastSettings.entertainmentState.rawValue))
        super.init(section)
        bar = .init(height: 0)
    }
    


    override func updateLocalizationAndTheme() {
        super.updateLocalizationAndTheme()
        self.section.updateLocalizationAndTheme()
        self.view.background = theme.colors.background
        emoji.view.background = theme.colors.background
        stickers.view.background = theme.colors.background
        gifs.view.background = theme.colors.background
    }
    
    deinit {
        languageDisposable.dispose()
        disposable.dispose()
    }

    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        section.viewWillAppear(animated)
    }
    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        section.viewWillDisappear(animated)
    }
    
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        section.viewDidAppear(animated)
    }
    override func viewDidDisappear(_ animated: Bool) {
        super.viewDidDisappear(animated)
        section.viewDidDisappear(animated)
    }
    

    
    override func viewDidLoad() {
        super.viewDidLoad()
        cap.loadViewIfNeeded()

        
        let contentRect = NSMakeRect(0, 0, frame.width, frame.height)
        
        
        emoji._frameRect = NSMakeRect(0, 0, frame.width, frame.height - 50)
        stickers._frameRect = NSMakeRect(0, 0, frame.width, frame.height - 50)
        
        
        section.selectionUpdateHandler = { [weak self] index in
            FastSettings.changeEntertainmentState(EntertainmentState(rawValue: Int32(index))!)
            self?.chatInteraction?.update({$0.withUpdatedIsEmojiSection(index == 0)})
        }

        section._frameRect = contentRect
        addSubview(section.view)

        self.ready.set(section.ready.get())
        
        languageDisposable.set((combineLatest(appearanceSignal, ready.get() |> filter {$0} |> take(1))).start(next: { [weak self] _ in
            self?.updateLocalizationAndTheme()
        }))
    }
    
    

    
}

