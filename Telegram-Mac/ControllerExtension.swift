//
//  TelegramTableViewController.swift
//  Telegram
//
//  Created by keepcoder on 26/05/2017.
//  Copyright © 2017 Telegram. All rights reserved.
//

import Cocoa
import TelegramCoreMac
import PostboxMac
import SwiftSignalKitMac
import TGUIKit

class TelegramGenericViewController<T>: GenericViewController<T> where T:NSView {

    let account:Account
    private let languageDisposable:MetaDisposable = MetaDisposable()
    init(_ account:Account) {
        self.account = account
        super.init()
    }
    
    
    override func viewDidLoad() {
        super.viewDidLoad()
        let ignore:Atomic<Bool> = Atomic(value: true)
        languageDisposable.set(combineLatest(appearanceSignal, ready.get() |> deliverOnMainQueue |> take(1)).start(next: { [weak self] _ in
            if !ignore.swap(false) {
                self?.updateLocalizationAndTheme()
            }
        }))
    }
    
    override func updateLocalizationAndTheme() {
        super.updateLocalizationAndTheme()
        
        self.genericView.background = theme.colors.background
        requestUpdateBackBar()
        requestUpdateCenterBar()
        requestUpdateRightBar()
    }
    
    deinit {
        languageDisposable.dispose()
    }
}

class TelegramViewController: TelegramGenericViewController<NSView> {
    
}




class TableViewController: TelegramGenericViewController<TableView>, TableViewDelegate {
    
   
    
    override func loadView() {
        super.loadView()
        genericView.delegate = self
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
    }
    
    
    func selectionDidChange(row:Int, item:TableRowItem, byClick:Bool, isNew:Bool) -> Void {
        
    }
    func selectionWillChange(row:Int, item:TableRowItem) -> Bool {
        return false
    }
    func isSelectable(row:Int, item:TableRowItem) -> Bool {
        return false
    }
    func findGroupStableId(for stableId: AnyHashable) -> AnyHashable? {
        return nil
    }
    
    override var enableBack: Bool {
        return true
    }
    
}


public enum ViewControllerState : Equatable {
    case Edit
    case Normal
    case Some
}


class EditableViewController<T>: TelegramGenericViewController<T> where T: NSView {
    
    
    var editBar:TextButtonBarView!
    
    public var state:ViewControllerState = .Normal {
        didSet {
            if state != oldValue {
                updateEditStateTitles()
            }
        }
    }
    
    override func getRightBarViewOnce() -> BarView {
        return editBar
    }
    
    override var enableBack: Bool {
        return true
    }
    
    func changeState() ->Void {
        
        if case .Normal = state {
            self.state = .Edit
        } else {
            self.state = .Normal
        }
        
        update(with:state)
    }
    
    var doneString:String {
        return localizedString("Navigation.Done")
    }
    var normalString:String {
        return localizedString("Navigation.Edit")
    }
    var someString:String {
        return localizedString("Navigation.Some")
    }
    
    var doneImage:CGImage? {
        return nil
    }
    var normalImage:CGImage? {
        return nil
    }
    var someImage:CGImage? {
        return nil
    }
    
    func updateEditStateTitles() -> Void {
        switch state {
        case .Edit:
            editBar.set(text: doneString, for: .Normal)
        case .Normal:
            editBar.set(text: normalString, for: .Normal)
        case .Some:
            editBar.set(text: someString, for: .Normal)
        }
        editBar.set(color: presentation.colors.blueUI, for: .Normal)
        self.editBar.needsLayout = true
    }
    
    override func requestUpdateRightBar() {
        super.requestUpdateRightBar()
        updateEditStateTitles()
    }
    
    func addHandler() -> Void {
        editBar.set (handler:{[weak self] _ in
            if let strongSelf = self {
                strongSelf.changeState()
            }
        }, for:.Click)
    }
    
    override init(_ account:Account) {
        super.init(account)
        editBar = TextButtonBarView(controller: self, text: "", style: navigationButtonStyle, alignment:.Right)
        addHandler()
    }

    func update(with state:ViewControllerState) -> Void {
        updateEditStateTitles()
    }
    
    public func set(editable: Bool) ->Void {
        editBar.isHidden = !editable
    }
    
    public func set(enabled: Bool) ->Void {
        editBar.isEnabled = enabled
    }
    
    override func updateNavigation(_ navigation: NavigationViewController?) {
        super.updateNavigation(navigation)
        if navigation != nil {
            rightBarView = editBar
            updateEditStateTitles()
        }
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
    }
    
}

final class Appearance : Equatable {
    let language:Language
    var presentation: TelegramPresentationTheme
    init(language: Language, presentation: TelegramPresentationTheme) {
        self.language = language
        self.presentation = presentation
    }
    
    var newAllocation: Appearance {
        return Appearance(language: language, presentation: presentation)
    }
}

func ==(lhs:Appearance, rhs:Appearance) -> Bool {
    return lhs === rhs //lhs.language === rhs.language && lhs.presentation === rhs.presentation
}

var theme: TelegramPresentationTheme {
    if let presentation = presentation as? TelegramPresentationTheme {
        return presentation
    }
    setDefaultTheme()
    return presentation as! TelegramPresentationTheme
}

var appAppearance:Appearance {
    return Appearance(language: appCurrentLanguage, presentation: theme)
}

var appearanceSignal:Signal<Appearance, Void> {
    return combineLatest(languageSignal, themeSignal) |> map {
        return Appearance(language: $0.0, presentation: $0.1)
    }
}

struct AppearanceWrapperEntry<E>: Comparable, Identifiable where E: Comparable, E:Identifiable {
    let entry: E
    let appearance: Appearance
    
    var stableId: AnyHashable {
        return entry.stableId
    }
}

func == <E>(lhs:AppearanceWrapperEntry<E>, rhs: AppearanceWrapperEntry<E>) -> Bool {
    return lhs.entry == rhs.entry && lhs.appearance == rhs.appearance
}
func < <E>(lhs:AppearanceWrapperEntry<E>, rhs: AppearanceWrapperEntry<E>) -> Bool {
    return lhs.entry < rhs.entry
}

