//
//  HashtagSearchController.swift
//  Telegram
//
//  Created by Mikhail Filimonov on 10.05.2024.
//  Copyright © 2024 Telegram. All rights reserved.
//

import AppKit
import TGUIKit
import TelegramCore
import Postbox
import SwiftSignalKit
import TelegramMedia


//TODOLANG
private final class CenterView : TitledBarView {
    let segment: CatalinaStyledSegmentController
    var select:((Int)->Void)? = nil
    init(controller: ViewController) {
        self.segment = CatalinaStyledSegmentController(frame: NSMakeRect(0, 0, 240, 30))
        super.init(controller: controller)
        
        segment.add(segment: .init(title: "This Chat", handler: { [weak self] in
            self?.select?(0)
        }))
        
        segment.add(segment: .init(title: "My Messages", handler: { [weak self] in
            self?.select?(1)
        }))
        
        segment.add(segment: .init(title: "Public Posts", handler: { [weak self] in
            self?.select?(2)
        }))
        
        self.addSubview(segment.view)
        
        updateLocalizationAndTheme(theme: theme)
    }
    
    override func updateLocalizationAndTheme(theme: PresentationTheme) {
        super.updateLocalizationAndTheme(theme: theme)
        
        segment.theme = CatalinaSegmentTheme(backgroundColor: theme.colors.listBackground, foregroundColor: theme.colors.background, activeTextColor: theme.colors.text, inactiveTextColor: theme.colors.listGrayText)

    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    required init(frame frameRect: NSRect) {
        fatalError("init(frame:) has not been implemented")
    }
    
    override func layout() {
        super.layout()
        segment.view.frame = focus(NSMakeSize(min(frame.width - 40, 600), 30))
    }
}


final class HashtagSearchView: View {
    
    private final class Search : View {
        
    }
    
    private let tableView = TableView()
    private let search = Search()
    required init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        addSubview(tableView)
        addSubview(search)
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}

final class HashtagSearchController : SectionViewController {
    private let hashtag: String
    private let peerId: PeerId
    private let context: AccountContext
    
    private let thisChat: ViewController
    private let myMessages: ViewController
    private let publicPosts: ViewController

    
    init(_ context: AccountContext, hashtag: String, peerId: PeerId) {
        self.hashtag = hashtag
        self.peerId = peerId
        self.context = context
        
        self.thisChat = ChatController(context: context, chatLocation: .peer(peerId), mode: .searchHashtags(initial: hashtag))
        self.myMessages = ChatController(context: context, chatLocation: .peer(peerId), mode: .searchHashtags(initial: hashtag))
        self.publicPosts = ChatController(context: context, chatLocation: .peer(peerId), mode: .searchHashtags(initial: hashtag))
        
        var items:[SectionControllerItem] = []
        items.append(SectionControllerItem(title: { "" }, controller: thisChat))
        items.append(SectionControllerItem(title: { "" }, controller: myMessages))
        items.append(SectionControllerItem(title: { "" }, controller: publicPosts))

        super.init(sections: items, selected: 0, hasHeaderView: false, hasBar: true)
    }
    
    
    override func getCenterBarViewOnce() -> TitledBarView {
        return CenterView(controller: self)
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        
        centerView.select = { [weak self] index in
            self?.select(index, true)
        }
        
        self.selectionUpdateHandler = { [weak self] index in
            self?.centerView.segment.set(selected: index, animated: true)
        }
        
        readyOnce()
    }
    
    private var centerView: CenterView {
        return self.centerBarView as! CenterView
    }
    
    
    override var enableBack: Bool {
        return true
    }
}

